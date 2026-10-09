param([Parameter(Mandatory=$true)][string]$Candidate)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
try {
 $head=(& git -C $root rev-parse HEAD).Trim()
 if($Candidate -notmatch '^[0-9a-f]{40}$' -or $Candidate -ne $head) { throw 'Publication candidate must exactly match the selected main commit' }
 if($env:GITHUB_REF -and $env:GITHUB_REF -ne 'refs/heads/main') { throw 'Production publication is restricted to main' }
 $report=Get-Content "$root\packaging\release-readiness.json" -Raw | ConvertFrom-Json
 if($report.schemaVersion -ne 1) { throw 'Unsupported release readiness schema' }
 $required=@('capabilities','desktopRuntime','installerLifecycle','privacy','updateLifecycle','freshMachineBootstrap','releasePhoto')
 foreach($name in $required) {
  $check=$report.checks.$name
  if(!$check -or $check.status -ne 'verified' -or @($check.evidence).Count -eq 0) { throw "Release capability evidence is incomplete: $name" }
  foreach($entry in $check.evidence) {
   if(!$entry.path -or $entry.sha256 -notmatch '^[0-9a-f]{64}$') { throw "Invalid release evidence: $name" }
   $path=[IO.Path]::GetFullPath((Join-Path $root $entry.path))
   if(!$path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Release evidence must remain inside the repository' }
   . "$PSScriptRoot\integrity.ps1"
   if(!(Test-Path $path) -or (Get-ContentHash $path) -ne $entry.sha256) { throw "Release evidence hash mismatch: $name" }
  }
 }
 Write-Host 'Recorded release capability evidence is complete for the explicitly selected candidate.'
 exit 0
} catch { Write-Error $_; exit 1 }
