import assert from 'node:assert/strict';
import {readFileSync, realpathSync} from 'node:fs';
import {resolve, relative, isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';

const [repoArg, runArg, manifestArg = 'docs/verification/startup-minimum.json'] = process.argv.slice(2);
assert(repoArg && runArg, 'Expected repository and private run root');
const repo = realpathSync(repoArg), run = realpathSync(runArg);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
function read(base, name) {
  const path = realpathSync(resolve(base, name)), part = relative(base, path);
  assert(part && !part.startsWith('..') && !isAbsolute(part));
  return readFileSync(path);
}
const json = name => JSON.parse(read(run, name));
const manifest = JSON.parse(read(repo, manifestArg));
assert.equal(manifest.version, 1);
assert.equal(manifest.route, 'cheap-lowlevel-headless');
assert.equal(manifest.captureMethod, 'flutter-repaint-boundary');
assert.deepEqual(manifest.tuple, {width: 800, height: 600, language: 'both', theme: 'dark', textScale: 2, motion: 'reduced'});
assert.equal(manifest.sourceCommit, json('bundle/build-receipt.json').source);
assert.deepEqual(manifest.buildReceipt, json('bundle/build-receipt.json'));
assert.equal(hash(read(run, 'bundle/material_system_care.exe')), manifest.buildReceipt.executableSha256);
for (const file of json('bundle/bundle-manifest.json').files) {
  const bytes = read(run, 'bundle/' + file.path);
  assert.equal(bytes.length, file.bytes);
  assert.equal(hash(bytes), file.sha256);
}
for (const [name, sha] of Object.entries(manifest.evidence)) assert.equal(hash(read(run, name)), sha, name);
for (const name of ['change', 'stale', 'finish']) assert.equal(json(name + '-independent.json').passed, true);
const fixture = json('fixture.json');
const changed = fixture.command.replace('exit 0', 'exit 1');
assert.deepEqual(json('minimum-stale-review-confirmed.json').ownedRegistryValue, [changed, fixture.kind]);
assert.equal(json('stale-independent.json').ownedJournalPresent, false);
assert.equal(json('finish-independent.json').ownedEntryPresent, false);
assert.equal(json('finish-independent.json').ownedJournalPresent, false);
for (const name of ['minimum-page-down', 'minimum-feedback-page-up']) {
  const action = json(name + '.json');
  assert.equal(action.action, 'win_send_keys');
  assert.equal(action.result.ok, true);
  assert.equal(action.result.client_ok, true);
}
for (const key of ['allBundleExecutablesAbsent', 'desktopEmpty', 'desktopClosed', 'visibleDesktopUntouched'])
  assert.equal(json('teardown.json')[key], true);
for (const frame of manifest.frames) {
  const bytes = read(run, frame.path), sidecar = json(frame.sidecar);
  assert.equal(hash(bytes), frame.sha256);
  assert.equal(sidecar.pngSha256, frame.sha256);
  assert.equal(bytes.readUInt32BE(16), 800);
  assert.equal(bytes.readUInt32BE(20), 600);
  assert.equal(sidecar.captureCompletedUtc, frame.capturedAt);
  assert(Date.parse(sidecar.captureStartedUtc) >= Date.parse(manifest.buildReceipt.builtUtc));
  assert(Date.parse(sidecar.captureCompletedUtc) >= Date.parse(sidecar.captureStartedUtc));
  assert.equal(frame.published, false);
}
assert(manifest.frames.some(frame => frame.state === 'review-confirmation'));
assert(manifest.frames.some(frame => frame.state === 'bilingual-stale-feedback'));
assert(manifest.limitations.includes('Native/framework diagnostics were not collected; these images are not promoted.'));
console.log('PASS: minimum startup review, source-bound private frames, stale-state preservation and owned teardown. Pixel inspection and complete accessibility remain separate.');
