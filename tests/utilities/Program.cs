using System.Text.Json;
using MaterialSystemCare.Engine;

var root = Path.Combine(Path.GetTempPath(), "msc-utilities-test-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
try {
    var module = new UtilitiesModule();
    var context = new EngineContext(root);
    async Task<JsonElement> Invoke(string method, object parameters) {
        var value = await module.HandleAsync(method, JsonSerializer.SerializeToElement(parameters), context, CancellationToken.None);
        return JsonSerializer.SerializeToElement(value);
    }
    void Check(bool value, string label) { if (!value) throw new Exception(label); }
    var input = Path.Combine(root, "input.json");
    await File.WriteAllTextAsync(input, "{\"value\":1}");
    var hash = await Invoke("files.hash", new { path = input });
    Check(hash.GetProperty("digest").GetString()!.Length == 64, "SHA256 length");
    var output = Path.Combine(root, "output.json");
    await Invoke("files.convert", new { path = input, outputPath = output, format = "json-pretty", confirmed = true });
    Check(JsonDocument.Parse(await File.ReadAllTextAsync(output)).RootElement.GetProperty("value").GetInt32() == 1, "JSON roundtrip");
    try { await Invoke("files.convert", new { path = input, outputPath = output, format = "json-pretty", confirmed = true }); throw new Exception("Overwrite accepted"); } catch (IOException) { }
    var bad = Path.Combine(root, "bad.json");
    await File.WriteAllTextAsync(bad, "{bad}");
    try { await Invoke("files.convert", new { path = bad, outputPath = Path.Combine(root, "bad-output"), format = "json-pretty", confirmed = true }); throw new Exception("Invalid JSON accepted"); } catch (JsonException) { }
    Check(!File.Exists(Path.Combine(root, "bad-output")), "Invalid input created output");
    var password = await Invoke("password.generate", new { length = 32, alphabet = "unambiguous" });
    Check(password.GetProperty("value").GetString()!.Length == 32 && !password.GetProperty("persisted").GetBoolean(), "Generator contract");
    var calc = await Invoke("utilities.calculate", new { kind = "edpi", dpi = 800, sensitivity = 0.5 });
    Check(calc.GetProperty("value").GetDouble() == 400, "EDPI arithmetic");
    var providers = await Invoke("providers.list", new { });
    Check(!providers.GetProperty("providers")[0].GetProperty("configured").GetBoolean(), "Provider default off");
    Console.WriteLine("PASS utilities fixtures: hash, conversion, no-overwrite, invalid JSON, generation, calculator, provider default");
} finally { Directory.Delete(root, true); }

