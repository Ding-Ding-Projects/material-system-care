export const MAX_BYTES = 256 * 1024;
export const MAX_ENTRIES = 4096;
export const MAX_KEY_CODE_POINTS = 160;
export const MAX_VALUE_CODE_POINTS = 1000;
const UNSAFE = new Set(['__proto__', 'prototype', 'constructor']);
const CONTROL = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/u;

function countCodePoints(value) { return Array.from(value).length; }

// JSON.parse intentionally keeps the last duplicate. Reject them before parsing instead.
export function assertNoDuplicateKeys(json) {
  let index = 0;
  const whitespace = /\s/u;
  const string = () => {
    const start = index; if (json[index++] !== '"') throw new Error('Malformed JSON.');
    while (index < json.length) {
      const char = json[index++];
      if (char === '"') { try { return JSON.parse(json.slice(start, index)); } catch { throw new Error('Malformed JSON string.'); } }
      if (char === '\\') {
        const escaped = json[index++];
        if (!'"\\/bfnrtu'.includes(escaped || '')) throw new Error('Malformed JSON escape.');
        if (escaped === 'u') {
          const hex = json.slice(index, index + 4);
          if (!/^[0-9a-f]{4}$/iu.test(hex)) throw new Error('Malformed JSON escape.');
          index += 4;
        }
      } else if (char < ' ') throw new Error('Malformed JSON string.');
    }
    throw new Error('Unterminated JSON string.');
  };
  const skip = () => { while (whitespace.test(json[index] || '')) index++; };
  const value = (depth) => {
    skip(); const char = json[index];
    if (char === '{') {
      if (depth >= 2) throw new Error('The vocabulary exceeds depth 2.');
      index++; const keys = new Set(); skip(); if (json[index] === '}') { index++; return; }
      for (;;) { skip(); const key = string(); if (keys.has(key)) throw new Error('Duplicate JSON key.'); keys.add(key); skip(); if (json[index++] !== ':') throw new Error('Malformed JSON.'); value(depth + 1); skip(); if (json[index] === '}') { index++; return; } if (json[index++] !== ',') throw new Error('Malformed JSON.'); }
    }
    if (char === '[') throw new Error('Arrays are not allowed.');
    if (char === '"') { string(); return; }
    const primitive = /^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/u.exec(json.slice(index));
    if (!primitive) throw new Error('Malformed JSON.'); index += primitive[0].length;
  };
  value(0); skip(); if (index !== json.length) throw new Error('Malformed JSON.');
}

export function validateVocabulary(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Root must be an object.');
  const root = Object.keys(value);
  if (root.length !== 2 || !root.includes('schemaVersion') || !root.includes('entries')) throw new Error('Root fields must be schemaVersion and entries only.');
  if (value.schemaVersion !== 1) throw new Error('Unsupported schema version.');
  const entries = value.entries;
  if (!entries || typeof entries !== 'object' || Array.isArray(entries)) throw new Error('Entries must be an object.');
  const pairs = Object.entries(entries);
  if (pairs.length > MAX_ENTRIES) throw new Error('Entry limit exceeded.');
  const output = Object.create(null);
  for (const [key, replacement] of pairs) {
    if (!key || UNSAFE.has(key) || countCodePoints(key) > MAX_KEY_CODE_POINTS) throw new Error('Invalid entry key.');
    if (typeof replacement !== 'string' || countCodePoints(replacement) > MAX_VALUE_CODE_POINTS || CONTROL.test(replacement)) throw new Error('Invalid entry value.');
    output[key] = replacement;
  }
  return { schemaVersion: 1, entries: output };
}

export function parseVocabularyBytes(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.byteLength > MAX_BYTES) throw new Error('File exceeds 256 KiB.');
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { throw new Error('File is not valid UTF-8.'); }
  assertNoDuplicateKeys(text);
  try { return validateVocabulary(JSON.parse(text)); } catch (error) { throw error instanceof Error ? error : new Error('Malformed JSON.'); }
}

export function serialiseVocabulary(vocabulary) { return JSON.stringify(validateVocabulary(vocabulary)); }
