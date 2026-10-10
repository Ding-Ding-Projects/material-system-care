import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {currentGallery} from '../scripts/current-gallery.mjs';

// Synthetic header bytes exercise manifest validation, not capture provenance.
const bytes = Buffer.alloc(33);
Buffer.from('89504e470d0a1a0a','hex').copy(bytes);
bytes.writeUInt32BE(800,16); bytes.writeUInt32BE(600,20);
const row = {id:'overview-test',active:true,language:'both',inspectionStatus:'inspected',path:'docs/captures/overview-test.png',sourceCommit:'a'.repeat(40),captureSha256:createHash('sha256').update(bytes).digest('hex'),title:['Overview','總覽'],theme:'dark',textScale:2,scale:1,reducedMotionRequested:true,viewportWidth:800,viewportHeight:600,screen:'overview',state:'idle',capturedAt:'2026-10-10T21:00:00.123456Z',captureMethod:'flutter-repaint-boundary'};
const convert = r => currentGallery(r,async () => bytes);
test('current gallery preserves reviewed provenance and emits only public fields',async()=>{
  const [result] = await convert([{...row,privateDiagnostic:'must not be emitted'}]);
  assert.equal(result.capturedAt,row.capturedAt); assert.equal(result.webPath,'gallery/overview-test.png');
  assert.equal(result.privateDiagnostic,undefined); assert.equal(result.inspectionStatus,undefined);
});
test('current gallery rejects destination traversal before reading a file',async()=>{
  for(const id of ['../outside','a/b','a\\b','a%2fb',null,42,'','a'.repeat(82)]){
    let read=false; await assert.rejects(currentGallery([{...row,id}],async()=>{read=true;return bytes;}),/identity/); assert.equal(read,false);
  }
});
test('UTC captions require exact valid UTC provenance',async()=>{
  for(const capturedAt of ['2026-10-10T17:00:00.123456-04:00','10 October 2026','2026-02-30T21:00:00.123456Z','2026-10-10T21:00:00Z']) await assert.rejects(convert([{...row,capturedAt}]),/UTC provenance/);
});
test('current gallery rejects changed bytes, dimensions and duplicate identities',async()=>{
  await assert.rejects(convert([{...row,captureSha256:'b'.repeat(64)}]),/bytes/);
  await assert.rejects(convert([{...row,viewportWidth:801}]),/bytes/);
  await assert.rejects(convert([row,row]),/identity/);
});
test('current gallery rejects unsupported paths, appearance and unreviewed state',async()=>{
  for(const change of [{path:'../capture.png'},{theme:'unknown'},{scale:2},{textScale:8},{active:false},{inspectionStatus:'pending'},{title:['only one']}]) await assert.rejects(convert([{...row,...change}]));
});
