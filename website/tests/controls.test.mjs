import {test} from 'node:test';
import assert from 'node:assert/strict';
import {parseVocabularyBytes, applyWording, MAX_RENDERED_WORDING_LENGTH} from '../src/wording.mjs';
const parse = text => parseVocabularyBytes(new TextEncoder().encode(text));
test('neutral versioned file validates without stored examples',()=>assert.deepEqual(Object.keys(parse('{"schemaVersion":1,"entries":{}}').entries),[]));
test('duplicate fields, unsupported versions, unsafe keys and nesting fail closed',()=>{
 for(const text of ['{"schemaVersion":1,"schemaVersion":1,"entries":{}}','{"schemaVersion":2,"entries":{}}','{"schemaVersion":1,"entries":{"constructor":""}}','{"schemaVersion":1,"entries":{"x":{}}}','{"schemaVersion":1,"entries":{},"extra":true}']) assert.throws(()=>parse(text));
});
test('byte limit and malformed UTF8 fail before cache',()=>{assert.throws(()=>parseVocabularyBytes(new Uint8Array(262145)));assert.throws(()=>parseVocabularyBytes(new Uint8Array([255])));});
import {Worker as NodeWorker} from 'node:worker_threads';
import {matchInWorker} from '../src/search.mjs';
class BrowserWorker {
 constructor(url){this.worker=new NodeWorker(`const {parentPort}=require('node:worker_threads');global.self={postMessage:value=>parentPort.postMessage(value)};import(${JSON.stringify(url.href)}).then(()=>parentPort.on('message',data=>self.onmessage({data})));`,{eval:true});this.worker.on('message',data=>this.onmessage?.({data}));this.worker.on('error',error=>this.onerror?.(error));}
 postMessage(data){this.worker.postMessage(data);}
 terminate(){void this.worker.terminate();}
}
globalThis.Worker=BrowserWorker;
test('real disposable regex worker handles Unicode, invalid syntax and zero width',async()=>{
 assert.deepEqual(await matchInWorker('^\\p{L}+$','u',['香港','123'],1000),[0]);
 assert.deepEqual(await matchInWorker('^','u',['one','two'],1000),[0,1]);
 await assert.rejects(matchInWorker('(','u',['one'],1000));
});
test('adversarial backtracking is terminated and size limits reject before evaluation',async()=>{
 await assert.rejects(matchInWorker('(a+)+$','u',['a'.repeat(4000)+'!'],80),/deadline/);
 await assert.rejects(matchInWorker('a'.repeat(257),'u',[]),/limits/);
 await assert.rejects(matchInWorker('a','uu',[]),/limits/);
});

test('wording never cascades into inserted values',()=>{
 const entries=parse(JSON.stringify({schemaVersion:1,entries:{Overview:'x'.repeat(1000),x:'y'.repeat(1000)}})).entries;
 assert.equal(applyWording('Overview',entries),'x'.repeat(1000));
});
test('wording prefers the longest original match and handles multiple matches',()=>{
 assert.equal(applyWording('cart cat cart',{cat:'pet',cart:'vehicle',car:'short'}),'vehicle pet vehicle');
 assert.equal(applyWording('aa aa',{aa:'a',a:'z'}),'a a');
 assert.equal(applyWording('香港香港',{香港:'Harbour'}),'HarbourHarbour');
 assert.equal(applyWording('remove keep',{remove:''}),' keep');
});
test('oversized transformed text falls back atomically to original text',()=>{
 const original='a'.repeat(17);
 assert.equal(applyWording(original,{a:'x'.repeat(1000)}),original);
 assert.equal(applyWording('ab',{a:'1234',b:'5678'},8),'12345678');
 assert.equal(applyWording('ab',{a:'1234',b:'56789'},8),'ab');
 assert.equal(MAX_RENDERED_WORDING_LENGTH,16384);
});
