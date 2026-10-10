import assert from 'node:assert/strict';
import {readFileSync,realpathSync} from 'node:fs';
import {resolve,relative,isAbsolute} from 'node:path';
import {createHash} from 'node:crypto';
const [rootArg,runArg]=process.argv.slice(2);
assert(rootArg&&runArg,'Expected repository and private website run root');
const root=realpathSync(rootArg),run=realpathSync(runArg);
const bytes=(base,name)=>{const p=realpathSync(resolve(base,name));const rel=relative(base,p);assert(rel&&!rel.startsWith('..')&&!isAbsolute(rel));return readFileSync(p);};
const hash=b=>createHash('sha256').update(b).digest('hex');
const receipt=JSON.parse(bytes(root,'docs/verification/website-articles-gallery.json'));
assert.equal(receipt.version,1);assert.equal(receipt.captures.length,4);
assert.equal(receipt.articleCount,168);assert.equal(receipt.internalArticleLinksChecked,192);
assert.equal(receipt.missingArticleTargets,0);assert.equal(receipt.desktopGalleryImages,40);
assert.deepEqual(receipt.delivery.failures,[]);assert.equal(receipt.delivery.filesChecked,688);
for(const c of receipt.captures){
 assert.equal(c.source,receipt.source);assert.equal(c.interfaceLanguage,'both');assert.equal(c.bodyOverflow,false);
 for(const field of ['consoleErrors','exceptions','resourceFailures','badResponses','unexpectedRequests','unnamedControls'])assert.equal(c[field],0);
 const raw=bytes(run,c.runId+'/'+c.raw);assert.deepEqual(bytes(root,c.path),raw);assert.equal(hash(raw),c.sha256);
 assert.equal(raw.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(raw.readUInt32BE(16),c.width);assert.equal(raw.readUInt32BE(20),c.height);
 for(const [path,digest] of Object.entries(c.evidence))assert.equal(hash(bytes(run,c.runId+'/'+path)),digest);
 assert(bytes(root,'docs/features/hosting/github-pages.md').toString().includes(c.path.split('/').pop()));
}
console.log('PASS: four source-bound live website captures, retained receipt hashes and 688-file deployment verdict. Pixel review and scope limitations remain explicit.');
