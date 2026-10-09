import { readFileSync, existsSync } from 'node:fs';
import { resolve, isAbsolute, relative } from 'node:path';
import { createHash } from 'node:crypto';
export const root = resolve(import.meta.dirname, '../..');
export const readJson = path => JSON.parse(readFileSync(resolve(root, path), 'utf8'));
export function invariant(condition, message) { if (!condition) throw new Error(message); }
export function localFile(path) {
  invariant(typeof path === 'string' && path.length > 0 && !isAbsolute(path) && !path.includes('\\') && !path.includes(':'), 'Expected public relative file path');
  const absolute = resolve(root, path);
  invariant(!relative(root, absolute).startsWith('..') && existsSync(absolute), `Missing or unsafe proof file: ${path}`);
  return absolute;
}
export function exactSet(actual, expected, name) {
  invariant(new Set(actual).size === actual.length, `Duplicate ${name}`);
  invariant(actual.length === expected.length && expected.every(x => actual.includes(x)), `Incomplete ${name}`);
}
export function references(values, name) {
  invariant(Array.isArray(values) && values.length > 0, `Missing ${name}`);
  values.forEach(localFile);
}
export function validateReceiptMetadata(data, expectedSurface) {
  invariant(data.schemaVersion === 1, 'Invalid evidence receipt version');
  invariant(/^[a-f0-9]{40}$/.test(data.sourceCommit), 'Missing source binding');
  invariant(/^[a-f0-9]{64}$/.test(data.artifactSha256), 'Missing built artifact binding');
  invariant(typeof data.surface === 'string' && (!expectedSurface || data.surface === expectedSurface), 'Wrong evidence surface');
  invariant(data.privacy === 'reviewed-public-safe', 'Missing reviewed privacy verdict');
  invariant(['cheap-lowlevel-headless','isolated-headless-cloud','isolated-headless-linux'].includes(data.method), 'Missing actual capture route');
  invariant(['en','yue','bilingual'].includes(data.language) && ['light','dark'].includes(data.theme), 'Missing localized theme tuple');
  invariant([1,1.25,1.5,2].includes(data.scale), 'Invalid display scale');
  invariant(Number.isInteger(data.viewport?.width) && data.viewport.width > 0 && Number.isInteger(data.viewport?.height) && data.viewport.height > 0, 'Missing viewport');
  invariant(Array.isArray(data.files) && data.files.length > 0, 'Missing evidence files');
  return data;
}
export function receipt(path, expectedSurface) {
  const data = validateReceiptMetadata(JSON.parse(readFileSync(localFile(path), 'utf8')), expectedSurface);
  for (const file of data.files) {
    invariant(/^[a-f0-9]{64}$/.test(file.sha256), 'Missing evidence hash');
    const actual = createHash('sha256').update(readFileSync(localFile(file.path))).digest('hex');
    invariant(actual === file.sha256, 'Stale evidence bytes');
  }
  return data;
}
