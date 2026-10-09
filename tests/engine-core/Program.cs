using System.Text.Json;
using MaterialSystemCare.Engine;
using MaterialSystemCare.Tests;

var root = Path.Combine(Path.GetTempPath(), "msc-integrated-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
var count = 0;
void Check(bool value, string name) { if (!value) throw new Exception(name); count++; }
try {
    var context = new EngineContext(root);
    Check(!context.IsElevated && context.IsFixture, "Fixture cannot acquire elevation");
    ManagementFixtures.PolicyChecks(); count++;
    await ManagementFixtures.ConsentChecksAsync(context); count++;
    Check(ProtectionModule.ParseDriverXml("<pnputil><driver DriverName='oem42.inf'><ProviderName>Fixture</ProviderName></driver></pnputil>").Single().Id == "oem42.inf", "Driver schema");
    foreach (var xml in new[] { "not xml", "<wrong/>", "<!DOCTYPE pnputil [<!ENTITY x SYSTEM 'file:///not-read'>]><pnputil>&x;</pnputil>" }) {
        try { ProtectionModule.ParseDriverXml(xml); throw new Exception("Invalid XML accepted"); }
        catch (EngineException ex) { Check(ex.Code == "INVALID_PLATFORM_OUTPUT", "XML validation"); }
    }
    var protection = new ProtectionModule();
    foreach (var method in new[] { "security.scan", "drivers.export", "drivers.install" }) {
        using var noConsent = JsonDocument.Parse("{}");
        try { await protection.HandleAsync(method, noConsent.RootElement, context, default); throw new Exception("Missing consent accepted"); }
        catch (EngineException ex) { Check(ex.Code == "CONFIRMATION_REQUIRED", "Explicit consent"); }
        using var confirmed = JsonDocument.Parse("{\"confirmed\":true}");
        try { await protection.HandleAsync(method, confirmed.RootElement, context, default); throw new Exception("Fixture mutation accepted"); }
        catch (EngineException ex) { Check(ex.Code == "ELEVATION_REQUIRED", "Fixture elevation restriction"); }
    }
    using var badVersion = JsonDocument.Parse("{}");
    var modules = new IEngineModule[] { new SystemModule(), new ManagementModule(), protection, new UtilitiesModule() };
    var invalid = JsonDocument.Parse(await MaterialSystemCare.Engine.Program.DispatchAsync("{\"version\":99,\"id\":\"x\",\"method\":\"engine.ping\",\"params\":{}}", context, modules, default));
    Check(invalid.RootElement.GetProperty("error").GetProperty("code").GetString() == "INVALID_REQUEST", "Version validation");
    using var oversized = new MemoryStream(new byte[MaterialSystemCare.Engine.Program.MaximumRequestBytes + 1]);
    try { await MaterialSystemCare.Engine.Program.ReadLineAsync(oversized, default); throw new Exception("Oversized transport accepted"); }
    catch (EngineException ex) { Check(ex.Code == "REQUEST_TOO_LARGE", "Transport bound"); }
    for (var i = 0; i < 17; i++) await context.SaveSettingAsync("bounded-setting-" + i, new string('a', 250000), default);
    var oversizedSettings = await MaterialSystemCare.Engine.Program.DispatchAsync("{\"version\":1,\"id\":\"oversized-settings\",\"method\":\"settings.get\",\"params\":{}}", context, modules, default);
    using var oversizedResult = JsonDocument.Parse(oversizedSettings);
    Check(!oversizedResult.RootElement.GetProperty("ok").GetBoolean() && oversizedResult.RootElement.GetProperty("error").GetProperty("code").GetString() == "RESULT_TOO_LARGE", "Oversized settings response is explicitly rejected");
    Check(System.Text.Encoding.UTF8.GetByteCount(oversizedSettings) <= MaterialSystemCare.Engine.Program.MaximumResponseBytes, "Response UTF-8 bound");
    var ordinarySetting = await MaterialSystemCare.Engine.Program.DispatchAsync("{\"version\":1,\"id\":\"individual\",\"method\":\"settings.get\",\"params\":{\"key\":\"bounded-setting-0\"}}", context, modules, default);
    using var ordinaryResult = JsonDocument.Parse(ordinarySetting);
    Check(ordinaryResult.RootElement.GetProperty("ok").GetBoolean() && ordinaryResult.RootElement.GetProperty("result").GetString()!.Length == 250000, "Individual settings reads remain available");
    try { MaterialSystemCare.Engine.Program.SerializeSuccessResponse("global-bound", new string('a', MaterialSystemCare.Engine.Program.MaximumResponseBytes)); throw new Exception("Global serialization bound missing"); }
    catch (EngineException ex) { Check(ex.Code == "RESULT_TOO_LARGE", "Global response serialization is bounded"); }
    var actualModules = MaterialSystemCare.Engine.Program.CreateModules();
    var advertised = MaterialSystemCare.Engine.Program.Capabilities;
    Check(actualModules.Length == 6 && advertised.Length == 37 && advertised.Distinct().Count() == advertised.Length, "Explicit module inventory");
    Check(advertised.All(method => actualModules.Count(module => module.CanHandle(method)) == 1), "Every advertised method has one real owner");
    Check(!advertised.Contains("host.shutdown") && !advertised.Contains("security.disable"), "Unsupported operations absent");
    using var ping = JsonDocument.Parse(await MaterialSystemCare.Engine.Program.DispatchAsync("{\"version\":1,\"id\":\"inventory\",\"method\":\"engine.ping\",\"params\":{}}", context, actualModules, default));
    Check(ping.RootElement.GetProperty("result").GetProperty("capabilities").EnumerateArray().Select(x => x.GetString()).SequenceEqual(advertised), "Ping inventory matches registration");
    using var counted = new CountingStream(System.Text.Encoding.UTF8.GetBytes(new string('a', 1024 * 1024)));
    Check((await new MaterialSystemCare.Engine.Program.RequestLineReader(counted).ReadLineAsync(default))!.Length == 1024 * 1024 && counted.ReadCalls <= 65, "One MiB uses bounded chunk reads");
    using var multiline = new MemoryStream(System.Text.Encoding.UTF8.GetBytes("first\r\nsecond\nthird"));
    var lines = new MaterialSystemCare.Engine.Program.RequestLineReader(multiline);
    Check(await lines.ReadLineAsync(default) == "first" && await lines.ReadLineAsync(default) == "second" && await lines.ReadLineAsync(default) == "third" && await lines.ReadLineAsync(default) == null, "Buffered multiline bytes retained");
    using var exact = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(new string('a', MaterialSystemCare.Engine.Program.MaximumRequestBytes) + "\nnext\n"));
    var exactReader = new MaterialSystemCare.Engine.Program.RequestLineReader(exact);
    Check((await exactReader.ReadLineAsync(default))!.Length == MaterialSystemCare.Engine.Program.MaximumRequestBytes && await exactReader.ReadLineAsync(default) == "next", "Exact byte limit and following line");
    using var invalidUtf8 = new MemoryStream(new byte[] { 0xc3, 0x28, 10 });
    try { await new MaterialSystemCare.Engine.Program.RequestLineReader(invalidUtf8).ReadLineAsync(default); throw new Exception("Invalid UTF-8 accepted"); }
    catch (EngineException ex) { Check(ex.Code == "INVALID_REQUEST", "Strict UTF-8 decoding"); }
    using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
    try { await new MaterialSystemCare.Engine.Program.RequestLineReader(multiline).ReadLineAsync(cancelled.Token); throw new Exception("Read cancellation ignored"); }
    catch (OperationCanceledException) { Check(true, "Buffered reader observes cancellation"); }
    Console.WriteLine($"PASS integrated engine fixtures: {count} assertions/groups; no host mutation executed.");
} finally { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(root, true); }

sealed class CountingStream(byte[] bytes) : MemoryStream(bytes)
{
    public int ReadCalls { get; private set; }
    public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) { ReadCalls++; return base.ReadAsync(buffer, cancellationToken); }
}
