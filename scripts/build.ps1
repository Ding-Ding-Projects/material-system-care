$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\integrity.ps1"
$root = Split-Path $PSScriptRoot
Set-Location $root
$silent = $env:SILENT -eq '1' -or $args -contains '/s' -or $args -contains '--silent'
$run = $env:RUN_AFTER_BUILD -eq '1' -or $args -contains '/run' -or $args -contains '--run'
$installer = $args -contains '--installer'
$target = 'all'
foreach ($arg in $args) { if ($arg -match '^--target=(engine|desktop|site|all)$') { $target=$Matches[1] } }
try {
 $binding=Get-SourceBinding $root
 & "$PSScriptRoot\bootstrap.ps1" @args
 $m = Get-Content build-manifest.json -Raw | ConvertFrom-Json
 $out = Join-Path $root $m.outputDirectory
 New-Item -ItemType Directory -Force $out | Out-Null
 if ($target -in @('all','engine')) {
  & dotnet publish $m.engineProject -c Release -r win-x64 --self-contained true -o "$out\engine"
  if ($LASTEXITCODE) { throw "Engine build exit $LASTEXITCODE" }
  $engineExecutable=Join-Path $out 'engine\MaterialSystemCare.Engine.exe'
  if (!(Test-Path $engineExecutable)) { throw 'Published engine executable is missing' }
  Assert-SourceBinding $root $binding
  $engineReceipt=$binding.Clone(); $engineReceipt.executableSha256=Get-ContentHash $engineExecutable; $engineReceipt.builtUtc=[DateTime]::UtcNow.ToString('o')
  $engineReceipt | ConvertTo-Json | Set-Content "$out\engine\build-receipt.json"
  if ($args -contains '--verify-engine') {
   foreach ($project in @('tests/engine-core/EngineFixtures.csproj','tests/utilities/Utilities.Tests.csproj','tests/storage/Storage.Tests.csproj','tests/protection/ProtectionFixtures.csproj')) {
    & dotnet run --project $project -c Release
    if ($LASTEXITCODE) { throw "Engine verification failed: $project ($LASTEXITCODE)" }
   }
   & "$root\tests\engine-core\verify.ps1" -Engine "$out\engine\MaterialSystemCare.Engine.exe"
   if ($LASTEXITCODE) { throw 'Engine pipe verification failed' }
  }
 }
 if ($target -in @('all','desktop')) {
  Push-Location $m.desktopPath
  try { & flutter.bat pub get; if ($LASTEXITCODE) { throw 'Flutter restore failed' }; & flutter.bat build windows --release; if ($LASTEXITCODE) { throw 'Flutter build failed' }; Copy-Item 'build\windows\x64\runner\Release\*' $out -Recurse -Force } finally { Pop-Location }
 }
 if ($target -in @('all','site')) {
  Push-Location $m.websitePath
  try { & npm.cmd ci; if ($LASTEXITCODE) { throw 'Website restore failed' }; & npm.cmd run build; if ($LASTEXITCODE) { throw 'Website build failed' } } finally { Pop-Location }
 }
 if ($target -in @('all','desktop')) {
  $exe=Join-Path $out $m.executable
  if (!(Test-Path $exe)) { throw "Missing executable: $exe" }
  Assert-SourceBinding $root $binding
  $desktopReceipt=$binding.Clone(); $desktopReceipt.executableSha256=Get-ContentHash $exe; $desktopReceipt.builtUtc=[DateTime]::UtcNow.ToString('o')
  $desktopReceipt | ConvertTo-Json | Set-Content "$out\build-receipt.json"
 }
 Assert-SourceBinding $root $binding
 if ($installer) { & "$PSScriptRoot\package.ps1"; if ($LASTEXITCODE) { throw 'Squirrel packaging failed' } }
 Assert-SourceBinding $root $binding
 if ($target -in @('all','desktop')) {
  if (!$silent -and !$run) { $run=(Read-Host 'Build complete. Run application? [y/N]') -eq 'y' }
  if ($run) { Start-Process $exe }
 }
 exit 0
} catch { Write-Error $_; exit 1 }
