using System.Text.Json;
using MaterialSystemCare.Engine;

var count = 0;
void Check(bool condition, string name) { if (!condition) throw new Exception(name); count++; }
string Event(string id, string provider, string field, string code, int record = 1) =>
    $"<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='{provider}'/><EventID>{id}</EventID><EventRecordID>{record}</EventRecordID><TimeCreated SystemTime='2026-01-01T00:00:00Z'/><Computer>private-host</Computer></System><EventData><Data Name='{field}'>{code}</Data></EventData></Event>";
const string power = "Microsoft-Windows-Kernel-Power", wer = "Microsoft-Windows-WER-SystemErrorReporting";
var decimalEvent = CrashDiagnosticsModule.ParseEvents(Event("41", power, "BugcheckCode", "159")).Single();
Check(decimalEvent.StopCode?.Hex == "0x0000009F", "Kernel-Power code uses decimal");
Check(decimalEvent.RecordedAt == "2026-01-01T00:00:00.0000000+00:00", "Recorded time is normalized to UTC");
var hexEvent = CrashDiagnosticsModule.ParseEvents(Event("1001", wer, "param1", "0x0000009f (0x12345678)")).Single();
Check(hexEvent.StopCode?.Name == "DRIVER_POWER_STATE_FAILURE", "WER code uses anchored hex without retaining addresses");
Check(CrashDiagnosticsModule.ParseEvents(Event("1001", "Unrelated-Provider", "param1", "0x9f")).Length == 0, "Provider qualification prevents unrelated event 1001");
Check(CrashDiagnosticsModule.ParseEvents(Event("41", power, "BugcheckCode", "0")).Single().EvidenceKind == "unexpected-restart", "Zero does not prove a blue screen");
Check(CrashDiagnosticsModule.ParseEvents(Event("1001", wer, "param1", "invalid")).Single().EvidenceKind == "bugcheck-report-without-readable-code", "Unreadable report remains qualified evidence");
Check(CrashDiagnosticsModule.ParseEvents(Event("41", power, "BugcheckCode", "159", 1) + Event("41", power, "BugcheckCode", "159", 2)).Select(x => x.RecordId).SequenceEqual(new long?[] {1, 2}), "Matching timestamps do not erase distinct records");
Check(CrashDiagnosticsModule.ParseEvents("").Length == 0, "Empty output is an empty inventory");
foreach (var bad in new[] {"<wrong/>", "not xml", "<Event>", "<!DOCTYPE Event [<!ENTITY x SYSTEM 'file:///not-read'>]><Event>&x;</Event>"}) {
    try { CrashDiagnosticsModule.ParseEvents(bad); throw new Exception("Malformed XML accepted"); }
    catch (EngineException ex) { Check(ex.Code == "INVALID_EVENT_DATA", "Malformed and entity XML rejected"); }
}
foreach (var bad in new[] {"-1", "4294967296", "0x100000000", "0x", "", "1.5", "+159", "0x9f trailing", new string('9', 100)})
    Check(!CrashDiagnosticsModule.TryCode(bad, out _), "Invalid stop code rejected");
Check(CrashDiagnosticsModule.TryCode("159", out var code) && code == 0x9f, "Manual decimal lookup");
Check(CrashDiagnosticsModule.TryCode("0X9F", out code) && code == 0x9f, "Manual hex lookup");
Check(CrashDiagnosticsModule.Explain(0xDEAD).Category == "unknown", "Unknown code never invents a known cause");
var serialized = JsonSerializer.Serialize(hexEvent);
Check(!serialized.Contains("private-host") && !serialized.Contains("12345678") && !serialized.Contains("Computer"), "Private event fields excluded");
var module = new CrashDiagnosticsModule();
Check(module.CanHandle("diagnostics.crashes") && !module.CanHandle("diagnostics.repair"), "No mutation method");
using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
try { await module.HandleAsync("diagnostics.explainStopCode", JsonDocument.Parse("{\"code\":\"159\"}").RootElement, new(), cancelled.Token); throw new Exception("Cancellation ignored"); }
catch (OperationCanceledException) { Check(true, "Cancellation enforced before lookup"); }
if (OperatingSystem.IsWindows()) {
    foreach (var bad in new[] {"{\"days\":\"30\"}", "{\"days\":0}", "{\"limit\":101}", "{\"days\":366}", "{\"limit\":null}"}) {
        try { await module.HandleAsync("diagnostics.crashes", JsonDocument.Parse(bad).RootElement, new(), default); throw new Exception("Invalid scope accepted"); }
        catch (EngineException ex) { Check(ex.Code == "INVALID_PARAMETERS", "Scope validated without invoking host"); }
    }
    try { await module.HandleAsync("diagnostics.crashes", JsonDocument.Parse("{}").RootElement, new(), default); throw new Exception("Host collection allowed in fixture"); }
    catch (EngineException ex) { Check(ex.Code == "LIVE_COLLECTION_DISABLED", "Fixture cannot inspect actual host"); }
}
try { CrashDiagnosticsModule.ParseEvents(new string(' ', 2*1024*1024+1)); throw new Exception("Unbounded XML accepted"); }
catch (EngineException ex) { Check(ex.Code == "RESULT_TOO_LARGE", "XML size bounded"); }
Check(CrashDiagnosticsModule.ParseEvents(string.Concat(Enumerable.Repeat(Event("41", power, "BugcheckCode", "159"), 101))).Length == 101, "Record count bounded with one truncation sentinel");
Console.WriteLine($"PASS crash diagnostics: {count} assertions; synthetic events only, no dump contents or host events accessed.");

namespace MaterialSystemCare.Engine {
    public interface IEngineModule { bool CanHandle(string method); Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken); }
    public sealed class EngineContext { public bool IsFixture => true; }
    public sealed class EngineException(string code, string message) : Exception(message) { public string Code { get; } = code; }
}
