import assert from 'node:assert/strict';
import {readFileSync, realpathSync} from 'node:fs';
import {resolve, relative, isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

// A deliberately narrow validator for painted native Flutter output. It cannot
// certify native compositor capture, input, accessibility, or event collection.
const [rootArg, runArg, bundleArg, mode = 'idle'] = process.argv.slice(2);
assert(['idle','explained','processes-idle','file-use-idle','scheduled-tasks-idle','services-idle','services-yue-dark-text2'].includes(mode), 'Unknown frame state');
assert(rootArg && runArg && bundleArg, 'Expected repository, owned capture run, and built bundle paths');
const root = realpathSync(rootArg), run = realpathSync(runArg), bundle = realpathSync(bundleArg);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const json = path => JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''));
const contained = (base, path) => {
  const result = realpathSync(resolve(base, path));
  const rel = relative(base, result);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Path must remain in its owned root');
  return result;
};
const processFrame = mode === 'processes-idle';
const enlargedServiceFrame = mode === 'services-yue-dark-text2';
const serviceFrame = mode === 'services-idle' || enlargedServiceFrame;
const taskFrame = mode === 'scheduled-tasks-idle';
const fileUseFrame = mode === 'file-use-idle';
const receipt = json(resolve(root, serviceFrame ? (enlargedServiceFrame ? 'docs/captures/services-yue-dark-text2.json' : 'docs/captures/services-idle.json') : taskFrame ? 'docs/captures/scheduled-tasks-idle.json' : fileUseFrame ? 'docs/captures/file-use-idle.json' : processFrame ? 'docs/captures/processes-idle.json' : `docs/captures/diagnostics-${mode}.json`));
assert.equal(receipt.route, 'lowlevel-hidden-desktop-flutter-frame-export');
assert.equal(receipt.scope, mode !== 'explained' ? 'render-only' : 'painted-frame-with-background-input');
for (const [key,value] of Object.entries(receipt.verification)) assert.equal(value, mode === 'explained' && key === 'inputHandling', 'Unsupported verification claim');
const raw = readFileSync(contained(run, serviceFrame ? 'output/services.png' : taskFrame ? 'output/scheduled-tasks.png' : fileUseFrame ? 'output/file-use.png' : processFrame ? 'output/processes.png' : mode === 'idle' ? 'output/diagnostics.png' : 'output/diagnostics-002.png'));
const saved = readFileSync(contained(root, receipt.capture.path));
assert(raw.equals(saved), 'Published bytes differ from the original render');
assert.equal(hash(raw), receipt.capture.sha256);
assert.equal(raw.length, receipt.capture.bytes);
assert(raw.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
assert.equal(raw.readUInt32BE(16), receipt.capture.width);
assert.equal(raw.readUInt32BE(20), receipt.capture.height);
let ended = false;
for (let offset = 8; offset < raw.length;) {
  const length = raw.readUInt32BE(offset), end = offset + 12 + length;
  assert(end <= raw.length, 'PNG chunk exceeds file');
  const type = raw.toString('ascii', offset + 4, offset + 8);
  assert(!['tEXt','zTXt','iTXt','eXIf'].includes(type), 'Unexpected PNG metadata');
  offset = end;
  if (type === 'IEND') { assert.equal(offset, raw.length); ended = true; break; }
}
assert(ended, 'Missing PNG end');
const producerBytes = readFileSync(contained(run, 'build-receipt.json'));
assert.equal(hash(producerBytes), receipt.buildReceiptSha256);
const producer = JSON.parse(producerBytes.toString('utf8').replace(/^\uFEFF/, ''));
assert.equal(producer.source, receipt.sourceCommit);
assert.equal(producer.bundleSha256, receipt.bundleSha256);
assert.equal(hash(readFileSync(contained(bundle, 'material_system_care.exe'))), receipt.executableSha256);
const manifest = json(contained(bundle, 'bundle-manifest.json'));
assert.equal(manifest.bundleSha256, producer.bundleSha256);
for (const entry of manifest.files) {
  const bytes = readFileSync(contained(bundle, entry.path));
  assert.equal(bytes.length, entry.bytes);
  assert.equal(hash(bytes), entry.sha256, `Changed bundle file: ${entry.path}`);
}
execFileSync('git', ['cat-file', '-e', `${receipt.sourceCommit}^{commit}`], {cwd: root, windowsHide: true});
const launch = json(contained(run, 'launch.json'));
assert(launch.created && launch.hwnd > 0 && launch.process.pid === launch.pid);
assert.equal(realpathSync(launch.process.executablePath), contained(bundle, 'material_system_care.exe'));
if (serviceFrame) {
 const request = json(contained(run, 'request.json'));
 assert.deepEqual(request.arguments, ['--services', '--capture-frame=' + resolve(run, 'output/services.png').replaceAll('\\', '/'), ...(enlargedServiceFrame ? ['--capture-language=yue','--capture-theme=dark','--capture-text-scale=2','--capture-motion=reduced'] : ['--capture-on-input'])]);
 if (enlargedServiceFrame) { assert.equal(receipt.state.language, 'yue'); assert.equal(receipt.state.theme, 'dark'); assert.equal(receipt.state.textScale, 2); assert.equal(receipt.state.reducedMotionRequested, true); }
 assert.equal(receipt.state.screen, 'services');
}
if (taskFrame) {
 const request = json(contained(run, 'request.json'));
 assert.deepEqual(request.arguments, ['--scheduled-tasks', '--capture-frame=' + resolve(run, 'output/scheduled-tasks.png').replaceAll('\\', '/'), '--capture-on-input']);
 assert.equal(receipt.state.screen, 'scheduled-tasks');
}
if (fileUseFrame) {
 const request = json(contained(run, 'request.json'));
 assert.deepEqual(request.arguments, ['--file-use', '--capture-frame=' + resolve(run, 'output/file-use.png').replaceAll('\\', '/'), '--capture-on-input']);
 assert.equal(receipt.state.screen, 'file-use');
}
if (processFrame) {
 const request = json(contained(run, 'request.json'));
 assert.deepEqual(request.arguments, ['--processes', '--capture-frame=' + resolve(run, 'output/processes.png').replaceAll('\\', '/')]);
 assert.equal(receipt.state.screen, 'processes');
}
if (mode === 'explained') {
 const inputBytes = readFileSync(contained(run, 'inputs.json')), childBytes = readFileSync(contained(run, 'children.json'));
 assert.equal(hash(inputBytes), receipt.interaction.inputReceiptSha256); assert.equal(hash(childBytes), receipt.interaction.childReceiptSha256);
 const children = JSON.parse(childBytes), inputs = JSON.parse(inputBytes);
 assert(children.ok && children.client_ok && children.parent_hwnd === launch.hwnd); assert.equal(children.children.length, 1);
 const child = children.children[0]; assert.equal(child.class, 'FLUTTERVIEW');
 assert.deepEqual(inputs.map(item => item.name), ['mouse_click','type_text','mouse_click']); assert.equal(inputs[1].params.text, '0x9F');
 assert.equal(inputs[2].params.x, 555); assert.equal(inputs[2].params.y, 274);
 for (const input of inputs) assert(input.params.hwnd === child.handle && input.result.ok && input.result.client_ok && input.result.mode === 'background' && input.result.target_hwnd === child.handle);
 assert.equal(receipt.interaction.expectedText, '0x0000009F · DRIVER_POWER_STATE_FAILURE');
 // This checks receipt consistency. Pixel inspection establishes visible text.
}
const teardown = json(contained(run, 'teardown.json'));
assert(teardown.processesAbsent && JSON.parse(teardown.result).closed === true);
assert(receipt.privacy.visibleDesktopUntouched && receipt.privacy.pixelsInspected && !receipt.privacy.sensitiveDataFound && !receipt.privacy.handEdited);
const readme = readFileSync(resolve(root, 'README.md'), 'utf8');
assert(readme.includes(receipt.capture.path) && readme.includes('render-only'), 'README must show and qualify the frame');
console.log(`PASS ${mode} frame: ${receipt.capture.width}x${receipt.capture.height}, ${receipt.capture.sha256}; ${manifest.files.length} bundle files verified. Native compositor and full interaction coverage remain unverified.`);
