using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

/// <summary>Structured WinGet inventory. Display names are never guessed into IDs.</summary>
public static class PackageInventory
{
    public const int MaximumBytes = 2 * 1024 * 1024;
    public const int MaximumPackages = 10000;
    public sealed record PackageRecord(string Id, string Name, string PackageId, string? Version,
        string Source, bool CanUninstall, bool CanUpgrade, string UpdateAvailability);

    public static PackageRecord[] Parse(string json)
    {
        if (Encoding.UTF8.GetByteCount(json) > MaximumBytes) throw Invalid("Package inventory exceeds its size limit.");
        try {
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty("Sources", out var sources) || sources.ValueKind != JsonValueKind.Array) throw Invalid("Package inventory has no source array.");
            var records = new List<PackageRecord>();
            var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var source in sources.EnumerateArray()) {
                if (source.ValueKind != JsonValueKind.Object || !source.TryGetProperty("SourceDetails", out var details) || details.ValueKind != JsonValueKind.Object) throw Invalid("Package source details are missing.");
                string? Field(JsonElement item, string name) => item.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
                // The mutation adapter uses --source winget. Do not silently
                // associate store, private, or renamed sources with that adapter.
                if (Field(details, "Name") != "winget" || Field(details, "Identifier") != "Microsoft.Winget.Source_8wekyb3d8bbwe") throw Invalid("Only packages matched to the standard WinGet source are supported.");
                if (!source.TryGetProperty("Packages", out var packages) || packages.ValueKind != JsonValueKind.Array) throw Invalid("Package source has no package array.");
                foreach (var package in packages.EnumerateArray()) {
                    if (package.ValueKind != JsonValueKind.Object) throw Invalid("Invalid package record.");
                    var id = Field(package, "PackageIdentifier");
                    if (id is null || !ManagementPolicy.ValidPackageId(id)) throw Invalid("Invalid exact package identifier in export.");
                    if (!ids.Add(id)) throw Invalid("Duplicate package identifiers require a refreshed inventory.");
                    if (records.Count >= MaximumPackages) throw Invalid("Package inventory exceeds its record limit.");
                    var version = Field(package, "Version");
                    if (package.TryGetProperty("Version", out _) && (version is null || version.Length > 256 || version.Any(char.IsControl))) throw Invalid("Invalid installed version.");
                    records.Add(new("winget:" + id, id, id, version, "winget", true, true, "not-checked"));
                }
            }
            return records.OrderBy(record => record.PackageId, StringComparer.OrdinalIgnoreCase).ToArray();
        } catch (JsonException) { throw Invalid("WinGet returned malformed inventory JSON."); }
    }

    private static EngineException Invalid(string message) => new("INVALID_PACKAGE_INVENTORY", message);

    public static async Task<object> CollectAsync(string dataRoot, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WindowsApps", "winget.exe");
        if (!File.Exists(executable)) return new { available = false, records = Array.Empty<PackageRecord>(), reason = "WinGet is not installed for the current user." };
        var folder = Path.Combine(dataRoot, "package-discovery-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        var output = Path.Combine(folder, "packages.json");
        try {
            var info = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            // Existing source agreements must already be accepted. Discovery
            // never accepts a new agreement or changes source configuration.
            foreach (var arg in new[] { "export", "--output", output, "--include-versions", "--source", "winget", "--disable-interactivity" }) info.ArgumentList.Add(arg);
            using var process = new Process { StartInfo = info };
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(TimeSpan.FromSeconds(90));
            var started = false;
            var tooLarge = false;
            try {
                started = process.Start();
                if (!started) throw new EngineException("PACKAGE_DISCOVERY_UNAVAILABLE", "WinGet discovery could not start.");
                async Task Drain(StreamReader stream) {
                    var buffer = new char[4096]; var total = 0;
                    while (true) { var n = await stream.ReadAsync(buffer.AsMemory(), timeout.Token); if (n == 0) return; total += n; if (total > MaximumBytes) { tooLarge = true; timeout.Cancel(); throw new EngineException("RESULT_TOO_LARGE", "WinGet output exceeded its limit."); } }
                }
                async Task WatchExport() {
                    while (!process.HasExited) {
                        var file = new FileInfo(output);
                        if (file.Exists && file.Length > MaximumBytes) {
                            tooLarge = true; timeout.Cancel();
                            throw new EngineException("RESULT_TOO_LARGE", "WinGet export exceeded its limit.");
                        }
                        await Task.Delay(100, timeout.Token);
                    }
                }
                await Task.WhenAll(process.WaitForExitAsync(timeout.Token), Drain(process.StandardOutput), Drain(process.StandardError), WatchExport());
                if (process.ExitCode != 0) return new { available = false, records = Array.Empty<PackageRecord>(), exitCode = process.ExitCode, reason = "WinGet discovery did not complete. Check its installation, source availability and previously accepted source agreements. No source configuration was changed." };
            } catch (OperationCanceledException) when (!ct.IsCancellationRequested) {
                if (tooLarge) throw new EngineException("RESULT_TOO_LARGE", "WinGet output exceeded its limit.");
                throw new EngineException("OPERATION_TIMEOUT", "WinGet discovery exceeded ninety seconds.");
            } catch (System.ComponentModel.Win32Exception) {
                throw new EngineException("PACKAGE_DISCOVERY_UNAVAILABLE", "WinGet could not be launched for this account.");
            } finally {
                if (started && !process.HasExited) {
                    try {
                        process.Kill(true);
                        using var teardown = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                        await process.WaitForExitAsync(teardown.Token);
                    } catch (InvalidOperationException) when (process.HasExited) { }
                    catch (Exception error) when (error is OperationCanceledException or System.ComponentModel.Win32Exception) {
                        throw new EngineException("DISCOVERY_TEARDOWN_INCOMPLETE", "Discovery stopped waiting, but exit of its WinGet process could not be confirmed. No package change was requested.");
                    }
                }
            }
            if (!File.Exists(output) || (File.GetAttributes(output) & FileAttributes.ReparsePoint) != 0) throw Invalid("WinGet did not produce a regular inventory file.");
            await using var stream = new FileStream(output, FileMode.Open, FileAccess.Read, FileShare.Read);
            if (stream.Length > MaximumBytes) throw Invalid("Package inventory exceeds its size limit.");
            using var reader = new StreamReader(stream, new UTF8Encoding(false, true));
            var records = Parse(await reader.ReadToEndAsync(ct));
            return new { available = true, records, completeInstalledInventory = false, updateAvailability = "not-checked",
                limitation = "Only installed packages matched by WinGet are listed. Unmatched applications remain in the general inventory. Available update versions are not inferred from an export." };
        } finally {
            // Only this request's exact output and empty scratch directory are removed.
            try { if (File.Exists(output)) File.Delete(output); Directory.Delete(folder, false); }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
                throw new EngineException("DISCOVERY_CLEANUP_INCOMPLETE", "Discovery ended, but its temporary local inventory could not be removed. A copy may remain in this account's application data. No package was changed.");
            }
        }
    }
}
