function New-PackageAttempt([string]$Output,[string]$Version) {
 $base=[IO.Path]::GetFullPath($Output)
 $id=$Version+'-'+[guid]::NewGuid().ToString('N')
 $attempt=Join-Path $base ('attempts\'+$id)
 foreach($child in @('input','releases','diagnostics')) { New-Item -ItemType Directory -Path (Join-Path $attempt $child) -Force | Out-Null }
 return @{id=$id;root=$attempt;input=(Join-Path $attempt 'input');releases=(Join-Path $attempt 'releases');diagnostics=(Join-Path $attempt 'diagnostics')}
}
function Assert-PackageOutputs([string]$Directory,[string]$Version) {
 $package="MaterialSystemCare-$Version-full.nupkg"
 foreach($name in @('Setup.exe','RELEASES',$package)) { $path=Join-Path $Directory $name; if(!(Test-Path $path) -or (Get-Item $path).Length -eq 0) { throw "Missing Squirrel output: $name" } }
 $entries=@(Get-Content (Join-Path $Directory 'RELEASES') | Where-Object { $_.Trim() })
 if($entries.Count -ne 1 -or $entries[0] -notmatch '\A([0-9A-Fa-f]{40}) ([^ ]+) ([0-9]+)\z' -or $Matches[2] -ne $package) { throw 'Fresh Squirrel release metadata contains an unexpected package' }
 $expectedHash=$Matches[1]; $expectedBytes=$Matches[3]
 $path=Join-Path $Directory $package
 if((Get-Item $path).Length.ToString() -ne $expectedBytes) { throw 'Squirrel release package size differs from metadata' }
 $algorithm=[Security.Cryptography.SHA1]::Create(); $stream=[IO.File]::OpenRead($path)
 try { $actual=([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','') } finally { $stream.Dispose(); $algorithm.Dispose() }
 if($actual -ne $expectedHash) { throw 'Squirrel release package hash differs from metadata' }
}
function Publish-PackageOutputs([string]$Output,$Attempt,[string]$Version,[scriptblock]$BeforeFinalRename=$null) {
 Assert-PackageOutputs $Attempt.releases $Version
 $base=[IO.Path]::GetFullPath($Output).TrimEnd('\','/')
 $canonical=Join-Path $base 'releases'; $stage=Join-Path $base ('promotion-'+$Attempt.id); $archive=Join-Path $base ('history\releases-'+$Attempt.id)
 foreach($path in @($canonical,$stage,$archive,$Attempt.releases)) { if(![IO.Path]::GetFullPath($path).StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Packaging paths must remain inside the output directory' } }
 New-Item -ItemType Directory -Path $stage | Out-Null
 foreach($name in @('Setup.exe','RELEASES',"MaterialSystemCare-$Version-full.nupkg")) { Copy-Item -LiteralPath (Join-Path $Attempt.releases $name) -Destination (Join-Path $stage $name) }
 Assert-PackageOutputs $stage $Version
 $expected=@{}
 foreach($name in @('Setup.exe','RELEASES',"MaterialSystemCare-$Version-full.nupkg")) { $expected[$name]=Get-ContentHash (Join-Path $Attempt.releases $name) }
 $lock=$null
 try {
  $lock=[IO.File]::Open((Join-Path $base 'promotion.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 } catch { throw 'Another packaging attempt owns canonical promotion; this attempt remains preserved' }
 $preserved=$false; $installed=$false
 try {
  if(Test-Path $canonical) { New-Item -ItemType Directory -Force (Split-Path $archive) | Out-Null; [IO.Directory]::Move($canonical,$archive); $preserved=$true }
  if($BeforeFinalRename) { & $BeforeFinalRename }
  [IO.Directory]::Move($stage,$canonical); $installed=$true
  Assert-PackageOutputs $canonical $Version
  foreach($name in $expected.Keys) { if((Get-ContentHash (Join-Path $canonical $name)) -ne $expected[$name]) { throw 'Canonical package differs from the validated attempt' } }
 } catch {
  if($installed -and (Test-Path $canonical)) { [IO.Directory]::Move($canonical,(Join-Path $base ('failed-promotion-'+$Attempt.id))) }
  if($preserved -and !(Test-Path $canonical)) { [IO.Directory]::Move($archive,$canonical) }
  throw
 } finally { $lock.Dispose() }
 return $canonical
}
