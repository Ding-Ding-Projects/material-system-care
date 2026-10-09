using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;

namespace MaterialSystemCare.Engine;

/// <summary>Read-only, local crash evidence. A stop code identifies a symptom, not a culprit.</summary>
public sealed class CrashDiagnosticsModule : IEngineModule
{
    public bool CanHandle(string method) => method is "diagnostics.crashes" or "diagnostics.explainStopCode";
    public async Task<object?> HandleAsync(string method, JsonElement p, EngineContext context, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        if (p.ValueKind != JsonValueKind.Object) throw Invalid("Parameters must be an object.");
        if (method == "diagnostics.explainStopCode")
        {
            if (!p.TryGetProperty("code", out var code) || code.ValueKind != JsonValueKind.String || !TryCode(code.GetString(), out var value))
                throw Invalid("Enter a hexadecimal stop code (0x...) or its unsigned decimal value.");
            return Explain(value);
        }
        if (method != "diagnostics.crashes") throw new EngineException("METHOD_NOT_FOUND", "Unknown diagnostic method.");
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "Crash event collection requires Windows.");
        var days = Integer(p, "days", 30, 1, 365);
        var limit = Integer(p, "limit", 50, 1, 100);
        if (context.IsFixture) throw new EngineException("LIVE_COLLECTION_DISABLED", "Fixture contexts cannot inspect host crash events.");
        var collected = ParseEvents(await ReadEvents(days, limit + 1, ct));
        var events = collected.Take(limit).ToArray();
        var warnings = new List<string>();
        var dumps = new List<DumpRecord>();
        var windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        foreach (var directory in new[] { Path.Combine(windows, "Minidump"), windows })
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                if ((File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) { warnings.Add("A redirected dump directory was not inspected."); continue; }
                var names = directory == windows ? new[] { Path.Combine(windows, "MEMORY.DMP") } : Directory.EnumerateFiles(directory, "*.dmp").Take(101);
                foreach (var path in names)
                {
                    ct.ThrowIfCancellationRequested();
                    if (dumps.Count >= 100) { warnings.Add("Dump inventory is limited to 100 records."); break; }
                    var file = new FileInfo(path);
                    if (!file.Exists || (file.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    dumps.Add(new(file.Name, file.Length, file.LastWriteTimeUtc.ToString("O"), "metadata-only"));
                }
            }
            catch (DirectoryNotFoundException) { }
            catch (FileNotFoundException) { }
            catch (UnauthorizedAccessException) { warnings.Add("Dump metadata is unavailable for this account. No elevation was requested."); }
            catch (IOException) { warnings.Add("A dump record changed or could not be read. Refresh to try again."); }
        }
        return new { collectedAt = DateTimeOffset.UtcNow.ToString("O"), lookbackDays = days, eventLimit = limit,
            events, eventsTruncated = collected.Length > limit, dumps, warnings, dumpContentsRead = false, uploaded = false, rootCauseEstablished = false,
            timeMeaning = "Recorded event times can follow the crash or restart; dump modification times are file metadata, not crash timestamps.",
            limitation = "Event evidence and file metadata only. No stack or symbol analysis was performed. A stop code does not identify a faulty driver, and an unexpected restart alone does not prove a blue screen." };
    }

