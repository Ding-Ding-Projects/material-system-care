using System.Security.Cryptography;
using System.Text.Json;

namespace MaterialSystemCare.Engine;

/// <summary>Bounded read-only analysis and plan-based reversible temporary-file cleanup.</summary>
public sealed class StorageModule : IEngineModule
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly string? fixtureTempRoot;
    public StorageModule() { }
    internal StorageModule(string fixtureTempRoot) { this.fixtureTempRoot = Path.GetFullPath(fixtureTempRoot); }
    public bool CanHandle(string method) => method is "storage.analyze" or "storage.duplicates" or "cleanup.scan" or "cleanup.apply" or "cleanup.restore" or "cleanup.history";

    public async Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken)
    {
        try
        {
            return method switch
            {
                "storage.analyze" => await Analyze(parameters, cancellationToken),
                "storage.duplicates" => await Duplicates(parameters, cancellationToken),
                "cleanup.scan" => await Scan(parameters, context, cancellationToken),
                "cleanup.apply" => await Apply(parameters, context, cancellationToken),
                "cleanup.restore" => await Restore(parameters, context, cancellationToken),
                "cleanup.history" => await History(context, cancellationToken),
                _ => throw new EngineException("METHOD_NOT_FOUND", "Unknown storage method.")
            };
        }
        catch (EngineException) { throw; }
        catch (OperationCanceledException) { throw; }
        catch (UnauthorizedAccessException) { throw new EngineException("ACCESS_DENIED", "The selected location is not accessible."); }
        catch (IOException) { throw new EngineException("STORAGE_IO", "The storage operation could not complete. Existing recovery records were retained."); }
        catch (JsonException) { throw new EngineException("INVALID_PLAN", "The recovery record is invalid."); }
        catch (ArgumentException) { throw new EngineException("INVALID_ARGUMENT", "A storage argument or persisted value is invalid."); }
    }

    private static string Text(JsonElement p, string name)
    {
        if (!p.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()) || value.GetString()!.Length > 1024)
            throw new EngineException("INVALID_ARGUMENT", $"A bounded {name} string is required.");
        return value.GetString()!;
    }
    private static int Number(JsonElement p, string name, int fallback, int min, int max)
    {
        if (!p.TryGetProperty(name, out var value)) return fallback;
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out int n) || n < min || n > max) throw new EngineException("INVALID_ARGUMENT", $"{name} is outside its allowed range.");
        return n;
    }
    private static void Confirm(JsonElement p)
    {
        if (!p.TryGetProperty("confirmed", out var c) || c.ValueKind != JsonValueKind.True) throw new EngineException("CONFIRMATION_REQUIRED", "Explicit confirmation is required.");
    }
    private static string Root(JsonElement p)
    {
        string root = Path.GetFullPath(Text(p, "path"));
        if (!Directory.Exists(root)) throw new EngineException("PATH_NOT_FOUND", "Select an existing folder.");
        StorageSafeFile.ValidateAncestors(root);
        return root;
    }
    private sealed record Entry(string Path, long Size, long ModifiedTicks, long CreatedTicks);
    private sealed class WalkResult
    {
        public List<Entry> Files { get; } = [];
        public List<string> EmptyFolders { get; } = [];
        public int Inaccessible { get; set; }
        public int ReparseSkipped { get; set; }
        public int TooDeep { get; set; }
        public bool Truncated { get; set; }
        public int Visited { get; set; }
    }
    private static WalkResult Walk(string root, int limit, CancellationToken ct)
    {
        var result = new WalkResult();
        var pending = new Stack<(string Path, int Depth)>();
        pending.Push((root, 0));
        while (pending.TryPop(out var dir))
        {
            ct.ThrowIfCancellationRequested();
            if (dir.Depth > 64) { result.TooDeep++; continue; }
            try
            {
                StorageSafeFile.ValidateAncestors(dir.Path);
                bool any = false;
                foreach (string path in Directory.EnumerateFileSystemEntries(dir.Path))
                {
                    ct.ThrowIfCancellationRequested();
                    any = true;
                    if (++result.Visited > limit) { result.Truncated = true; return result; }
                    if (path.Length > 1024) { result.Inaccessible++; continue; }
                    try
                    {
                        var attr = File.GetAttributes(path);
                        if ((attr & FileAttributes.ReparsePoint) != 0) { result.ReparseSkipped++; continue; }
                        if ((attr & FileAttributes.Directory) != 0) pending.Push((path, dir.Depth + 1));
                        else
                        {
                            var f = new FileInfo(path);
                            result.Files.Add(new(path, f.Length, f.LastWriteTimeUtc.Ticks, f.CreationTimeUtc.Ticks));
                        }
                    }
                    catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { result.Inaccessible++; }
                }
                if (!any) result.EmptyFolders.Add(dir.Path);
            }
            catch (EngineException) { result.ReparseSkipped++; }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { result.Inaccessible++; }
        }
        return result;
    }
    private static async Task<object> Analyze(JsonElement p, CancellationToken ct)
    {
        string root = Root(p);
        var scan = await Task.Run(() => Walk(root, Number(p, "maxEntries", 20000, 1, 100000), ct), ct);
        return new { root, fileCount = scan.Files.Count, totalBytes = scan.Files.Sum(x => x.Size), scan.Inaccessible, scan.ReparseSkipped, scan.TooDeep, scan.Truncated,
            largeFiles = scan.Files.OrderByDescending(x => x.Size).Take(100).Select(x => new { path = x.Path, size = x.Size, modifiedUtc = new DateTime(x.ModifiedTicks, DateTimeKind.Utc) }),
            emptyFolders = scan.EmptyFolders.Take(1000), emptyFolderCount = scan.EmptyFolders.Count, scope = "selected-folder-only", mutationPerformed = false };
    }
    private static async Task<object> Duplicates(JsonElement p, CancellationToken ct)
    {
        string root = Root(p);
        var scan = await Task.Run(() => Walk(root, Number(p, "maxEntries", 10000, 1, 50000), ct), ct);
        long budget = Number(p, "maxHashMiB", 512, 1, 4096) * 1024L * 1024;
        long hashedBytes = 0;
        int changedOrUnavailable = 0;
        bool budgetReached = false;
        var groups = new List<object>();
        foreach (var sizes in scan.Files.GroupBy(x => x.Size).Where(x => x.Count() > 1))
        {
            var hashes = new Dictionary<string, List<Entry>>(StringComparer.Ordinal);
            foreach (var file in sizes)
            {
                ct.ThrowIfCancellationRequested();
                if (hashedBytes + file.Size > budget) { budgetReached = true; continue; }
                try
                {
                    using var stream = StorageSafeFile.OpenRead(file.Path);
                    if (!Matches(file, stream)) { changedOrUnavailable++; continue; }
                    string hash = Convert.ToHexString(await SHA256.HashDataAsync(stream, ct));
                    hashedBytes += file.Size;
                    if (!Matches(file, stream)) { changedOrUnavailable++; continue; }
                    if (!hashes.TryGetValue(hash, out var list)) hashes[hash] = list = [];
                    list.Add(file);
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException) { changedOrUnavailable++; }
            }
            foreach (var candidates in hashes.Values.Where(x => x.Count > 1))
            {
                var exactGroups = new List<List<Entry>>();
                foreach (var candidate in candidates)
                {
                    bool joined = false;
                    foreach (var exact in exactGroups)
                    {
                        try
                        {
                            if (await Equal(exact[0], candidate, ct)) { exact.Add(candidate); joined = true; break; }
                        }
                        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException) { changedOrUnavailable++; }
                    }
                    if (!joined) exactGroups.Add([candidate]);
                }
                foreach (var exact in exactGroups.Where(x => x.Count > 1).Take(100))
                {
                    if (groups.Count >= 100) { budgetReached = true; break; }
                    groups.Add(new { size = exact[0].Size, paths = exact.Take(20).Select(x => x.Path), totalMatchingFiles = exact.Count, pathsTruncated = exact.Count > 20, reclaimableBytes = exact[0].Size * (exact.Count - 1), verification = "sha256-and-byte-comparison" });
                }
            }
        }
        return new { root, groups, hashedBytes, budgetReached, changedOrUnavailable, scan.Inaccessible, scan.ReparseSkipped, scan.Truncated, mutationPerformed = false };
    }
    private static bool Matches(Entry e, FileStream stream)
    {
        var f = new FileInfo(e.Path);
        return stream.Length == e.Size && f.Length == e.Size && f.LastWriteTimeUtc.Ticks == e.ModifiedTicks && f.CreationTimeUtc.Ticks == e.CreatedTicks;
    }
    private static async Task<bool> Equal(Entry a, Entry b, CancellationToken ct)
    {
        using var left = StorageSafeFile.OpenRead(a.Path);
        using var right = StorageSafeFile.OpenRead(b.Path);
        if (!Matches(a, left) || !Matches(b, right)) return false;
        byte[] x = new byte[65536], y = new byte[65536];
        while (true)
        {
            int nx = await left.ReadAsync(x, ct), ny = await right.ReadAsync(y, ct);
            if (nx != ny || !x.AsSpan(0, nx).SequenceEqual(y.AsSpan(0, ny))) return false;
            if (nx == 0) return Matches(a, left) && Matches(b, right);
        }
    }

    private sealed record Target(string Path, long Size, long ModifiedTicks, long CreatedTicks, string Hash, string Identity);
    private sealed record Plan(string Id, string Root, DateTime CreatedUtc, int MinimumAgeDays, List<Target> Targets);
    private sealed record RecoveryItem(Target Target, string QuarantinePath, string State, string? Reason);
    private sealed record Receipt(string Id, string PlanId, DateTime CreatedUtc, List<RecoveryItem> Items);
    private static string Store(EngineContext c)
    {
        string path = Path.Combine(c.DataRoot, "cleanup");
        Directory.CreateDirectory(path);
        StorageSafeFile.ValidateAncestors(path);
        return path;
    }
    private static string Id(JsonElement p, string name)
    {
        string id = Text(p, name);
        if (!Guid.TryParseExact(id, "N", out _)) throw new EngineException("INVALID_ARGUMENT", "The record identifier is invalid.");
        return id;
    }
    private static async Task SaveNew<T>(string path, T value, CancellationToken ct)
    {
        using var f = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await JsonSerializer.SerializeAsync(f, value, Json, ct);
        await f.FlushAsync(ct);
        f.Flush(true);
    }
    private static async Task SaveAtomic<T>(string path, T value)
    {
        string temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        await SaveNew(temp, value, CancellationToken.None);
        File.Move(temp, path, true);
    }
    private static async Task<T> Load<T>(string path, CancellationToken ct)
    {
        StorageSafeFile.ValidateAncestors(path);
        if (new FileInfo(path).Length > 4 * 1024 * 1024) throw new EngineException("INVALID_PLAN", "The record exceeds the size limit.");
        using var f = StorageSafeFile.OpenRead(path);
        return await JsonSerializer.DeserializeAsync<T>(f, Json, ct) ?? throw new EngineException("INVALID_PLAN", "The record is empty.");
    }
    private string TempRoot()
    {
        if (fixtureTempRoot != null) { StorageSafeFile.ValidateAncestors(fixtureTempRoot); return fixtureTempRoot; }
        string expected = Path.GetFullPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Temp"));
        string actual = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
        if (!string.Equals(expected.TrimEnd(Path.DirectorySeparatorChar), actual, StringComparison.OrdinalIgnoreCase))
            throw new EngineException("TEMP_ROOT_UNAVAILABLE", "The current temporary path is not the supported local user temporary directory.");
        StorageSafeFile.ValidateAncestors(expected);
        return expected;
    }
    private static bool Within(string root, string path) => Path.GetFullPath(path).StartsWith(Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    private async Task<object> Scan(JsonElement p, EngineContext c, CancellationToken ct)
    {
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "Temporary-file cleanup requires Windows.");
        string root = TempRoot();
        if (p.TryGetProperty("path", out _) && !string.Equals(Path.GetFullPath(Text(p, "path")), root, StringComparison.OrdinalIgnoreCase))
            throw new EngineException("SCOPE_NOT_ALLOWED", "Cleanup accepts only the supported current-user temporary directory.");
        int days = Number(p, "minimumAgeDays", 7, 1, 365);
        var scan = await Task.Run(() => Walk(root, Number(p, "maxEntries", 10000, 1, 20000), ct), ct);
        var targets = new List<Target>();
        long bytes = 0, budget = Number(p, "maxHashMiB", 512, 1, 4096) * 1024L * 1024;
        int unavailable = 0;
        string store = Store(c);
        foreach (var file in scan.Files.Where(x => x.ModifiedTicks < DateTime.UtcNow.AddDays(-days).Ticks))
        {
            ct.ThrowIfCancellationRequested();
            if (targets.Count >= 1000) { scan.Truncated = true; break; }
            if (Within(store, file.Path) || file.Path.Equals(store, StringComparison.OrdinalIgnoreCase) || bytes + file.Size > budget) continue;
            try
            {
                using var f = StorageSafeFile.OpenRead(file.Path);
                if (!Matches(file, f)) { unavailable++; continue; }
                string identity = StorageSafeFile.Identity(f);
                string hash = Convert.ToHexString(await SHA256.HashDataAsync(f, ct));
                bytes += file.Size;
                if (Matches(file, f)) targets.Add(new(file.Path, file.Size, file.ModifiedTicks, file.CreatedTicks, hash, identity));
                else unavailable++;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException) { unavailable++; }
        }
        var plan = new Plan(Guid.NewGuid().ToString("N"), root, DateTime.UtcNow, days, targets);
        await SaveNew(Path.Combine(store, plan.Id + ".plan.json"), plan, ct);
        return new { fixture = fixtureTempRoot != null, planId = plan.Id, root, category = "aged-user-temp-files", minimumAgeDays = days, targets, totalBytes = targets.Sum(x => x.Size), scan.Truncated, scan.Inaccessible, scan.ReparseSkipped, unavailable, expiresUtc = plan.CreatedUtc.AddDays(1), mutationPerformed = false };
    }
    private static async Task ValidateTarget(Target t, string root, FileStream f, CancellationToken ct)
    {
        if (!Within(root, t.Path) || !Matches(new(t.Path, t.Size, t.ModifiedTicks, t.CreatedTicks), f) || StorageSafeFile.Identity(f) != t.Identity)
            throw new EngineException("TARGET_CHANGED", "The planned file identity or metadata changed.");
        string hash = Convert.ToHexString(await SHA256.HashDataAsync(f, ct));
        if (hash != t.Hash || !Matches(new(t.Path, t.Size, t.ModifiedTicks, t.CreatedTicks), f)) throw new EngineException("TARGET_CHANGED", "The planned file content changed.");
    }
    private async Task<object> Apply(JsonElement p, EngineContext c, CancellationToken ct)
    {
        Confirm(p);
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "Recoverable cleanup requires Windows.");
        string id = Id(p, "planId"), store = Store(c);
        using var operationLock = new FileStream(Path.Combine(store, id + ".lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        var plan = await Load<Plan>(Path.Combine(store, id + ".plan.json"), ct);
        if (plan.Id != id || plan.Targets == null || plan.Targets.Any(x => x == null) || plan.Targets.Count > 1000 || plan.MinimumAgeDays < 1 || plan.MinimumAgeDays > 365 || plan.CreatedUtc > DateTime.UtcNow || plan.CreatedUtc < DateTime.UtcNow.AddDays(-1) || !string.Equals(plan.Root, TempRoot(), StringComparison.OrdinalIgnoreCase))
            throw new EngineException("PLAN_EXPIRED", "The plan is expired or its approved scope changed. Scan again.");
        string receiptPath = Path.Combine(store, id + ".receipt.json");
        if (File.Exists(receiptPath))
        {
            var existing = await Load<Receipt>(receiptPath, ct);
            return new { receiptId = id, items = existing.Items, plannedCount = plan.Targets.Count, partial = existing.Items.Count(x => x.State == "quarantined") != plan.Targets.Count, cancelled = false, permanentDeletion = false };
        }
        string recovery = Path.Combine(store, id);
        Directory.CreateDirectory(recovery);
        StorageSafeFile.ValidateAncestors(recovery);
        var receipt = new Receipt(id, id, DateTime.UtcNow, []);
        await SaveNew(receiptPath, receipt, ct);
        foreach (var t in plan.Targets)
        {
            if (ct.IsCancellationRequested) break;
            string destination = Path.Combine(recovery, Guid.NewGuid().ToString("N") + ".recovery");
            int index = receipt.Items.Count;
            receipt.Items.Add(new(t, destination, "pending", null));
            await SaveAtomic(receiptPath, receipt);
            try
            {
                using var file = StorageSafeFile.OpenForMove(t.Path);
                await ValidateTarget(t, plan.Root, file, ct);
                if (t.ModifiedTicks >= DateTime.UtcNow.AddDays(-plan.MinimumAgeDays).Ticks) throw new EngineException("TARGET_CHANGED", "The file is no longer old enough.");
                StorageSafeFile.Move(file, destination);
                receipt.Items[index] = new(t, destination, "quarantined", null);
            }
            catch (OperationCanceledException) { receipt.Items[index] = new(t, destination, "skipped", "cancelled"); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException) { receipt.Items[index] = new(t, destination, "skipped", ex is EngineException ee ? ee.Code : ex.InnerException is System.ComponentModel.Win32Exception native ? "FILE_UNAVAILABLE_WIN32_" + native.NativeErrorCode : "FILE_UNAVAILABLE"); }
            await SaveAtomic(receiptPath, receipt);
        }
        await c.RecordAsync("cleanup.apply", new { receiptId = id, moved = receipt.Items.Count(x => x.State == "quarantined"), planned = plan.Targets.Count }, CancellationToken.None);
        return new { receiptId = id, items = receipt.Items, plannedCount = plan.Targets.Count, partial = receipt.Items.Count(x => x.State == "quarantined") != plan.Targets.Count, cancelled = ct.IsCancellationRequested, permanentDeletion = false };
    }
    private async Task<object> Restore(JsonElement p, EngineContext c, CancellationToken ct)
    {
        Confirm(p);
        string id = Id(p, "receiptId"), store = Store(c);
        using var operationLock = new FileStream(Path.Combine(store, id + ".lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        string path = Path.Combine(store, id + ".receipt.json");
        var receipt = await Load<Receipt>(path, ct);
        if (receipt.Id != id || receipt.Items == null || receipt.Items.Any(x => x == null || x.Target == null) || receipt.Items.Count > 1000) throw new EngineException("INVALID_PLAN", "Invalid recovery record.");
        for (int i = 0; i < receipt.Items.Count; i++)
        {
            if (ct.IsCancellationRequested) break;
            var item = receipt.Items[i];
            if (item.State is "restored" or "skipped") continue;
            try
            {
                if (!Within(Path.Combine(store, id), item.QuarantinePath) || !Within(TempRoot(), item.Target.Path)) throw new EngineException("SCOPE_NOT_ALLOWED", "Recovery scope changed.");
                if (!File.Exists(item.QuarantinePath)) { receipt.Items[i] = item with { State = "unresolved", Reason = "RECOVERY_FILE_MISSING" }; continue; }
                if (File.Exists(item.Target.Path) || Directory.Exists(item.Target.Path)) throw new EngineException("RESTORE_CONFLICT", "The original path is occupied. Recovery data was retained.");
                StorageSafeFile.ValidateAncestors(Path.GetDirectoryName(item.Target.Path)!);
                using var file = StorageSafeFile.OpenForMove(item.QuarantinePath);
                if (file.Length != item.Target.Size || StorageSafeFile.Identity(file) != item.Target.Identity || Convert.ToHexString(await SHA256.HashDataAsync(file, ct)) != item.Target.Hash)
                    throw new EngineException("RECOVERY_CHANGED", "The recovery file changed. It was retained for inspection.");
                receipt.Items[i] = item with { State = "restoring", Reason = null };
                await SaveAtomic(path, receipt);
                StorageSafeFile.Move(file, item.Target.Path);
                receipt.Items[i] = item with { State = "restored", Reason = null };
            }
            catch (OperationCanceledException) { receipt.Items[i] = item with { Reason = "cancelled" }; }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException) { receipt.Items[i] = item with { State = "conflict", Reason = ex is EngineException ee ? ee.Code : "FILE_UNAVAILABLE" }; }
            await SaveAtomic(path, receipt);
        }
        await SaveAtomic(path, receipt);
        await c.RecordAsync("cleanup.restore", new { receiptId = id, restored = receipt.Items.Count(x => x.State == "restored") }, CancellationToken.None);
        return new { receiptId = id, items = receipt.Items, partial = receipt.Items.Any(x => x.State is not ("restored" or "skipped")), cancelled = ct.IsCancellationRequested };
    }
    private static async Task<object> History(EngineContext c, CancellationToken ct)
    {
        var items = new List<object>();
        foreach (var file in Directory.EnumerateFiles(Store(c), "*.receipt.json").Take(1000))
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                var r = await Load<Receipt>(file, ct);
                if (r.Items == null || r.Items.Any(x => x == null)) throw new EngineException("INVALID_PLAN", "Invalid recovery record.");
                items.Add(new { id = r.Id, planId = r.PlanId, createdUtc = r.CreatedUtc, itemCount = r.Items.Count,
                    quarantined = r.Items.Count(x => x.State == "quarantined"), restored = r.Items.Count(x => x.State == "restored"),
                    conflicts = r.Items.Count(x => x.State is "conflict" or "pending" or "restoring" or "unresolved"), skipped = r.Items.Count(x => x.State == "skipped") });
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or EngineException or JsonException) { items.Add(new { receiptId = Path.GetFileName(file).Split('.')[0], state = "unreadable", reason = "RECOVERY_RECORD_UNAVAILABLE" }); }
        }
        return new { receipts = items, limit = 1000 };
    }
}

