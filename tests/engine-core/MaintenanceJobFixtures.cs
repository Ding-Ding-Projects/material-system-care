using System.Text.Json;
using MaterialSystemCare.Engine;
using Microsoft.Data.Sqlite;

namespace MaterialSystemCare.Tests;

public static class MaintenanceJobFixtures
{
    public static async Task<int> RunAsync(string parent)
    {
        int count = 0;
        void Check(bool condition, string name) { if (!condition) throw new Exception(name); count++; }
        var data = Path.Combine(parent, "job-records"); var files = Path.Combine(parent, "job-target"); Directory.CreateDirectory(files);
        await File.WriteAllTextAsync(Path.Combine(files, "one.txt"), "exact duplicate"); await File.WriteAllTextAsync(Path.Combine(files, "two.txt"), "exact duplicate");
        using var context = new EngineContext(data);
        JsonElement Call(string method, object parameters, CancellationToken ct = default) => JsonSerializer.SerializeToElement(context.Jobs.Handle(method, JsonSerializer.SerializeToElement(parameters), ct), MaterialSystemCare.Engine.Program.JsonOptions);
        void Reject(string method, object parameters, string code) {
            try { Call(method, parameters); throw new Exception("Invalid job accepted: " + code); }
            catch (EngineException ex) { Check(ex.Code == code, "Expected job rejection " + code); }
        }
        Reject("jobs.start", new { method = "cleanup.apply", parameters = new { path = files } }, "JOB_METHOD_UNSUPPORTED");
        Reject("jobs.start", new { method = "storage.analyze", parameters = new { path = files, maxEntries = 0 } }, "INVALID_ARGUMENT");
        Reject("jobs.start", new { method = "storage.analyze", parameters = new { path = files, maxEntries = 100001 } }, "INVALID_ARGUMENT");
        Reject("jobs.start", new { method = "storage.duplicates", parameters = new { path = files, maxHashMiB = 4097 } }, "INVALID_ARGUMENT");
        Reject("jobs.start", new { method = "storage.analyze", parameters = new { path = files, confirmed = true } }, "INVALID_ARGUMENT");
        Reject("jobs.start", new { method = "storage.analyze", parameters = new { path = Path.Combine(files, "absent") } }, "PATH_NOT_FOUND");
        Reject("jobs.status", new { jobId = "../records" }, "INVALID_ARGUMENT");
        Reject("jobs.status", new { jobId = new string('0', 32) }, "JOB_NOT_FOUND");
        Reject("jobs.list", new { limit = 101 }, "INVALID_ARGUMENT");
        Reject("jobs.list", new { limit = 1.5 }, "INVALID_ARGUMENT");
        using var cancelledRequest = new CancellationTokenSource(); cancelledRequest.Cancel();
        try { Call("jobs.start", new { method = "storage.analyze", parameters = new { path = files } }, cancelledRequest.Token); throw new Exception("Cancelled admission accepted"); }
        catch (OperationCanceledException) { Check(true, "Cancelled request not admitted"); }
        using var duplicateArguments = JsonDocument.Parse("{\"limit\":1,\"limit\":2}");
        try { context.Jobs.Handle("jobs.list", duplicateArguments.RootElement, default); throw new Exception("Duplicate field accepted"); }
        catch (EngineException ex) { Check(ex.Code == "INVALID_ARGUMENT", "Duplicate arguments rejected"); }
        async Task<JsonElement> Terminal(string id, EngineContext? owner = null) {
            for (int attempt = 0; attempt < 200; attempt++) {
                var record = owner == null ? Call("jobs.status", new { jobId = id }) : JsonSerializer.SerializeToElement(owner.Jobs.Handle("jobs.status", JsonSerializer.SerializeToElement(new { jobId = id }), default), MaterialSystemCare.Engine.Program.JsonOptions);
                if (record.GetProperty("state").GetString() is not ("queued" or "running")) return record;
                await Task.Delay(10);
            }
            throw new Exception("Analysis did not reach bounded terminal state");
        }
        var started = Call("jobs.start", new { method = "storage.analyze", parameters = new { path = files } }); var id = started.GetProperty("jobId").GetString()!;
        Check(id.Length == 32 && started.GetProperty("state").GetString() == "queued", "Durable identity issued before worker transition");
        var completed = await Terminal(id);
        Check(completed.GetProperty("state").GetString() == "succeeded" && completed.GetProperty("result").GetProperty("fileCount").GetInt32() == 2, "Real measurement retained");
        Check(completed.GetProperty("parameters").GetProperty("path").GetString() == Path.GetFullPath(files), "Selected target retained canonically");
        var duplicate = Call("jobs.start", new { method = "storage.duplicates", parameters = new { path = files } });
        Check((await Terminal(duplicate.GetProperty("jobId").GetString()!)).GetProperty("result").GetProperty("groups").GetArrayLength() == 1, "Actual duplicate comparison available");
        var successWins = Call("jobs.cancel", new { jobId = id });
        Check(successWins.GetProperty("state").GetString() == "succeeded" && !successWins.GetProperty("cancellationRequested").GetBoolean(), "Success before cancellation preserves its terminal receipt");
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using (var cancelContext = new EngineContext(Path.Combine(parent, "cancel-records")) {
            BeforeJobExecution = ct => { entered.TrySetResult(); return Task.Delay(Timeout.Infinite, ct); }
        }) {
            JsonElement CancelCall(string method, object parameters) => JsonSerializer.SerializeToElement(cancelContext.Jobs.Handle(method, JsonSerializer.SerializeToElement(parameters), default), MaterialSystemCare.Engine.Program.JsonOptions);
            var cancellable = CancelCall("jobs.start", new { method = "storage.duplicates", parameters = new { path = files } });
            var cancelId = cancellable.GetProperty("jobId").GetString()!;
            await entered.Task.WaitAsync(TimeSpan.FromSeconds(2));
            Check(CancelCall("jobs.cancel", new { jobId = cancelId }).GetProperty("cancellationRequested").GetBoolean(), "Active cancellation request persisted while worker held deterministically");
            var cancelOutcome = await Terminal(cancelId, cancelContext);
            Check(cancelOutcome.GetProperty("state").GetString() == "cancelled" && cancelOutcome.GetProperty("result").ValueKind == JsonValueKind.Null, "Worker observes cancellation without incomplete success");
        }
        var listing = Call("jobs.list", new { limit = 1 });
        Check(listing.GetProperty("records").GetArrayLength() == 1 && listing.GetProperty("records")[0].GetProperty("result").ValueKind == JsonValueKind.Null && listing.GetProperty("records")[0].GetProperty("parameters").ValueKind == JsonValueKind.Null, "List excludes large results and target paths");
        using var second = new EngineContext(data);
        {
            for (var attempt = 0; attempt < 2; attempt++) {
                try { _ = second.Jobs; throw new Exception("Concurrent store owner accepted"); }
                catch (EngineException ex) { Check(ex.Code == "JOBS_IN_USE", "Exclusive store owner enforced without caching transient failure"); }
            }
        }
        var interrupted = Guid.NewGuid().ToString("N");
        using (var db = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = Path.Combine(data, "records.db") }.ToString())) {
            db.Open(); using var command = db.CreateCommand(); command.CommandText = "INSERT INTO maintenance_jobs(id,method,parameters,state,created_at,updated_at) VALUES($id,'storage.analyze','{}','running','2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')"; command.Parameters.AddWithValue("$id", interrupted); command.ExecuteNonQuery();
        }
        context.Dispose();
        {
            JsonElement Read(string value) => JsonSerializer.SerializeToElement(second.Jobs.Handle("jobs.status", JsonSerializer.SerializeToElement(new { jobId = value }), default), MaterialSystemCare.Engine.Program.JsonOptions);
            var acquired = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Task.Run(() => second.Jobs)));
            Check(acquired.All(manager => ReferenceEquals(manager, acquired[0])), "Concurrent retry after lease release publishes one successful manager");
            Check(Read(id).GetProperty("result").GetProperty("fileCount").GetInt32() == 2, "Completed receipt survives restart");
            var recovery = Read(interrupted);
            Check(recovery.GetProperty("state").GetString() == "interrupted" && recovery.GetProperty("error").GetProperty("code").GetString() == "ENGINE_INTERRUPTED", "Unfinished receipt interrupted, never replayed");
        }
        second.Dispose();
        try { _ = second.Jobs; throw new Exception("Disposed context initialized jobs"); }
        catch (ObjectDisposedException) { Check(true, "Disposed context cannot reacquire job lease"); }
        Check(Directory.GetFiles(files).Length == 2 && await File.ReadAllTextAsync(Path.Combine(files, "one.txt")) == "exact duplicate", "Data never mutated");
        return count;
    }
}
