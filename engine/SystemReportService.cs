using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace MaterialSystemCare.Engine;

public sealed class SystemReportService(EngineContext context)
{
    public const int MaximumReports = 30;
    public const int LifetimeHours = 24;
    public sealed record Report(int SchemaVersion, string ReportId, string CreatedAt, string ExpiresAt, string Revision, SystemInventory.Snapshot Inventory, SystemMonitor.Measurement? Performance, bool Fixture);
    public sealed record Review(string ReportId, string Revision, string Format, string OutputFolder, string FileName, string Destination, string FolderIdentity, string ReviewRevision, string ExpiresAt, bool OverwriteAllowed = false);
    private DateTimeOffset Now => (context.ReportClock?.Invoke() ?? DateTimeOffset.UtcNow).ToUniversalTime();
    private SqliteConnection Open()
    {
        var db = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = Path.Combine(context.DataRoot,"records.db") }.ToString()); db.Open();
        using var command = db.CreateCommand(); command.CommandText = "PRAGMA busy_timeout=5000; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS system_reports(id TEXT PRIMARY KEY, expires_at TEXT NOT NULL, payload TEXT NOT NULL);"; command.ExecuteNonQuery(); return db;
    }
    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    private static string Revision(SystemInventory.Snapshot inventory, SystemMonitor.Measurement? performance, bool fixture) => Hash(JsonSerializer.Serialize(new { inventory, performance, fixture },Program.JsonOptions));
    private static void Fields(JsonElement p, params string[] names) {
        if (p.ValueKind != JsonValueKind.Object) throw new EngineException("INVALID_ARGUMENT","Report parameters must be an object."); var seen = new HashSet<string>();
        foreach (var field in p.EnumerateObject()) if (!names.Contains(field.Name,StringComparer.Ordinal) || !seen.Add(field.Name)) throw new EngineException("INVALID_ARGUMENT","Unknown or duplicate report argument.");
    }
    private static string Text(JsonElement p,string name,int maximum=1024) { if (!p.TryGetProperty(name,out var value) || value.ValueKind != JsonValueKind.String || value.GetString() is not {Length:>0} s || s.Length > maximum || s.Any(char.IsControl)) throw new EngineException("INVALID_ARGUMENT","A bounded report argument is required."); return s; }
    private static int Number(JsonElement p,string name,int fallback,int min,int max) { if (!p.TryGetProperty(name,out var value)) return fallback; if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out var n) || n < min || n > max) throw new EngineException("INVALID_ARGUMENT","A report pagination argument is outside its integer range."); return n; }
    private static string Id(JsonElement p) { var id=Text(p,"reportId",32); if (id.Length!=32 || !id.All(char.IsAsciiHexDigit)) throw new EngineException("INVALID_ARGUMENT","A server-issued report identifier is required."); return id.ToLowerInvariant(); }
    private static string RequestedRevision(JsonElement p,string name="revision") { var revision=Text(p,name,64); if (revision.Length!=64 || !revision.All(char.IsAsciiHexDigit)) throw new EngineException("INVALID_ARGUMENT","A complete report review revision is required."); return revision.ToUpperInvariant(); }
    public async Task<object> HandleAsync(string method,JsonElement p,CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (method=="system.monitor") {
            Fields(p,"intervalMs","thresholds"); int interval=Number(p,"intervalMs",500,250,2000);
            var thresholds=p.TryGetProperty("thresholds",out var t) ? SystemMonitor.Thresholds(t) : new Dictionary<string,double>();
            var measurement=await Measure(interval,ct);
            return new { measurement, alerts=SystemMonitor.Evaluate(measurement,thresholds), continuousMonitoring=false, fixture=context.IsFixture, mutationPerformed=false };
        }
        if (method=="system.inventory") {
            Fields(p,"offset","limit"); int offset=Number(p,"offset",0,0,2304),limit=Number(p,"limit",100,1,200);
            var inventory=context.InventoryCollector != null ? await context.InventoryCollector(ct) : context.IsFixture ? SystemInventory.Unavailable("FIXTURE_COLLECTION_DISABLED","Host inventory collection is disabled in fixture mode.") : await SystemInventory.CollectAsync(ct);
            ValidateInventory(inventory);
            var performance=context.IsFixture && context.MonitorCollector == null ? null : await Measure(250,ct);
            var now=Now; var report=new Report(1,Guid.NewGuid().ToString("N"),now.ToString("O"),now.AddHours(LifetimeHours).ToString("O"),Revision(inventory,performance,context.IsFixture),inventory,performance,context.IsFixture);
            var page=Page(report,offset,limit,null); var json=JsonSerializer.Serialize(report,Program.JsonOptions);
            if (Encoding.UTF8.GetByteCount(json)>SystemInventory.MaximumBytes) throw new EngineException("RESULT_TOO_LARGE","The immutable system report exceeds its storage bound.");
            using var db=Open(); using var transaction=db.BeginTransaction();
            using var expiry=db.CreateCommand(); expiry.Transaction=transaction; expiry.CommandText="DELETE FROM system_reports WHERE expires_at <= $now"; expiry.Parameters.AddWithValue("$now",now.ToString("O")); await expiry.ExecuteNonQueryAsync(ct);
            using var count=db.CreateCommand(); count.Transaction=transaction; count.CommandText="SELECT COUNT(*) FROM system_reports";
            if (Convert.ToInt64(await count.ExecuteScalarAsync(ct))>=MaximumReports) throw new EngineException("REPORT_CAPACITY","Thirty unexpired system reports are retained. Wait for their 24-hour expiry; existing receipts were preserved.");
            using var insert=db.CreateCommand(); insert.Transaction=transaction; insert.CommandText="INSERT INTO system_reports(id,expires_at,payload) VALUES($id,$expires,$payload)"; insert.Parameters.AddWithValue("$id",report.ReportId); insert.Parameters.AddWithValue("$expires",report.ExpiresAt); insert.Parameters.AddWithValue("$payload",json); await insert.ExecuteNonQueryAsync(ct); transaction.Commit(); return page;
        }
        if (method=="system.inventory.page") {
            Fields(p,"reportId","revision","offset","limit","category"); var report=await Read(Id(p),ct);
            Match(report,RequestedRevision(p)); var category=p.TryGetProperty("category",out _) ? Text(p,"category",32) : null;
            if (category!=null && !SystemInventory.Categories.Any(c=>c.Id==category)) throw new EngineException("INVALID_ARGUMENT","Select a registered inventory category.");
            return Page(report,Number(p,"offset",0,0,2304),Number(p,"limit",100,1,200),category);
        }
        bool exporting=method=="system.report.export";
        Fields(p,exporting ? ["reportId","revision","format","outputFolder","fileName","reviewRevision","confirmed"] : ["reportId","revision","format","outputFolder","fileName"]);
        if (exporting && (!p.TryGetProperty("confirmed",out var confirmation) || confirmation.ValueKind!=JsonValueKind.True)) throw new EngineException("CONFIRMATION_REQUIRED","Review the exact selected report and output target, then explicitly confirm export.");
        var selected=await Read(Id(p),ct); Match(selected,RequestedRevision(p)); var review=ReviewTarget(selected,p);
        if (!exporting) return review;
        if (review.ReviewRevision!=RequestedRevision(p,"reviewRevision")) throw new EngineException("REPORT_REVIEW_CHANGED","The selected report, format or output target differs from the reviewed selection.");
        var bytes=Encoding.UTF8.GetBytes(Format(selected,review.Format));
        if (bytes.Length>8*1024*1024) throw new EngineException("RESULT_TOO_LARGE","The formatted report exceeds the export bound.");
        using var locks=new StorageSafeFile.DestinationLocks(review.OutputFolder);
        if (locks.Identity!=review.FolderIdentity) throw new EngineException("REPORT_REVIEW_CHANGED","The selected output folder identity changed.");
        var stage=Path.Combine(review.OutputFolder,".msc-report-"+Guid.NewGuid().ToString("N")+".tmp");
        using var output=StorageSafeFile.CreateForMove(stage); bool published=false;
        try {
            await output.WriteAsync(bytes,ct); output.Flush(true);
            if(context.BeforeReportPublication is {} beforePublication)await beforePublication(ct);
            ct.ThrowIfCancellationRequested(); locks.Validate();
            if(DateTimeOffset.ParseExact(review.ExpiresAt,"O",CultureInfo.InvariantCulture)<=Now)throw new EngineException("REPORT_EXPIRED","The report expired before publication. Capture and review a new report.");
            StorageSafeFile.Move(output,review.Destination); published=true;
            return new { reportId=selected.ReportId,revision=selected.Revision,path=review.Destination,format=review.Format,bytes=bytes.Length,sha256=Convert.ToHexString(SHA256.HashData(bytes)),overwritten=false,exportedAt=Now.ToString("O"),fixture=selected.Fixture,localOnly=true };
        } catch (IOException) { throw new EngineException("REPORT_EXPORT_IO","Report publication failed. Existing destination content was never replaced."); }
        finally { if (!published) StorageSafeFile.DiscardCreated(output); }
    }
    private async Task<SystemMonitor.Measurement> Measure(int interval,CancellationToken ct)
    {
        if (context.MonitorCollector != null) return ValidateMeasurement(await context.MonitorCollector(interval,ct));
        if (context.IsFixture) return new(Now.ToString("O"),0,interval,null,null,null,null,[],"fixture-disabled",SystemMonitor.Limitations);
        return ValidateMeasurement(await SystemMonitor.CollectAsync(interval,ct));
    }
    private static SystemMonitor.Measurement ValidateMeasurement(SystemMonitor.Measurement value)
    {
        if (!DateTimeOffset.TryParse(value.ObservedAt,CultureInfo.InvariantCulture,DateTimeStyles.None,out _) || !double.IsFinite(value.MeasuredIntervalMs) || value.MeasuredIntervalMs<0 || value.RequestedIntervalMs is <250 or >2000 || value.CpuPercent is {} cpu && (!double.IsFinite(cpu) || cpu is <0 or >100) || value.MemoryPercent is >100 || value.Volumes.Length>64 || value.MutationPerformed) throw new EngineException("INVALID_SYSTEM_MEASUREMENT","The measured response is inconsistent.");
        foreach(var volume in value.Volumes) if (volume.Id.Length>64 || volume.Id.Any(char.IsControl) || volume.UsedPercent is {} used && (!double.IsFinite(used) || used is <0 or >100) || volume.Available != (volume.TotalBytes>0 && volume.FreeBytes>=0 && volume.FreeBytes<=volume.TotalBytes && volume.UsedPercent!=null)) throw new EngineException("INVALID_SYSTEM_MEASUREMENT","Volume measurements are inconsistent.");
        return value;
    }
    private static void ValidateInventory(SystemInventory.Snapshot value)
    {
        if (value.SchemaVersion!=1 || value.MutationPerformed || value.Records.Length>2304 || value.Providers.Length!=SystemInventory.Categories.Length) throw new EngineException("INVALID_SYSTEM_INVENTORY","The stored inventory is inconsistent.");
        var projected=new { providers=value.Providers.Select(provider=>new {category=provider.Category,available=provider.Available,code=provider.Code,truncated=provider.Truncated,records=value.Records.Where(r=>r.Category==provider.Category).Select(r=>r.Values).ToArray()}).ToArray() };
        var validated=SystemInventory.Parse(JsonSerializer.Serialize(projected,Program.JsonOptions),value.ObservedAt);
        if (!validated.Records.Select(r=>r.Id).SequenceEqual(value.Records.Select(r=>r.Id)) || value.Providers.Any(p=>p.RecordCount!=value.Records.Count(r=>r.Category==p.Category) || p.Reason!=SystemInventory.Reason(p.Code)) || JsonSerializer.Serialize(validated.Sensors,Program.JsonOptions)!=JsonSerializer.Serialize(value.Sensors,Program.JsonOptions) || !validated.PrivacyExclusions.SequenceEqual(value.PrivacyExclusions) || value.Limitation!=validated.Limitation) throw new EngineException("INVALID_SYSTEM_INVENTORY","The inventory count, record identity or sensor/privacy declaration is inconsistent.");
    }
    private async Task<Report> Read(string id,CancellationToken ct)
    {
        using var db=Open(); using var command=db.CreateCommand(); command.CommandText="SELECT payload FROM system_reports WHERE id=$id"; command.Parameters.AddWithValue("$id",id);
        var json=await command.ExecuteScalarAsync(ct) as string ?? throw new EngineException("REPORT_NOT_FOUND","The report is unknown or its expired cache was removed.");
        if (Encoding.UTF8.GetByteCount(json)>SystemInventory.MaximumBytes) throw new EngineException("INVALID_REPORT","The persisted report exceeds its size bound.");
        Report report;
        try { report=JsonSerializer.Deserialize<Report>(json,Program.JsonOptions) ?? throw new EngineException("INVALID_REPORT","The persisted report is invalid."); ValidateInventory(report.Inventory); if(report.Performance!=null)ValidateMeasurement(report.Performance); }
        catch(Exception error) when (error is JsonException or NullReferenceException or ArgumentException or InvalidOperationException || error is EngineException {Code:"INVALID_SYSTEM_INVENTORY" or "INVALID_SYSTEM_MEASUREMENT"}) {throw new EngineException("INVALID_REPORT","The persisted report is invalid.");}
        if (report.SchemaVersion!=1 || report.ReportId!=id || report.Revision!=Revision(report.Inventory,report.Performance,report.Fixture)) throw new EngineException("INVALID_REPORT","The persisted report identity or content revision is invalid.");
        if (!DateTimeOffset.TryParseExact(report.ExpiresAt,"O",CultureInfo.InvariantCulture,DateTimeStyles.None,out var expires) || !DateTimeOffset.TryParseExact(report.CreatedAt,"O",CultureInfo.InvariantCulture,DateTimeStyles.None,out var created) || expires!=created.AddHours(LifetimeHours)) throw new EngineException("INVALID_REPORT","The persisted report lifetime is invalid.");
        if (expires<=Now) throw new EngineException("REPORT_EXPIRED","The 24-hour report has expired. Capture and review a new report."); return report;
    }
    private static void Match(Report report,string revision) { if(report.Revision!=revision)throw new EngineException("REPORT_REVISION_CHANGED","The submitted report revision does not match its immutable observations."); }
    private static object Page(Report report,int offset,int limit,string? category)
    {
        var rows=report.Inventory.Records.Where(r=>category==null || r.Category==category).ToArray(); if(offset>rows.Length)throw new EngineException("INVALID_OFFSET","The offset exceeds the selected inventory count.");
        var page=rows.Skip(offset).Take(limit).ToArray(); return new {reportId=report.ReportId,revision=report.Revision,createdAt=report.CreatedAt,expiresAt=report.ExpiresAt,observedAt=report.Inventory.ObservedAt,totalRecords=rows.Length,totalInventoryRecords=report.Inventory.Records.Length,offset,limit,nextOffset=offset+page.Length<rows.Length ? (int?)(offset+page.Length):null,category,records=page,providers=report.Inventory.Providers,sensors=report.Inventory.Sensors,privacyExclusions=report.Inventory.PrivacyExclusions,performance=report.Performance,fixture=report.Fixture,mutationPerformed=false};
    }
    private static Review ReviewTarget(Report report,JsonElement p)
    {
        var format=Text(p,"format",16); string extension=format switch{"json"=>".json","csv"=>".csv","markdown"=>".md",_=>throw new EngineException("INVALID_ARGUMENT","Select JSON, CSV or Markdown export.")};
        var file=Text(p,"fileName",128); if(file.StartsWith('.') || file.EndsWith(' ') || file.Any(c=>!(char.IsAsciiLetterOrDigit(c) || c is '.' or '-' or '_' or ' ')) || !file.EndsWith(extension,StringComparison.OrdinalIgnoreCase))throw new EngineException("INVALID_ARGUMENT","Select a simple report filename with the matching extension.");
        var stem=file.Split('.')[0].TrimEnd(' ').ToUpperInvariant();
        if(new[]{"CON","PRN","AUX","NUL"}.Contains(stem) || stem.Length==4 && (stem.StartsWith("COM") || stem.StartsWith("LPT")) && stem[3] is >= '1' and <= '9')throw new EngineException("INVALID_ARGUMENT","Reserved device names cannot be report output targets.");
        var folder=Path.GetFullPath(Text(p,"outputFolder"));
        if(folder.StartsWith("\\\\",StringComparison.Ordinal) || new DriveInfo(Path.GetPathRoot(folder)!).DriveType==DriveType.Network)throw new EngineException("EXPORT_SCOPE_NOT_ALLOWED","Report export is restricted to an explicitly selected local folder.");
        if(!Directory.Exists(folder))throw new EngineException("PATH_NOT_FOUND","Select an existing output folder."); StorageSafeFile.ValidateAncestors(folder);
        var destination=Path.Combine(folder,file); if(File.Exists(destination) || Directory.Exists(destination))throw new EngineException("TARGET_EXISTS","The selected output target already exists. Choose a new filename.");
        using var locks=new StorageSafeFile.DestinationLocks(folder); var identity=locks.Identity; var review=Hash(JsonSerializer.Serialize(new {reportId=report.ReportId,revision=report.Revision,format,folder,file,identity,expiresAt=report.ExpiresAt},Program.JsonOptions));
        return new(report.ReportId,report.Revision,format,folder,file,destination,identity,review,report.ExpiresAt);
    }
    public static string Format(Report report,string format)
    {
        if(format=="json")return JsonSerializer.Serialize(report,new JsonSerializerOptions(Program.JsonOptions){WriteIndented=true});
        var rows=new List<string[]> {new[]{"report",report.ReportId,"metadata","revision",report.Revision,"captured",report.CreatedAt},new[]{"report",report.ReportId,"metadata","expiresAt",report.ExpiresAt,"expires","24-hour local cache"}};
        foreach(var provider in report.Inventory.Providers)rows.Add(["provider","",provider.Category,"recordCount",provider.RecordCount.ToString(CultureInfo.InvariantCulture),provider.Available ? "available":"unavailable",provider.Reason ?? (provider.Truncated ? "truncated-at-256":"")]);
        foreach(var record in report.Inventory.Records)foreach(var field in record.Values)rows.Add(["hardware",record.Id,record.Category,field.Key,field.Value.ValueKind==JsonValueKind.Null ? "" : field.Value.ValueKind==JsonValueKind.String ? field.Value.GetString()! : field.Value.GetRawText(),field.Value.ValueKind==JsonValueKind.Null ? "unavailable":"reported",""]);
        foreach(var sensor in report.Inventory.Sensors)rows.Add(["sensor","",sensor.Metric,"measurement","","unavailable",sensor.Reason]);
        foreach(var exclusion in report.Inventory.PrivacyExclusions)rows.Add(["privacy","","exclusions",exclusion,"omitted","excluded",""]);
        if(report.Performance is {} sample){ rows.Add(["measurement","cpu","performance","usagePercent",sample.CpuPercent?.ToString(CultureInfo.InvariantCulture) ?? "",sample.CpuPercent==null ? "unavailable":"measured",sample.CpuScope]); rows.Add(["measurement","memory","performance","loadPercent",sample.MemoryPercent?.ToString(CultureInfo.InvariantCulture) ?? "",sample.MemoryPercent==null ? "unavailable":"measured",sample.ObservedAt]); rows.Add(["measurement","","performance","measuredIntervalMs",sample.MeasuredIntervalMs.ToString(CultureInfo.InvariantCulture),"measured",sample.ObservedAt]); foreach(var volume in sample.Volumes)rows.Add(["measurement",volume.Id,"fixed-volume","usedPercent",volume.UsedPercent?.ToString(CultureInfo.InvariantCulture) ?? "",volume.Available ? "measured":"unavailable",volume.Reason ?? sample.ObservedAt]); }
        string[] header=["Section","RecordId","Category","Field","Value","State","Reason"];
        if(format=="csv") {
            string Cell(string text){if(text.Length>0 && "=+-@".Contains(text[0]))text="'"+text; return "\""+text.Replace("\"","\"\"")+"\"";}
            return string.Join("\r\n",new[]{header}.Concat(rows).Select(row=>string.Join(',',row.Select(Cell))))+"\r\n";
        }
        if(format!="markdown")throw new EngineException("INVALID_ARGUMENT","Unsupported report format.");
        string Markdown(string text)=>text.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace("\\","\\\\").Replace("|","\\|").Replace("`","\\`").Replace("[","\\[").Replace("]","\\]").Replace("\r"," ").Replace("\n"," ");
        return "# Local system report\n\nObservations are provider-reported and may be incomplete. No serial numbers, user profiles, sensor temperatures or inferred health are included.\n\n| "+string.Join(" | ",header)+" |\n| "+string.Join(" | ",header.Select(_=>"---"))+" |\n"+string.Join("\n",rows.Select(row=>"| "+string.Join(" | ",row.Select(Markdown))+" |"))+"\n";
    }
}
