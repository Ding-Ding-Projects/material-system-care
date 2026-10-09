using System.Runtime.InteropServices;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

public sealed class SystemModule : IEngineModule
{
    public bool CanHandle(string method) => method is "engine.ping" or "system.snapshot" or "settings.get" or "settings.save" or "history.list";
    public async Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken)
    {
        switch (method) {
            case "engine.ping":
                JsonElement? manifest = null;
                var manifestPath = Path.Combine(AppContext.BaseDirectory, "build-manifest.json");
                if (File.Exists(manifestPath)) manifest = JsonSerializer.Deserialize<JsonElement>(await File.ReadAllTextAsync(manifestPath, cancellationToken));
                JsonElement? buildReceipt = null;
                var receiptPath = Path.Combine(AppContext.BaseDirectory, "build-receipt.json");
                if (File.Exists(receiptPath)) buildReceipt = JsonSerializer.Deserialize<JsonElement>(await File.ReadAllTextAsync(receiptPath, cancellationToken));
                return new { protocolVersion = 1, manifest, buildReceipt, fixture = context.IsFixture, elevated = context.IsElevated, capabilities = new[] { "system.snapshot", "settings.get", "settings.save", "history.list" } };
            case "settings.get":
                if (parameters.TryGetProperty("key", out var key) && key.ValueKind == JsonValueKind.String) return await context.ReadSettingAsync(key.GetString()!, cancellationToken);
                return await context.ReadSettingsAsync(cancellationToken);
            case "settings.save":
                if (!parameters.TryGetProperty("key", out key) || key.ValueKind != JsonValueKind.String || !parameters.TryGetProperty("value", out var value)) throw new EngineException("INVALID_SETTING", "A key and value are required.");
                await context.SaveSettingAsync(key.GetString()!, value, cancellationToken); return new { saved = true };
            case "history.list":
                var limit = 100;
                if (parameters.TryGetProperty("limit", out var requested) && (requested.ValueKind != JsonValueKind.Number || !requested.TryGetInt32(out limit) || limit is < 1 or > 1000)) throw new EngineException("INVALID_LIMIT", "History limit must be between 1 and 1000.");
                return new { records = await context.ReadHistoryAsync(limit, cancellationToken), order = "newest-first" };
            default:
                var memory = new MemoryStatus { Length = (uint)Marshal.SizeOf<MemoryStatus>() };
                var available = GlobalMemoryStatusEx(ref memory);
                var drives = DriveInfo.GetDrives().Select(d => { try { return (object)new { id = d.Name, name = d.Name, ready = d.IsReady, totalBytes = d.IsReady ? (long?)d.TotalSize : null, freeBytes = d.IsReady ? (long?)d.AvailableFreeSpace : null, format = d.IsReady ? d.DriveFormat : null }; } catch (IOException) { return new { id = d.Name, name = d.Name, ready = false, unavailableReason = "Volume metadata is unavailable." }; } catch (UnauthorizedAccessException) { return new { id = d.Name, name = d.Name, ready = false, unavailableReason = "Volume access is unavailable." }; } }).ToArray();
                return new { measuredAt = DateTimeOffset.UtcNow, fixtureDataRoot = context.IsFixture, measurementSource = "live-machine", cpu = new { logicalProcessors = Environment.ProcessorCount }, os = new { description = RuntimeInformation.OSDescription, architecture = RuntimeInformation.OSArchitecture.ToString() }, memory = new { available, totalBytes = available ? (ulong?)memory.TotalPhysical : null, availableBytes = available ? (ulong?)memory.AvailablePhysical : null, loadPercent = available ? (uint?)memory.MemoryLoad : null }, drives };
        }
    }
    [StructLayout(LayoutKind.Sequential)] private struct MemoryStatus { public uint Length, MemoryLoad; public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtendedVirtual; }
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
}
