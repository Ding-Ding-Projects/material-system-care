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
    Write-Output 'PASS: engine core protocol, persistence, history, sensitive-data validation, and live measurements.'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
