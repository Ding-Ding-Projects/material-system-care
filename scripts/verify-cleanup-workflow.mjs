import assert from 'node:assert/strict';
import { readFileSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, relative, isAbsolute } from 'node:path';

const [rootArg, runArg, manifestArg = 'docs/captures/cleanup-workflow.json'] = process.argv.slice(2);
assert(rootArg && runArg, 'Expected repository and private run root');
const root = realpathSync(rootArg), run = realpathSync(runArg);
const read = (base, name) => {
  const path = realpathSync(resolve(base, name)), suffix = relative(base, path);
  assert(suffix && !suffix.startsWith('..') && !isAbsolute(suffix), 'Evidence escapes its root');
  return readFileSync(path);
};
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = name => JSON.parse(read(run, name));
const manifest = JSON.parse(read(root, manifestArg));
assert.equal(manifest.version, 1);
assert.equal(manifest.route, 'cheap-lowlevel-headless');
assert.match(manifest.sourceCommit, /^[a-f0-9]{40}$/);
assert.deepEqual(json('bundle/build-receipt.json'), manifest.buildReceipt);
assert.equal(manifest.buildReceipt.source, manifest.sourceCommit);
assert.equal(hash(read(run, 'bundle/material_system_care.exe')), manifest.buildReceipt.executableSha256);
for (const [name, sha] of Object.entries(manifest.evidence)) assert.equal(hash(read(run, name)), sha, name);
assert.equal(manifest.frameCapturedAt, null, 'Exact frame times were not emitted');
assert.equal(manifest.privacy.populatedImagesPublished, false);
assert.equal(manifest.privacy.hostRecordsCollected, false);
assert.equal(manifest.privacy.disposableFilesOnly, true);
const baseline = json('baseline.json');
assert.equal(baseline.length, 2);
assert.notEqual(baseline[0].fileId, baseline[1].fileId);
const cancelled = json('cancel-review.json');
for (const before of baseline) {
  const file = cancelled.fixtureFiles.find(item => item.path.endsWith(before.path.split('\\').at(-1)));
  assert(file, 'Cancelled review lost an original file');
  assert.equal(file.sha256, before.sha256);
  assert.equal(file.fileId, before.fileId);
}
assert(!cancelled.fixtureFiles.some(item => item.path.endsWith('.receipt.json')));
const applied = json('apply-independent-proof.json');
assert.equal(applied.selectedMoved, true);
assert.equal(applied.unselectedUnchanged, true);
assert.equal(applied.recoveryHash, baseline[0].sha256);
assert.equal(applied.recoveryFileId, baseline[0].fileId);
assert.deepEqual(applied.receipt.selectedIndexes, [0]);
assert.equal(applied.receipt.items.length, 1);
assert.equal(applied.receipt.items[0].state, 'quarantined');
const conflict = json('conflict-independent-proof.json');
for (const key of ['conflictPreserved', 'recoveryPreserved', 'unselectedUnchanged']) assert.equal(conflict[key], true);
assert.equal(conflict.receipt.items[0].state, 'conflict');
assert.equal(conflict.receipt.items[0].reason, 'RESTORE_CONFLICT');
const restored = json('restore-independent-proof.json');
for (const key of ['bothOriginalHashes', 'bothOriginalFileIds', 'bothOriginalModificationTimes', 'recoverySourceAbsent']) assert.equal(restored[key], true);
assert.deepEqual(restored.selectedIndexes, [0]);
assert.equal(restored.receipt.items[0].state, 'restored');
for (const key of ['rootProcessAbsent', 'allBundleExecutablesAbsent', 'desktopEmpty', 'desktopClosed', 'visibleDesktopUntouched']) assert.equal(json('teardown.json')[key], true);
for (const frame of manifest.inspectedFrames) {
  const bytes = read(run, frame.path);
  assert.equal(hash(bytes), frame.sha256);
  assert.equal(bytes.readUInt32BE(16), 1280);
  assert.equal(bytes.readUInt32BE(20), 1000);
  assert.equal(frame.published, false);
}
console.log('PASS: selected cleanup, cancelled review, conflict-preserving restoration, exact original-file observations, source-bound frames and owned teardown. Raw paths and populated images remain private.');
