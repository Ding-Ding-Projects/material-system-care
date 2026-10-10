namespace MaterialSystemCare.Engine;

/// <summary>Explicit, disposable cleanup scope. Holds directories against replacement.</summary>
public sealed class CleanupFixture : IDisposable
{
    public const string MarkerName = "cleanup-fixture.json";
    public const string Marker = "{\"schemaVersion\":1,\"purpose\":\"MaterialSystemCare.cleanup-verification\"}";
    public static readonly string[] Methods = ["engine.ping", "settings.get", "settings.save", "history.list", "cleanup.scan", "cleanup.apply", "cleanup.restore", "cleanup.history", "cleanup.details"];
    public string Root { get; }
    public string Records => Path.Combine(Root, "records");
    public string Temp => Path.Combine(Root, "temp");
    private readonly List<IDisposable> locks = [];
    private readonly FileStream marker;

    public CleanupFixture(string root)
    {
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "Cleanup fixture mode requires Windows.");
        var parent = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "MaterialSystemCare-cleanup-fixtures"));
        if (!Path.IsPathFullyQualified(root) || root.StartsWith("\\\\", StringComparison.Ordinal) || root.Contains('/') || root.IndexOf(':', 2) >= 0)
            throw new EngineException("INVALID_FIXTURE", "A local fixture directory is required.");
        Root = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
        if (!string.Equals(Path.GetDirectoryName(Root), parent.TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase))
            throw new EngineException("INVALID_FIXTURE", "The fixture must be a direct child of the dedicated temporary directory.");
        try {
            foreach (var path in new[] { Root, Records, Temp }) {
                StorageSafeFile.ValidateAncestors(path);
                locks.Add(new StorageSafeFile.DestinationLocks(path));
            }
            marker = StorageSafeFile.OpenRead(Path.Combine(Root, MarkerName));
            locks.Add(marker);
            Validate();
        } catch { Dispose(); throw; }
    }
    public void Validate()
    {
        foreach (var scope in locks.OfType<StorageSafeFile.DestinationLocks>()) scope.Validate();
        foreach (var path in new[] { Root, Records, Temp }) StorageSafeFile.ValidateAncestors(path);
        marker.Position = 0;
        if (marker.Length != System.Text.Encoding.UTF8.GetByteCount(Marker)) throw new EngineException("INVALID_FIXTURE", "The fixture marker is invalid.");
        using var reader = new StreamReader(marker, System.Text.Encoding.UTF8, false, 1024, leaveOpen: true);
        if (reader.ReadToEnd() != Marker) throw new EngineException("INVALID_FIXTURE", "The fixture marker is invalid.");
        foreach (var file in Directory.EnumerateFileSystemEntries(Records)) StorageSafeFile.ValidateAncestors(file);
    }
    public void Dispose() { foreach (var item in locks) item.Dispose(); locks.Clear(); }
}
