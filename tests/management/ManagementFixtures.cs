using MaterialSystemCare.Engine;
using System.Text.Json;

namespace MaterialSystemCare.Tests;

// Dependency-free fixture checks, invoked by the repository verification runner.
public static class ManagementFixtures
{
    public static void PolicyChecks()
    {
        string Export(string packages, string source = "winget") => "{\"Sources\":[{\"SourceDetails\":{\"Name\":\"" + source + "\",\"Identifier\":\"Microsoft.Winget.Source_8wekyb3d8bbwe\"},\"Packages\":" + packages + "}]}";
        var packages = PackageInventory.Parse(Export("[{\"PackageIdentifier\":\"Publisher.Tool\",\"Version\":\"1.2\",\"InitialCustomSwitches\":\"private value\"}]"));
        if (packages.Length != 1 || packages[0].PackageId != "Publisher.Tool" || packages[0].Version != "1.2" || packages[0].UpdateAvailability != "not-checked") throw new Exception("Structured package record lost.");
        if (JsonSerializer.Serialize(packages).Contains("private value")) throw new Exception("Unneeded export fields leaked.");
        if (PackageInventory.Parse("{\"Sources\":[]}").Length != 0) throw new Exception("Empty inventory changed meaning.");
        foreach (var invalid in new[] { "{}", "[]", "not json", Export("[]", "msstore"), Export("[{\"PackageIdentifier\":\"--all\"}]"), Export("[{\"PackageIdentifier\":\"A.B\"},{\"PackageIdentifier\":\"a.b\"}]"), Export("[{\"PackageIdentifier\":\"A.B\",\"Version\":12}]"), new string(' ', PackageInventory.MaximumBytes + 1) }) {
            try { PackageInventory.Parse(invalid); throw new Exception("Invalid export accepted."); }
            catch (EngineException error) when (error.Code == "INVALID_PACKAGE_INVENTORY") { }
        }
        foreach (string invalid in new[] { "--all", "x y", "x;shutdown", "x\n", "../x", "" })
            if (ManagementPolicy.ValidPackageId(invalid)) throw new Exception("Unsafe identifier accepted.");
        if (!ManagementPolicy.ValidPackageId("Microsoft.PowerToys")) throw new Exception("Exact package id rejected.");
        string[] args = ManagementPolicy.PackageArguments(true, "Microsoft.PowerToys");
        if (args[0] != "upgrade" || !args.Contains("--exact") || args.Contains("--all") || args.Contains("--allow-reboot")) throw new Exception("Unsafe upgrade arguments.");
        foreach (string protectedName in new[] { "EXPLORER", "lsass", "pwsh", "codex", "MaterialSystemCare.Engine" })
            if (!ManagementPolicy.ProtectedProcess(protectedName)) throw new Exception("Host process protection missing.");
    }

    public static async Task ConsentChecksAsync(EngineContext context)
    {
        try { await new ManagementModule().HandleAsync("apps.managed", JsonDocument.Parse("{}").RootElement, context, default); throw new Exception("Fixture accessed host package inventory."); }
        catch (EngineException error) when (error.Code == "LIVE_COLLECTION_DISABLED") { }
        var platform = new FixturePlatform();
        var module = new ManagementModule(platform);
        using var missingConsent = JsonDocument.Parse("{\"packageId\":\"Microsoft.PowerToys\"}");
        try { await module.HandleAsync("apps.upgrade", missingConsent.RootElement, context, CancellationToken.None); throw new Exception("Missing consent accepted."); }
        catch (ArgumentException) { }
        if (platform.Calls != 0) throw new Exception("Platform called before consent validation.");
        using var injection = JsonDocument.Parse("{\"confirmed\":true,\"packageId\":\"x;shutdown\"}");
        try { await module.HandleAsync("apps.uninstall", injection.RootElement, context, CancellationToken.None); throw new Exception("Injection accepted."); }
        catch (ArgumentException) { }
        if (platform.Calls != 0) throw new Exception("Platform called before identifier validation.");
    }
    private sealed class FixturePlatform : ManagementPlatform
    {
        public int Calls { get; private set; }
        public override Task<object> PackageAsync(bool upgrade, string id, CancellationToken ct) { Calls++; return Task.FromResult<object>(new { completed = true, fixture = true, packageId = id }); }
    }
}
