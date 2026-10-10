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
        await StartupReviewChecksAsync(context);
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
    private static async Task StartupReviewChecksAsync(EngineContext context)
    {
        var platform = new FixturePlatform();
        var module = new ManagementModule(platform);
        const string name = "StartupReviewFixture";
        string Revision(bool enabled) => JsonSerializer.SerializeToElement(platform.Startup(context.DataRoot)).GetProperty("records").EnumerateArray().Single(r => r.GetProperty("id").GetString() == name && r.GetProperty("enabled").GetBoolean() == enabled).GetProperty("reviewRevision").GetString()!;
        async Task Change(bool enabled, string? revision) => _ = await module.HandleAsync("startup.set", JsonSerializer.SerializeToElement(new { id = name, enabled, confirmed = true, reviewRevision = revision }), context, default);
        async Task Reject(bool enabled, string? revision) {
            int writes = platform.StartupWrites;
            try { await Change(enabled, revision); throw new Exception("Stale startup review accepted."); }
            catch (EngineException e) when (e.Code == "STARTUP_REVIEW_CHANGED") { }
            if (platform.StartupWrites != writes) throw new Exception("Stale review mutated startup state.");
        }
        platform.StartupValues[name] = new("original-command", Microsoft.Win32.RegistryValueKind.String);
        string reviewed = Revision(true);
        if (reviewed != Revision(true) || reviewed.Length != 64) throw new Exception("Startup revision is not deterministic.");
        await Reject(false, null);
        await Reject(false, "invalid");
        platform.StartupValues[name] = new("changed-command", Microsoft.Win32.RegistryValueKind.String);
        await Reject(false, reviewed);
        platform.StartupValues[name] = new("original-command", Microsoft.Win32.RegistryValueKind.ExpandString);
        await Reject(false, reviewed);
        platform.StartupValues.Remove(name);
        await Reject(false, reviewed);
        string folder = Path.Combine(context.DataRoot, "management-startup");
        if (Directory.Exists(folder)) throw new Exception("Rejected startup review created a journal directory.");
        platform.StartupValues[name] = new("original-command", Microsoft.Win32.RegistryValueKind.String);
        await Change(false, reviewed);
        if (platform.StartupValues.ContainsKey(name) || platform.StartupWrites != 1) throw new Exception("Reviewed disable did not complete.");
        await Reject(false, reviewed);
        string restoreRevision = Revision(false);
        if (restoreRevision == reviewed) throw new Exception("Enabled and restore revisions are interchangeable.");
        string journal = Directory.GetFiles(folder, "*.json").Single();
        File.WriteAllText(journal, JsonSerializer.Serialize(new { name, value = "changed-recovery-command", kind = (int)Microsoft.Win32.RegistryValueKind.String }));
        await Reject(true, restoreRevision);
        string changedRestore = Revision(false);
        platform.StartupValues[name] = new("new-occupant", Microsoft.Win32.RegistryValueKind.String);
        await Reject(true, changedRestore);
        platform.StartupValues.Remove(name);
        await Change(true, changedRestore);
        if (platform.StartupValues[name].Value != "changed-recovery-command" || File.Exists(journal) || platform.StartupWrites != 2) throw new Exception("Reviewed restore did not complete.");
        await Reject(true, changedRestore);
        reviewed = Revision(true);
        int readCount = 0;
        platform.BeforeStartupRead = () => { if (++readCount == 3) platform.StartupValues[name] = new("changed-during-review", Microsoft.Win32.RegistryValueKind.String); };
        await Reject(false, reviewed);
        platform.BeforeStartupRead = null;
        if (!File.Exists(journal) || platform.StartupValues[name].Value != "changed-during-review") throw new Exception("Late change was removed or recovery was lost.");
        platform.StartupValues.Remove(name);
        restoreRevision = Revision(false);
        readCount = 0;
        platform.BeforeStartupRead = () => { if (++readCount == 2) platform.StartupValues[name] = new("appeared-during-restore", Microsoft.Win32.RegistryValueKind.String); };
        await Reject(true, restoreRevision);
        platform.BeforeStartupRead = null;
        if (!File.Exists(journal) || platform.StartupValues[name].Value != "appeared-during-restore") throw new Exception("Late occupant was overwritten or recovery was lost.");
        Console.WriteLine("PASS startup review: deterministic revisions, missing/malformed/changed/removed state, disable/restore, journal changes, occupied names and replay");
    }
    private sealed class FixturePlatform : ManagementPlatform
    {
        public Dictionary<string, StartupValue> StartupValues { get; } = new();
        public int StartupWrites { get; private set; }
        public Action? BeforeStartupRead { get; set; }
        protected override string[] StartupNames() => StartupValues.Keys.ToArray();
        protected override StartupValue? ReadStartupValue(string name) { BeforeStartupRead?.Invoke(); return StartupValues.GetValueOrDefault(name); }
        protected override void DeleteStartupValue(string name) { StartupWrites++; StartupValues.Remove(name); }
        protected override void WriteStartupValue(string name, StartupValue value) { StartupWrites++; StartupValues[name] = value; }
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
