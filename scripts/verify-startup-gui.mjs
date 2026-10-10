import assert from 'node:assert/strict';
import {readFileSync,realpathSync} from 'node:fs';
import {resolve,relative,isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
const [repoArg,runArg,manifestArg='docs/verification/startup-gui.json']=process.argv.slice(2);
assert(repoArg&&runArg,'Expected repository and private run root');
const repo=realpathSync(repoArg),run=realpathSync(runArg);
const hash=b=>createHash('sha256').update(b).digest('hex');
function read(base,name){const p=realpathSync(resolve(base,name)),r=relative(base,p);assert(r&&!r.startsWith('..')&&!isAbsolute(r));return readFileSync(p);}
const json=name=>JSON.parse(read(run,name));
const m=JSON.parse(read(repo,manifestArg));
assert.equal(m.version,1);assert.equal(m.route,'cheap-lowlevel-headless');
assert.equal(m.captureMethod,'flutter-repaint-boundary');
assert.equal(m.sourceCommit,json('bundle/build-receipt.json').source);
assert.deepEqual(m.buildReceipt,json('bundle/build-receipt.json'));
assert.equal(hash(read(run,'bundle/material_system_care.exe')),m.buildReceipt.executableSha256);
for(const file of json('bundle/bundle-manifest.json').files){const b=read(run,'bundle/'+file.path);assert.equal(b.length,file.bytes);assert.equal(hash(b),file.sha256);}
for(const [name,sha] of Object.entries(m.evidence))assert.equal(hash(read(run,name)),sha,name);
for(const name of ['cancel','change','stale','disabled','finish'])assert.equal(json(name+'-independent.json').passed,true);
const fixture=json('fixture.json');const changed=fixture.command.replace('exit 0','exit 1');
assert.deepEqual(json('review-cancelled.json').ownedRegistryValue,[fixture.command,fixture.kind]);
assert.deepEqual(json('stale-review-confirmed.json').ownedRegistryValue,[changed,fixture.kind]);
assert.equal(json('fresh-disable-confirmed.json').ownedRegistryValue,null);
assert.deepEqual(json('restore-confirmed.json').ownedRegistryValue,[changed,fixture.kind]);
assert.equal(json('finish-independent.json').ownedEntryPresent,false);
assert.equal(json('finish-independent.json').ownedJournalPresent,false);
for(const key of ['allBundleExecutablesAbsent','desktopEmpty','desktopClosed','visibleDesktopUntouched'])assert.equal(json('teardown.json')[key],true);
for(const frame of m.frames){const b=read(run,frame.path),s=json(frame.sidecar);assert.equal(hash(b),frame.sha256);assert.equal(s.pngSha256,frame.sha256);assert.equal(b.readUInt32BE(16),frame.width);assert.equal(b.readUInt32BE(20),frame.height);assert.equal(s.captureCompletedUtc,frame.capturedAt);assert(Date.parse(s.captureStartedUtc)>=Date.parse(m.buildReceipt.builtUtc));assert(Date.parse(s.captureCompletedUtc)>=Date.parse(s.captureStartedUtc));assert.equal(frame.published,false);}
assert(m.limitations.some(s=>s.includes('missing Cantonese')));
console.log('PASS: startup GUI cancellation, stale rejection, reviewed disable, exact command/type restoration, source-bound private frames and owned teardown. Translation correction and full visual matrix remain separate.');
