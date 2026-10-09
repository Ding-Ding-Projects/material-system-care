using MaterialSystemCare.Engine;
using System.Text.Json;

namespace MaterialSystemCare.Tests;

// Dependency-free fixture checks, invoked by the repository verification runner.
public static class ManagementFixtures
{
    public static void PolicyChecks()
    {
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
