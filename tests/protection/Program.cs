using System.Text.Json;
using MaterialSystemCare.Engine;

var count = 0;
void Check(bool value, string name) { if (!value) throw new Exception(name); count++; }
var package = ProtectionModule.ParseDriverXml("<pnputil><driver DriverName='oem42.inf'><OriginalName>device.inf</OriginalName><ProviderName>Fixture provider</ProviderName><ClassName>Net</ClassName><DriverVersion>1.0</DriverVersion></driver></pnputil>").Single();
Check(package.Id == "oem42.inf" && package.Provider == "Fixture provider", "Parse actual attribute schema");
Check(ProtectionModule.ParseDriverXml("<pnputil/>").Length == 0, "Empty driver store");
foreach (var xml in new[] { "not xml", "<wrong/>", "<!DOCTYPE pnputil [<!ENTITY x SYSTEM 'file:///not-read'>]><pnputil>&x;</pnputil>", "<pnputil><driver DriverName='../../bad.inf'/></pnputil>" })
{
    try { ProtectionModule.ParseDriverXml(xml); throw new Exception("Expected malformed inventory rejection"); }
    catch (EngineException ex) { Check(ex.Code == "INVALID_PLATFORM_OUTPUT", "Reject unsupported XML safely"); }
}
var module = new ProtectionModule();
Check(module.CanHandle("files.lockOwners") && !module.CanHandle("security.disable"), "Only supported methods");
if (OperatingSystem.IsWindows())
{
    foreach (var method in new[] { "security.scan", "drivers.export", "drivers.install" })
    {
        foreach (var json in new[] { "{}", "{\"confirmed\":\"true\"}", "{\"confirmed\":false}" })
        {
            try { await module.HandleAsync(method, JsonDocument.Parse(json).RootElement, new EngineContext(), default); throw new Exception("Confirmation was not required"); }
            catch (EngineException ex) { Check(ex.Code == "CONFIRMATION_REQUIRED", "Require literal confirmation"); }
        }
        try { await module.HandleAsync(method, JsonDocument.Parse("{\"confirmed\":true}").RootElement, new EngineContext(), default); throw new Exception("Elevation was not required"); }
        catch (EngineException ex) { Check(ex.Code == "ELEVATION_REQUIRED", "Do not mutate without elevation"); }
    }
}
Console.WriteLine($"PASS protection fixtures: {count} assertions; no scan or driver mutation executed.");

namespace MaterialSystemCare.Engine
{
    // Standalone fixtures deliberately provide no host mutation capabilities.
    public interface IEngineModule { bool CanHandle(string method); Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken); }
    public sealed class EngineContext { public bool IsElevated => false; public Task RecordAsync(string operation, object details, CancellationToken ct) => Task.CompletedTask; }
    public sealed class EngineException(string code, string message) : Exception(message) { public string Code { get; } = code; }
}
