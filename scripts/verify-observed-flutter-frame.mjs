import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFileSync, realpathSync, readdirSync, lstatSync} from 'node:fs';
import {resolve, relative, isAbsolute, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const digest = value => assert.match(value, /^[0-9a-f]{64}$/, 'Invalid digest');
const parse = bytes => JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, ''));
function keys(value, expected) {
  assert(value && typeof value === 'object' && !Array.isArray(value), 'Expected object');
  assert.deepEqual(Object.keys(value).sort(), [...expected].sort(), 'Unexpected fields');
}
function name(value) {
  assert(typeof value === 'string' && value.length <= 240 &&
    /^[A-Za-z0-9_.\/-]+$/.test(value) && !value.startsWith('/') &&
    value.split('/').every(part => part && part !== '.' && part !== '..'), 'Invalid relative reference');
  return value;
}
function read(base, reference) {
  const path = realpathSync(resolve(base, name(reference)));
  const rel = relative(base, path);
  assert(rel && !rel.startsWith('..') && !isAbsolute(rel), 'Escaping reference');
  return readFileSync(path);
}
function integer(value, min, max) {
  assert(Number.isSafeInteger(value) && value >= min && value <= max, 'Invalid integer');
}
function utc(value, build = false) {
  assert.equal(typeof value, 'string');
  const match = /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)\.(\d{6,7})Z$/.exec(value);
  assert(match && (build || match[2].length === 6), 'Invalid UTC precision');
  const millis = Date.parse(match[1] + '.000Z');
  assert(Number.isFinite(millis) && new Date(millis).toISOString().slice(0, 19) === match[1], 'Invalid UTC date');
  return BigInt(millis) * 1000n + BigInt(match[2].slice(0, 6));
}
const excluded = new Set(['build-receipt.json', 'bundle-manifest.json', 'engine/build-receipt.json', 'engine/bundle-manifest.json']);
function inventory(base, prefix = '') {
  return readdirSync(join(base, prefix)).flatMap(entry => {
    const item = prefix + entry, stat = lstatSync(join(base, item));
    assert(!stat.isSymbolicLink(), 'Linked bundle entry');
    if (stat.isDirectory()) return inventory(base, item + '/');
    assert(stat.isFile(), 'Non-file bundle entry');
    return excluded.has(item) ? [] : [item];
  }).sort();
}

