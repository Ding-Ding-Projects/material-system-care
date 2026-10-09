$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\integrity.ps1"
$root = Split-Path $PSScriptRoot
$manifest = Get-Content (Join-Path $root 'build-manifest.json') -Raw | ConvertFrom-Json
$cache = Join-Path $env:LOCALAPPDATA 'MaterialSystemCare\toolchains'
New-Item -ItemType Directory -Force $cache | Out-Null
function Download($url,$path) {
 & curl.exe -L --fail --retry 3 -o "$path.partial" $url
 if ($LASTEXITCODE) { throw "Download failed: $url ($LASTEXITCODE)" }
 Move-Item -Force "$path.partial" $path
}
$env:PATH="$cache\git\cmd;$cache\flutter\bin;$cache\dotnet;$cache\node;$env:PATH"
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
 $gitArchive=Join-Path $cache 'mingit.zip'
 Download 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/MinGit-2.56.0.2-64-bit.zip' $gitArchive
 if ((Get-ContentHash $gitArchive) -ne 'da35e72aa21c005a5a0d298cfbae110bc1609a815730ea0dde84b01a1b3cd3be') { throw 'MinGit archive SHA-256 mismatch' }
 Expand-Archive $gitArchive "$cache\git"
 if (!(Test-Path "$cache\git\cmd\git.exe")) { throw 'MinGit extraction verification failed' }
}
$flutter = Join-Path $cache 'flutter\bin\flutter.bat'
if (!(Test-Path $flutter)) {
 $archive = Join-Path $cache 'flutter.zip'
 if (!(Test-Path $archive)) { Download $manifest.flutterArchive $archive }
 if ((Get-ContentHash $archive) -ne $manifest.flutterSha256) { throw 'Flutter archive SHA-256 mismatch' }
 $stage = Join-Path $cache ('stage-'+[guid]::NewGuid())
 New-Item -ItemType Directory $stage | Out-Null
 & tar.exe -xf $archive -C $stage
 if ($LASTEXITCODE -or !(Test-Path "$stage\flutter\bin\flutter.bat")) { throw 'Flutter extraction failed' }
 Move-Item "$stage\flutter" (Join-Path $cache 'flutter')
}
$env:PATH = "$cache\flutter\bin;$cache\dotnet;$cache\node;$env:PATH"
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
 $nodeVersion='26.10.0'
 $nodeArchive=Join-Path $cache 'node.zip'
 Download "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-win-x64.zip" $nodeArchive
 $expected='9fef7eca6743a6b910989cd8e78712376b394fcb9b6e1e9c44a0799a287f90c5'
 if (!$expected -or (Get-ContentHash $nodeArchive) -ne $expected) { throw 'Node archive SHA-256 mismatch' }
 $stage=Join-Path $cache ('node-stage-'+[guid]::NewGuid())
 Expand-Archive $nodeArchive $stage
 Move-Item "$stage\node-v$nodeVersion-win-x64" "$cache\node"
}
if (!(Get-Command dotnet -ErrorAction SilentlyContinue) -or !((& dotnet --list-sdks) -match '^10\.0\.401 ')) {
 $installer = Join-Path $cache 'dotnet-install.ps1'
 Download 'https://dot.net/v1/dotnet-install.ps1' $installer
 & $installer -Version $manifest.frameworks.dotnetSdk -InstallDir "$cache\dotnet" -NoPath
 if ($LASTEXITCODE) { throw 'Pinned .NET SDK installation failed' }
}
Write-Host "Flutter: $flutter. Portable toolchains require no administrator rights."
$vswhere="${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs=if(Test-Path $vswhere) { & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath }
if (!$vs) {
 $setup=Join-Path $cache 'vs_buildtools.exe'
 Download 'https://aka.ms/vs/18/release/vs_buildtools.exe' $setup
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $admin=([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if (!$admin -and ($args -contains '/s' -or $args -contains '--silent' -or $env:SILENT -eq '1')) { throw 'Visual C++ Build Tools requires native UAC consent; silent bootstrap cannot obtain elevation. Source: https://aka.ms/vs/18/release/vs_buildtools.exe' }
 $options=@{FilePath=$setup;ArgumentList='--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended';Wait=$true;PassThru=$true}
 if(!$admin) { $options.Verb='RunAs' }
 $installed=Start-Process @options
 if($installed.ExitCode -ne 0) { throw "Visual C++ installation exit $($installed.ExitCode). Host restart is never automatic." }
 $vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
 if(!$vs) { throw 'Visual C++ installation verification failed' }
}
Write-Host "Visual C++ Build Tools: $vs"
