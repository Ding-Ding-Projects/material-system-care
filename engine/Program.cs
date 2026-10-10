using System.IO.Pipes;
using System.Security.Principal;
using System.Text;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

public static class Program
{
    public const int MaximumRequestBytes = 4 * 1024 * 1024;
    public const int MaximumResponseBytes = 4 * 1024 * 1024;
    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly (Type Type, string[] Methods)[] ModuleInventory = [
        (typeof(SystemModule), ["engine.ping", "system.snapshot", "settings.get", "settings.save", "history.list"]),
        (typeof(CrashDiagnosticsModule), ["diagnostics.crashes", "diagnostics.explainStopCode"]),
        (typeof(StorageModule), ["storage.analyze", "storage.duplicates", "cleanup.scan", "cleanup.apply", "cleanup.restore", "cleanup.history"]),
        (typeof(ManagementModule), ["apps.list", "apps.managed", "apps.updates", "apps.upgrade", "apps.uninstall", "startup.list", "startup.set", "processes.list", "processes.stop", "services.list"]),
        (typeof(ProtectionModule), ["security.status", "security.scan", "drivers.list", "drivers.export", "drivers.install", "network.diagnostics", "files.lockOwners"]),
        (typeof(UtilitiesModule), ["files.hash", "files.convert", "password.generate", "tools.catalogue", "providers.list", "providers.configure", "providers.invoke", "utilities.calculate"])
    ];
    public static string[] Capabilities => ModuleInventory.SelectMany(entry => entry.Methods).Order(StringComparer.Ordinal).ToArray();
    public static IEngineModule[] CreateModules() => ModuleInventory.Select(entry => (IEngineModule)Activator.CreateInstance(entry.Type)!).ToArray();
    public static async Task<int> Main(string[] args)
    {
        using var shutdown = new CancellationTokenSource();
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; shutdown.Cancel(); };
        try {
            string? Option(string name) { var i = Array.IndexOf(args, name); if (i < 0) return null; if (i + 1 >= args.Length) throw new EngineException("INVALID_ARGUMENT", "An option value is missing."); return args[i + 1]; }
            var context = new EngineContext(Option("--data-root"));
            var modules = CreateModules();
            if (Option("--request-file") is { } file) {
                await using var input = File.OpenRead(file);
                var request = await ReadLineAsync(input, shutdown.Token);
                Console.WriteLine(await DispatchAsync(request, context, modules, shutdown.Token)); return 0;
            }
            if (args.Contains("--stdio")) { await ServeAsync(Console.OpenStandardInput(), Console.OpenStandardOutput(), context, modules, shutdown.Token); return 0; }
            var sid = WindowsIdentity.GetCurrent().User?.Value ?? throw new InvalidOperationException("No local user identity is available.");
            using var slots = new SemaphoreSlim(16);
            var clients = new List<Task>();
            while (!shutdown.IsCancellationRequested) {
                await slots.WaitAsync(shutdown.Token);
                var pipe = new NamedPipeServerStream("MaterialSystemCare." + sid, PipeDirection.InOut, 16, PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                try { await pipe.WaitForConnectionAsync(shutdown.Token); }
                catch { pipe.Dispose(); slots.Release(); throw; }
                clients.RemoveAll(t => t.IsCompleted);
                clients.Add(Task.Run(async () => { await using (pipe) { try { await ServeAsync(pipe, pipe, context, modules, shutdown.Token); } catch (IOException) { } catch (OperationCanceledException) { } } slots.Release(); }));
            }
            await Task.WhenAll(clients); return 0;
        } catch (OperationCanceledException) { return 0; }
        catch { Console.Error.WriteLine("Engine startup failed. Check local storage availability and supported runtime."); return 1; }
    }
    public static Task<string?> ReadLineAsync(Stream input, CancellationToken ct) => new RequestLineReader(input).ReadLineAsync(ct);
    public sealed class RequestLineReader(Stream input)
    {
        private readonly byte[] chunk = new byte[16 * 1024];
        private int offset, count;
        public async Task<string?> ReadLineAsync(CancellationToken ct)
        {
            using var line = new MemoryStream();
            while (true) {
                ct.ThrowIfCancellationRequested();
                if (offset == count) {
                    count = await input.ReadAsync(chunk, ct); offset = 0;
                    if (count == 0) break;
                }
                var newline = Array.IndexOf(chunk, (byte)10, offset, count - offset);
                var take = (newline < 0 ? count : newline) - offset;
                if (take > MaximumRequestBytes - line.Length) throw new EngineException("REQUEST_TOO_LARGE", "The request exceeds 4 MiB.");
                line.Write(chunk, offset, take); offset += take;
                if (newline >= 0) { offset++; break; }
            }
            if (line.Length == 0) return null;
            try { return new UTF8Encoding(false, true).GetString(line.GetBuffer(), 0, checked((int)line.Length)).TrimEnd('\r'); }
            catch (DecoderFallbackException) { throw new EngineException("INVALID_REQUEST", "The request is not valid UTF-8."); }
        }
    }
    private static async Task ServeAsync(Stream input, Stream output, EngineContext context, IEngineModule[] modules, CancellationToken ct)
    {
        using var connection = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var reader = new RequestLineReader(input);
        var pendingRead = reader.ReadLineAsync(connection.Token);
        while (!ct.IsCancellationRequested) {
            string? request;
            try { request = await pendingRead; }
            catch (EngineException e) { await WriteAsync(output, Error(null, e.Code, e.Message), ct); return; }
            if (request == null) return;
            pendingRead = reader.ReadLineAsync(connection.Token);
            if (input is NamedPipeServerStream) {
                _ = pendingRead.ContinueWith(t => {
                    if (t.IsFaulted || t.IsCanceled || (t.IsCompletedSuccessfully && t.Result == null)) connection.Cancel();
                }, CancellationToken.None, TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
            }
            await WriteAsync(output, await DispatchAsync(request, context, modules, connection.Token), ct);
        }
    }
    private static async Task WriteAsync(Stream output, string response, CancellationToken ct) { await output.WriteAsync(Encoding.UTF8.GetBytes(response + "\n"), ct); await output.FlushAsync(ct); }
    private static string Error(string? id, string code, string message) => JsonSerializer.Serialize(new { version = 1, id, ok = false, error = new { code, message } }, JsonOptions);
    private sealed class BoundedResponseStream : MemoryStream
    {
        private void CheckLength(int count) { if (count > MaximumResponseBytes - Length) throw new EngineException("RESULT_TOO_LARGE", "The result exceeds the 4 MiB response limit. Narrow the requested scope or request an individual record."); }
        public override void Write(byte[] buffer, int offset, int count) { CheckLength(count); base.Write(buffer, offset, count); }
        public override void Write(ReadOnlySpan<byte> buffer) { CheckLength(buffer.Length); base.Write(buffer); }
        public override void WriteByte(byte value) { CheckLength(1); base.WriteByte(value); }
    }
    public static string SerializeSuccessResponse(string id, object? result)
    {
        using var output = new BoundedResponseStream();
        JsonSerializer.Serialize(output, new { version = 1, id, ok = true, result }, JsonOptions);
        return Encoding.UTF8.GetString(output.GetBuffer(), 0, checked((int)output.Length));
    }
    public static async Task<string> DispatchAsync(string? request, EngineContext context, IEngineModule[] modules, CancellationToken ct)
    {
        string? id = null;
        try {
            if (request == null || Encoding.UTF8.GetByteCount(request) > MaximumRequestBytes) throw new EngineException("INVALID_REQUEST", "A bounded JSON request is required.");
            using var document = JsonDocument.Parse(request, new JsonDocumentOptions { MaxDepth = 32 }); var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_REQUEST", "The request must be an object.");
            if (root.TryGetProperty("id", out var requestId) && requestId.ValueKind == JsonValueKind.String && requestId.GetString()!.Length <= 128) id = requestId.GetString();
            if (id == null || !root.TryGetProperty("version", out var version) || version.ValueKind != JsonValueKind.Number || !version.TryGetInt32(out var v) || v != 1 || !root.TryGetProperty("method", out var methodValue) || methodValue.ValueKind != JsonValueKind.String || !root.TryGetProperty("params", out var parameters) || parameters.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_REQUEST", "Version 1, a bounded id, method, and object parameters are required.");
            var method = methodValue.GetString()!;
            if (method.Length is < 1 or > 128 || method.Any(c => !(char.IsAsciiLetterOrDigit(c) || c is '.' or '_'))) throw new EngineException("INVALID_REQUEST", "The method name is invalid.");
            var owner = ModuleInventory.FirstOrDefault(entry => entry.Methods.Contains(method, StringComparer.Ordinal)).Type;
            var module = owner == null ? null : modules.FirstOrDefault(m => owner.IsInstanceOfType(m) && m.CanHandle(method));
            if (module == null) throw new EngineException("METHOD_NOT_FOUND", "The requested capability is not available.");
            var result = await module.HandleAsync(method, parameters, context, ct);
            return SerializeSuccessResponse(id, result);
        } catch (EngineException e) { return Error(id, e.Code, e.Message); }
        catch (OperationCanceledException) { return Error(id, "CANCELLED", "The operation was cancelled."); }
        catch (JsonException) { return Error(id, "INVALID_REQUEST", "The request contains invalid JSON."); }
        catch { return Error(id, "OPERATION_FAILED", "The operation could not be completed. Check access and local resource availability."); }
    }
}
