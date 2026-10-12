using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace MaterialSystemCare.Engine;

/// <summary>Durable, reconnectable selected-folder analysis, without detached mutations.</summary>
public sealed class MaintenanceJobs : IDisposable
{
    private readonly EngineContext context;
    private readonly string connectionString;
    private readonly FileStream lease;
    private readonly object sync = new();
    private readonly Dictionary<string, CancellationTokenSource> active = [];
    private bool disposed;

    public MaintenanceJobs(EngineContext context)
    {
        this.context = context;
        StorageSafeFile.ValidateAncestors(context.DataRoot);
        try { lease = new FileStream(Path.Combine(context.DataRoot, "jobs.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.Read); }
        catch (IOException) { throw new EngineException("JOBS_IN_USE", "Another engine owns the maintenance jobs store."); }
        connectionString = new SqliteConnectionStringBuilder { DataSource = Path.Combine(context.DataRoot, "records.db") }.ToString();
        try {
            using var db = Open(); using var command = db.CreateCommand();
            command.CommandText = "CREATE TABLE IF NOT EXISTS maintenance_jobs(id TEXT PRIMARY KEY, method TEXT NOT NULL, parameters TEXT NOT NULL, state TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, cancellation_requested INTEGER NOT NULL DEFAULT 0, result TEXT, error_code TEXT, error_message TEXT); UPDATE maintenance_jobs SET state='interrupted', updated_at=$at, error_code='ENGINE_INTERRUPTED', error_message='The engine stopped before a terminal result was persisted. Review the target and start a new analysis.' WHERE state IN ('queued','running');";
            command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O")); command.ExecuteNonQuery();
        } catch { lease.Dispose(); throw; }
    }
    private SqliteConnection Open()
    {
        var db = new SqliteConnection(connectionString); db.Open();
        using var command = db.CreateCommand(); command.CommandText = "PRAGMA busy_timeout=5000; PRAGMA synchronous=FULL;"; command.ExecuteNonQuery(); return db;
    }
    private static void Fields(JsonElement p, params string[] allowed)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in p.EnumerateObject()) if (!allowed.Contains(property.Name, StringComparer.Ordinal) || !seen.Add(property.Name)) throw new EngineException("INVALID_ARGUMENT", "Unknown or duplicate job argument.");
    }
    private static string Text(JsonElement p, string key)
    {
        if (!p.TryGetProperty(key, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()) || value.GetString()!.Length > 1024) throw new EngineException("INVALID_ARGUMENT", "A bounded job argument is required.");
        return value.GetString()!;
    }
    private static int Number(JsonElement p, string key, int fallback, int max)
    {
        if (!p.TryGetProperty(key, out var value)) return fallback;
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out var number) || number < 1 || number > max) throw new EngineException("INVALID_ARGUMENT", "Job limit is outside its allowed range.");
        return number;
    }
    private static string Id(JsonElement p)
    {
        var id = Text(p, "jobId");
        if (id.Length != 32 || !id.All(char.IsAsciiHexDigit)) throw new EngineException("INVALID_ARGUMENT", "A 32-character job identifier is required.");
        return id.ToLowerInvariant();
    }
    public object Handle(string method, JsonElement p, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        lock (sync) {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (method == "jobs.start") return Start(p);
            if (method == "jobs.list") {
                Fields(p, "limit"); var limit = Number(p, "limit", 50, 100);
                using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "SELECT id FROM maintenance_jobs ORDER BY created_at DESC,id DESC LIMIT $limit"; command.Parameters.AddWithValue("$limit", limit);
                using var reader = command.ExecuteReader(); var ids = new List<string>(); while (reader.Read()) ids.Add(reader.GetString(0));
                return new { records = ids.Select(id => Read(id, false)).ToArray(), order = "newest-first", limit, resultsIncluded = false };
            }
            Fields(p, "jobId"); var requested = Id(p);
            if (method == "jobs.cancel") {
                Read(requested, true);
                if (active.TryGetValue(requested, out var cancellation)) {
                    using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "UPDATE maintenance_jobs SET cancellation_requested=1,updated_at=$at WHERE id=$id AND state IN ('queued','running')";
                    command.Parameters.AddWithValue("$id", requested); command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O")); command.ExecuteNonQuery(); cancellation.Cancel();
                }
                return Read(requested, true);
            }
            return Read(requested, true);
        }
    }
    private object Start(JsonElement p)
    {
        Fields(p, "method", "parameters"); var method = Text(p, "method");
        if (method is not ("storage.analyze" or "storage.duplicates")) throw new EngineException("JOB_METHOD_UNSUPPORTED", "Only selected-folder analysis and duplicate inspection support detached jobs.");
        if (!p.TryGetProperty("parameters", out var parameters) || parameters.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_ARGUMENT", "Job parameters must be an object.");
        Fields(parameters, method == "storage.analyze" ? ["path", "maxEntries"] : ["path", "maxEntries", "maxHashMiB"]);
        var path = Path.GetFullPath(Text(parameters, "path"));
        if (!Directory.Exists(path)) throw new EngineException("PATH_NOT_FOUND", "Select an existing folder.");
        StorageSafeFile.ValidateAncestors(path);
        Number(parameters, "maxEntries", method == "storage.analyze" ? 20000 : 10000, method == "storage.analyze" ? 100000 : 50000);
        if (method == "storage.duplicates") Number(parameters, "maxHashMiB", 512, 4096);
        var normalized = parameters.EnumerateObject().ToDictionary(property => property.Name, property => (object)property.Value.Clone(), StringComparer.Ordinal);
        normalized["path"] = path;
        parameters = JsonSerializer.SerializeToElement(normalized, Program.JsonOptions);
        if (active.Count >= 4) throw new EngineException("JOB_CAPACITY", "Four analyses are already active. Wait or cancel an owned job.");
        using var db = Open(); using var count = db.CreateCommand(); count.CommandText = "SELECT COUNT(*) FROM maintenance_jobs";
        if (Convert.ToInt64(count.ExecuteScalar()) >= 1000) throw new EngineException("JOB_HISTORY_FULL", "The durable job store contains 1000 records. Existing receipts were retained.");
        var id = Guid.NewGuid().ToString("N"); var now = DateTimeOffset.UtcNow.ToString("O");
        using var insert = db.CreateCommand(); insert.CommandText = "INSERT INTO maintenance_jobs(id,method,parameters,state,created_at,updated_at) VALUES($id,$method,$params,'queued',$at,$at)";
        insert.Parameters.AddWithValue("$id", id); insert.Parameters.AddWithValue("$method", method); insert.Parameters.AddWithValue("$params", parameters.GetRawText()); insert.Parameters.AddWithValue("$at", now); insert.ExecuteNonQuery();
        var cancellation = new CancellationTokenSource(); active.Add(id, cancellation);
        var detachedParameters = parameters.Clone();
        _ = Task.Run(() => Run(id, method, detachedParameters, cancellation));
        return Read(id, true);
    }
    private async Task Run(string id, string method, JsonElement p, CancellationTokenSource cancellation)
    {
        string state = "failed"; string? result = null, code = null, message = null;
        try {
            lock (sync) { Update(id, "running", null, null, null); }
            cancellation.Token.ThrowIfCancellationRequested();
            if (context.BeforeJobExecution is { } beforeExecution) await beforeExecution(cancellation.Token);
            var value = await new StorageModule().HandleAsync(method, p, context, cancellation.Token);
            result = JsonSerializer.Serialize(value, Program.JsonOptions);
            if (Encoding.UTF8.GetByteCount(result) > 3 * 1024 * 1024) throw new EngineException("RESULT_TOO_LARGE", "The analysis result exceeded the durable result limit. Narrow the target.");
            state = "succeeded";
        } catch (OperationCanceledException) { state = "cancelled"; code = "CANCELLED"; message = "Analysis cancellation was observed. No file changes were performed."; result = null; }
        catch (EngineException ex) { code = ex.Code; message = ex.Message; result = null; }
        catch { code = "OPERATION_FAILED"; message = "The analysis could not complete. Review access and local storage availability."; result = null; }
        finally {
            lock (sync) {
                try { Update(id, state, result, code, message); }
                catch { /* Retain running state for restart recovery rather than fabricate a durable terminal receipt. */ }
                active.Remove(id); cancellation.Dispose();
                if (disposed && active.Count == 0) lease.Dispose();
            }
        }
    }
    private void Update(string id, string state, string? result, string? code, string? message)
    {
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "UPDATE maintenance_jobs SET state=$state,updated_at=$at,result=$result,error_code=$code,error_message=$message WHERE id=$id";
        command.Parameters.AddWithValue("$id", id); command.Parameters.AddWithValue("$state", state); command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O"));
        command.Parameters.AddWithValue("$result", (object?)result ?? DBNull.Value); command.Parameters.AddWithValue("$code", (object?)code ?? DBNull.Value); command.Parameters.AddWithValue("$message", (object?)message ?? DBNull.Value); command.ExecuteNonQuery();
    }
    private object Read(string id, bool includeResult)
    {
        using var db = Open(); using var command = db.CreateCommand(); command.CommandText = "SELECT method,state,created_at,updated_at,cancellation_requested,result,error_code,error_message,parameters FROM maintenance_jobs WHERE id=$id"; command.Parameters.AddWithValue("$id", id);
        using var reader = command.ExecuteReader(); if (!reader.Read()) throw new EngineException("JOB_NOT_FOUND", "The job record was not found.");
        return new { jobId = id, method = reader.GetString(0), state = reader.GetString(1), createdAt = reader.GetString(2), updatedAt = reader.GetString(3), cancellationRequested = reader.GetBoolean(4),
            result = includeResult && !reader.IsDBNull(5) ? (JsonElement?)JsonSerializer.Deserialize<JsonElement>(reader.GetString(5)) : null,
            error = reader.IsDBNull(6) ? null : new { code = reader.GetString(6), message = reader.GetString(7) },
            parameters = includeResult ? (JsonElement?)JsonSerializer.Deserialize<JsonElement>(reader.GetString(8)) : null, mutationPerformed = false };
    }
    public void Dispose()
    {
        lock (sync) { if (disposed) return; disposed = true; foreach (var cancellation in active.Values) cancellation.Cancel(); if (active.Count == 0) lease.Dispose(); }
    }
}
