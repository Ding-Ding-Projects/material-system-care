$ErrorActionPreference='Stop'
. "$PSScriptRoot\integrity.ps1"
$root=Split-Path $PSScriptRoot
$m=Get-Content "$root\build-manifest.json" -Raw | ConvertFrom-Json
$binding=Get-SourceBinding $root
$cache=Join-Path $env:LOCALAPPDATA 'MaterialSystemCare\toolchains'
function Fetch($url,$path,$sha) {
 if (!(Test-Path $path) -or (Get-ContentHash $path) -ne $sha) {
  & curl.exe -L --fail --retry 3 -o "$path.partial" $url
  if ($LASTEXITCODE) { throw "Download failed: $url" }
  if ((Get-ContentHash "$path.partial") -ne $sha) { throw "Hash mismatch: $url" }
  Move-Item -Force "$path.partial" $path
 }
}
Fetch 'https://api.nuget.org/v3-flatcontainer/squirrel.windows/2.0.1/squirrel.windows.2.0.1.nupkg' "$cache\squirrel.2.0.1.zip" '923e18abb4fd50b5a4878a39dbcd042ed3f7eb68fc0f82c0955cd5380c921ac7'
Fetch 'https://dist.nuget.org/win-x86-commandline/v6.14.0/nuget.exe' "$cache\nuget.exe" '92dbed160ddee0f64b901e907439e021211b428e57c089ecc12fc38dcc4bd9a5'
if (!(Test-Path "$cache\squirrel\tools\Squirrel.exe")) { Expand-Archive "$cache\squirrel.2.0.1.zip" "$cache\squirrel" -Force }
$payload=Join-Path $root $m.outputDirectory
foreach ($required in @($m.executable,'flutter_windows.dll','data\icudtl.dat','engine\MaterialSystemCare.Engine.exe')) { if (!(Test-Path "$payload\$required")) { throw "Missing package payload: $required" } }
foreach($pair in @(@('build-receipt.json',$m.executable),@('engine\build-receipt.json','engine\MaterialSystemCare.Engine.exe'))) {
 $receipt=Get-Content (Join-Path $payload $pair[0]) -Raw | ConvertFrom-Json
 foreach($key in @('source','sourceTree','indexTree','manifestSha256')) { if($receipt.$key -ne $binding[$key]) { throw "Package receipt does not match current source: $($pair[0]) $key" } }
 if($receipt.executableSha256 -ne (Get-ContentHash (Join-Path $payload $pair[1]))) { throw 'Package executable changed after build receipt' }
}
$version=if ($env:BUILD_VERSION) { $env:BUILD_VERSION } else { $m.version }
if ($version -notmatch '^\d+\.\d+\.\d+(\.\d+)?$') { throw 'BUILD_VERSION must be a numeric NuGet version' }
$out=Join-Path $root 'artifacts\installer'
New-Item -ItemType Directory -Force $out | Out-Null
$spec=Join-Path $out 'MaterialSystemCare.nuspec'
$escaped=[Security.SecurityElement]::Escape($payload)
@"
<?xml version="1.0"?>
<package><metadata><id>MaterialSystemCare</id><version>$version</version><authors>Material System Care contributors</authors><description>Independent local Windows maintenance workspace.</description><title>Material System Care</title></metadata><files><file src="$escaped\**\*" target="lib\net45" /></files></package>
"@ | Set-Content $spec -Encoding UTF8
& "$cache\nuget.exe" pack $spec -OutputDirectory $out -NoPackageAnalysis
if ($LASTEXITCODE) { throw "NuGet pack exit $LASTEXITCODE" }
& "$cache\squirrel\tools\Squirrel.exe" --releasify "$out\MaterialSystemCare.$version.nupkg" --releaseDir "$out\releases" --no-msi
if ($LASTEXITCODE) { throw "Squirrel releasify exit $LASTEXITCODE" }
Assert-SourceBinding $root $binding
foreach ($required in @('Setup.exe','RELEASES',"MaterialSystemCare-$version-full.nupkg")) {
 $path=Join-Path "$out\releases" $required
 if (!(Test-Path $path) -or (Get-Item $path).Length -eq 0) { throw "Missing Squirrel output: $required" }
 Write-Host "$required SHA-256 $(Get-ContentHash $path)"
}
Write-Host 'Squirrel.Windows outputs are unsigned and may trigger unknown-publisher or SmartScreen warnings.'
