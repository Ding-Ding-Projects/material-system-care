import assert from 'node:assert/strict';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {verifyObservedFlutterFrame} from './verify-observed-flutter-frame.mjs';

// Synthetic parser fixtures only. These are not captured UI evidence.
const root = mkdtempSync(join(tmpdir(), 'observed-frame-parser-'));
const repo = join(root, 'repo'), run = join(root, 'run'), bundle = join(root, 'bundle');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const save = (base, name, value) => writeFileSync(join(base, name), JSON.stringify(value));
let checks = 0;
try {
  for (const dir of [repo, run, bundle]) mkdirSync(dir);
  const git = (...args) => execFileSync('git', ['-C', repo, ...args], {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']}).toString().trim();
  git('init'); git('config', 'user.name', 'Claude Fable 5.1'); git('config', 'user.email', 'noreply@anthropic.com');
  writeFileSync(join(repo, 'build-manifest.json'), '{}\n');
  git('add', 'build-manifest.json'); git('commit', '-m', 'Create synthetic verifier fixture', '-m', 'Parser rehearsal only; no camera was invited.\n只係解析測試，冇請相機到場。', '-m', 'Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>');
  const source = git('rev-parse', 'HEAD'), tree = git('rev-parse', 'HEAD^{tree}');
  const png = Buffer.from('89504e470d0a1a0a0000000d4948445200000001000000010804000000b51c0c020000000b4944415478da63fcff1f0003030200efa30b6d0000000049454e44ae426082', 'hex');
  const sidecar = {
    schemaVersion: 1, captureMethod: 'flutter-repaint-boundary',
    captureStartedUtc: '2026-10-10T12:00:01.000000Z', captureCompletedUtc: '2026-10-10T12:00:02.000000Z', captureElapsedMicroseconds: 1000000,
    writeStartedUtc: '2026-10-10T12:00:02.100000Z', writeCompletedUtc: '2026-10-10T12:00:02.200000Z', writeElapsedMicroseconds: 100000,
    sequence: 0, width: 1, height: 1, pixelRatio: 1, pngBytes: png.length, pngSha256: hash(png), diagnosticStatus: 'observed',
    diagnostics: {schemaVersion: 1, coverage: 'flutter-framework,platform-dispatcher', startedUtc: '2026-10-10T12:00:00.500000Z', completedUtc: '2026-10-10T12:00:02.000000Z', sequence: 0, frameworkErrorCount: 0, platformErrorCount: 0, droppedCount: 0, healthy: true},
  };
  const payload = Buffer.from('synthetic executable bytes, never executed');
  writeFileSync(join(bundle, 'material_system_care.exe'), payload);
  const files = [{path: 'material_system_care.exe', bytes: payload.length, sha256: hash(payload)}];
  const bundleSha256 = hash(files.map(f => `${f.path}\0${f.bytes}\0${f.sha256}\n`).join(''));
  const inventory = {schemaVersion: 1, bundleSha256, files};
  const build = {source, sourceTree: tree, indexTree: tree, manifestSha256: hash('{}\r\n'), builtUtc: '2026-10-10T12:00:00.0000000Z', bundleSha256, executableSha256: hash(payload)};
  writeFileSync(join(run, 'frame.png'), png); save(run, 'frame.png.json', sidecar); save(run, 'teardown.json', {synthetic: true});
  save(bundle, 'bundle-manifest.json', inventory); save(bundle, 'build-receipt.json', build);
  const manifest = {schemaVersion: 1, scope: 'observed-flutter-hooks-and-bytes', sourceCommit: source,
    buildReceiptSha256: hash(readFileSync(join(bundle, 'build-receipt.json'))), bundleManifestSha256: hash(readFileSync(join(bundle, 'bundle-manifest.json'))),
    frames: [{png: 'frame.png', sidecar: 'frame.png.json', sha256: hash(png), sidecarSha256: hash(readFileSync(join(run, 'frame.png.json'))), sequence: 0}],
    evidence: [{role: 'teardown', path: 'teardown.json', sha256: hash(readFileSync(join(run, 'teardown.json')))}]};
  const verify = () => verifyObservedFlutterFrame(repo, run, bundle, 'manifest.json');
  save(repo, 'manifest.json', manifest); assert.equal(verify().frames, 1); checks++;
  function alteredReceipt(change) {
    const changed = structuredClone(sidecar); change(changed); save(run, 'frame.png.json', changed);
    const m = structuredClone(manifest); m.frames[0].sidecarSha256 = hash(readFileSync(join(run, 'frame.png.json'))); save(repo, 'manifest.json', m);
    assert.throws(verify); checks++;
    save(run, 'frame.png.json', sidecar); save(repo, 'manifest.json', manifest);
  }
  for (const change of [
    s => delete s.diagnostics, s => {s.diagnostics = null;},
    s => {s.diagnosticStatus = 'legacy-unverified';}, s => {s.diagnostics.healthy = false;},
    s => {s.diagnostics.healthy = 'true';}, s => {s.diagnostics.coverage = 'console';},
    s => {s.diagnostics.frameworkErrorCount = 1;}, s => {s.diagnostics.platformErrorCount = 1;},
    s => {s.diagnostics.droppedCount = 1;}, s => {s.diagnostics.frameworkErrorCount = '0';},
    s => {s.diagnostics.sequence = 1;}, s => {s.diagnostics.completedUtc = s.captureStartedUtc;},
    s => {s.diagnostics.startedUtc = '2026-02-30T00:00:00.000000Z';},
    s => {s.diagnostics.startedUtc = s.writeCompletedUtc;}, s => {s.width = 2;},
    s => {s.sequence = 1;}, s => {s.pngSha256 = '0'.repeat(64);},
    s => {s.writeCompletedUtc = s.captureStartedUtc;}, s => {s.consoleErrorCount = 0;},
  ]) alteredReceipt(change);
  save(run, 'frame.png.json', {...sidecar, diagnosticStatus: 'legacy-unverified'});
  assert.throws(verify); checks++; save(run, 'frame.png.json', sidecar);
  const wrongSource = structuredClone(manifest); wrongSource.sourceCommit = '0'.repeat(40);
  save(repo, 'manifest.json', wrongSource); assert.throws(verify); checks++; save(repo, 'manifest.json', manifest);
  save(bundle, 'build-receipt.json', {...build, sourceTree: '0'.repeat(40)});
  const changedBuild = structuredClone(manifest); changedBuild.buildReceiptSha256 = hash(readFileSync(join(bundle, 'build-receipt.json')));
  save(repo, 'manifest.json', changedBuild); assert.throws(verify); checks++;
  save(bundle, 'build-receipt.json', build); save(repo, 'manifest.json', manifest);
  save(bundle, 'bundle-manifest.json', {...inventory, bundleSha256: '0'.repeat(64)});
  const changedBundle = structuredClone(manifest); changedBundle.bundleManifestSha256 = hash(readFileSync(join(bundle, 'bundle-manifest.json')));
  save(repo, 'manifest.json', changedBundle); assert.throws(verify); checks++;
  save(bundle, 'bundle-manifest.json', inventory); save(repo, 'manifest.json', manifest);
  writeFileSync(join(run, 'frame.png'), Buffer.alloc(png.length)); assert.throws(verify); checks++; writeFileSync(join(run, 'frame.png'), png);
  writeFileSync(join(run, 'teardown.json'), '{}'); assert.throws(verify); checks++; save(run, 'teardown.json', {synthetic: true});
  writeFileSync(join(bundle, 'unexpected.txt'), 'extra'); assert.throws(verify); checks++; rmSync(join(bundle, 'unexpected.txt'));
  writeFileSync(join(bundle, 'material_system_care.exe'), 'changed'); assert.throws(verify); checks++; writeFileSync(join(bundle, 'material_system_care.exe'), payload);
  const escape = structuredClone(manifest); escape.frames[0].png = '../frame.png'; save(repo, 'manifest.json', escape); assert.throws(verify); checks++;
  console.log(`PASS: ${checks} synthetic observed-frame verifier checks. No live capture proof.`);
} finally {
  rmSync(root, {recursive: true, force: true});
}
