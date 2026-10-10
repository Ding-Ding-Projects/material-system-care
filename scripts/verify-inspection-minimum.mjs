import assert from 'node:assert/strict';
import {readFileSync, realpathSync} from 'node:fs';
import {resolve, relative, isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

// Checks retained bytes and declared observations, not pixels or runtime behavior.
const [rootArg, runArg] = process.argv.slice(2);
assert(rootArg && runArg, 'Expected repository and owned matrix run');
const root = realpathSync(rootArg), run = realpathSync(runArg);
const hash = b => createHash('sha256').update(b).digest('hex');
const file = (base, name) => {
  const path = realpathSync(resolve(base, name));
  const rel = relative(base, path);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Path escapes root');
  return path;
};
const bytes = (base, name) => readFileSync(file(base, name));
const json = (base, name) => JSON.parse(bytes(base, name).toString('utf8').replace(/^\uFEFF/, ''));
const receipt = json(root, 'docs/verification/inspection-minimum.json');
assert.equal(receipt.version, 1);
assert.equal(receipt.route, 'lowlevel-compatibility-http-native-cpp-hidden-desktop-with-native-resize-and-flutter-painted-export');
assert.deepEqual(receipt.state, {language:'both',theme:'dark',textScale:2,reducedMotionRequested:true,clientWidth:800,clientHeight:600});
assert.equal(receipt.captureTimestamp, null);
assert.deepEqual(receipt.privacy, {pixelsReviewed:true,localRecordsCollected:false,privatePathsVisible:false,visibleDesktopUntouched:true});
assert.deepEqual(receipt.inspection, {titlesVisible:true,initialViewportOnly:true,bodyBelowFold:true,servicePageDownMovedViewport:false});
const build = json(run, 'bundle/build-receipt.json');
assert.equal(build.source, receipt.sourceCommit);
assert.equal(build.sourceTree, build.indexTree);
assert.equal(build.bundleSha256, receipt.bundleSha256);
assert.equal(hash(bytes(run, 'bundle/build-receipt.json')), receipt.buildReceiptSha256);
assert.equal(hash(bytes(run, 'bundle/material_system_care.exe')), receipt.executableSha256);
const manifest = json(run, 'bundle/bundle-manifest.json');
assert.equal(manifest.bundleSha256, receipt.bundleSha256);
for (const entry of manifest.files) {
  const b = bytes(run, 'bundle/' + entry.path);
  assert.equal(b.length, entry.bytes);
  assert.equal(hash(b), entry.sha256);
}
execFileSync('git', ['cat-file', '-e', receipt.sourceCommit + '^{commit}'], {cwd:root,windowsHide:true});
assert.equal(hash(bytes(run, 'bundle-absence.json')), receipt.bundleAbsenceReceiptSha256);
assert.equal(json(run, 'bundle-absence.json').count, 0);
const screens = ['services','diagnostics','processes','file-use','scheduled-tasks'];
assert.deepEqual(receipt.captures.map(c=>c.screen), screens);
for (const c of receipt.captures) {
  assert.equal(c.id, c.screen + '-minimum-bilingual');
  assert.equal(c.path, 'docs/captures/' + c.id + '.png');
  assert.equal(c.raw, c.screen + '/output/' + c.screen + '-001.png');
  const raw = bytes(run, c.raw);
  assert(raw.equals(bytes(root, c.path)));
  assert.equal(hash(raw), c.sha256);
  assert.equal(raw.length, c.bytes);
  assert(raw.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
  assert.equal(raw.readUInt32BE(16), 800); assert.equal(c.width, 800);
  assert.equal(raw.readUInt32BE(20), 600); assert.equal(c.height, 600);
  let ended = false;
  for (let offset=8; offset<raw.length;) {
    const end=offset+12+raw.readUInt32BE(offset);
    assert(end<=raw.length);
    const type=raw.toString('ascii',offset+4,offset+8);
    assert(!['tEXt','zTXt','iTXt','eXIf'].includes(type));
    offset=end;
    if(type==='IEND'){assert.equal(end,raw.length); ended=true;break;}
  }
  assert(ended);
  const required=['build-receipt.json','request.json','launch.json','window-before.json','native-resize.json','children.json','input.json','window-close.json','teardown.json'];
  assert.deepEqual(Object.keys(c.evidence), required.map(f=>c.screen+'/'+f));
  for(const [path,digest] of Object.entries(c.evidence)) assert.equal(hash(bytes(run,path)),digest);
  const sub = file(run,c.screen), launch=json(sub,'launch.json');
  assert(launch.created && launch.process.pid===launch.pid);
  assert.equal(realpathSync(launch.process.executablePath),file(run,'bundle/material_system_care.exe'));
  const request=json(sub,'request.json');
  assert.deepEqual(request.arguments,['--'+c.screen,'--capture-frame='+resolve(sub,'output',c.screen+'.png').replaceAll('\\','/'),'--capture-on-input','--capture-language=both','--capture-theme=dark','--capture-text-scale=2','--capture-motion=reduced']);
  const size=json(sub,'native-resize.json');
  assert.equal(size.pid,launch.pid); assert.equal(size.hwnd,launch.hwnd);
  assert.equal(size.width,800);assert.equal(size.height,600);assert.equal(size.activated,false);
  const children=json(sub,'children.json');
  assert.equal(children.client_ok,true);assert.equal(children.children.length,1);
  const child=children.children[0];assert.equal(child.width,800);assert.equal(child.height,600);
  const input=json(sub,'input.json');
  assert.equal(input.name,'mouse_click');assert.deepEqual(input.params,{hwnd:child.handle,x:785,y:575,button:'left'});
  assert.equal(input.result.client_ok,true);
  const teardown=json(sub,'teardown.json');
  assert.equal(teardown.processesAbsent,true);assert.equal(teardown.result.closed,true);assert.equal(teardown.result.name,launch.desktop);
  assert(bytes(root,'docs/captures/README.md').toString().includes('('+c.id+'.png)'));
}
console.log(`PASS: ${screens.length} minimum-size frames and ${manifest.files.length} bundle files; visual inspection and runtime coverage remain separate.`);
