import assert from 'node:assert/strict';
import {readFileSync,realpathSync} from 'node:fs';
import {resolve,relative,isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
const [rootArg,runArg]=process.argv.slice(2);
assert(rootArg&&runArg,'Expected repository and private capture root');
const root=realpathSync(rootArg),run=realpathSync(runArg);
const bytes=(base,name)=>{const p=realpathSync(resolve(base,name));const r=relative(base,p);assert(r&&!r.startsWith('..')&&!isAbsolute(r));return readFileSync(p);};
const hash=b=>createHash('sha256').update(b).digest('hex');
const manifest=JSON.parse(bytes(root,'docs/captures/gallery.json'));
assert.equal(manifest.version,1);assert.equal(manifest.screenshots.length,40);assert.equal(manifest.runs.length,20);
assert.equal(manifest.capturedAt,null);assert.deepEqual(manifest.privacy,{pixelsInspected:true,noHostRecordsCollected:true,visibleDesktopUntouched:true});
const tuples=new Set();
for(const record of manifest.runs) for(const [name,digest] of Object.entries(record.evidence)) assert.equal(hash(bytes(run,record.id+'/'+name)),digest,record.id+'/'+name);
for(const shot of manifest.screenshots){
 assert.equal(shot.language,'both');assert.equal(shot.state,'idle');assert.equal(shot.reducedMotionRequested,true);
 assert(['light','dark'].includes(shot.theme));assert([1,2].includes(shot.textScale));
 assert(['800x600','1280x900'].includes(shot.width+'x'+shot.height));
 const tuple=[shot.screen,shot.theme,shot.textScale,shot.width,shot.height].join('/');assert(!tuples.has(tuple));tuples.add(tuple);
 const published=bytes(root,shot.path),raw=bytes(run,shot.runId+'/'+shot.raw);
 assert.deepEqual(published,raw);assert.equal(hash(raw),shot.sha256);assert.equal(raw.length,shot.bytes);
 assert.equal(raw.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(raw.readUInt32BE(16),shot.width);assert.equal(raw.readUInt32BE(20),shot.height);
 assert(bytes(root,'SCREENSHOTS.md').toString().includes(shot.path));
}
console.log('PASS: 40 bilingual gallery images, dimensions, raw-byte identity and 20 lifecycle receipt sets. Pixel review is declared separately.');
