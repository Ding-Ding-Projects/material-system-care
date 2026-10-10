import {createHash} from 'node:crypto';

export async function currentGallery(records, readPng) {
  if (!Array.isArray(records) || records.length > 256) throw Error('Invalid current gallery inventory.');
  const ids = new Set();
  const output = [];
  for (const record of records) {
    const id = record?.id;
    if (typeof id !== 'string' || !/^[a-z0-9][a-z0-9-]{2,80}$/.test(id) || ids.has(id)) throw Error('Invalid current gallery identity.');
    if (record.active !== true || record.language !== 'both' || record.inspectionStatus !== 'inspected' || record.path !== `docs/captures/${id}.png` || !/^[a-f0-9]{40}$/.test(record.sourceCommit) || !/^[a-f0-9]{64}$/.test(record.captureSha256)) throw Error('Invalid current gallery binding.');
    if (!Array.isArray(record.title) || record.title.length !== 2 || record.title.some(t => typeof t !== 'string' || !t.trim() || t.length > 256)) throw Error('Invalid bilingual gallery title.');
    if (!['light', 'dark'].includes(record.theme) || !Number.isFinite(record.textScale) || record.textScale < .8 || record.textScale > 2 || record.scale !== 1 || record.reducedMotionRequested !== true) throw Error('Invalid current gallery appearance.');
    if (![record.viewportWidth, record.viewportHeight].every(n => Number.isSafeInteger(n) && n > 0 && n <= 8192) || typeof record.screen !== 'string' || !/^[a-z0-9-]{1,80}$/.test(record.screen) || typeof record.state !== 'string' || !/^[a-z0-9-]{1,120}$/.test(record.state)) throw Error('Invalid current gallery state.');
    const time = record.capturedAt;
    if (typeof time !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z$/.test(time) || !Number.isFinite(Date.parse(time)) || new Date(time).toISOString().slice(0, 19) !== time.slice(0, 19) || record.captureMethod !== 'flutter-repaint-boundary') throw Error('Invalid current gallery UTC provenance.');
    const bytes = await readPng(record.path);
    if (bytes.length < 33 || createHash('sha256').update(bytes).digest('hex') !== record.captureSha256 || bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' || bytes.readUInt32BE(16) !== record.viewportWidth || bytes.readUInt32BE(20) !== record.viewportHeight) throw Error('Current gallery bytes differ from the reviewed record.');
    ids.add(id);
    output.push({id, title: [...record.title], language: 'both', screen: record.screen, state: record.state, theme: record.theme, textScale: record.textScale, width: record.viewportWidth, height: record.viewportHeight, reducedMotionRequested: true, path: record.path, webPath: `gallery/${id}.png`, sha256: record.captureSha256, sourceCommit: record.sourceCommit, capturedAt: time, captureMethod: record.captureMethod});
  }
  return output;
}
