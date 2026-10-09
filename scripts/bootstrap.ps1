$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$manifest = Get-Content (Join-Path $root 'build-manifest.json') -Raw | ConvertFrom-Json
$cache = Join-Path $env:LOCALAPPDATA 'MaterialSystemCare\toolchains'
New-Item -ItemType Directory -Force $cache | Out-Null
function Download($url,$path) {
 & curl.exe -L --fail --retry 3 -o "$path.partial" $url
 if ($LASTEXITCODE) { throw "Download failed: $url ($LASTEXITCODE)" }
 Move-Item -Force "$path.partial" $path
}
$flutter = Join-Path $cache 'flutter\bin\flutter.bat'
if (!(Test-Path $flutter)) {
 $archive = Join-Path $cache 'flutter.zip'
 if (!(Test-Path $archive)) { Download $manifest.flutterArchive $archive }
 if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.flutterSha256) { throw 'Flutter archive SHA-256 mismatch' }
 $stage = Join-Path $cache ('stage-'+[guid]::NewGuid())
 New-Item -ItemType Directory $stage | Out-Null
 & tar.exe -xf $archive -C $stage
 if ($LASTEXITCODE -or !(Test-Path "$stage\flutter\bin\flutter.bat")) { throw 'Flutter extraction failed' }
 Move-Item "$stage\flutter" (Join-Path $cache 'flutter')
}
$env:PATH = "$cache\flutter\bin;$cache\dotnet;$cache\node;$env:PATH"
if (!(Get-Command dotnet -ErrorAction SilentlyContinue) -or !((& dotnet --list-sdks) -match '^10\.0\.401 ')) {
 $installer = Join-Path $cache 'dotnet-install.ps1'
 Download 'https://dot.net/v1/dotnet-install.ps1' $installer
 & $installer -Version $manifest.frameworks.dotnetSdk -InstallDir "$cache\dotnet" -NoPath
 if ($LASTEXITCODE) { throw 'Pinned .NET SDK installation failed' }
}
Write-Host "Flutter: $flutter. Portable toolchains require no administrator rights."
