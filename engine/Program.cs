using System.IO.Pipes;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

public static class Program
{
    public const int MaximumRequestBytes = 4 * 1024 * 1024;
    public static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    public static async Task<int> Main(string[] args)
    {
        using var shutdown = new CancellationTokenSource();
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; shutdown.Cancel(); };
        try {
            string? Option(string name) { var i = Array.IndexOf(args, name); if (i < 0) return null; if (i + 1 >= args.Length) throw new EngineException("INVALID_ARGUMENT", "An option value is missing."); return args[i + 1]; }
            var context = new EngineContext(Option("--data-root"));
            var modules = Assembly.GetExecutingAssembly().GetTypes().Where(t => !t.IsAbstract && typeof(IEngineModule).IsAssignableFrom(t) && t.GetConstructor(Type.EmptyTypes) != null).Select(t => (IEngineModule)Activator.CreateInstance(t)!).ToArray();
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
    public static async Task<string?> ReadLineAsync(Stream input, CancellationToken ct)
    {
        using var buffer = new MemoryStream(); var one = new byte[1];
        while (await input.ReadAsync(one, ct) != 0) {
            if (one[0] == 10) break;
            if (buffer.Length >= MaximumRequestBytes) throw new EngineException("REQUEST_TOO_LARGE", "The request exceeds 4 MiB.");
            buffer.WriteByte(one[0]);
        }
        if (buffer.Length == 0) return null;
        try { return new UTF8Encoding(false, true).GetString(buffer.ToArray()).TrimEnd('\r'); }
        catch (DecoderFallbackException) { throw new EngineException("INVALID_REQUEST", "The request is not valid UTF-8."); }
    }
    private static async Task ServeAsync(Stream input, Stream output, EngineContext context, IEngineModule[] modules, CancellationToken ct)
    {
        using var connection = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var pendingRead = ReadLineAsync(input, connection.Token);
        while (!ct.IsCancellationRequested) {
            string? request;
            try { request = await pendingRead; }
            catch (EngineException e) { await WriteAsync(output, Error(null, e.Code, e.Message), ct); return; }
            if (request == null) return;
            pendingRead = ReadLineAsync(input, connection.Token);
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
    public static async Task<string> DispatchAsync(string? request, EngineContext context, IEngineModule[] modules, CancellationToken ct)
    {
        string? id = null;
        try {
            if (request == null || Encoding.UTF8.GetByteCount(request) > MaximumRequestBytes) throw new EngineException("INVALID_REQUEST", "A bounded JSON request is required.");
            using var document = JsonDocument.Parse(request, new JsonDocumentOptions { MaxDepth = 32 }); var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_REQUEST", "The request must be an object.");
            if (root.TryGetProperty("id", out var requestId) && requestId.ValueKind == JsonValueKind.String && requestId.GetString()!.Length <= 128) id = requestId.GetString();
            if (id == null || !root.TryGetProperty("version", out var version) || !version.TryGetInt32(out var v) || v != 1 || !root.TryGetProperty("method", out var methodValue) || methodValue.ValueKind != JsonValueKind.String || !root.TryGetProperty("params", out var parameters) || parameters.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_REQUEST", "Version 1, a bounded id, method, and object parameters are required.");
            var method = methodValue.GetString()!;
            if (method.Length is < 1 or > 128 || method.Any(c => !(char.IsAsciiLetterOrDigit(c) || c is '.' or '_'))) throw new EngineException("INVALID_REQUEST", "The method name is invalid.");
            var module = modules.FirstOrDefault(m => m.CanHandle(method)) ?? throw new EngineException("METHOD_NOT_FOUND", "The requested capability is not available.");
            var result = await module.HandleAsync(method, parameters, context, ct);
            return JsonSerializer.Serialize(new { version = 1, id, ok = true, result }, JsonOptions);
        } catch (EngineException e) { return Error(id, e.Code, e.Message); }
        catch (OperationCanceledException) { return Error(id, "CANCELLED", "The operation was cancelled."); }
        catch (JsonException) { return Error(id, "INVALID_REQUEST", "The request contains invalid JSON."); }
        catch { return Error(id, "OPERATION_FAILED", "The operation could not be completed. Check access and local resource availability."); }
    }
}
