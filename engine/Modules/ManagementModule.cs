using System.Diagnostics;
using System.Security.Principal;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace MaterialSystemCare.Engine;

public sealed class ManagementModule : IEngineModule
{
    private readonly ManagementPlatform platform;
    public ManagementModule() : this(new ManagementPlatform()) { }
    public ManagementModule(ManagementPlatform platform) => this.platform = platform;
    public bool CanHandle(string method) => method is "apps.list" or "apps.managed" or "apps.updates" or "apps.upgrade" or "apps.uninstall" or "startup.list" or "startup.set" or "processes.list" or "processes.stop" or "services.list" or "tasks.list";
    public async Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken)
    {
        if (!OperatingSystem.IsWindows() && platform.GetType() == typeof(ManagementPlatform))
            throw new PlatformNotSupportedException("Management requires Windows.");
        switch (method)
        {
            case "apps.list": return await platform.AppsAsync(cancellationToken);
            case "apps.managed":
                if (context.IsFixture && platform.GetType() == typeof(ManagementPlatform)) throw new EngineException("LIVE_COLLECTION_DISABLED", "Fixture contexts cannot discover installed host packages.");
                return await platform.ManagedAppsAsync(cancellationToken);
            case "apps.updates": return await platform.UpdatesAsync(cancellationToken);
            case "apps.upgrade":
            case "apps.uninstall":
                Confirm(parameters);
                string packageId = Text(parameters, "packageId");
                if (!ManagementPolicy.ValidPackageId(packageId)) throw new ArgumentException("Invalid exact package identifier.");
                var receipt = await platform.PackageAsync(method == "apps.upgrade", packageId, cancellationToken);
                await context.RecordAsync(method, new { packageId, receipt }, cancellationToken);
                return receipt;
            case "startup.list": return platform.Startup(context.DataRoot);
            case "startup.set":
                Confirm(parameters);
                string name = Text(parameters, "id");
                if (!parameters.TryGetProperty("enabled", out var enabled) || enabled.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) throw new ArgumentException("enabled must be boolean.");
                if (!parameters.TryGetProperty("reviewRevision", out var revision) || revision.ValueKind != JsonValueKind.String)
                    throw StartupReviewChanged();
                return await platform.SetStartupAsync(name, enabled.GetBoolean(), revision.GetString()!, context, cancellationToken);
            case "processes.list": return platform.Processes();
            case "processes.stop":
                Confirm(parameters);
                if (!parameters.TryGetProperty("pid", out var pid) || !pid.TryGetInt32(out int processId) || processId <= 0) throw new ArgumentException("A positive pid is required.");
                string started = Text(parameters, "startedAt");
                var stopped = platform.Stop(processId, started);
                await context.RecordAsync(method, new { pid = processId, stopped }, cancellationToken);
                return stopped;
            case "services.list": return await platform.ServicesAsync(cancellationToken);
            case "tasks.list":
                if (context.IsFixture && platform.GetType() == typeof(ManagementPlatform)) throw new EngineException("LIVE_COLLECTION_DISABLED", "Fixture contexts cannot inspect host scheduled tasks.");
                int limit = 200;
                if (parameters.TryGetProperty("limit", out var supplied) && (supplied.ValueKind != JsonValueKind.Number || !supplied.TryGetInt32(out limit) || limit is < 1 or > 1000)) throw new EngineException("INVALID_PARAMETERS", "limit must be between 1 and 1000.");
                return await platform.TasksAsync(limit, cancellationToken);
            default: throw new ArgumentException("Unknown management method.");
        }
    }
    private static void Confirm(JsonElement p) { if (!p.TryGetProperty("confirmed", out var c) || c.ValueKind != JsonValueKind.True) throw new ArgumentException("Explicit confirmed:true is required."); }
    private static string Text(JsonElement p, string key) => p.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String && v.GetString() is { Length: > 0 and <= 256 } s && !s.Any(char.IsControl) ? s : throw new ArgumentException($"A bounded {key} is required.");
    internal static EngineException StartupReviewChanged() => new("STARTUP_REVIEW_CHANGED", "The startup record changed or its review is missing. Refresh the records and review the selected action again.");
}

public static class ManagementPolicy
{
    public static bool ProtectedProcess(string name) => new[] { "system", "registry", "smss", "csrss", "wininit", "winlogon", "services", "lsass", "svchost", "dwm", "explorer", "sihost", "taskhostw", "conhost", "WindowsTerminal", "cmd", "powershell", "pwsh", "codex", "MaterialSystemCare.Engine", "material_system_care", "shutdown", "logoff" }.Contains(name, StringComparer.OrdinalIgnoreCase);
    public static bool ValidPackageId(string id) => id.Length is > 0 and <= 256 && Regex.IsMatch(id, @"\A[A-Za-z0-9][A-Za-z0-9._+-]*\z", RegexOptions.CultureInvariant);
    public static string[] PackageArguments(bool upgrade, string id)
    {
        if (!ValidPackageId(id)) throw new ArgumentException("Invalid package identifier.");
        return [upgrade ? "upgrade" : "uninstall", "--id", id, "--exact", "--source", "winget", "--disable-interactivity", "--accept-source-agreements"];
    }
}

