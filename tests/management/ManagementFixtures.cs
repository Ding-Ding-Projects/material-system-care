using MaterialSystemCare.Engine;
using System.Text.Json;

namespace MaterialSystemCare.Tests;

// Dependency-free fixture checks, invoked by the repository verification runner.
public static class ManagementFixtures
{
    public static void PolicyChecks()
    {
        var taskRow = "{\"name\":\"Example\",\"path\":\"\\\\\",\"state\":\"Ready\",\"enabled\":true,\"lastRun\":null,\"nextRun\":\"2026-10-10T09:30:00\",\"lastResult\":267011,\"infoAvailable\":true,\"action\":\"private command\"}";
        string TaskJson(string rows, bool truncated = false) => "{\"records\":[" + rows + "],\"truncated\":" + (truncated ? "true" : "false") + "}";
        var scheduled = ScheduledTaskInventory.Parse(TaskJson(taskRow, true), 1, "fixture-time");
        if (scheduled.Records.Length != 1 || !scheduled.Truncated || scheduled.Records[0].NextRun != "2026-10-10T09:30:00" || scheduled.Records[0].LastResult != 267011) throw new Exception("Task metadata lost.");
        if (JsonSerializer.Serialize(scheduled).Contains("private command")) throw new Exception("Task action leaked.");
        if (ScheduledTaskInventory.Parse(TaskJson(""), 1, "fixture-time").Records.Length != 0) throw new Exception("Empty task inventory changed meaning.");
        foreach (var invalid in new[] { "[]", "{}", "not json", TaskJson(taskRow + "," + taskRow), TaskJson(taskRow.Replace("267011", "-1")), TaskJson(taskRow.Replace("2026-10-10T09:30:00", "not a date")), TaskJson(taskRow.Replace("\"infoAvailable\":true", "\"infoAvailable\":false")), TaskJson(taskRow.Replace("\"enabled\":true", "\"enabled\":3")), new string(' ', ScheduledTaskInventory.MaximumBytes + 1) }) {
            try { ScheduledTaskInventory.Parse(invalid, 2, "fixture-time"); throw new Exception("Invalid task inventory accepted."); }
            catch (EngineException error) when (error.Code == "INVALID_TASK_INVENTORY") { }
        }
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
        try { await new ManagementModule().HandleAsync("tasks.list", JsonDocument.Parse("{}").RootElement, context, default); throw new Exception("Fixture accessed host task inventory."); }
        catch (EngineException error) when (error.Code == "LIVE_COLLECTION_DISABLED") { }
        try { await new ManagementModule().HandleAsync("apps.managed", JsonDocument.Parse("{}").RootElement, context, default); throw new Exception("Fixture accessed host package inventory."); }
        catch (EngineException error) when (error.Code == "LIVE_COLLECTION_DISABLED") { }
        var platform = new FixturePlatform();
        var module = new ManagementModule(platform);
        foreach (var value in new[] { "0", "1001", "\"2\"", "null", "1.5" }) {
            using var badLimit = JsonDocument.Parse("{\"limit\":" + value + "}");
            try { await module.HandleAsync("tasks.list", badLimit.RootElement, context, default); throw new Exception("Invalid task limit accepted."); }
            catch (EngineException error) when (error.Code == "INVALID_PARAMETERS") { }
        }
        if (platform.TaskCalls != 0) throw new Exception("Task query ran before limit validation.");
        using var explicitLimit = JsonDocument.Parse("{\"limit\":17}");
        await module.HandleAsync("tasks.list", explicitLimit.RootElement, context, default);
        if (platform.TaskCalls != 1 || platform.TaskLimit != 17) throw new Exception("Task limit changed.");
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
        public int TaskCalls { get; private set; }
        public int TaskLimit { get; private set; }
        public override Task<ScheduledTaskInventory.Inventory> TasksAsync(int limit, CancellationToken ct) {
            TaskCalls++; TaskLimit = limit;
            return Task.FromResult(new ScheduledTaskInventory.Inventory([], false, "fixture-time"));
        }
        public override Task<object> PackageAsync(bool upgrade, string id, CancellationToken ct) { Calls++; return Task.FromResult<object>(new { completed = true, fixture = true, packageId = id }); }
    }
}