    public static CrashEvent[] ParseEvents(string xml)
    {
        if (xml.Length > 2 * 1024 * 1024) throw new EngineException("RESULT_TOO_LARGE", "Crash events exceeded the bounded output limit.");
        try
        {
            using var reader = XmlReader.Create(new StringReader("<Events>" + xml + "</Events>"), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 2 * 1024 * 1024 + 32 });
            var document = XDocument.Load(reader);
            if (document.Root!.Elements().Any(e => e.Name.LocalName != "Event") || document.Root.Nodes().OfType<XText>().Any(t => !string.IsNullOrWhiteSpace(t.Value)))
                throw new XmlException("Unexpected event output.");
            var result = new List<CrashEvent>();
            foreach (var item in document.Root!.Elements().Where(e => e.Name.LocalName == "Event").Take(101))
            {
                XElement? Child(XElement? node, string name) => node?.Elements().FirstOrDefault(e => e.Name.LocalName == name);
                var system = Child(item, "System");
                var provider = Child(system, "Provider")?.Attribute("Name")?.Value;
                var id = Child(system, "EventID")?.Value;
                if (!((id == "1001" && provider == "Microsoft-Windows-WER-SystemErrorReporting") || (id == "41" && provider == "Microsoft-Windows-Kernel-Power"))) continue;
                var data = Child(item, "EventData")?.Elements().Where(e => e.Name.LocalName == "Data").ToArray() ?? [];
                string? Field(string name) => data.FirstOrDefault(e => e.Attribute("Name")?.Value == name)?.Value;
                uint? stopCode = null;
                if (id == "41" && uint.TryParse(Field("BugcheckCode"), NumberStyles.None, CultureInfo.InvariantCulture, out var decimalCode) && decimalCode != 0) stopCode = decimalCode;
                if (id == "1001")
                {
                    var raw = Field("param1") ?? Field("BugcheckCode");
                    if (raw is { Length: <= 1024 })
                    {
                        var match = Regex.Match(raw, @"\A\s*(0x[0-9a-fA-F]{1,8})(?=\s|\(|\z)", RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(100));
                        if (match.Success && TryCode(match.Groups[1].Value, out var parsed) && parsed != 0) stopCode = parsed;
                    }
                }
                var timestamp = Child(system, "TimeCreated")?.Attribute("SystemTime")?.Value;
                var occurred = DateTimeOffset.TryParse(timestamp, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var at) ? at.ToUniversalTime().ToString("O") : null;
                var record = long.TryParse(Child(system, "EventRecordID")?.Value, out var recordId) ? recordId : (long?)null;
                result.Add(new(record, occurred, int.Parse(id!, CultureInfo.InvariantCulture), provider!, stopCode is not null ? "stop-code-recorded" : id == "1001" ? "bugcheck-report-without-readable-code" : "unexpected-restart", stopCode is null ? null : Explain(stopCode.Value)));
            }
            return result.ToArray();
        }
        catch (XmlException) { throw new EngineException("INVALID_EVENT_DATA", "The event query returned malformed or unsupported XML."); }
    }

    public static bool TryCode(string? code, out uint value)
    {
        value = 0;
        if (code is null || code.Length is < 1 or > 16) return false;
        code = code.Trim();
        return code.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
            ? code.Length is >= 3 and <= 10 && uint.TryParse(code[2..], NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture, out value)
            : uint.TryParse(code, NumberStyles.None, CultureInfo.InvariantCulture, out value);
    }

    public static StopCodeExplanation Explain(uint code)
    {
        var (name, category) = code switch
        {
            0xA => ("IRQL_NOT_LESS_OR_EQUAL", "memory-or-driver"),
            0x1A => ("MEMORY_MANAGEMENT", "memory"),
            0x1E => ("KMODE_EXCEPTION_NOT_HANDLED", "exception"),
            0x50 => ("PAGE_FAULT_IN_NONPAGED_AREA", "memory-or-driver"),
            0x7E => ("SYSTEM_THREAD_EXCEPTION_NOT_HANDLED", "exception"),
            0x9F => ("DRIVER_POWER_STATE_FAILURE", "driver-power"),
            0x124 => ("WHEA_UNCORRECTABLE_ERROR", "hardware-report"),
            0x133 => ("DPC_WATCHDOG_VIOLATION", "watchdog"),
            0xEF => ("CRITICAL_PROCESS_DIED", "critical-process"),
            _ => ("Uncatalogued stop code", "unknown")
        };
        return new($"0x{code:X8}", code, name, category, "The recorded code is evidence of the reported stop condition. It does not establish the root cause or identify a culprit driver.",
            ["Compare the event time with recent driver, firmware, hardware, and Windows updates.", "Preserve available dump files before making changes.", "Use Microsoft WinDbg with matching symbols for deeper dump analysis.", "Follow the device manufacturer's diagnostics when hardware evidence warrants it."],
            "https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2");
    }

    private static int Integer(JsonElement p, string key, int fallback, int minimum, int maximum)
    {
        if (!p.TryGetProperty(key, out var v)) return fallback;
        if (v.ValueKind != JsonValueKind.Number || !v.TryGetInt32(out var number) || number < minimum || number > maximum) throw Invalid($"{key} must be between {minimum} and {maximum}.");
        return number;
    }
    private static EngineException Invalid(string message) => new("INVALID_PARAMETERS", message);
    private static async Task<string> ReadEvents(int days, int limit, CancellationToken ct)
    {
        var executable = Path.Combine(Environment.SystemDirectory, "wevtutil.exe");
        var query = $"*[System[TimeCreated[timediff(@SystemTime) <= {(long)days * 86400000}] and ((EventID=1001 and Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting']) or (EventID=41 and Provider[@Name='Microsoft-Windows-Kernel-Power']))]]";
        var info = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8 };
        foreach (var arg in new[] { "qe", "System", "/q:" + query, "/rd:true", "/c:" + limit, "/f:xml", "/uni:false" }) info.ArgumentList.Add(arg);
        using var process = new Process { StartInfo = info };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(15));
        var started = false;
        try
        {
            started = process.Start();
            if (!started) throw new EngineException("EVENT_LOG_UNAVAILABLE", "The local event query could not start.");
            async Task<string> Bounded(StreamReader stream)
            {
                var text = new StringBuilder(); var buffer = new char[4096];
                while (true) { var count = await stream.ReadAsync(buffer.AsMemory(), timeout.Token); if (count == 0) return text.ToString(); if (text.Length + count > 2 * 1024 * 1024) throw new EngineException("RESULT_TOO_LARGE", "Event output exceeded its limit."); text.Append(buffer, 0, count); }
            }
            var output = Bounded(process.StandardOutput); var error = Bounded(process.StandardError);
            await Task.WhenAll(process.WaitForExitAsync(timeout.Token), output, error);
            if (process.ExitCode != 0) throw new EngineException("EVENT_LOG_UNAVAILABLE", "System events could not be read for this account. No permission or logging configuration was changed.");
            return await output;
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new EngineException("OPERATION_TIMEOUT", "Crash event collection exceeded fifteen seconds."); }
        catch (System.ComponentModel.Win32Exception) { throw new EngineException("EVENT_LOG_UNAVAILABLE", "The supported event query is unavailable."); }
        finally { if (started && !process.HasExited) { try { process.Kill(true); } catch (InvalidOperationException) { } } }
    }
    public sealed record CrashEvent(long? RecordId, string? RecordedAt, int EventId, string Provider, string EvidenceKind, StopCodeExplanation? StopCode);
    public sealed record DumpRecord(string Name, long Bytes, string ModifiedAt, string Analysis);
    public sealed record StopCodeExplanation(string Hex, uint Decimal, string Name, string Category, string Confidence, string[] NextChecks, string Reference);
}
