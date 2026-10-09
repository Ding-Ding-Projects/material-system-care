param([string]$OutputRoot)
. "$PSScriptRoot\integrity.ps1"
$fixture=Join-Path $OutputRoot ('bundle-fixture-'+[guid]::NewGuid())
New-Item -ItemType Directory -Force "$fixture\data","$fixture\engine" | Out-Null
[IO.File]::WriteAllBytes("$fixture\desktop.exe",[byte[]](1,2,3))
[IO.File]::WriteAllBytes("$fixture\data\app.so",[byte[]](4,5,6))
[IO.File]::WriteAllBytes("$fixture\engine\engine.exe",[byte[]](7,8,9))
$expected=Write-BundleManifest $fixture
Assert-BundleManifest $fixture $expected
[IO.File]::WriteAllBytes("$fixture\data\app.so",[byte[]](4,5,7))
$rejected=$false
try { Assert-BundleManifest $fixture $expected } catch { $rejected=$true }
if(!$rejected) { throw 'Changed AOT bytes were accepted' }
[IO.File]::WriteAllBytes("$fixture\data\app.so",[byte[]](4,5,6))
Assert-BundleManifest $fixture $expected
[IO.File]::WriteAllBytes("$fixture\unexpected.dll",[byte[]](1))
$rejected=$false
try { Assert-BundleManifest $fixture $expected } catch { $rejected=$true }
if(!$rejected) { throw 'Unexpected bundle file was accepted' }
Write-Host 'Bundle receipt: 4 passed (valid, changed AOT rejected, restored valid, unexpected file rejected)'
