$ErrorActionPreference='Stop'
. "$PSScriptRoot\package-attempt.ps1"
. "$PSScriptRoot\integrity.ps1"
$root=Split-Path $PSScriptRoot
$output=Join-Path $root ('artifacts\package-isolation-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force "$output\releases" | Out-Null
$stale=Join-Path "$output\releases" 'MaterialSystemCare.0.1.8.1.nupkg'
[IO.File]::WriteAllText($stale,'stale invalid four-part package fixture')
$script:checks=0
function Check([bool]$Condition,[string]$Message) { if(!$Condition) { throw $Message }; $script:checks++ }
function FixtureOutputs($Attempt,[string]$Version) {
 $package="MaterialSystemCare-$Version-full.nupkg"
 $path=Join-Path $Attempt.releases $package
 [IO.File]::WriteAllBytes($path,[byte[]](1,2,3,4))
 [IO.File]::WriteAllBytes((Join-Path $Attempt.releases 'Setup.exe'),[byte[]](77,90,1))
 $algorithm=[Security.Cryptography.SHA1]::Create()
 try { $hash=([BitConverter]::ToString($algorithm.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-','') } finally { $algorithm.Dispose() }
 [IO.File]::WriteAllText((Join-Path $Attempt.releases 'RELEASES'),"$hash $package 4`n")
}
$first=New-PackageAttempt $output '0.8.1'
$second=New-PackageAttempt $output '0.8.1'
Check ($first.root -ne $second.root) 'Repeated versions reused a packaging attempt'
Check (@(Get-ChildItem $first.releases -Force).Count -eq 0) 'A stale package entered the fresh release directory'
Check (Test-Path $stale) 'Earlier invalid input was discarded'
$input=Join-Path $first.input 'MaterialSystemCare.0.8.1.nupkg'
[IO.File]::WriteAllText($input,'raw input fixture retained')
FixtureOutputs $first '0.8.1'
$canonical=Publish-PackageOutputs $output $first '0.8.1'
Check (!(Test-Path (Join-Path $canonical 'MaterialSystemCare.0.1.8.1.nupkg'))) 'Stale invalid package contaminated canonical outputs'
Check ((Get-Content (Join-Path "$output\history\releases-$($first.id)" 'MaterialSystemCare.0.1.8.1.nupkg') -Raw) -eq 'stale invalid four-part package fixture') 'Prior evidence was not preserved byte-for-byte'
Check ((Test-Path $input) -and (Test-Path (Join-Path $first.releases 'Setup.exe'))) 'Raw input or verified attempt output was lost during promotion'
$rejected=$false
try { Publish-PackageOutputs $output $second '0.8.1' | Out-Null } catch { $rejected=$true }
Check ($rejected -and (Test-Path (Join-Path $canonical 'Setup.exe'))) 'Incomplete attempt replaced known-good outputs'
FixtureOutputs $second '0.8.1'
[IO.File]::WriteAllBytes((Join-Path $second.releases 'MaterialSystemCare-0.8.1-full.nupkg'),[byte[]](9,9,9,9))
$rejected=$false
try { Publish-PackageOutputs $output $second '0.8.1' | Out-Null } catch { $rejected=$true }
Check ($rejected) 'A package hash mismatch was promoted'
$third=New-PackageAttempt $output '0.8.1'; FixtureOutputs $third '0.8.1'
[IO.File]::WriteAllBytes((Join-Path $third.releases 'Setup.exe'),[byte[]](77,90,2))
$before=Get-ContentHash (Join-Path $canonical 'Setup.exe')
$lock=[IO.File]::Open((Join-Path $output 'promotion.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$rejected=$false
try { try { Publish-PackageOutputs $output $third '0.8.1' | Out-Null } catch { $rejected=$true } } finally { $lock.Dispose() }
Check ($rejected -and (Get-ContentHash (Join-Path $canonical 'Setup.exe')) -eq $before -and (Test-Path (Join-Path $third.releases 'Setup.exe'))) 'Contention changed canonical outputs or lost the distinct-byte attempt'
$fourth=New-PackageAttempt $output '0.8.1'; FixtureOutputs $fourth '0.8.1'
[IO.File]::WriteAllBytes((Join-Path $fourth.releases 'Setup.exe'),[byte[]](77,90,3))
$rejected=$false
try { Publish-PackageOutputs $output $fourth '0.8.1' { throw 'Injected final rename failure' } | Out-Null } catch { $rejected=$true }
Check ($rejected -and (Get-ContentHash (Join-Path $canonical 'Setup.exe')) -eq $before) 'Failed promotion did not restore prior canonical bytes'
$fifth=New-PackageAttempt $output '0.8.1'; FixtureOutputs $fifth '0.8.1'
[IO.File]::WriteAllBytes((Join-Path $fifth.releases 'Setup.exe'),[byte[]](77,90,4))
Publish-PackageOutputs $output $fifth '0.8.1' | Out-Null
Check ((Get-ContentHash (Join-Path $canonical 'Setup.exe')) -eq (Get-ContentHash (Join-Path $fifth.releases 'Setup.exe'))) 'Canonical verification returned another same-version attempt'
Write-Host "Package attempt isolation: $script:checks passed (synthetic file fixtures, no installer execution)"
