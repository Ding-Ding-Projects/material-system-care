using System.Text.Json;

namespace MaterialSystemCare.Engine;

public static class SystemMonitor
{
    public sealed record Volume(string Id, bool Available, long? TotalBytes, long? FreeBytes, double? UsedPercent, string? Reason);
    public sealed record Measurement(string ObservedAt, double MeasuredIntervalMs, int RequestedIntervalMs, double? CpuPercent, uint? MemoryPercent,
        ulong? TotalMemoryBytes, ulong? AvailableMemoryBytes, Volume[] Volumes, string CpuScope, string[] Limitations, bool MutationPerformed = false);
    public sealed record Alert(string Metric, string TargetId, double? Value, double Threshold, string State, string? Reason, string ObservedAt);
    public static readonly string[] Limitations = ["CPU accounting uses the calling thread primary processor group above 64 logical processors.", "Physical memory and fixed-volume capacities are end-of-interval snapshots, not throughput or hardware health.", "No temperature, SMART-health, GPU-load or disk-throughput provider is bundled."];
    public static Dictionary<string, double> Thresholds(JsonElement p)
    {
        if (p.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_ARGUMENT", "Thresholds must be an object."); var thresholds = new Dictionary<string, double>(StringComparer.Ordinal);
        foreach (var field in p.EnumerateObject()) {
            if (field.Name is not ("cpuPercent" or "memoryPercent" or "diskUsedPercent") || thresholds.ContainsKey(field.Name) || field.Value.ValueKind != JsonValueKind.Number || !field.Value.TryGetDouble(out var value) || !double.IsFinite(value) || value < 0 || value > 100) throw new EngineException("INVALID_ARGUMENT", "Explicit thresholds must be finite percentages from 0 through 100.");
            thresholds.Add(field.Name, value);
        }
        if (thresholds.Count == 0) throw new EngineException("INVALID_ARGUMENT", "Select at least one actual measured threshold."); return thresholds;
    }
    public static Alert[] Evaluate(Measurement measurement, IReadOnlyDictionary<string,double> thresholds)
    {
        var alerts = new List<Alert>();
        void Add(string metric, string target, double? value, string? reason) {
            if (!thresholds.TryGetValue(metric, out var threshold)) return;
            if (!double.IsFinite(threshold) || threshold is < 0 or > 100) throw new EngineException("INVALID_ARGUMENT", "An alert threshold is invalid.");
            alerts.Add(new(metric, target, value, threshold, value == null ? "unavailable" : value >= threshold ? "threshold-reached" : "below-threshold", value == null ? reason : null, measurement.ObservedAt));
        }
        Add("cpuPercent", "cpu", measurement.CpuPercent, "A valid CPU accounting delta was unavailable.");
        Add("memoryPercent", "memory", measurement.MemoryPercent, "Physical-memory accounting was unavailable.");
        if (measurement.Volumes.Length == 0) Add("diskUsedPercent", "fixed-volumes", null, "No readable fixed-volume capacity was discovered.");
        foreach (var volume in measurement.Volumes) Add("diskUsedPercent", volume.Id, volume.UsedPercent, volume.Reason);
        return alerts.ToArray();
    }
    public static async Task<Measurement> CollectAsync(int intervalMs, CancellationToken ct)
    {
        var sample = JsonSerializer.SerializeToElement(await PerformanceSample.ReadAsync(JsonSerializer.SerializeToElement(new { intervalMs }), false, ct), Program.JsonOptions);
        var cpu = sample.GetProperty("cpu"); var memory = sample.GetProperty("memory"); var volumes = new List<Volume>();
        foreach (var drive in DriveInfo.GetDrives().Take(64)) {
            ct.ThrowIfCancellationRequested();
            try {
                if (drive.DriveType != DriveType.Fixed) continue;
                if (!drive.IsReady) { volumes.Add(new(drive.Name,false,null,null,null,"The fixed volume is not ready.")); continue; }
                var total = drive.TotalSize; var free = drive.AvailableFreeSpace;
                if (total <= 0 || free < 0 || free > total) { volumes.Add(new(drive.Name,false,null,null,null,"The fixed-volume capacity counters are inconsistent.")); continue; }
                volumes.Add(new(drive.Name,true,total,free,Math.Round(100.0 * (total-free)/total,2),null));
            } catch (Exception error) when (error is IOException or UnauthorizedAccessException) { volumes.Add(new(drive.Name,false,null,null,null,"The fixed-volume capacity is unavailable to this account.")); }
        }
        return new(sample.GetProperty("observedAt").GetString()!, sample.GetProperty("measuredIntervalMs").GetDouble(), intervalMs,
            cpu.GetProperty("available").GetBoolean() ? cpu.GetProperty("usagePercent").GetDouble() : null,
            memory.GetProperty("available").GetBoolean() ? memory.GetProperty("loadPercent").GetUInt32() : null,
            memory.GetProperty("available").GetBoolean() ? memory.GetProperty("totalBytes").GetUInt64() : null,
            memory.GetProperty("available").GetBoolean() ? memory.GetProperty("availableBytes").GetUInt64() : null,
            volumes.ToArray(), "GetSystemTimes-primary-processor-group", Limitations);
    }
}
