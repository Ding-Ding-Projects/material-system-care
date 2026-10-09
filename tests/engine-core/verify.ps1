param([Parameter(Mandatory)][string]$Engine)
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('msc-core-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
function Invoke-Engine($Method, $Parameters, $Version = 1) {
    $request = @{version=$Version;id='fixture';method=$Method;params=$Parameters} | ConvertTo-Json -Depth 20 -Compress
    $result = $request | & $Engine --stdio --data-root $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Engine process failed.' }
    $result | ConvertFrom-Json
}
try {
    $ping = Invoke-Engine 'engine.ping' @{}
    if (!$ping.ok -or !$ping.result.fixture -or $ping.result.protocolVersion -ne 1) { throw 'Ping contract failed.' }
    $save = Invoke-Engine 'settings.save' @{key='theme';value='dark'}
    if (!$save.ok) { throw 'Settings save failed.' }
    $read = Invoke-Engine 'settings.get' @{key='theme'}
    if (!$read.ok -or $read.result -ne 'dark') { throw 'Settings did not survive process restart.' }
    $history = Invoke-Engine 'history.list' @{}
    if (!$history.ok -or $history.result.records.Count -ne 1 -or $history.result.records[0].operation -ne 'settings.save') { throw 'Durable history failed.' }
    $sensitive = Invoke-Engine 'settings.save' @{key='appearance';value=@{password='fixture-only'}}
    if ($sensitive.ok -or $sensitive.error.code -ne 'INVALID_SETTING') { throw 'Sensitive settings validation failed.' }
    $invalid = Invoke-Engine 'engine.ping' @{} 99
    if ($invalid.ok -or $invalid.error.code -ne 'INVALID_REQUEST') { throw 'Protocol version validation failed.' }
    $unknown = Invoke-Engine 'host.shutdown' @{}
    if ($unknown.ok -or $unknown.error.code -ne 'METHOD_NOT_FOUND') { throw 'Unknown operation validation failed.' }
    $snapshot = Invoke-Engine 'system.snapshot' @{}
    if (!$snapshot.ok -or $snapshot.result.cpu.logicalProcessors -lt 1 -or $snapshot.result.memory.totalBytes -lt 1) { throw 'Live measurement failed.' }
    $start = [Diagnostics.ProcessStartInfo]::new($Engine)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.Arguments = '--data-root "' + $fixture + '"'
    $server = [Diagnostics.Process]::Start($start)
    try {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $pipe = [IO.Pipes.NamedPipeClientStream]::new('.', ('MaterialSystemCare.' + $sid), [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
        try {
            $pipe.Connect(10000)
            $writer = [IO.StreamWriter]::new($pipe, [Text.UTF8Encoding]::new($false), 1024, $true)
            $reader = [IO.StreamReader]::new($pipe, [Text.UTF8Encoding]::new($false), $false, 1024, $true)
            $writer.AutoFlush = $true
            $writer.WriteLine('{"version":1,"id":"pipe-fixture","method":"engine.ping","params":{}}')
            $readTask = $reader.ReadLineAsync()
            if (!$readTask.Wait(10000)) { throw 'Named pipe response timed out.' }
            $response = $readTask.GetAwaiter().GetResult() | ConvertFrom-Json
            if (!$response.ok -or $response.id -ne 'pipe-fixture') { throw 'Named pipe roundtrip failed.' }
        } finally { if ($reader) { $reader.Dispose() }; if ($writer) { $writer.Dispose() }; $pipe.Dispose() }
    } finally { if (!$server.HasExited) { $server.Kill(); $server.WaitForExit() }; $server.Dispose() }
    Write-Output 'PASS: 8 engine core groups covering protocol, persistence, history, sensitive-data validation, live measurements, and named pipe transport.'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