public class ManagementPlatform
{
    public sealed record StartupValue(string Value, RegistryValueKind Kind);
    protected virtual string[] StartupNames() { using var key = Registry.CurrentUser.OpenSubKey(RunKey); return key?.GetValueNames() ?? []; }
    protected virtual StartupValue? ReadStartupValue(string name) {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        if (key == null || !key.GetValueNames().Contains(name, StringComparer.Ordinal)) return null;
        return new(key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames)?.ToString() ?? "", key.GetValueKind(name));
    }
    protected virtual void DeleteStartupValue(string name) { using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true) ?? throw new IOException("Current-user Run key is unavailable."); key.DeleteValue(name, throwOnMissingValue: true); }
    protected virtual void WriteStartupValue(string name, StartupValue value) { using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true) ?? throw new IOException("Current-user Run key is unavailable."); key.SetValue(name, value.Value, value.Kind); }
    private static string StartupRevision(string name, bool enabled, StartupValue value) => Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(new { schema = 1, name, enabled, value.Value, kind = (int)value.Kind })));
    private static void RequireRevision(string supplied, string expected) { if (!string.Equals(supplied, expected, StringComparison.Ordinal)) throw ManagementModule.StartupReviewChanged(); }
    private static StartupValue ReadJournal(string journal, string name) {
        try {
        if (!File.Exists(journal)) throw ManagementModule.StartupReviewChanged();
        using var original = JsonDocument.Parse(File.ReadAllText(journal));
        if (original.RootElement.GetProperty("name").GetString() != name) throw ManagementModule.StartupReviewChanged();
        var value = original.RootElement.GetProperty("value").GetString();
        var kind = (RegistryValueKind)original.RootElement.GetProperty("kind").GetInt32();
        if (value == null || kind is not (RegistryValueKind.String or RegistryValueKind.ExpandString)) throw ManagementModule.StartupReviewChanged();
        return new(value, kind);
        } catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException or FileNotFoundException or DirectoryNotFoundException) { throw ManagementModule.StartupReviewChanged(); }
    }
    public virtual Task<ScheduledTaskInventory.Inventory> TasksAsync(int limit, CancellationToken ct) => ScheduledTaskInventory.CollectAsync(limit, ct);
    public virtual Task<object> ManagedAppsAsync(CancellationToken ct) => PackageInventory.CollectAsync(ct);
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public virtual async Task<object> AppsAsync(CancellationToken ct)
    {
        var records = new List<object>();
        var unavailable = new List<string>();
        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            using var root = RegistryKey.OpenBaseKey(hive, view);
            using var uninstall = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall");
            if (uninstall is null) continue;
            foreach (string keyName in uninstall.GetSubKeyNames())
            {
                ct.ThrowIfCancellationRequested();
                try
                {
                    using var key = uninstall.OpenSubKey(keyName);
                    if (key?.GetValue("DisplayName") is not string displayName || string.IsNullOrWhiteSpace(displayName)) continue;
                    records.Add(new { id = $"registry:{hive}:{view}:{keyName}", name = displayName, version = key.GetValue("DisplayVersion") as string, publisher = key.GetValue("Publisher") as string, scope = hive == RegistryHive.CurrentUser ? "user" : "machine", source = "uninstallRegistry", canUninstall = false, unavailableReason = "Resolve a supported exact WinGet package identifier before uninstalling." });
                }
                catch (System.Security.SecurityException) { unavailable.Add($"Registry record is not accessible in {hive}/{view}."); }
            }
        }
        try
        {
            var appx = await PowerShellAsync("Get-AppxPackage | Select-Object Name,PackageFullName,Version,Publisher | ConvertTo-Json -Compress", ct);
            if (appx.exitCode == 0 && !string.IsNullOrWhiteSpace(appx.output))
            {
                using var json = JsonDocument.Parse(appx.output);
                var items = json.RootElement.ValueKind == JsonValueKind.Array ? json.RootElement.EnumerateArray().ToArray() : new[] { json.RootElement };
                foreach (var item in items) records.Add(new { id = "appx:" + item.GetProperty("PackageFullName").GetString(), name = item.GetProperty("Name").GetString(), version = item.GetProperty("Version").Clone(), publisher = item.GetProperty("Publisher").GetString(), scope = "user", source = "appx", canUninstall = false, unavailableReason = "AppX removal is not exposed by this module." });
            }
            else unavailable.Add("Current-user AppX inventory is unavailable.");
        }
        catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or JsonException or TimeoutException) { unavailable.Add("Current-user AppX inventory is unavailable: " + ex.GetType().Name); }
        return new { records, unavailable };
    }
    public virtual async Task<object> UpdatesAsync(CancellationToken ct)
    {
        string? winget = Winget();
        if (winget is null) return new { available = false, reason = "WinGet is not installed for the current user.", records = Array.Empty<object>() };
        var output = await RunAsync(winget, ["upgrade", "--source", "winget", "--disable-interactivity", "--accept-source-agreements"], ct);
        return new { available = output.exitCode == 0, exitCode = output.exitCode, format = "wingetText", output = output.output, reason = output.exitCode == 0 ? null : "WinGet update discovery did not complete successfully. Text output is retained, no guessed package records are created." };
    }
    public virtual async Task<object> PackageAsync(bool upgrade, string id, CancellationToken ct)
    {
        string? winget = Winget();
        if (winget is null) return new { completed = false, reason = "WinGet is not installed for the current user." };
        var result = await RunAsync(winget, ManagementPolicy.PackageArguments(upgrade, id), ct);
        return new { completed = result.exitCode == 0, packageId = id, exitCode = result.exitCode, output = result.output, restartInitiated = false };
    }
    public virtual object Startup(string dataRoot)
    {
        var records = new List<object>();
        string folder = Path.Combine(dataRoot, "management-startup");
        foreach (string name in StartupNames()) {
            var value = ReadStartupValue(name);
            bool conflict = File.Exists(Path.Combine(folder, Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(name))) + ".json"));
            if (value != null) records.Add(new { id = name, name, enabled = true, scope = "user", source = "HKCU.Run", command = value.Value, reviewRevision = StartupRevision(name, true, value), recoveryRequired = conflict, canChange = !conflict && value.Kind is RegistryValueKind.String or RegistryValueKind.ExpandString });
        }
        if (Directory.Exists(folder)) foreach (string journal in Directory.EnumerateFiles(folder, "*.json").Take(10000))
        {
            using var original = JsonDocument.Parse(File.ReadAllText(journal));
            string? name = original.RootElement.GetProperty("name").GetString();
            if (name == null) continue;
            var value = ReadJournal(journal, name);
            bool conflict = ReadStartupValue(name) != null;
            records.Add(new { id = name, name, enabled = false, scope = "user", source = "originalStateJournal", reviewRevision = StartupRevision(name, false, value), canChange = !conflict, recoveryRequired = conflict });
        }
        return new { records, unavailable = new[] { "Startup-folder and machine entries are not modified." } };
    }
    public virtual async Task<object> SetStartupAsync(string name, bool enabled, string reviewRevision, EngineContext context, CancellationToken ct)
    {
        if (name.Length > 256 || name.Any(char.IsControl)) throw new ArgumentException("Invalid startup id.");
        string folder = Path.Combine(context.DataRoot, "management-startup");
        if (reviewRevision.Length != 64 || !reviewRevision.All(char.IsAsciiHexDigit)) throw ManagementModule.StartupReviewChanged();
        string hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(name)));
        string journal = Path.Combine(folder, hash + ".json");
        if (!enabled)
        {
            var current = ReadStartupValue(name) ?? throw ManagementModule.StartupReviewChanged();
            RequireRevision(reviewRevision, StartupRevision(name, true, current));
            var kind = current.Kind;
            if (kind is not (RegistryValueKind.String or RegistryValueKind.ExpandString)) throw new ArgumentException("Only string startup entries are supported.");
            string value = current.Value;
            if (File.Exists(journal)) throw ManagementModule.StartupReviewChanged();
            void ValidateCurrent() { var now = ReadStartupValue(name) ?? throw ManagementModule.StartupReviewChanged(); RequireRevision(reviewRevision, StartupRevision(name, true, now)); }
            ValidateCurrent();
            Directory.CreateDirectory(folder);
            await using (var journalFile = new FileStream(journal, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                await JsonSerializer.SerializeAsync(journalFile, new { name, value, kind = (int)kind }, cancellationToken: ct);
            await context.RecordAsync("startup.set", new { id = name, enabled = false, journal = hash }, ct);
            ValidateCurrent();
            DeleteStartupValue(name);
        }
        else
        {
            var original = ReadJournal(journal, name);
            void ValidateRestore() { RequireRevision(reviewRevision, StartupRevision(name, false, ReadJournal(journal, name))); if (ReadStartupValue(name) != null) throw ManagementModule.StartupReviewChanged(); }
            ValidateRestore();
            await context.RecordAsync("startup.set", new { id = name, enabled = true, journal = hash }, ct);
            ValidateRestore();
            WriteStartupValue(name, original);
            RequireRevision(reviewRevision, StartupRevision(name, false, ReadJournal(journal, name)));
            var restored = ReadStartupValue(name) ?? throw ManagementModule.StartupReviewChanged();
            RequireRevision(StartupRevision(name, true, original), StartupRevision(name, true, restored));
            File.Delete(journal);
        }
        return new { id = name, enabled, completed = true, restartInitiated = false };
    }
    public virtual object Processes()
    {
        var records = new List<object>();
        foreach (var p in Process.GetProcesses()) using (p)
        {
            try { records.Add(new { pid = p.Id, name = p.ProcessName, startedAt = p.StartTime.ToUniversalTime().ToString("O"), workingSetBytes = p.WorkingSet64, cpuTotalMilliseconds = p.TotalProcessorTime.TotalMilliseconds, canRequestClose = p.Id != Environment.ProcessId && !ManagementPolicy.ProtectedProcess(p.ProcessName) && SameUser(p) && p.MainWindowHandle != IntPtr.Zero }); }
            catch (Exception ex) when (ex is System.ComponentModel.Win32Exception or InvalidOperationException or NotSupportedException) { records.Add(new { pid = p.Id, accessible = false, reason = "Process metadata is inaccessible or the process exited." }); }
        }
        return new { records, cpuMeasurement = "cumulativeProcessorTime", stopMode = "gracefulWindowCloseOnly" };
    }
    public virtual object Stop(int pid, string startedAt)
    {
        using var p = Process.GetProcessById(pid);
        using var self = Process.GetCurrentProcess();
        if (pid == Environment.ProcessId || pid <= 4 || ManagementPolicy.ProtectedProcess(p.ProcessName) || !SameUser(p) || p.SessionId != self.SessionId) throw new ArgumentException("Only accessible same-user interactive processes may receive a close request; system and host processes are protected.");
        if (p.StartTime.ToUniversalTime().ToString("O") != startedAt) throw new ArgumentException("Process identity changed; refresh the selected record.");
        if (p.MainWindowHandle == IntPtr.Zero) return new { pid, requested = false, reason = "No main window is available for graceful close." };
        return new { pid, requested = p.CloseMainWindow(), terminated = false, mode = "CloseMainWindow" };
    }
    public virtual async Task<object> ServicesAsync(CancellationToken ct)
    {
        var result = await PowerShellAsync("Get-Service | Select-Object Name,DisplayName,@{n='Status';e={$_.Status.ToString()}},@{n='StartType';e={$_.StartType.ToString()}} | ConvertTo-Json -Compress", ct);
        if (result.exitCode != 0) return new { available = false, reason = "Read-only service inventory is unavailable.", exitCode = result.exitCode };
        using var json = JsonDocument.Parse(result.output);
        return new { available = true, records = json.RootElement.Clone(), canChange = false };
    }
    private static bool SameUser(Process p)
    {
        if (!OpenProcessToken(p.Handle, 8, out var handle)) return false;
        using (handle) using (var identity = new WindowsIdentity(handle.DangerousGetHandle())) using (var current = WindowsIdentity.GetCurrent()) return identity.User == current.User;
    }
    [System.Runtime.InteropServices.DllImport("advapi32.dll", SetLastError = true)]
    [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out Microsoft.Win32.SafeHandles.SafeAccessTokenHandle token);
    private static string? Winget()
    {
        string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WindowsApps", "winget.exe");
        return File.Exists(path) ? path : null;
    }
    private static Task<(int exitCode, string output)> PowerShellAsync(string script, CancellationToken ct) => RunAsync(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe"), ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script], ct);
    private static async Task<(int exitCode, string output)> RunAsync(string file, IEnumerable<string> args, CancellationToken ct)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromMinutes(3));
        var info = new ProcessStartInfo(file) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (string arg in args) info.ArgumentList.Add(arg);
        using var process = Process.Start(info) ?? throw new InvalidOperationException("The supported command could not start.");
        var stdout = ReadBoundedAsync(process.StandardOutput, timeout.Token);
        var stderr = ReadBoundedAsync(process.StandardError, timeout.Token);
        await process.WaitForExitAsync(timeout.Token);
        return (process.ExitCode, await stdout + "\n" + await stderr);
    }
    private static async Task<string> ReadBoundedAsync(StreamReader reader, CancellationToken ct)
    {
        char[] buffer = new char[4096];
        var text = new System.Text.StringBuilder();
        int count;
        while ((count = await reader.ReadAsync(buffer.AsMemory(), ct)) > 0)
        {
            if (text.Length + count > 1024 * 1024) throw new InvalidDataException("Command output exceeded its safe bound.");
            text.Append(buffer, 0, count);
        }
        return text.ToString();
    }
}
