import assert from 'node:assert/strict';
import {readFileSync, realpathSync} from 'node:fs';
import {resolve, relative, isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const [rootArg, runArg, bundleArg] = process.argv.slice(2);
assert(rootArg && runArg && bundleArg, 'Expected repository, private run and producer bundle');
const root = realpathSync(rootArg), run = realpathSync(runArg), bundle = realpathSync(bundleArg);
const json = p => JSON.parse(readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const hash = b => createHash('sha256').update(b).digest('hex');
function owned(base, name) {
  const path = realpathSync(resolve(base, name)), rel = relative(base, path);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Escaping evidence path');
  return path;
}
const summary = json(resolve(root, 'docs/verification/file-use-holder.json'));
assert.equal(summary.schemaVersion, 1);
assert.equal(summary.scope, 'owned-file-holder-inventory-and-refresh-after-release');
assert.equal(summary.route, 'lowlevel-hidden-desktop-flutter-frame-export');
assert.equal(summary.publishedPixels, false);
assert.equal(summary.captureInstant, null);
const expected = ['build-receipt.json','request.json','launch.json','window.json','children.json','inputs.json','parent-check.json','fixture-build.json','fixture-launch.json','fixture-identity-before.json','fixture-identity-after-query.json','fixture-state.json','fixture-closed.json','teardown.json','output/file-use-004.png','output/file-use-005.png','fixture-windows.json'];
assert.deepEqual(Object.keys(summary.files), expected);
for (const name of expected) {
  const data = readFileSync(owned(run, name));
  assert.equal(data.length, summary.files[name].bytes);
  assert.equal(hash(data), summary.files[name].sha256);
  if (name.endsWith('.png')) {
    assert(data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
    assert.equal(data.readUInt32BE(16),1264); assert.equal(data.readUInt32BE(20),681);
  }
}
const producer = json(owned(run, 'build-receipt.json'));
assert.equal(producer.source, summary.sourceCommit);
assert.equal(producer.bundleSha256, summary.bundleSha256);
const manifest = json(owned(bundle, 'bundle-manifest.json'));
assert.equal(manifest.bundleSha256, producer.bundleSha256);
for (const entry of manifest.files) {
  const data = readFileSync(owned(bundle, entry.path));
  assert.equal(data.length, entry.bytes); assert.equal(hash(data), entry.sha256);
}
execFileSync('git', ['cat-file','-e',`${summary.sourceCommit}^{commit}`], {cwd:root,windowsHide:true});
execFileSync('git', ['cat-file','-e',`${summary.fixtureSource}:scripts/native-fixture/file_use_window.cpp`], {cwd:root,windowsHide:true});
const fixtureBuild = json(owned(run, 'fixture-build.json'));
assert.equal(fixtureBuild.source, summary.fixtureSource);
assert.equal(fixtureBuild.command, 'build.bat /s --target=native --resource-only');
assert.equal(fixtureBuild.exitCode, 0);
assert.equal(hash(readFileSync(owned(run,'file_use_fixture.exe'))), fixtureBuild.sha256);
const launch = json(owned(run,'launch.json'));
assert(launch.created && launch.pid === launch.process.pid && launch.hwnd > 0);
assert.equal(realpathSync(launch.process.executablePath),owned(bundle,'material_system_care.exe'));
const request = json(owned(run,'request.json'));
assert.deepEqual(request.arguments,['--file-use','--capture-frame='+resolve(run,'output/file-use.png').replaceAll('\\','/'),'--capture-on-input']);
const windows = json(owned(run,'window.json'));
assert(windows.ok && windows.client_ok && windows.pid === launch.pid && windows.hwnd === launch.hwnd);
const child = json(owned(run,'children.json'));
assert(child.ok && child.client_ok && child.parent_hwnd === launch.hwnd && child.children.length === 1 && child.children[0].class === 'FLUTTERVIEW');
const inputs = json(owned(run,'inputs.json'));
const chars = inputs.filter(i=>i.name==='type_text');
assert.equal(chars.map(i=>i.params.text).join(''),resolve(run,'held.txt').replaceAll('/','\\'));
assert(chars.every(i=>i.params.text.length===1));
assert(inputs.slice(1,chars.length+1).every(i=>i.name==='type_text'));
assert.equal(inputs.length,chars.length+5);
assert.deepEqual(inputs.filter(i=>i.name==='mouse_click').map(i=>[i.params.x,i.params.y]),[[300,192],[850,450],[300,192],[385,274],[385,274]]);
for(const input of inputs) assert(input.status===0 && input.params.hwnd===child.children[0].handle && input.result.ok && input.result.client_ok && input.result.mode==='background' && input.result.target_hwnd===child.children[0].handle);
const parent = json(owned(run,'parent-check.json'));
assert(parent.driveType===3 && parent.reparseCount===0 && parent.targetExists===false);
const holder = json(owned(run,'fixture-launch.json'));
assert(holder.ok && holder.client_ok && holder.desktop===launch.desktop && holder.focus_stealing===false);
const before = json(owned(run,'fixture-identity-before.json'));
const after = json(owned(run,'fixture-identity-after-query.json'));
assert.deepEqual(before,after);
assert.equal(holder.command, '"'+owned(run,'file_use_fixture.exe')+'" "'+resolve(run,'held.txt')+'"');
assert.equal(before.pid,holder.pid);
assert.equal(realpathSync(before.path),owned(run,'file_use_fixture.exe'));
const state = json(owned(run,'fixture-state.json'));
assert(state.desktop===launch.desktop && state.pid===before.pid && state.hwnd>0);
assert(state.process.creationDate===before.creation && state.process.executablePath===before.path);
const holderWindows=json(owned(run,'fixture-windows.json'));
assert(holderWindows.ok && holderWindows.client_ok && holderWindows.name===launch.desktop);
assert.equal(holderWindows.windows.filter(w=>w.handle===state.hwnd && w.process_id===before.pid && w.class==='MSC_FileUseFixture').length,1);
const closed = json(owned(run,'fixture-closed.json'));
assert(closed.absent && closed.elapsedMs>0 && closed.elapsedMs<300000);
assert(Math.abs(Date.parse(closed.observedAt)-Date.parse(before.nativeStart)-closed.elapsedMs)<100);
const retained = readFileSync(owned(run,'held.txt'));
assert.equal(retained.toString(),'Owned file-use holder fixture.\r\n');
assert.equal(retained.length,closed.retainedFileBytes);
assert.equal(hash(retained),closed.retainedFileSha256);
const teardown = json(owned(run,'teardown.json')), desktop=JSON.parse(teardown.result);
assert(teardown.processesAbsent && desktop.ok && desktop.closed && desktop.name===launch.desktop);
assert.deepEqual(summary.review,{fullResultPathInspected:true,populatedOwnerInspected:true,displayedPidMatchesOwnedFixture:true,identityStableAcrossQuery:true,emptyAfterOwnedReleaseInspected:true,fixtureFileRetainedUnchanged:true,ownedTeardown:true,nativePicker:false,nativeCompositor:false,fullAppearanceMatrix:false});
console.log(`PASS file-holder receipts: ${manifest.files.length} bundle files, stable owned identity, retained fixture and teardown. Populated/empty pixel review remains a separate declaration.`);
