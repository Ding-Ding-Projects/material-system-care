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
    Console.WriteLine($"PASS integrated engine fixtures: {count} assertions/groups; no host mutation executed.");
} finally { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(root, true); }
