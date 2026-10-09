function Get-ContentHash([string]$Path) {
 $stream=[IO.File]::OpenRead($Path)
 $algorithm=[Security.Cryptography.SHA256]::Create()
 try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
 finally { $algorithm.Dispose(); $stream.Dispose() }
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
