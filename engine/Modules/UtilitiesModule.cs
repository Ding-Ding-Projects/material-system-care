using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Net;

namespace MaterialSystemCare.Engine;

/// <summary>Bounded, local utilities. No operation reads existing credentials.</summary>
public sealed class UtilitiesModule : IEngineModule
{
    private const long MaxFile = 64L * 1024 * 1024;
    private static readonly HttpClient Client = new(new HttpClientHandler { AllowAutoRedirect = false, UseProxy = false }) { Timeout = TimeSpan.FromSeconds(60) };
    public bool CanHandle(string method) => method is "files.hash" or "files.convert" or "password.generate" or "tools.catalogue" or "providers.list" or "providers.configure" or "providers.invoke" or "utilities.calculate";
    private static string Text(JsonElement p, string key, int max = 4096)
    {
        if (!p.TryGetProperty(key, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()) || value.GetString()!.Length > max) throw new ArgumentException($"Invalid {key}.");
        return value.GetString()!;
    }
    private static void Confirm(JsonElement p)
    {
        if (!p.TryGetProperty("confirmed", out var v) || v.ValueKind != JsonValueKind.True) throw new ArgumentException("Explicit confirmation is required.");
    }
    private static FileStream OpenInput(string path)
    {
        var file = new FileStream(Path.GetFullPath(path), FileMode.Open, FileAccess.Read, FileShare.Read, 65536, true);
        if (file.Length > MaxFile) { file.Dispose(); throw new ArgumentException("File exceeds the 64 MiB limit."); }
        return file;
    }
    public async Task<object?> HandleAsync(string method, JsonElement p, EngineContext context, CancellationToken ct)
    {
        switch (method)
        {
            case "files.hash":
                await using (var input = OpenInput(Text(p, "path")))
                {
                    var algorithm = p.TryGetProperty("algorithm", out var a) ? a.GetString() : "SHA256";
                    byte[] digest = algorithm switch {
                        "SHA256" => await SHA256.HashDataAsync(input, ct),
                        "SHA384" => await SHA384.HashDataAsync(input, ct),
                        "SHA512" => await SHA512.HashDataAsync(input, ct),
                        _ => throw new ArgumentException("Supported algorithms: SHA256, SHA384, SHA512.") };
                    return new { algorithm, digest = Convert.ToHexString(digest).ToLowerInvariant(), bytes = input.Length };
                }
            case "password.generate":
                var length = p.TryGetProperty("length", out var n) ? n.GetInt32() : 24;
                if (length is < 12 or > 256) throw new ArgumentException("Length must be 12 to 256.");
                var alphabetId = p.TryGetProperty("alphabet", out var ai) ? ai.GetString() : "all";
                var alphabet = alphabetId switch {
                    "alphanumeric" => "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
                    "unambiguous" => "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789",
                    "all" => "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}:,.?",
                    _ => throw new ArgumentException("Unknown alphabet.") };
                var chars = new char[length];
                for (var i = 0; i < chars.Length; i++) { ct.ThrowIfCancellationRequested(); chars[i] = alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)]; }
                return new { value = new string(chars), length, alphabet = alphabetId, persisted = false };
            case "files.convert":
                Confirm(p);
                var source = Path.GetFullPath(Text(p, "path"));
                var output = Path.GetFullPath(Text(p, "outputPath"));
                if (string.Equals(source, output, StringComparison.OrdinalIgnoreCase)) throw new ArgumentException("Output must differ from input.");
                var format = Text(p, "format", 32);
                await using (var input = OpenInput(source))
                {
                    // Decode strictly, so invalid input never silently becomes replacement characters.
                    var encoding = p.TryGetProperty("inputEncoding", out var ie) ? ie.GetString() : "utf-8";
                    Encoding decoder = encoding switch { "utf-8" => new UTF8Encoding(false, true), "utf-16le" => new UnicodeEncoding(false, false, true), "utf-16be" => new UnicodeEncoding(true, false, true), _ => throw new ArgumentException("Unsupported encoding.") };
                    using var reader = new StreamReader(input, decoder, false);
                    var text = await reader.ReadToEndAsync(ct);
                    string converted;
                    if (format == "json-pretty" || format == "json-compact")
                    {
                        using var doc = JsonDocument.Parse(text, new JsonDocumentOptions { MaxDepth = 64 });
                        converted = JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions { WriteIndented = format == "json-pretty" });
                    }
                    else if (format is "utf-8" or "utf-16le" or "utf-16be") converted = text;
                    else throw new ArgumentException("Supported formats: json-pretty, json-compact, utf-8, utf-16le, utf-16be.");
                    Encoding encoder = format switch { "utf-16le" => new UnicodeEncoding(false, true, true), "utf-16be" => new UnicodeEncoding(true, true, true), _ => new UTF8Encoding(false, true) };
                    var temp = Path.Combine(Path.GetDirectoryName(output)!, ".msc-" + Guid.NewGuid().ToString("N") + ".tmp");
                    try {
                        await File.WriteAllTextAsync(temp, converted, encoder, ct);
                        ct.ThrowIfCancellationRequested();
                        File.Move(temp, output, false);
                    } finally { if (File.Exists(temp)) File.Delete(temp); }
                    return new { outputPath = output, format, bytes = new FileInfo(output).Length, inputPreserved = true };
                }
            case "tools.catalogue":
                return new { tools = new object[] {
                    new { id = "file-hash", status = "supported", method = "files.hash" },
                    new { id = "text-json-conversion", status = "supported", method = "files.convert" },
                    new { id = "password-generator", status = "supported", method = "password.generate" },
                    new { id = "edpi", status = "supported", method = "utilities.calculate" },
                    new { id = "image-metadata", status = "needs-adapter", method = "", reason = "No lossless image metadata adapter is bundled." },
                    new { id = "media-ai", status = "needs-adapter", method = "", reason = "No media inference adapter or model is bundled." },
                    new { id = "remote-ai", status = "needs-adapter", method = "", reason = "HTTPS provider and OS credential storage adapters are not bundled." }
                } };
            case "utilities.calculate":
                var kind = Text(p, "kind", 32);
                double Positive(string key) { var v = p.GetProperty(key).GetDouble(); if (!double.IsFinite(v) || v <= 0 || v > 100000) throw new ArgumentException($"Invalid {key}."); return v; }
                return kind switch {
                    "edpi" => new { kind, value = Positive("dpi") * Positive("sensitivity"), unit = "eDPI" },
                    "psu-headroom" => new { kind, value = Math.Ceiling(Positive("loadWatts") * 1.3 / 50) * 50, unit = "W", note = "30% arithmetic headroom only. Check component and manufacturer requirements." },
                    _ => throw new ArgumentException("Supported calculations: edpi, psu-headroom.") };
            case "providers.list":
                return new { providers = new[] { new { id = "ollama", endpoint = "http://127.0.0.1:11434", configured = await Enabled(context, ct), status = "available-adapter", disclosure = "Prompts go to the locally installed Ollama service only. Model availability is checked on invocation." } } };
            case "providers.configure":
                Confirm(p);
                if (Text(p, "provider", 32) != "ollama") throw new ArgumentException("Only the local Ollama adapter is bundled.");
                var enabled = p.GetProperty("enabled").GetBoolean();
                Directory.CreateDirectory(context.DataRoot);
                await File.WriteAllTextAsync(Path.Combine(context.DataRoot, "utilities-ollama-opt-in.json"), JsonSerializer.Serialize(new { enabled }), ct);
                return new { provider = "ollama", enabled, storesCredentials = false };
            case "providers.invoke":
            {
                Confirm(p);
                if (Text(p, "provider", 32) != "ollama" || !await Enabled(context, ct)) throw new ArgumentException("Local Ollama must be explicitly enabled first.");
                using var providerDeadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
                providerDeadline.CancelAfter(TimeSpan.FromSeconds(60));
                ct = providerDeadline.Token;
                var action = Text(p, "action", 32);
                using (var request = action switch {
                    "models" => new HttpRequestMessage(HttpMethod.Get, "http://127.0.0.1:11434/api/tags"),
                    "chat" => new HttpRequestMessage(HttpMethod.Post, "http://127.0.0.1:11434/api/chat") { Content = new StringContent(JsonSerializer.Serialize(new { model = Text(p, "model", 200), messages = new[] { new { role = "user", content = Text(p, "prompt", 16000) } }, stream = false, options = new { num_predict = 1024 } }), Encoding.UTF8, "application/json") },
                    _ => throw new ArgumentException("Supported actions: models, chat.") })
                using (var response = await Client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct))
                {
                    if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Local provider returned an unsuccessful status.");
                    await using var body = await response.Content.ReadAsStreamAsync(ct);
                    using var memory = new MemoryStream();
                    var buffer = new byte[8192];
                    int read;
                    while ((read = await body.ReadAsync(buffer, ct)) > 0) { if (memory.Length + read > 1024 * 1024) throw new InvalidOperationException("Provider response exceeds 1 MiB."); await memory.WriteAsync(buffer.AsMemory(0, read), ct); }
                    using var document = JsonDocument.Parse(memory.ToArray(), new JsonDocumentOptions { MaxDepth = 64 });
                    return new { provider = "ollama", localOnly = true, response = document.RootElement.Clone() };
                }
            }
            default: throw new ArgumentException("Unknown utility method.");
        }
    }
    private static async Task<bool> Enabled(EngineContext context, CancellationToken ct)
    {
        var file = Path.Combine(context.DataRoot, "utilities-ollama-opt-in.json");
        if (!File.Exists(file)) return false;
        using var doc = JsonDocument.Parse(await File.ReadAllTextAsync(file, ct));
        return doc.RootElement.TryGetProperty("enabled", out var enabled) && enabled.ValueKind == JsonValueKind.True;
    }
}



