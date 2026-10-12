using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

/// <summary>Measured aggregate CPU and physical memory without optimization side effects.</summary>
public static class PerformanceSample
{
    public static double? CpuPercent(ulong idleBefore, ulong kernelBefore, ulong userBefore, ulong idleAfter, ulong kernelAfter, ulong userAfter)
    {
        if (idleAfter < idleBefore || kernelAfter < kernelBefore || userAfter < userBefore) return null;
        var kernel = kernelAfter - kernelBefore; var user = userAfter - userBefore; var idle = idleAfter - idleBefore;
        // Kernel time includes idle time. Reject impossible deltas rather than display invented percentages.
        if (ulong.MaxValue - kernel < user) return null;
        var total = kernel + user;
        if (total == 0 || idle > total) return null;
        return Math.Round(100.0 * (total - idle) / total, 2);
    }
    public static async Task<object> ReadAsync(JsonElement parameters, bool fixtureDataRoot, CancellationToken ct)
    {
        int interval = 500; var seen = new HashSet<string>();
        foreach (var field in parameters.EnumerateObject()) {
            if (field.Name != "intervalMs" || !seen.Add(field.Name) || field.Value.ValueKind != JsonValueKind.Number || !field.Value.TryGetInt32(out interval) || interval is < 250 or > 2000)
                throw new EngineException("INVALID_ARGUMENT", "Performance interval must be an integer from 250 through 2000 milliseconds.");
        }
        ct.ThrowIfCancellationRequested();
        bool before = GetSystemTimes(out var idleBefore, out var kernelBefore, out var userBefore);
        var clock = Stopwatch.StartNew();
        await Task.Delay(interval, ct);
        bool after = GetSystemTimes(out var idleAfter, out var kernelAfter, out var userAfter);
        clock.Stop();
        var percent = before && after ? CpuPercent(idleBefore, kernelBefore, userBefore, idleAfter, kernelAfter, userAfter) : null;
        var memory = new MemoryStatus { Length = (uint)Marshal.SizeOf<MemoryStatus>() };
        bool available = GlobalMemoryStatusEx(ref memory);
        return new {
            observedAt = DateTimeOffset.UtcNow, requestedIntervalMs = interval, measuredIntervalMs = Math.Round(clock.Elapsed.TotalMilliseconds, 2), fixtureDataRoot,
            cpu = new { available = percent != null, usagePercent = percent, measurementSource = "GetSystemTimes-aggregate-delta", logicalProcessors = Environment.ProcessorCount,
                unavailableReason = percent == null ? "CPU accounting is unavailable or changed during the measurement. No percentage was inferred." : null },
            memory = new { available, totalBytes = available ? (ulong?)memory.TotalPhysical : null, availableBytes = available ? (ulong?)memory.AvailablePhysical : null, loadPercent = available ? (uint?)memory.MemoryLoad : null,
                measurementSource = "GlobalMemoryStatusEx", unavailableReason = available ? null : "Physical memory accounting is unavailable. No values were inferred." },
            mutationPerformed = false, limitation = "CPU is sampled from GetSystemTimes. On hosts above 64 logical processors this API covers the calling thread processor group, not guaranteed whole-host usage. Memory is one end-of-interval snapshot. No GPU, temperature, per-process or disk throughput measurement is provided."
        };
    }
    [StructLayout(LayoutKind.Sequential)] private struct MemoryStatus { public uint Length, MemoryLoad; public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, AvailableExtendedVirtual; }
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
    [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool GetSystemTimes(out ulong idle, out ulong kernel, out ulong user);
}
