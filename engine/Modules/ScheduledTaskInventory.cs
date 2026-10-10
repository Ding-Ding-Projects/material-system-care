using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

public static class ScheduledTaskInventory
{
    public const int MaximumBytes = 2 * 1024 * 1024;
    public sealed record TaskRecord(string Name, string Path, string State, bool? Enabled,
        string? LastRun, string? NextRun, long? LastResult, bool InfoAvailable);
    public sealed record Inventory(TaskRecord[] Records, bool Truncated, string ObservedAt,
        string Limitation = "Only tasks visible to the current account are included. Reported times carry no timezone. No task was run or changed.");
    private static EngineException Invalid() => new("INVALID_TASK_INVENTORY", "Task Scheduler returned an invalid or oversized inventory.");

    public static Inventory Parse(string text, int limit, string observedAt)
    {
        if (limit is < 1 or > 1000 || Encoding.UTF8.GetByteCount(text) > MaximumBytes) throw Invalid();
        try {
            using var document = JsonDocument.Parse(text, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("records", out var list) || list.ValueKind != JsonValueKind.Array || list.GetArrayLength() > limit ||
                !root.TryGetProperty("truncated", out var truncated) || truncated.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) throw Invalid();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            string Text(JsonElement row, string key, int max) {
                if (!row.TryGetProperty(key, out var value) || value.ValueKind != JsonValueKind.String || value.GetString() is not { Length: > 0 } s || s.Length > max || s.Any(char.IsControl)) throw Invalid();
                return s;
            }
            string? Time(JsonElement row, string key) {
                if (!row.TryGetProperty(key, out var value)) throw Invalid();
                if (value.ValueKind == JsonValueKind.Null) return null;
                if (value.ValueKind != JsonValueKind.String || !DateTime.TryParseExact(value.GetString(), "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)) throw Invalid();
                return value.GetString();
            }
            var rows = new List<TaskRecord>();
            foreach (var row in list.EnumerateArray()) {
                if (row.ValueKind != JsonValueKind.Object) throw Invalid();
                var name = Text(row, "name", 256); var path = Text(row, "path", 1024); var state = Text(row, "state", 64);
                if (!path.StartsWith('\\') || !path.EndsWith('\\') || !seen.Add(path + name)) throw Invalid();
                if (!row.TryGetProperty("enabled", out var enabled) || enabled.ValueKind is not (JsonValueKind.True or JsonValueKind.False or JsonValueKind.Null) ||
                    !row.TryGetProperty("infoAvailable", out var available) || available.ValueKind is not (JsonValueKind.True or JsonValueKind.False) ||
                    !row.TryGetProperty("lastResult", out var result)) throw Invalid();
                long? resultCode = null;
                if (result.ValueKind != JsonValueKind.Null) {
                    if (!result.TryGetInt64(out var code) || code < 0 || code > uint.MaxValue) throw Invalid();
                    resultCode = code;
                }
                var last = Time(row, "lastRun"); var next = Time(row, "nextRun");
                if (!available.GetBoolean() && (last is not null || next is not null || resultCode is not null)) throw Invalid();
                rows.Add(new(name, path, state, enabled.ValueKind == JsonValueKind.Null ? null : enabled.GetBoolean(), last, next, resultCode, available.GetBoolean()));
            }
            return new(rows.ToArray(), truncated.GetBoolean(), observedAt);
        } catch (Exception error) when (error is JsonException or InvalidOperationException or FormatException) { throw Invalid(); }
    }

    public static async Task<Inventory> CollectAsync(int limit, CancellationToken ct)
    {
        if (limit is < 1 or > 1000) throw new EngineException("INVALID_PARAMETERS", "limit must be between 1 and 1000.");
        ct.ThrowIfCancellationRequested();
        var script = $$"""
            $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
            [Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
            function Stamp($value) { if($null -eq $value -or $value.Year -le 1900){return $null}; return $value.ToString('yyyy-MM-ddTHH:mm:ss',[Globalization.CultureInfo]::InvariantCulture) }
            try {
              $tasks=@(Get-ScheduledTask -ErrorAction Stop | Select-Object -First {{limit + 1}})
              $rows=@(foreach($task in ($tasks | Select-Object -First {{limit}})) {
                $last=$null; $next=$null; $result=$null; $known=$false
                try { $info=$task | Get-ScheduledTaskInfo -ErrorAction Stop; $last=Stamp $info.LastRunTime; $next=Stamp $info.NextRunTime; $result=[long]$info.LastTaskResult; $known=$true } catch { $last=$null; $next=$null; $result=$null }
                $enabled=$null; if($null -ne $task.Settings.Enabled){$enabled=[bool]$task.Settings.Enabled}
                [pscustomobject]@{name=[string]$task.TaskName;path=[string]$task.TaskPath;state=$task.State.ToString();enabled=$enabled;lastRun=$last;nextRun=$next;lastResult=$result;infoAvailable=$known}
              })
              @{records=$rows;truncated=($tasks.Count -gt {{limit}})} | ConvertTo-Json -Depth 5 -Compress
            } catch { exit 2 }
            """;
        var executable = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
        var start = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8 };
        foreach (var argument in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", Convert.ToBase64String(Encoding.Unicode.GetBytes(script)) }) start.ArgumentList.Add(argument);
        using var process = new Process { StartInfo = start };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(20));
        var started = false; var oversized = false;
        try {
            started = process.Start();
            if (!started) throw new EngineException("TASK_QUERY_UNAVAILABLE", "Task Scheduler inspection could not start.");
            async Task<string> Read(StreamReader reader) {
                var output = new StringBuilder(); var buffer = new char[4096];
                while (true) {
                    var count = await reader.ReadAsync(buffer.AsMemory(), timeout.Token); if (count == 0) break;
                    if (output.Length + count > MaximumBytes) { oversized = true; timeout.Cancel(); throw Invalid(); }
                    output.Append(buffer, 0, count);
                }
                return output.ToString();
            }
            var output = Read(process.StandardOutput); var error = Read(process.StandardError);
            await Task.WhenAll(process.WaitForExitAsync(timeout.Token), output, error);
            if (process.ExitCode != 0) throw new EngineException("TASK_QUERY_UNAVAILABLE", "Task Scheduler inspection is unavailable for this account.");
            return Parse(await output, limit, DateTimeOffset.UtcNow.ToString("O"));
        } catch (OperationCanceledException) when (!ct.IsCancellationRequested) {
            if (oversized) throw Invalid();
            throw new EngineException("OPERATION_TIMEOUT", "Task Scheduler inspection exceeded twenty seconds.");
        } catch (System.ComponentModel.Win32Exception) {
            throw new EngineException("TASK_QUERY_UNAVAILABLE", "The supported Task Scheduler query could not start.");
        } finally {
            if (started && !process.HasExited) {
                try {
                    process.Kill();
                    using var ending = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                    await process.WaitForExitAsync(ending.Token);
                } catch (InvalidOperationException) when (process.HasExited) { }
                catch (Exception error) when (error is OperationCanceledException or System.ComponentModel.Win32Exception) {
                    throw new EngineException("TASK_QUERY_TEARDOWN_INCOMPLETE", "Inspection stopped waiting, but its query process exit is unverified. No task change was requested.");
                }
            }
        }
    }
}
