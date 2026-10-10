using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml;
using System.Xml.Linq;

namespace MaterialSystemCare.Engine;

/// <summary>Supported local protection, driver-store, and bounded connectivity operations.</summary>
public sealed class ProtectionModule : IEngineModule
{
    private static readonly HashSet<string> Methods = new(StringComparer.Ordinal)
    { "security.status", "security.scan", "drivers.list", "drivers.export", "drivers.install", "network.diagnostics", "files.lockOwners" };
    public bool CanHandle(string method) => Methods.Contains(method);

    public async Task<object?> HandleAsync(string method, JsonElement parameters, EngineContext context, CancellationToken cancellationToken)
    {
        if (!OperatingSystem.IsWindows()) throw new EngineException("PLATFORM_UNSUPPORTED", "This operation requires Windows.");
        if (parameters.ValueKind != JsonValueKind.Object) throw Invalid("Parameters must be an object.");
        return method switch
        {
            "security.status" => await SecurityStatus(cancellationToken),
            "security.scan" => await Scan(parameters, context, cancellationToken),
            "drivers.list" => await DriverList(cancellationToken),
            "drivers.export" => await Export(parameters, context, cancellationToken),
            "drivers.install" => await Install(parameters, context, cancellationToken),
            "network.diagnostics" => await Diagnose(parameters, cancellationToken),
            "files.lockOwners" => LockOwners(parameters, cancellationToken),
            _ => throw new EngineException("METHOD_NOT_FOUND", "Unknown protection method.")
        };
    }

    private static async Task<object> SecurityStatus(CancellationToken ct)
    {
        // The script is a constant. No request data enters PowerShell source or arguments.
        const string script = "[Console]::OutputEncoding=[Text.UTF8Encoding]::new(); $ErrorActionPreference='Stop'; " +
            "$d=$null;$f=$null;$dr=$null;$fr=$null;" +
            "try{$d=Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,AntispywareEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,NISEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanStartTime,QuickScanEndTime,FullScanStartTime,FullScanEndTime,RebootRequired}catch{$dr='Defender status is unavailable on this installation or for this account.'};" +
            "try{$f=@(Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction)}catch{$fr='Firewall status is unavailable for this account.'};" +
            "@{defender=$d;defenderUnavailableReason=$dr;firewall=$f;firewallUnavailableReason=$fr}|ConvertTo-Json -Depth 5 -Compress";
        var result = await Run(PowerShell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", Convert.ToBase64String(Encoding.Unicode.GetBytes(script))], TimeSpan.FromSeconds(30), ct);
        RequireSuccess(result, "STATUS_UNAVAILABLE", "Platform security status could not be read.");
        try { return JsonDocument.Parse(result.Output).RootElement.Clone(); }
        catch (JsonException) { throw new EngineException("INVALID_PLATFORM_OUTPUT", "Security status returned invalid JSON."); }
    }

    private static async Task<object> Scan(JsonElement p, EngineContext context, CancellationToken ct)
    {
        Confirm(p); Elevation(context);
        var kind = Text(p, "kind", 16);
        var type = kind switch { "quick" => "1", "full" => "2", _ => throw Invalid("kind must be quick or full.") };
        var executable = FindDefender();
        var started = DateTimeOffset.UtcNow;
        await context.RecordAsync("security.scan.started", new { kind, started }, ct);
        var result = await Run(executable, ["-Scan", "-ScanType", type], TimeSpan.FromHours(1), ct);
        // Exit zero means the tool completed successfully, not that the entire computer is safe.
        var receipt = new { kind, started, completed = DateTimeOffset.UtcNow, exitCode = result.ExitCode, toolCompleted = result.ExitCode == 0,
            message = result.ExitCode == 0 ? "Defender completed the requested scan. Review Windows Security for detection and remediation details." : "Defender reported an unsuccessful scan. Review Windows Security for details." };
        await context.RecordAsync("security.scan.completed", receipt, ct);
        return receipt;
    }

    private static string FindDefender()
    {
        var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "Microsoft", "Windows Defender", "Platform");
        if (Directory.Exists(root))
        {
            foreach (var directory in Directory.EnumerateDirectories(root).OrderByDescending(x => x, StringComparer.Ordinal))
            {
                var executable = Path.Combine(directory, "MpCmdRun.exe");
                if (File.Exists(executable) && (File.GetAttributes(directory) & FileAttributes.ReparsePoint) == 0) return executable;
            }
        }
        var fallback = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Windows Defender", "MpCmdRun.exe");
        if (File.Exists(fallback)) return fallback;
        throw new EngineException("CAPABILITY_UNAVAILABLE", "Microsoft Defender command-line tools are not installed.");
    }

    private static async Task<object> DriverList(CancellationToken ct) => new
    { source = "Windows driver store", packages = await Packages(ct), onlineCatalogueAvailable = false };

