import assert from 'node:assert/strict';
import { readFileSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, relative, isAbsolute } from 'node:path';

const [repoArg, runsArg, manifestArg = 'docs/verification/cleanup-cards.json'] = process.argv.slice(2);
assert(repoArg && runsArg, 'Expected repository and private runs root');
const repo = realpathSync(repoArg), runs = realpathSync(runsArg);
function read(root, name) {
  const path = realpathSync(resolve(root, name)), rel = relative(root, path);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Evidence escapes its root');
  return readFileSync(path);
}
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = name => JSON.parse(read(runs, name));
const manifest = JSON.parse(read(repo, manifestArg));
assert.equal(manifest.version, 1);
assert.equal(manifest.route, 'cheap-lowlevel-headless');
assert.equal(manifest.captureMethod, 'flutter-repaint-boundary');
assert.match(manifest.sourceCommit, /^[0-9a-f]{40}$/);
assert.equal(manifest.buildReceipt.source, manifest.sourceCommit);
for (const [path, expected] of Object.entries(manifest.evidence)) assert.equal(hash(read(runs, path)), expected, path);
const find = suffix => {
  const paths = Object.keys(manifest.evidence).filter(path => path.endsWith(suffix));
  assert.equal(paths.length, 1, `Expected exactly one ${suffix}`);
  return json(paths[0]);
};
const applied = find('/apply-proof.json');
assert.equal(applied.selectedOnly, true);
assert.equal(applied.recoveryExactBytesAndIdentity, true);
assert.equal(applied.unselectedUnchanged, true);
assert.deepEqual(applied.receipt.selectedIndexes, [0]);
assert.equal(applied.receipt.items.length, 1);
const restored = find('/restore-proof.json');
for (const field of ['selectedRestoredExactBytesAndIdentity', 'unselectedUnchanged', 'recoveryPayloadAbsent']) assert.equal(restored[field], true);
const initial = find('/history-tab-1.json').fixtureFiles;
const beforeSelected = initial.find(file => file.path.endsWith('.recovery'));
const beforeUnselected = initial.find(file => file.path.endsWith('unselected-beta.tmp'));
assert(beforeSelected && beforeUnselected);
for (const [name, before] of [['selected-alpha.tmp', beforeSelected], ['unselected-beta.tmp', beforeUnselected]]) {
  for (const field of ['bytes', 'sha256', 'fileId']) assert.equal(restored.files[name][field], before[field]);
}
assert.equal(manifest.frames.length, 2);
for (const frame of manifest.frames) {
  const bytes = read(runs, frame.path), sidecar = json(frame.sidecar);
  assert.equal(hash(bytes), frame.sha256);
  assert.equal(sidecar.pngSha256, frame.sha256);
  assert.equal(bytes.readUInt32BE(16), frame.width);
  assert.equal(bytes.readUInt32BE(20), frame.height);
  assert.equal(sidecar.width, frame.width);
  assert.equal(sidecar.height, frame.height);
  assert.equal(sidecar.captureCompletedUtc, frame.capturedAt);
  assert(Date.parse(sidecar.captureStartedUtc) >= Date.parse(manifest.buildReceipt.builtUtc));
  assert(Date.parse(sidecar.captureCompletedUtc) >= Date.parse(sidecar.captureStartedUtc));
  assert(Date.parse(sidecar.writeStartedUtc) >= Date.parse(sidecar.captureCompletedUtc));
  assert(Date.parse(sidecar.writeCompletedUtc) >= Date.parse(sidecar.writeStartedUtc));
  assert.equal(frame.published, false, 'Incomplete diagnostic provenance must not be promoted');
}
for (const path of Object.keys(manifest.evidence).filter(path => path.endsWith('/teardown.json'))) {
  const teardown = json(path);
  if ('allBundleExecutablesAbsent' in teardown) assert.equal(teardown.allBundleExecutablesAbsent, true);
  if ('processesAbsent' in teardown) assert.equal(teardown.processesAbsent, true);
  if ('desktopClosed' in teardown) assert.equal(teardown.desktopClosed, true);
  if ('close' in teardown) assert.equal(teardown.close.closed, true);
}
console.log('PASS: typed cleanup selected-only movement, exact-byte/identity restoration, timestamped private frames and owned teardown. Generic promotion diagnostics remain unverified.');
