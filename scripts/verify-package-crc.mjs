import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import crypto from 'node:crypto';
import {crc32,validatePackage} from './validate-package.mjs';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'material-system-care-zip-fixture-'));
const bytes=Buffer.from('synthetic native runtime payload');
const name='lib/net45/flutter_windows.dll';
fs.writeFileSync(path.join(root,'bundle-manifest.json'),JSON.stringify({schemaVersion:1,files:[{path:'flutter_windows.dll',bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')}]}));
function zip(content,entryName,wrongCRC=false){
 const encoded=Buffer.from(entryName),crc=(crc32(content)+(wrongCRC?1:0))>>>0;
 const local=Buffer.alloc(30);local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt32LE(crc,14);local.writeUInt32LE(content.length,18);local.writeUInt32LE(content.length,22);local.writeUInt16LE(encoded.length,26);
 const central=Buffer.alloc(46);central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt32LE(crc,16);central.writeUInt32LE(content.length,20);central.writeUInt32LE(content.length,24);central.writeUInt16LE(encoded.length,28);
 const end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(central.length+encoded.length,12);end.writeUInt32LE(local.length+encoded.length+content.length,16);
 return Buffer.concat([local,encoded,content,central,encoded,end]);
}
let passed=0;
for(const test of [{name:'valid',data:zip(bytes,name),accept:true},{name:'wrong-crc-intact-payload',data:zip(bytes,name,true),accept:false},{name:'changed-payload-valid-crc',data:zip(Buffer.from('different bytes'),name),accept:false},{name:'missing-payload',data:zip(bytes,'other.dll'),accept:false}]){
 const file=path.join(root,test.name+'.nupkg');fs.writeFileSync(file,test.data);let accepted=false;try{validatePackage(file,root);accepted=true;}catch(error){if(test.accept)throw error;}
 if(accepted!==test.accept)throw Error('ZIP regression mismatch: '+test.name);passed++;
}
console.log(`Package CRC and payload verification: ${passed} passed (synthetic ZIP fixtures)`);