    private static async Task<ProtectionDriverPackage[]> Packages(CancellationToken ct)
    {
        var result = await Run(PnpUtil, ["/enum-drivers", "/format", "xml"], TimeSpan.FromSeconds(45), ct);
        RequireSuccess(result, "CAPABILITY_UNAVAILABLE", "This Windows version cannot provide structured PnPUtil driver inventory.");
        return ParseDriverXml(result.Output);
    }

    public static ProtectionDriverPackage[] ParseDriverXml(string xml)
    {
        try
        {
            using var reader = XmlReader.Create(new StringReader(xml), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 2 * 1024 * 1024 });
            var document = XDocument.Load(reader);
            var packages = new Dictionary<string, ProtectionDriverPackage>(StringComparer.OrdinalIgnoreCase);
            foreach (var node in document.Descendants().Where(x => x.Name.LocalName.Equals("driver", StringComparison.OrdinalIgnoreCase)))
            {
                string? Get(params string[] names) => node.Elements().FirstOrDefault(x => names.Contains(x.Name.LocalName, StringComparer.OrdinalIgnoreCase))?.Value;
                var published = node.Attribute("DriverName")?.Value ?? node.Attribute("PublishedName")?.Value ?? Get("PublishedName", "Published_Name", "DriverName");
                if (published is null || !PackageId.IsMatch(published)) continue;
                packages[published] = new(published, Get("OriginalName", "Original_Name", "OriginalFileName"), Get("ProviderName", "Provider_Name", "Provider"), Get("ClassName", "Class_Name"), Get("DriverVersion", "Driver_Version", "Version"), Get("SignerName", "Signer_Name"));
            }
            if (document.Root is null || !document.Root.Name.LocalName.Equals("pnputil", StringComparison.OrdinalIgnoreCase))
                throw new XmlException("Unexpected inventory root.");
            if (document.Descendants().Any(x => x.Name.LocalName.Equals("driver", StringComparison.OrdinalIgnoreCase)) && packages.Count == 0)
                throw new XmlException("Unsupported inventory schema.");
            return packages.Values.OrderBy(x => x.Id, StringComparer.OrdinalIgnoreCase).ToArray();
        }
        catch (XmlException) { throw new EngineException("INVALID_PLATFORM_OUTPUT", "PnPUtil returned unsupported or invalid XML."); }
    }

    private static async Task<object> Export(JsonElement p, EngineContext context, CancellationToken ct)
    {
        Confirm(p); Elevation(context);
        var destination = LocalPath(Text(p, "destination", 1024));
        if (!Directory.Exists(destination)) throw Invalid("Select an existing export directory.");
        RejectReparsePath(destination);
        var id = Text(p, "id", 64);
        var inventory = await Packages(ct);
        if (id != "all" && (!PackageId.IsMatch(id) || !inventory.Any(x => x.Id.Equals(id, StringComparison.OrdinalIgnoreCase))))
            throw Invalid("Select an existing published driver package or all.");
        // Use a new child directory so an export cannot overwrite an existing backup.
        var output = Path.Combine(destination, "DriverBackup-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(output);
        var result = await Run(PnpUtil, ["/export-driver", id == "all" ? "*" : id, output], TimeSpan.FromMinutes(5), ct);
        var receipt = new { id, destination = output, exitCode = result.ExitCode, exported = result.ExitCode == 0, packageCount = id == "all" ? inventory.Length : 1 };
        await context.RecordAsync("drivers.export", receipt, ct);
        return receipt;
    }

    private static async Task<object> Install(JsonElement p, EngineContext context, CancellationToken ct)
    {
        Confirm(p); Elevation(context);
        var path = LocalPath(Text(p, "path", 1024));
        if (!File.Exists(path) || !Path.GetExtension(path).Equals(".inf", StringComparison.OrdinalIgnoreCase)) throw Invalid("Select an existing local INF package.");
        RejectReparsePath(path);
        ct.ThrowIfCancellationRequested();
        var signature = new ProtectionSignerInfo { Size = (uint)Marshal.SizeOf<ProtectionSignerInfo>() };
        if (!SetupVerifyInfFile(path, IntPtr.Zero, ref signature))
            throw new EngineException("DRIVER_SIGNATURE_INVALID", "Windows could not validate this INF package signature for the current platform.");
        // No force or reboot option. Windows selects the highest-ranked applicable driver.
        var result = await Run(PnpUtil, ["/add-driver", path, "/install"], TimeSpan.FromMinutes(5), ct);
        var receipt = new { path, signer = signature.Signer, exitCode = result.ExitCode, accepted = result.ExitCode is 0 or 3010,
            rebootRequired = result.ExitCode == 3010, rankingRespected = true,
            message = "Windows controls package applicability and ranking. An accepted package does not prove a device changed drivers. No restart was requested." };
        await context.RecordAsync("drivers.install", receipt, ct);
        return receipt;
    }

    private static async Task<object> Diagnose(JsonElement p, CancellationToken ct)
    {
        var interfaces = NetworkInterface.GetAllNetworkInterfaces().Take(128).Select(x => new
        { id = x.Id, name = x.Name, type = x.NetworkInterfaceType.ToString(), status = x.OperationalStatus.ToString(),
            addresses = x.GetIPProperties().UnicastAddresses.Take(32).Select(a => a.Address.ToString()).ToArray() }).ToArray();
        if (!p.TryGetProperty("host", out _)) return new { interfaces, target = (object?)null };
        var host = Text(p, "host", 253);
        if (Uri.CheckHostName(host) == UriHostNameType.Unknown || host.Contains('%') || host.Contains('*')) throw Invalid("Provide one DNS hostname or IP address.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(TimeSpan.FromSeconds(10));
        try
        {
            var addresses = await Dns.GetHostAddressesAsync(host, timeout.Token);
            var address = addresses.FirstOrDefault(x => x.AddressFamily is System.Net.Sockets.AddressFamily.InterNetwork or System.Net.Sockets.AddressFamily.InterNetworkV6);
            if (address is null) return new { interfaces, target = (object)new { host, resolved = false, reason = "No usable IP address was returned." } };
            using var ping = new Ping();
            var reply = await ping.SendPingAsync(address, TimeSpan.FromSeconds(2), new byte[32], null, timeout.Token);
            return new { interfaces, target = (object)new { host, resolved = true, addresses = addresses.Take(16).Select(a => a.ToString()).ToArray(), pingStatus = reply.Status.ToString(), roundTripMilliseconds = reply.Status == IPStatus.Success ? (long?)reply.RoundtripTime : null,
                message = "One ICMP echo was sent. ICMP filtering does not establish whether an internet service is available." } };
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new EngineException("OPERATION_TIMEOUT", "The selected host diagnostic exceeded ten seconds."); }
        catch (System.Net.Sockets.SocketException) { throw new EngineException("DNS_UNAVAILABLE", "The selected host could not be resolved."); }
        catch (PingException) { throw new EngineException("PING_UNAVAILABLE", "The selected host could not be tested with ICMP."); }
    }

    private static object LockOwners(JsonElement p, CancellationToken ct)
    {
        var requestedPath = Text(p, "path", 1024);
        var path = LocalPath(requestedPath);
        if (!File.Exists(path)) throw Invalid("Select an existing local file.");
        ct.ThrowIfCancellationRequested();
        var key = new StringBuilder(33);
        var error = RmStartSession(out var session, 0, key);
        if (error != 0) throw new EngineException("LOCK_QUERY_UNAVAILABLE", "Restart Manager could not start a diagnostic session.");
        try
        {
            error = RmRegisterResources(session, 1, [path], 0, IntPtr.Zero, 0, null);
            if (error != 0) throw new EngineException("LOCK_QUERY_UNAVAILABLE", "Restart Manager could not register this file.");
            uint needed = 0, count = 0, reboot = 0;
            error = RmGetList(session, out needed, ref count, null, ref reboot);
            if (error != 0 && error != 234) throw new EngineException("LOCK_QUERY_UNAVAILABLE", "Restart Manager could not list owners.");
            for (var attempt = 0; attempt < 3; attempt++)
            {
                ct.ThrowIfCancellationRequested();
                if (needed > 1024) throw new EngineException("RESULT_TOO_LARGE", "Too many owners were reported.");
                count = needed;
                var owners = new ProtectionProcessInfo[count];
                error = RmGetList(session, out needed, ref count, owners, ref reboot);
                if (error == 234) continue;
                if (error != 0) throw new EngineException("LOCK_QUERY_UNAVAILABLE", "Restart Manager could not list owners.");
                return new { requestedPath, path, owners = owners.Take((int)count).Select(x => new { processId = x.Process.Id, processStartTime = ((long)x.Process.StartHigh << 32) | x.Process.StartLow, name = x.Name, service = x.Service, restartable = x.Restartable }).ToArray(),
                    message = "Restart Manager reports affected applications, not every possible file handle. No process or handle was closed." };
            }
            throw new EngineException("LOCK_QUERY_BUSY", "File ownership changed repeatedly. Retry the query.");
        }
        finally { RmEndSession(session); }
    }

    private static readonly Regex PackageId = new(@"\Aoem[0-9]+\.inf\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    private static string PowerShell => Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
    private static string PnpUtil => Path.Combine(Environment.SystemDirectory, "pnputil.exe");
    private static EngineException Invalid(string message) => new("INVALID_PARAMETERS", message);
    private static string Text(JsonElement p, string key, int limit)
    {
        if (!p.TryGetProperty(key, out var v) || v.ValueKind != JsonValueKind.String) throw Invalid($"{key} must be a string.");
        var value = v.GetString()!;
        if (value.Length == 0 || value.Length > limit || value.Any(char.IsControl)) throw Invalid($"{key} has an invalid length or character.");
        return value;
    }
    private static void Confirm(JsonElement p)
    { if (!p.TryGetProperty("confirmed", out var v) || v.ValueKind != JsonValueKind.True) throw new EngineException("CONFIRMATION_REQUIRED", "Explicit confirmation is required."); }
    private static void Elevation(EngineContext c)
    { if (!c.IsElevated) throw new EngineException("ELEVATION_REQUIRED", "This operation requires an approved elevated engine."); }
    private static string LocalPath(string path)
    {
        if (!Path.IsPathFullyQualified(path) || path.StartsWith(@"\\", StringComparison.Ordinal) || path.Contains('*') || path.Contains('?') || path[2..].Contains(':')) throw Invalid("Use a fully qualified local filesystem path.");
        try { return Path.GetFullPath(path); } catch (Exception ex) when (ex is ArgumentException or NotSupportedException or PathTooLongException) { throw Invalid("The path is invalid."); }
    }
    private static void RejectReparsePath(string path)
    {
        for (string? current = path; current is not null; current = Path.GetDirectoryName(current))
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) throw Invalid("Reparse-point paths are not supported for driver operations.");
    }
    private static void RequireSuccess(ProtectionCommandResult r, string code, string message)
    { if (r.ExitCode != 0) throw new EngineException(code, message); }
    private static async Task<ProtectionCommandResult> Run(string executable, string[] args, TimeSpan duration, CancellationToken ct)
    {
        if (!File.Exists(executable)) throw new EngineException("CAPABILITY_UNAVAILABLE", "The required Windows tool is not installed.");
        var info = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var arg in args) info.ArgumentList.Add(arg);
        using var process = new Process { StartInfo = info };
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct); timeout.CancelAfter(duration);
        var started = false;
        try
        {
            started = process.Start();
            if (!started) throw new EngineException("TOOL_START_FAILED", "The Windows tool could not start.");
            var stdout = ReadBounded(process.StandardOutput, timeout.Token);
            var stderr = ReadBounded(process.StandardError, timeout.Token);
            await Task.WhenAll(process.WaitForExitAsync(timeout.Token), stdout, stderr);
            return new(process.ExitCode, await stdout);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new EngineException("OPERATION_TIMEOUT", "The Windows tool exceeded the operation time limit. Its completion is unverified."); }
        catch (System.ComponentModel.Win32Exception) { throw new EngineException("TOOL_START_FAILED", "The Windows tool could not start with the current account."); }
        finally { if (started && !process.HasExited) { try { process.Kill(true); } catch (InvalidOperationException) { } } }
    }
    private static async Task<string> ReadBounded(StreamReader reader, CancellationToken ct)
    {
        var result = new StringBuilder(); var buffer = new char[4096];
        while (true)
        {
            var count = await reader.ReadAsync(buffer.AsMemory(), ct); if (count == 0) return result.ToString();
            if (result.Length + count > 2 * 1024 * 1024) throw new EngineException("RESULT_TOO_LARGE", "The Windows tool exceeded its output limit.");
            result.Append(buffer, 0, count);
        }
    }
    private sealed record ProtectionCommandResult(int ExitCode, string Output);
    public sealed record ProtectionDriverPackage(string Id, string? OriginalName, string? Provider, string? ClassName, string? Version, string? Signer);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct ProtectionSignerInfo
    { public uint Size; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string Catalog; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string Signer; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string Version; public uint Score; }
    [DllImport("setupapi.dll", EntryPoint = "SetupVerifyInfFileW", CharSet = CharSet.Unicode, SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupVerifyInfFile(string name, IntPtr platform, ref ProtectionSignerInfo signer);
    [StructLayout(LayoutKind.Sequential)] private struct ProtectionUniqueProcess { public uint Id; public uint StartLow; public uint StartHigh; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct ProtectionProcessInfo
    { public ProtectionUniqueProcess Process; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Name; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string Service; public uint Type; public uint Status; public uint Session; [MarshalAs(UnmanagedType.Bool)] public bool Restartable; }
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] private static extern uint RmStartSession(out uint session, uint flags, StringBuilder key);
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)] private static extern uint RmRegisterResources(uint session, uint fileCount, string[] files, uint appCount, IntPtr apps, uint serviceCount, string[]? services);
    [DllImport("rstrtmgr.dll")] private static extern uint RmGetList(uint session, out uint needed, ref uint count, [In, Out] ProtectionProcessInfo[]? processes, ref uint reboot);
    [DllImport("rstrtmgr.dll")] private static extern uint RmEndSession(uint session);
}
