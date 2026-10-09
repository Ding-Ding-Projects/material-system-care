import { strict as assert } from 'node:assert';
import { validateReceiptMetadata } from './validation.mjs';
// Synthetic metadata tests validate rejection behavior, never production evidence.
const fixture={schemaVersion:1,sourceCommit:'a'.repeat(40),artifactSha256:'b'.repeat(64),surface:'desktop.overview',privacy:'reviewed-public-safe',method:'cheap-lowlevel-headless',language:'en',theme:'light',scale:1,viewport:{width:1280,height:800},files:[{path:'synthetic.png',sha256:'c'.repeat(64)}]};
validateReceiptMetadata(fixture,'desktop.overview');
let rejected=0;
for(const key of ['schemaVersion','sourceCommit','artifactSha256','surface','privacy','method','language','theme','scale','viewport','files']){
  const changed=structuredClone(fixture);delete changed[key];assert.throws(()=>validateReceiptMetadata(changed,'desktop.overview'));rejected++;
}
for(const [key,value] of [['sourceCommit','latest'],['artifactSha256','build-ok'],['privacy','unchecked'],['method','source-preview'],['language','unknown'],['theme','unknown'],['scale',0],['viewport',{width:-1,height:800}],['files',[]]]){
  const changed=structuredClone(fixture);changed[key]=value;assert.throws(()=>validateReceiptMetadata(changed,'desktop.overview'));rejected++;
}
assert.throws(()=>validateReceiptMetadata(fixture,'website.home'));rejected++;
console.log(`PASS evidence metadata: ${rejected} negative mutations rejected; synthetic metadata is not runtime proof.`);
