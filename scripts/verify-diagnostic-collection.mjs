import assert from 'node:assert/strict';
import {readFileSync, realpathSync} from 'node:fs';
import {resolve, relative, isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const [rootArg, runArg, bundleArg] = process.argv.slice(2);
assert(rootArg && runArg && bundleArg, 'Expected repository, private run and producer bundle');
const root = realpathSync(rootArg), run = realpathSync(runArg), bundle = realpathSync(bundleArg);
const bytes = path => readFileSync(path);
const json = path => JSON.parse(bytes(path).toString('utf8').replace(/^\uFEFF/, ''));
const hash = value => createHash('sha256').update(value).digest('hex');
function owned(base, name) {
  const path = realpathSync(resolve(base, name));
  const rel = relative(base, path);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Escaping evidence path');
  return path;
}
const summary = json(resolve(root, 'docs/verification/diagnostic-collection.json'));
assert.equal(summary.schemaVersion, 1);
assert.equal(summary.route, 'lowlevel-hidden-desktop-flutter-frame-export');
assert.equal(summary.transport, 'documented-compatibility-http/native-cpp');
assert.equal(summary.scope, 'read-only-crash-collection-and-one-expanded-record');
assert.equal(summary.publishedPixels, false);
assert.equal(summary.captureInstant, null);
const expected = ['build-receipt.json', 'launch.json', 'window.json', 'children.json', 'inputs.json', 'unsupported-scroll.json', 'teardown.json', 'output/diagnostics.png', 'output/diagnostics-001.png', 'output/diagnostics-002.png'];
assert.deepEqual(Object.keys(summary.files), expected);
for (const name of expected) {
  const data = bytes(owned(run, name));
  assert.equal(data.length, summary.files[name].bytes);
  assert.equal(hash(data), summary.files[name].sha256, `Changed evidence: ${name}`);
  if (name.endsWith('.png')) {
    assert(data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
    assert.equal(data.readUInt32BE(16), 1264);
    assert.equal(data.readUInt32BE(20), 681);
  }
}
const producer = json(owned(run, 'build-receipt.json'));
assert.equal(producer.source, summary.sourceCommit);
assert.equal(producer.bundleSha256, summary.bundleSha256);
execFileSync('git', ['cat-file', '-e', `${summary.sourceCommit}^{commit}`], {cwd: root, windowsHide: true});
const manifest = json(owned(bundle, 'bundle-manifest.json'));
assert.equal(manifest.bundleSha256, producer.bundleSha256);
for (const entry of manifest.files) {
  const data = bytes(owned(bundle, entry.path));
  assert.equal(data.length, entry.bytes);
  assert.equal(hash(data), entry.sha256);
}
const launch = json(owned(run, 'launch.json'));
assert(launch.created && launch.hwnd > 0 && launch.pid === launch.process.pid);
assert.equal(realpathSync(launch.process.executablePath), owned(bundle, 'material_system_care.exe'));
const window = json(owned(run, 'window.json'));
assert(window.ok && window.client_ok && window.hwnd === launch.hwnd && window.pid === launch.pid);
const children = json(owned(run, 'children.json'));
assert(children.ok && children.client_ok && children.parent_hwnd === launch.hwnd);
assert.equal(children.children.length, 1);
const child = children.children[0];
assert.equal(child.class, 'FLUTTERVIEW');
const inputs = json(owned(run, 'inputs.json'));
assert.equal(inputs.length, 2);
assert.deepEqual(inputs.map(i => [i.parameters.x, i.parameters.y]), [[510,193],[1068,465]]);
for (const input of inputs) {
  assert.equal(input.tool, 'mouse_click');
  assert.equal(input.status, 0);
  assert.deepEqual(input.parameters, {hwnd: child.handle, x: input.parameters.x, y: input.parameters.y, button: 'left'});
  assert(input.result.ok && input.result.client_ok && input.result.mode === 'background' && input.result.target_hwnd === child.handle);
}
const scroll = json(owned(run, 'unsupported-scroll.json'));
assert.equal(scroll.client_ok, false);
assert.equal(scroll.is_error, true);
assert(scroll.content.some(text => typeof text === 'string' && text.includes('validation error for mouse_scrollArguments') && text.includes('params.hwnd') && text.includes('Extra inputs are not permitted')));
const teardown = json(owned(run, 'teardown.json'));
const closed = JSON.parse(teardown.result);
assert(teardown.processesAbsent && closed.ok && closed.closed && closed.name === launch.desktop);
assert.deepEqual(summary.review, {
  initialIdleInspected: true, completedCollectionInspected: true,
  oneExpandedRecordInspected: true, providerAndEventTypeVisible: true,
  unknownCodePresentedWithoutRootCause: true, ownedTeardown: true,
  visibleDesktopUntouched: true, nativeCompositor: false,
  fullInputMatrix: false, dumpMetadataSectionInspected: false,
});
console.log(`PASS diagnostic collection receipts: ${manifest.files.length} bundle files, two background inputs, three private frames and owned teardown. Pixel review remains a separate declaration; no full-matrix claim.`);