export function verifyObservedFlutterFrame(repoArg, runArg, bundleArg, manifestArg) {
  const repo = realpathSync(repoArg), run = realpathSync(runArg), bundle = realpathSync(bundleArg);
  const m = parse(read(repo, manifestArg));
  keys(m, ['schemaVersion', 'scope', 'sourceCommit', 'buildReceiptSha256', 'bundleManifestSha256', 'frames', 'evidence']);
  assert.equal(m.schemaVersion, 1);
  assert.equal(m.scope, 'observed-flutter-hooks-and-bytes');
  assert.match(m.sourceCommit, /^[0-9a-f]{40}$/);
  const git = (...args) => execFileSync('git', ['-C', repo, ...args], {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
  const tree = git('rev-parse', `${m.sourceCommit}^{tree}`).toString().trim();
  const buildBytes = read(bundle, 'build-receipt.json'), build = parse(buildBytes);
  digest(m.buildReceiptSha256); assert.equal(hash(buildBytes), m.buildReceiptSha256);
  assert.equal(build.source, m.sourceCommit); assert.equal(build.sourceTree, tree); assert.equal(build.indexTree, tree);
  const sourceManifest = git('show', `${m.sourceCommit}:build-manifest.json`);
  const windowsManifest = Buffer.from(sourceManifest.toString('utf8').replace(/\r?\n/g, '\r\n'));
  assert([hash(sourceManifest), hash(windowsManifest)].includes(build.manifestSha256), 'Build manifest differs from source checkout');
  const built = utc(build.builtUtc, true);
  const bundleBytes = read(bundle, 'bundle-manifest.json'), manifest = parse(bundleBytes);
  digest(m.bundleManifestSha256); assert.equal(hash(bundleBytes), m.bundleManifestSha256);
  assert.equal(manifest.schemaVersion, 1); assert(Array.isArray(manifest.files) && manifest.files.length > 0);
  const files = manifest.files.map(file => {
    keys(file, ['path', 'bytes', 'sha256']); name(file.path); integer(file.bytes, 0, Number.MAX_SAFE_INTEGER); digest(file.sha256);
    const bytes = read(bundle, file.path);
    assert.equal(bytes.length, file.bytes); assert.equal(hash(bytes), file.sha256);
    return file.path;
  });
  assert.deepEqual(files, [...new Set(files)].sort(), 'Bundle order or duplicate entry');
  assert.deepEqual(files, inventory(bundle), 'Bundle inventory mismatch');
  const projection = manifest.files.map(f => `${f.path}\0${f.bytes}\0${f.sha256}\n`).join('');
  assert.equal(hash(projection), manifest.bundleSha256); assert.equal(build.bundleSha256, manifest.bundleSha256);
  assert.equal(hash(read(bundle, 'material_system_care.exe')), build.executableSha256);
  assert(Array.isArray(m.frames) && m.frames.length > 0 && m.frames.length <= 20);
  const sequences = new Set(), paths = new Set();
  for (const frame of m.frames) {
    keys(frame, ['png', 'sidecar', 'sha256', 'sidecarSha256', 'sequence']);
    name(frame.png); assert(frame.png.endsWith('.png')); assert.equal(frame.sidecar, frame.png + '.json');
    integer(frame.sequence, 0, 19); assert(!sequences.has(frame.sequence) && !paths.has(frame.png), 'Duplicate frame');
    sequences.add(frame.sequence); paths.add(frame.png);
    if (frame.sequence > 0) assert(frame.png.endsWith(`-${String(frame.sequence).padStart(3, '0')}.png`), 'Frame filename sequence mismatch');
    const png = read(run, frame.png), sidecarBytes = read(run, frame.sidecar), s = parse(sidecarBytes);
    digest(frame.sha256); digest(frame.sidecarSha256);
    assert.equal(hash(png), frame.sha256); assert.equal(hash(sidecarBytes), frame.sidecarSha256);
    keys(s, ['schemaVersion', 'captureMethod', 'captureStartedUtc', 'captureCompletedUtc', 'captureElapsedMicroseconds', 'writeStartedUtc', 'writeCompletedUtc', 'writeElapsedMicroseconds', 'sequence', 'width', 'height', 'pixelRatio', 'pngBytes', 'pngSha256', 'diagnosticStatus', 'diagnostics']);
    assert.equal(s.schemaVersion, 1); assert.equal(s.captureMethod, 'flutter-repaint-boundary');
    assert.equal(s.sequence, frame.sequence); assert.equal(s.pngSha256, frame.sha256); assert.equal(s.pngBytes, png.length);
    assert(png.length >= 33 && png.length <= 32 * 1024 * 1024);
    assert(png.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
    assert.equal(png.readUInt32BE(8), 13); assert.equal(png.toString('ascii', 12, 16), 'IHDR');
    integer(s.width, 1, 32768); integer(s.height, 1, 32768); assert(s.width * s.height <= 100000000);
    assert.equal(png.readUInt32BE(16), s.width); assert.equal(png.readUInt32BE(20), s.height); assert.equal(s.pixelRatio, 1);
    integer(s.captureElapsedMicroseconds, 0, 600000000); integer(s.writeElapsedMicroseconds, 0, 600000000);
    const start = utc(s.captureStartedUtc), end = utc(s.captureCompletedUtc), writeStart = utc(s.writeStartedUtc), writeEnd = utc(s.writeCompletedUtc);
    assert(built <= start && start <= end && end <= writeStart && writeStart <= writeEnd, 'Clock order mismatch');
    assert(end - start <= 600000000n && writeStart - end <= 600000000n && writeEnd - writeStart <= 600000000n);
    assert.equal(s.diagnosticStatus, 'observed');
    const d = s.diagnostics;
    keys(d, ['schemaVersion', 'coverage', 'startedUtc', 'completedUtc', 'sequence', 'frameworkErrorCount', 'platformErrorCount', 'droppedCount', 'healthy']);
    assert.equal(d.schemaVersion, 1); assert.equal(d.coverage, 'flutter-framework,platform-dispatcher'); assert.equal(d.healthy, true);
    for (const count of ['frameworkErrorCount', 'platformErrorCount', 'droppedCount']) assert.equal(d[count], 0);
    assert.equal(d.sequence, s.sequence); assert.equal(d.completedUtc, s.captureCompletedUtc);
    const hooked = utc(d.startedUtc); assert(built <= hooked && hooked <= start && end - hooked <= 86400000000n);
  }
  assert(Array.isArray(m.evidence) && m.evidence.length <= 256);
  for (const e of m.evidence) {
    keys(e, ['role', 'path', 'sha256']); assert(['action', 'teardown'].includes(e.role)); digest(e.sha256);
    assert.equal(hash(read(run, e.path)), e.sha256, 'Changed supporting evidence');
  }
  return {frames: m.frames.length, supportingFiles: m.evidence.length, scope: m.scope};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    assert.equal(process.argv.length, 6, 'Expected: repository-root private-run-root private-bundle-root manifest-relative-path');
    const result = verifyObservedFlutterFrame(...process.argv.slice(2));
    console.log(`PASS: ${result.frames} observed Flutter frame(s), source and bundle bytes, ${result.supportingFiles} supporting hashes. No global promotion or semantic action/teardown verdict.`);
  } catch {
    console.error('FAIL: observed Flutter frame verification rejected the supplied evidence.');
    process.exitCode = 1;
  }
}
