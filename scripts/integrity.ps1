function Get-ContentHash([string]$Path) {
 $stream=[IO.File]::OpenRead($Path)
 $algorithm=[Security.Cryptography.SHA256]::Create()
 try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
 finally { $algorithm.Dispose(); $stream.Dispose() }
}
function Resolve-BuildVersion($Manifest) {
 $version=if($env:BUILD_VERSION) { $env:BUILD_VERSION } else { $Manifest.version }
 if($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw 'BUILD_VERSION must be a three-part numeric SemVer version for Squirrel.Windows 2.0.1' }
 foreach($part in $version.Split('.')) {
  [uint32]$component=0
  if(![uint32]::TryParse($part,[ref]$component) -or $component -gt 65535) { throw 'Every BUILD_VERSION component must be between 0 and 65535 for Windows version resources' }
 }
 return $version
}
function Get-BundleManifest([string]$Directory) {
 $base=[IO.Path]::GetFullPath($Directory).TrimEnd('\','/')
 $paths=[string[]]@(Get-ChildItem -LiteralPath $base -Recurse -File | ForEach-Object { $_.FullName.Substring($base.Length+1).Replace('\','/') })
 [Array]::Sort($paths,[StringComparer]::Ordinal)
 $files=@(); $projection=[Text.StringBuilder]::new()
 foreach($relative in $paths) {
  if($relative -in @('build-receipt.json','bundle-manifest.json','engine/build-receipt.json','engine/bundle-manifest.json')) { continue }
  $file=Get-Item -LiteralPath (Join-Path $base $relative)
  for($parent=$file;$parent -and $parent.FullName.Length -ge $base.Length;) { if(($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse points cannot enter a produced bundle' }; $parent=if($parent -is [IO.DirectoryInfo]) { $parent.Parent } else { $parent.Directory } }
  $hash=Get-ContentHash $file.FullName
  $files+=@([ordered]@{path=$relative;bytes=$file.Length;sha256=$hash})
  [void]$projection.Append($relative).Append([char]0).Append($file.Length.ToString([Globalization.CultureInfo]::InvariantCulture)).Append([char]0).Append($hash).Append("`n")
 }
 $algorithm=[Security.Cryptography.SHA256]::Create()
 try { $digest=([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($projection.ToString())))).Replace('-','').ToLowerInvariant() } finally { $algorithm.Dispose() }
 return [ordered]@{schemaVersion=1;bundleSha256=$digest;files=$files}
}
function Write-BundleManifest([string]$Directory) {
 $manifest=Get-BundleManifest $Directory
 $manifest | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Directory 'bundle-manifest.json')
 return $manifest.bundleSha256
}
function Assert-BundleManifest([string]$Directory,[string]$Expected) {
 $recorded=Get-Content (Join-Path $Directory 'bundle-manifest.json') -Raw | ConvertFrom-Json
 $actual=Get-BundleManifest $Directory
 if($recorded.schemaVersion -ne 1 -or $recorded.bundleSha256 -ne $Expected -or $actual.bundleSha256 -ne $Expected) { throw 'Bundle contents changed after production receipt' }
 if(@($recorded.files).Count -ne @($actual.files).Count) { throw 'Bundle manifest omits produced files' }
 for($i=0;$i -lt @($actual.files).Count;$i++) { foreach($key in @('path','bytes','sha256')) { if($recorded.files[$i].$key -ne $actual.files[$i][$key]) { throw 'Bundle manifest entries differ from produced files' } } }
}
function Get-SourceBinding([string]$Root) {
 $dirty=& git -C $Root status --porcelain
 if ($LASTEXITCODE -ne 0) { throw 'Cannot read source status' }
 if ($dirty) { throw 'Build requires committed source with no staged, unstaged, or untracked changes' }
 $head=& git -C $Root rev-parse HEAD
 $tree=& git -C $Root rev-parse 'HEAD^{tree}'
 $index=& git -C $Root write-tree
 if ($LASTEXITCODE -ne 0) { throw 'Cannot read source index' }
 return @{source=$head;sourceTree=$tree;indexTree=$index;manifestSha256=(Get-ContentHash "$Root\build-manifest.json")}
}
function Assert-SourceBinding([string]$Root,$Binding) {
 $current=Get-SourceBinding $Root
 foreach($key in @('source','sourceTree','indexTree','manifestSha256')) { if($current[$key] -ne $Binding[$key]) { throw "Source changed during production: $key" } }
}
function Assert-SquirrelAware([string]$Executable) {
 if(!('MaterialSystemCare.VersionResource' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace MaterialSystemCare {
 public static class VersionResource {
  [DllImport("version.dll", CharSet=CharSet.Unicode)] static extern uint GetFileVersionInfoSize(string path, out uint handle);
  [DllImport("version.dll", CharSet=CharSet.Unicode)] static extern bool GetFileVersionInfo(string path,uint handle,uint size,byte[] data);
  [DllImport("version.dll", CharSet=CharSet.Unicode)] static extern bool VerQueryValue(byte[] data,string key,out IntPtr value,out uint length);
  public static bool IsAware(string path) {
   uint handle; uint size=GetFileVersionInfoSize(path,out handle);
   if(size==0 || size>4096) return false;
   byte[] data=new byte[size]; if(!GetFileVersionInfo(path,0,size,data)) return false;
   IntPtr value; uint length;
   return VerQueryValue(data,@"\StringFileInfo\040904B0\SquirrelAwareVersion",out value,out length) && length>0 && Marshal.PtrToStringUni(value)=="1";
  }
 }
}
'@
 }
 if(![MaterialSystemCare.VersionResource]::IsAware($Executable)) { throw 'Built executable lacks the pinned Squirrel 2.0.1 English Unicode awareness resource' }
 Write-Host 'Squirrel 2.0.1 English Unicode awareness resource: verified'
}
