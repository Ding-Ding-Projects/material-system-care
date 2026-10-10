import assert from 'node:assert/strict';
import { readFileSync, realpathSync } from 'node:fs';
import { resolve, relative, isAbsolute } from 'node:path';
import { createHash } from 'node:crypto';

const [rootArg, runArg, manifestArg = 'docs/captures/keyboard-navigation.json'] = process.argv.slice(2);
assert(rootArg && runArg, 'Expected repository and private capture root');
const root = realpathSync(rootArg), run = realpathSync(runArg);
const bytes = (base, name) => {
  const path = realpathSync(resolve(base, name));
  const suffix = relative(base, path);
  assert(suffix && !suffix.startsWith('..') && !isAbsolute(suffix), 'Evidence escapes its root');
  return readFileSync(path);
};
const hash = value => createHash('sha256').update(value).digest('hex');
const manifest = JSON.parse(bytes(root, manifestArg));
assert.equal(manifest.version, 1);
assert.match(manifest.sourceCommit, /^[a-f0-9]{40}$/);
assert.match(manifest.lowlevelCommit, /^[a-f0-9]{40}$/);
assert.equal(manifest.buildReceipt.source, manifest.sourceCommit);
const buildReceipt = bytes(run, 'bundle/build-receipt.json');
assert.equal(hash(buildReceipt), manifest.buildReceiptSha256);
assert.deepEqual(JSON.parse(buildReceipt), manifest.buildReceipt);
assert.equal(hash(bytes(run, 'bundle/material_system_care.exe')), manifest.buildReceipt.executableSha256);
assert.equal(manifest.capturedAt, null, 'Do not manufacture exact frame timestamps');
assert.equal(manifest.privacy.pixelsInspected, true);
assert.equal(manifest.privacy.noHostRecordsCollected, true);
assert.equal(manifest.privacy.visibleDesktopUntouched, true);
const screens = ['services', 'scheduled-tasks', 'processes'];
const states = ['initial-focus', 'page-down', 'search-input'];
assert.equal(manifest.runs.length, screens.length);
assert.equal(manifest.screenshots.length, screens.length * states.length);
for (const screen of screens) {
  const matches = manifest.runs.filter(item => item.id === screen);
  assert.equal(matches.length, 1);
  const record = matches[0];
  assert.equal(record.allRecordedProcessesAbsent, true);
  assert.equal(record.desktopClosed, true);
  for (const [name, digest] of Object.entries(record.evidence))
    assert.equal(hash(bytes(run, `${screen}-final/${name}`)), digest, name);
  for (const state of states) {
    const shots = manifest.screenshots.filter(item => item.screen === screen && item.state === state);
    assert.equal(shots.length, 1);
    const shot = shots[0], raw = bytes(run, shot.raw), published = bytes(root, shot.path);
    assert.deepEqual(published, raw);
    assert.equal(hash(raw), shot.sha256);
    assert.equal(raw.length, shot.bytes);
    assert.equal(raw.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.equal(raw.readUInt32BE(16), 800);
    assert.equal(raw.readUInt32BE(20), 600);
    assert.equal(shot.language, 'both');
    assert.equal(shot.theme, 'dark');
    assert.equal(shot.textScale, 2);
    assert.equal(shot.physicalDpiVerified, false);
    for (let offset = 8; offset < raw.length;) {
      const length = raw.readUInt32BE(offset), kind = raw.toString('ascii', offset + 4, offset + 8);
      assert(!['tEXt', 'zTXt', 'iTXt'].includes(kind), 'Textual PNG metadata is not accepted');
      offset += length + 12;
    }
    assert(bytes(root, 'SCREENSHOTS.md').toString().includes(`](${shot.path})`));
    assert(bytes(root, 'docs/features/management/keyboard-navigation.md').toString().includes(`](../../captures/${shot.path.split('/').at(-1)})`));
  }
}
console.log('PASS: nine exact keyboard-observation frames, three runtime receipt sets, source/build hashes and documentation links. Pixel inspection is declared separately; native compositor, exact frame timestamps and physical DPI are unverified.');
