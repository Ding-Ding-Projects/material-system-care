using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

public static class SystemInventory
{
    public const int MaximumBytes = 2 * 1024 * 1024;
    public const int MaximumRecordsPerCategory = 256;
    public sealed record Field(string Name, string Kind);
    public sealed record Category(string Id, string ClassName, Field[] Fields);
    public static readonly Category[] Categories = [
        new("cpu", "Win32_Processor", [new("Name","text"),new("Manufacturer","text"),new("NumberOfCores","number"),new("NumberOfLogicalProcessors","number"),new("MaxClockSpeed","number"),new("Architecture","number")]),
        new("os", "Win32_OperatingSystem", [new("Caption","text"),new("Version","text"),new("BuildNumber","text"),new("OSArchitecture","text")]),
        new("computer", "Win32_ComputerSystem", [new("Manufacturer","text"),new("Model","text"),new("SystemType","text"),new("HypervisorPresent","bool")]),
        new("board", "Win32_BaseBoard", [new("Manufacturer","text"),new("Product","text"),new("Version","text")]),
        new("bios", "Win32_BIOS", [new("Manufacturer","text"),new("SMBIOSBIOSVersion","text"),new("Version","text")]),
        new("memory", "Win32_PhysicalMemory", [new("Manufacturer","text"),new("Capacity","number"),new("Speed","number"),new("ConfiguredClockSpeed","number")]),
        new("gpu", "Win32_VideoController", [new("Name","text"),new("AdapterCompatibility","text"),new("DriverVersion","text"),new("VideoProcessor","text")]),
        new("disk", "Win32_DiskDrive", [new("Model","text"),new("InterfaceType","text"),new("MediaType","text"),new("Size","number")]),
        new("device", "Win32_PnPEntity", [new("Name","text"),new("Manufacturer","text"),new("PNPClass","text"),new("Status","text"),new("ConfigManagerErrorCode","number")])
    ];
    public sealed record HardwareRecord(string Id, string Category, Dictionary<string, JsonElement> Values);
    public sealed record ProviderState(string Category, bool Available, string? Code, string? Reason, int RecordCount, bool Truncated);
    public sealed record SensorState(string Metric, bool Available, string Code, string Reason);
    public sealed record Snapshot(int SchemaVersion, string ObservedAt, HardwareRecord[] Records, ProviderState[] Providers, SensorState[] Sensors,
        string[] PrivacyExclusions, bool MutationPerformed = false, string Limitation = "Provider-reported descriptions are not hardware health or verified sensor measurements. Device names may contain user-assigned labels. Reports remain local.");
    private static EngineException Invalid() => new("INVALID_SYSTEM_INVENTORY", "The local provider returned malformed, inconsistent or oversized inventory.");
    public static Snapshot Unavailable(string code, string reason) => new(1, DateTimeOffset.UtcNow.ToString("O"), [],
        Categories.Select(c => new ProviderState(c.Id, false, code, Reason(code), 0, false)).ToArray(), Sensors(), Exclusions());
    public static string? Reason(string? code) => code switch {
        "ACCESS_DENIED" => "This account cannot read the selected local CIM provider.",
        "PROVIDER_TIMEOUT" => "The local CIM provider exceeded its bounded query interval.",
        "PROVIDER_UNAVAILABLE" => "The local CIM class or provider is unavailable.",
        "FIXTURE_COLLECTION_DISABLED" => "Host inventory collection is disabled in fixture mode.",
        "PLATFORM_UNSUPPORTED" => "Local CIM inventory requires Windows.",
        "QUERY_RUNTIME_UNAVAILABLE" => "The operating-system PowerShell CIM query runtime is unavailable.",
        "QUERY_START_FAILED" => "The local read-only inventory query could not start.",
        "QUERY_FAILED" => "The local read-only inventory query could not produce a valid result.",
        "QUERY_TIMEOUT" => "The complete local inventory query exceeded twenty-five seconds.", _ => null
    };
    private static SensorState[] Sensors() => [
        new("temperatureCelsius", false, "SENSOR_PROVIDER_UNAVAILABLE", "No supported per-component temperature provider is bundled. ACPI thermal-zone readings are not assumed to be CPU or GPU temperatures."),
        new("gpuUsagePercent", false, "GPU_LOAD_PROVIDER_UNAVAILABLE", "Video-controller descriptions do not measure GPU engine utilization. No GPU-load adapter is bundled."),
        new("diskSmartHealth", false, "SMART_PROVIDER_UNAVAILABLE", "Disk model and capacity do not establish SMART health. No supported SMART-health adapter is bundled.")
    ];
    private static string[] Exclusions() => ["serial-numbers", "processor-identifiers", "device-instance-identifiers", "computer-name", "registered-user", "user-profiles", "network-addresses", "license-keys"];
    public static Snapshot Parse(string json, string observedAt)
    {
        if (Encoding.UTF8.GetByteCount(json) > MaximumBytes || !DateTimeOffset.TryParseExact(observedAt, "O", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)) throw Invalid();
        try {
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 12 }); var root = document.RootElement;
            Strict(root, "providers"); var providers = Required(root, "providers", JsonValueKind.Array);
            if (providers.GetArrayLength() != Categories.Length) throw Invalid();
            var seen = new HashSet<string>(StringComparer.Ordinal); var records = new List<HardwareRecord>(); var states = new List<ProviderState>();
            foreach (var provider in providers.EnumerateArray()) {
                Strict(provider, "category", "available", "code", "truncated", "records"); var id = Required(provider, "category", JsonValueKind.String).GetString()!;
                var category = Categories.SingleOrDefault(c => c.Id == id); if (category == null || !seen.Add(id)) throw Invalid();
                var available = Boolean(provider, "available"); var truncated = Boolean(provider, "truncated"); var rows = Required(provider, "records", JsonValueKind.Array);
                if (rows.GetArrayLength() > MaximumRecordsPerCategory) throw Invalid();
                var codeElement = provider.GetProperty("code"); string? code = null;
                if (codeElement.ValueKind != JsonValueKind.Null) {
                    if (codeElement.ValueKind != JsonValueKind.String || codeElement.GetString() is not ("PROVIDER_UNAVAILABLE" or "ACCESS_DENIED" or "PROVIDER_TIMEOUT" or "FIXTURE_COLLECTION_DISABLED" or "PLATFORM_UNSUPPORTED" or "QUERY_RUNTIME_UNAVAILABLE" or "QUERY_START_FAILED" or "QUERY_FAILED" or "QUERY_TIMEOUT")) throw Invalid(); code = codeElement.GetString();
                }
                if (available != (code == null) || !available && (rows.GetArrayLength() != 0 || truncated)) throw Invalid();
                if(truncated && rows.GetArrayLength()!=MaximumRecordsPerCategory)throw Invalid();
                int index = 0;
                foreach (var row in rows.EnumerateArray()) {
                    Strict(row, category.Fields.Select(f => f.Name).ToArray()); var values = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
                    foreach (var field in category.Fields) {
                        if (!row.TryGetProperty(field.Name, out var value)) throw Invalid();
                        if (value.ValueKind != JsonValueKind.Null) {
                            bool valid = field.Kind switch {
                                "text" => value.ValueKind == JsonValueKind.String && value.GetString()!.Length <= 512 && !value.GetString()!.Any(char.IsControl),
                                "number" => value.ValueKind == JsonValueKind.Number && value.TryGetUInt64(out _),
                                "bool" => value.ValueKind is JsonValueKind.True or JsonValueKind.False,
                                _ => false };
                            if (!valid) throw Invalid();
                        }
                        values.Add(field.Name, value.Clone());
                    }
                    records.Add(new(id + ":" + index++, id, values));
                }
                states.Add(new(id, available, code, Reason(code), rows.GetArrayLength(), truncated));
            }
            return new(1, observedAt, records.OrderBy(r => r.Category, StringComparer.Ordinal).ThenBy(r => int.Parse(r.Id[(r.Id.IndexOf(':')+1)..], CultureInfo.InvariantCulture)).ToArray(), states.OrderBy(s => s.Category, StringComparer.Ordinal).ToArray(), Sensors(), Exclusions());
        } catch (Exception error) when (error is JsonException or InvalidOperationException or KeyNotFoundException or FormatException) { throw Invalid(); }
    }
    internal static void Strict(JsonElement item, params string[] allowed)
    {
        if (item.ValueKind != JsonValueKind.Object) throw Invalid(); var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var field in item.EnumerateObject()) if (!allowed.Contains(field.Name, StringComparer.Ordinal) || !seen.Add(field.Name)) throw Invalid();
    }
    private static JsonElement Required(JsonElement row, string name, JsonValueKind kind) { if (!row.TryGetProperty(name, out var value) || value.ValueKind != kind) throw Invalid(); return value; }
    private static bool Boolean(JsonElement row, string name) { if (!row.TryGetProperty(name, out var value) || value.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) throw Invalid(); return value.GetBoolean(); }
    public static async Task<Snapshot> CollectAsync(CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (!OperatingSystem.IsWindows()) return Unavailable("PLATFORM_UNSUPPORTED", "Local CIM inventory requires Windows.");
        var executable = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!File.Exists(executable)) return Unavailable("QUERY_RUNTIME_UNAVAILABLE", "The operating-system PowerShell CIM query runtime is unavailable.");
        var commands = new StringBuilder();
        foreach (var category in Categories) {
            var names = string.Join(',', category.Fields.Select(f => "'" + f.Name + "'"));
            commands.AppendLine($"Collect '{category.Id}' '{category.ClassName}' @({names})");
        }
        var script = """
            $ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'
            [Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
            function Collect($category,$class,$fields) {
              try {
                $items=@(Get-CimInstance -ClassName $class -Property $fields -OperationTimeoutSec 2 -ErrorAction Stop | Select-Object -First 257)
                $rows=@(foreach($item in ($items | Select-Object -First 256)) {
                  $row=[ordered]@{}; foreach($field in $fields){$row[$field]=$item.$field}; [pscustomobject]$row
                })
                [pscustomobject]@{category=$category;available=$true;code=$null;truncated=($items.Count -gt 256);records=$rows}
              } catch {
                $code='PROVIDER_UNAVAILABLE'
                if($_.Exception -is [UnauthorizedAccessException] -or $_.Exception.NativeErrorCode -eq 2){$code='ACCESS_DENIED'}
                if($_.Exception.NativeErrorCode -eq 22){$code='PROVIDER_TIMEOUT'}
                [pscustomobject]@{category=$category;available=$false;code=$code;truncated=$false;records=@()}
              }
            }
            $providers=@(
            """ + "\n" + commands + "\n)\n@{providers=$providers} | ConvertTo-Json -Depth 8 -Compress\n";
        var start = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8 };
        foreach (var arg in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", Convert.ToBase64String(Encoding.Unicode.GetBytes(script)) }) start.ArgumentList.Add(arg);
        using var process = new Process { StartInfo = start }; using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(25));
        bool started = false; DateTime created = default;
        try {
            started = process.Start(); if (!started) return Unavailable("QUERY_START_FAILED", "The local read-only inventory query could not start.");
            _ = process.SafeHandle; created = process.StartTime;
            async Task<string> Read(StreamReader reader) {
                var output = new StringBuilder(); var buffer = new char[4096];
                while (true) { int read = await reader.ReadAsync(buffer.AsMemory(), timeout.Token); if (read == 0) break; if (output.Length + read > MaximumBytes) { timeout.Cancel(); throw Invalid(); } output.Append(buffer, 0, read); }
                return output.ToString();
            }
            var output = Read(process.StandardOutput); var error = Read(process.StandardError);
            await Task.WhenAll(process.WaitForExitAsync(timeout.Token), output, error);
            if (process.ExitCode != 0) return Unavailable("QUERY_FAILED", "The local read-only inventory query could not produce a valid result.");
            return Parse(await output, DateTimeOffset.UtcNow.ToString("O"));
        } catch (OperationCanceledException) when (!ct.IsCancellationRequested) { return Unavailable("QUERY_TIMEOUT", "The complete local inventory query exceeded twenty-five seconds."); }
        catch (System.ComponentModel.Win32Exception) { return Unavailable("QUERY_START_FAILED", "The local read-only inventory runtime could not start."); }
        finally {
            if (started && !process.HasExited) {
                if (process.StartTime != created || !string.Equals(process.MainModule?.FileName, executable, StringComparison.OrdinalIgnoreCase)) throw new EngineException("QUERY_IDENTITY_CHANGED", "The owned query process identity could not be revalidated for teardown.");
                process.Kill(); using var ending = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                try { await process.WaitForExitAsync(ending.Token); }
                catch (OperationCanceledException) { throw new EngineException("QUERY_TEARDOWN_INCOMPLETE", "The owned query process exit could not be verified."); }
            }
        }
    }
}
