using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using MaterialSystemCare.Engine;
using Microsoft.Data.Sqlite;

namespace MaterialSystemCare.Tests;

public static class SystemInventoryFixtures
{
    private static string FixtureJson()
    {
        var providers=SystemInventory.Categories.Select(category=> {
            int count=category.Id=="cpu" ? 2 : category.Id is "gpu" or "device" ? 0 : 1;
            var rows=Enumerable.Range(0,count).Select(index=>category.Fields.ToDictionary(field=>field.Name,field=>(object?)(field.Kind switch {
                "text" => category.Id=="cpu" && field.Name=="Name" ? "=1+2|<script>Fixture CPU</script>" : "Fixture "+field.Name,
                "number" => (object)(ulong)(field.Name=="Capacity" ? 8388608 : field.Name=="NumberOfLogicalProcessors" ? 8 : 4),
                "bool" => false, _=>null
            }))).ToArray();
            return new {category=category.Id,available=category.Id!="gpu",code=category.Id=="gpu" ? "PROVIDER_UNAVAILABLE":null,truncated=false,records=rows};
        }).ToArray();
        return JsonSerializer.Serialize(new {providers},MaterialSystemCare.Engine.Program.JsonOptions);
    }
    public static async Task<int> RunAsync(string parent)
    {
        int count=0; void Check(bool value,string name){if(!value)throw new Exception(name);count++;}
        var observed=DateTimeOffset.UtcNow.ToString("O");var json=FixtureJson();var snapshot=SystemInventory.Parse(json,observed);
        Check(snapshot.Records.Length==8 && snapshot.Providers.Sum(p=>p.RecordCount)==8,"Hardware records and provider counts agree");
        Check(snapshot.Providers.Single(p=>p.Category=="gpu").Available==false && snapshot.Providers.Single(p=>p.Category=="device").Available && snapshot.Providers.Single(p=>p.Category=="device").RecordCount==0,"Missing provider differs from available zero-record provider");
        Check(snapshot.Sensors.All(s=>!s.Available) && snapshot.Sensors.Select(s=>s.Metric).Distinct().Count()==3,"No fabricated temperature, GPU load or SMART health");
        Check(SystemInventory.Categories.SelectMany(c=>c.Fields).All(f=>f.Name is not ("SerialNumber" or "ProcessorId" or "PNPDeviceID" or "CSName" or "RegisteredUser")),"Sensitive fields absent from provider allowlists");
        void Invalid(string candidate) {try{SystemInventory.Parse(candidate,observed);throw new Exception("Malformed provider accepted");}catch(EngineException ex){Check(ex.Code=="INVALID_SYSTEM_INVENTORY","Malformed provider rejected");}}
        Invalid("not-json");Invalid("{\"providers\":[]}");Invalid(new string('x',SystemInventory.MaximumBytes+1));
        foreach(var mutate in new Action<JsonNode>[] {
            n=>n["providers"]![0]!["records"]![0]!["SerialNumber"]="not-collected",
            n=>n["providers"]![0]!["records"]![0]!["NumberOfCores"]=-1,
            n=>n["providers"]![0]!["records"]![0]!["Name"]=new string('a',513),
            n=>n["providers"]![0]!["records"]![0]!["Name"]="control\ntext",
            n=>n["providers"]![0]!["available"]=false,
            n=>n["providers"]![0]!["truncated"]=true,
            n=>n["providers"]![0]!["category"]="unknown",
            n=>n["providers"]![1]!["category"]="cpu",
            n=>n["providers"]![6]!["code"]="arbitrary",
            n=>n["providers"]![0]!["records"]=new JsonArray(Enumerable.Range(0,257).Select(_=>n["providers"]![0]!["records"]![0]!.DeepClone()).ToArray())
        }){var malformed=JsonNode.Parse(json)!;mutate(malformed);Invalid(malformed.ToJsonString());}
        var denied=JsonNode.Parse(json)!;denied["providers"]![6]!["code"]="ACCESS_DENIED";
        Check(SystemInventory.Parse(denied.ToJsonString(),observed).Providers.Single(p=>p.Category=="gpu").Code=="ACCESS_DENIED","Access denial remains distinct from missing class");
        var timed=JsonNode.Parse(json)!;timed["providers"]![6]!["code"]="PROVIDER_TIMEOUT";
        Check(SystemInventory.Parse(timed.ToJsonString(),observed).Providers.Single(p=>p.Category=="gpu").Code=="PROVIDER_TIMEOUT","Provider deadline remains distinct from empty inventory");
        var root=Path.Combine(parent,"system-reports");var output=Path.Combine(parent,"system-exports");Directory.CreateDirectory(output);
        var now=DateTimeOffset.UtcNow;
        var measurement=new SystemMonitor.Measurement(observed,250,250,82,90,10000,1000,[new("C:\\",true,1000,100,90,null)],"synthetic-fixture",SystemMonitor.Limitations);
        using var context=new EngineContext(root){InventoryCollector=ct=>{ct.ThrowIfCancellationRequested();return Task.FromResult(snapshot);},MonitorCollector=(interval,ct)=>{ct.ThrowIfCancellationRequested();return Task.FromResult(measurement with {RequestedIntervalMs=interval});},ReportClock=()=>now};
        async Task<JsonElement> Call(string method,object parameters,EngineContext? owner=null,CancellationToken ct=default)=>JsonSerializer.SerializeToElement(await new SystemReportService(owner ?? context).HandleAsync(method,JsonSerializer.SerializeToElement(parameters),ct),MaterialSystemCare.Engine.Program.JsonOptions);
        async Task Reject(string method,object parameters,string code,EngineContext? owner=null){try{await Call(method,parameters,owner);throw new Exception("Invalid report accepted: "+code);}catch(EngineException ex){Check(ex.Code==code,"Report boundary "+code);}}
        var captured=await Call("system.inventory",new {limit=3});var id=captured.GetProperty("reportId").GetString()!;var revision=captured.GetProperty("revision").GetString()!;
        Check(captured.GetProperty("totalRecords").GetInt32()==8 && captured.GetProperty("records").GetArrayLength()==3 && captured.GetProperty("nextOffset").GetInt32()==3 && captured.GetProperty("fixture").GetBoolean(),"Captured report returns truthful bounded first page");
        var second=await Call("system.inventory.page",new {reportId=id,revision,offset=3,limit=3});
        Check(second.GetProperty("records").GetArrayLength()==3 && second.GetProperty("nextOffset").GetInt32()==6,"Stable second page advances exact counts");
        var last=await Call("system.inventory.page",new {reportId=id,revision,offset=6,limit=3});
        Check(last.GetProperty("records").GetArrayLength()==2 && last.GetProperty("nextOffset").ValueKind==JsonValueKind.Null,"Last page carries exact remainder");
        var gpu=await Call("system.inventory.page",new {reportId=id,revision,category="gpu"});
        Check(gpu.GetProperty("totalRecords").GetInt32()==0 && gpu.GetProperty("providers").EnumerateArray().Single(p=>p.GetProperty("category").GetString()=="gpu").GetProperty("available").GetBoolean()==false,"Category pagination keeps unavailable provider state");
        await Reject("system.inventory.page",new {reportId=id,revision=new string('0',64)},"REPORT_REVISION_CHANGED");
        await Reject("system.inventory.page",new {reportId=new string('0',32),revision},"REPORT_NOT_FOUND");
        await Reject("system.inventory.page",new {reportId=id,revision,offset=9},"INVALID_OFFSET");
        await Reject("system.inventory",new {limit=201},"INVALID_ARGUMENT");
        await Reject("system.inventory.page",new {reportId=id,revision,category="temperature"},"INVALID_ARGUMENT");
        var monitor=await Call("system.monitor",new {intervalMs=250,thresholds=new {cpuPercent=80,memoryPercent=95,diskUsedPercent=90}});
        var alerts=monitor.GetProperty("alerts").EnumerateArray().ToArray();
        Check(alerts.Length==3 && alerts.Single(a=>a.GetProperty("metric").GetString()=="cpuPercent").GetProperty("state").GetString()=="threshold-reached" && alerts.Single(a=>a.GetProperty("metric").GetString()=="memoryPercent").GetProperty("state").GetString()=="below-threshold" && alerts.Single(a=>a.GetProperty("metric").GetString()=="diskUsedPercent").GetProperty("state").GetString()=="threshold-reached","Alerts evaluate actual submitted measurements with inclusive thresholds");
        await Reject("system.monitor",new {thresholds=new {}},"INVALID_ARGUMENT");
        await Reject("system.monitor",new {thresholds=new {temperatureCelsius=80}},"INVALID_ARGUMENT");
        await Reject("system.monitor",new {thresholds=new {cpuPercent=101}},"INVALID_ARGUMENT");
        await Reject("system.monitor",new {intervalMs=2001},"INVALID_ARGUMENT");
        using(var unavailable=new EngineContext(Path.Combine(parent,"missing-system-providers"))){var missing=await Call("system.inventory",new {},unavailable);Check(missing.GetProperty("totalRecords").GetInt32()==0 && missing.GetProperty("providers").EnumerateArray().All(p=>!p.GetProperty("available").GetBoolean() && p.GetProperty("code").GetString()=="FIXTURE_COLLECTION_DISABLED"),"Fixture mode cannot fall through to live host collection");var missingAlert=await Call("system.monitor",new {thresholds=new {cpuPercent=50,diskUsedPercent=80}},unavailable);Check(missingAlert.GetProperty("alerts").EnumerateArray().All(a=>a.GetProperty("state").GetString()=="unavailable"),"Unavailable measurements never imply below-threshold health");}
        foreach(var format in new[]{"json","csv","markdown"}){
            var file="fixture-report"+(format=="markdown" ? ".md":"."+format);
            var review=await Call("system.report.review",new {reportId=id,revision,format,outputFolder=output,fileName=file});
            var exported=await Call("system.report.export",new {reportId=id,revision,format,outputFolder=output,fileName=file,reviewRevision=review.GetProperty("reviewRevision").GetString(),confirmed=true});
            var bytes=await File.ReadAllBytesAsync(Path.Combine(output,file));var text=Encoding.UTF8.GetString(bytes);
            Check(exported.GetProperty("sha256").GetString()==Convert.ToHexString(SHA256.HashData(bytes)) && exported.GetProperty("bytes").GetInt32()==bytes.Length && !exported.GetProperty("overwritten").GetBoolean(),"Export receipt binds exact bytes without replacement "+format);
            if(format=="json"){using var result=JsonDocument.Parse(text);Check(result.RootElement.GetProperty("inventory").GetProperty("records").GetArrayLength()==8,"JSON contains complete selected immutable inventory");}
            if(format=="csv")Check(text.Contains("\"'=1+2|<script>Fixture CPU</script>\"") && text.StartsWith("\"Section\",\"RecordId\""),"CSV protects formula-like descriptions and carries column schema");
            if(format=="markdown")Check(text.Contains("&lt;script&gt;") && text.Contains("\\|") && !text.Contains("<script>"),"Markdown descriptions cannot inject HTML or table columns");
            await Reject("system.report.review",new {reportId=id,revision,format,outputFolder=output,fileName=file},"TARGET_EXISTS");
        }
        var selected=await Call("system.report.review",new {reportId=id,revision,format="json",outputFolder=output,fileName="reviewed.json"});
        var reviewRevision=selected.GetProperty("reviewRevision").GetString();
        await Reject("system.report.export",new {reportId=id,revision,format="json",outputFolder=output,fileName="reviewed.json",reviewRevision,confirmed=false},"CONFIRMATION_REQUIRED");
        await Reject("system.report.export",new {reportId=id,revision,format="json",outputFolder=output,fileName="changed.json",reviewRevision,confirmed=true},"REPORT_REVIEW_CHANGED");
        foreach(var file in new[]{"../escape.json","CON.json","NUL.json","COM1.json","bad.csv"})await Reject("system.report.review",new {reportId=id,revision,format="json",outputFolder=output,fileName=file},"INVALID_ARGUMENT");
        using(var cancelled=new CancellationTokenSource()){cancelled.Cancel();try{await Call("system.inventory",new {},ct:cancelled.Token);throw new Exception("Cancelled capture accepted");}catch(OperationCanceledException){Check(true,"Cancelled capture does not admit report");}}
        using(var cancelled=new CancellationTokenSource())using(var cancelContext=new EngineContext(root){ReportClock=()=>now,BeforeReportPublication=ct=>{cancelled.Cancel();return Task.CompletedTask;}}){try{await Call("system.report.export",new {reportId=id,revision,format="json",outputFolder=output,fileName="reviewed.json",reviewRevision,confirmed=true},cancelContext,cancelled.Token);throw new Exception("Cancelled publication accepted");}catch(OperationCanceledException){Check(!File.Exists(Path.Combine(output,"reviewed.json")) && !Directory.GetFiles(output,".msc-report-*.tmp").Any(),"Cancellation removes only owned staging and publishes nothing");}}
        using(var racing=new EngineContext(root){ReportClock=()=>now,BeforeReportPublication=ct=>File.WriteAllTextAsync(Path.Combine(output,"reviewed.json"),"owned racing occupant",ct)}){
            await Reject("system.report.export",new {reportId=id,revision,format="json",outputFolder=output,fileName="reviewed.json",reviewRevision,confirmed=true},"REPORT_EXPORT_IO",racing);
            Check(await File.ReadAllTextAsync(Path.Combine(output,"reviewed.json"))=="owned racing occupant" && !Directory.GetFiles(output,".msc-report-*.tmp").Any(),"Late target occupant survives atomic no-replace publication");
        }
        var folder=Path.Combine(parent,"reviewed-folder");Directory.CreateDirectory(folder);
        var folderReview=await Call("system.report.review",new {reportId=id,revision,format="json",outputFolder=folder,fileName="output.json"});Directory.Move(folder,folder+"-retained");Directory.CreateDirectory(folder);
        await Reject("system.report.export",new {reportId=id,revision,format="json",outputFolder=folder,fileName="output.json",reviewRevision=folderReview.GetProperty("reviewRevision").GetString(),confirmed=true},"REPORT_REVIEW_CHANGED");
        for(int i=1;i<SystemReportService.MaximumReports;i++)await Call("system.inventory",new {});
        await Reject("system.inventory",new {},"REPORT_CAPACITY");
        now=now.AddHours(24);
        await Reject("system.inventory.page",new {reportId=id,revision},"REPORT_EXPIRED");
        var renewed=await Call("system.inventory",new {});Check(renewed.GetProperty("totalRecords").GetInt32()==8,"Expired local report cache is reclaimed before new admission");
        await Reject("system.inventory.page",new {reportId=id,revision},"REPORT_NOT_FOUND");
        var newId=renewed.GetProperty("reportId").GetString()!;var newRevision=renewed.GetProperty("revision").GetString();
        using(var db=new SqliteConnection(new SqliteConnectionStringBuilder{DataSource=Path.Combine(root,"records.db")}.ToString())){db.Open();using var command=db.CreateCommand();command.CommandText="UPDATE system_reports SET payload='not-json' WHERE id=$id";command.Parameters.AddWithValue("$id",newId);command.ExecuteNonQuery();}
        await Reject("system.inventory.page",new {reportId=newId,revision=newRevision},"INVALID_REPORT");
        Check(!Directory.GetFiles(output,".msc-report-*.tmp").Any(),"No report staging remains after bounded fixtures");
        return count;
    }
}
