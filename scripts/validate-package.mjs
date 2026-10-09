import fs from 'node:fs';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const table=Array.from({length:256},(_,n)=>{let c=n;for(let k=0;k<8;k++)c=(c>>>1)^((c&1)?0xedb88320:0);return c>>>0;});
export function crc32(bytes){let c=0xffffffff;for(const b of bytes)c=(c>>>8)^table[(c^b)&255];return(c^0xffffffff)>>>0;}
export function validatePackage(archivePath,payload,source,version){
 const archive=fs.readFileSync(archivePath);let end=-1;
 for(let n=archive.length-22;n>=Math.max(0,archive.length-65557);n--)if(archive.readUInt32LE(n)===0x06054b50){end=n;break;}
 if(end<0)throw Error('ZIP end record is missing');
 const count=archive.readUInt16LE(end+10);let offset=archive.readUInt32LE(end+16);
 if(count===65535 || offset===0xffffffff)throw Error('ZIP64 packages are not supported by this bounded validator');
 const manifest=JSON.parse(fs.readFileSync(path.join(payload,'bundle-manifest.json'),'utf8'));
 const expected=new Map(manifest.files.map(file=>['lib/net45/'+file.path,file]));const found=new Set();const names=new Set();const receipts=new Map();
 for(let n=0;n<count;n++){
  if(offset+46>archive.length || archive.readUInt32LE(offset)!==0x02014b50)throw Error('Invalid ZIP central directory');
  const flags=archive.readUInt16LE(offset+8),method=archive.readUInt16LE(offset+10),crc=archive.readUInt32LE(offset+16),compressed=archive.readUInt32LE(offset+20),size=archive.readUInt32LE(offset+24),nameLength=archive.readUInt16LE(offset+28),extra=archive.readUInt16LE(offset+30),comment=archive.readUInt16LE(offset+32),local=archive.readUInt32LE(offset+42);
  const name=archive.toString('utf8',offset+46,offset+46+nameLength).replaceAll('\\','/');offset+=46+nameLength+extra+comment;
  if(flags&1 || names.has(name) || name.startsWith('/') || name.split('/').includes('..'))throw Error('Encrypted, duplicate, or unsafe ZIP entry: '+name);names.add(name);
  if(local+30>archive.length || archive.readUInt32LE(local)!==0x04034b50)throw Error('Invalid ZIP local header: '+name);
  const start=local+30+archive.readUInt16LE(local+26)+archive.readUInt16LE(local+28);
  if(start+compressed>archive.length || size>512*1024*1024)throw Error('ZIP entry exceeds bounded size: '+name);
  const data=archive.subarray(start,start+compressed);
  const bytes=method===0?data:method===8?zlib.inflateRawSync(data,{maxOutputLength:Math.max(1,size)}):null;
  if(!bytes || bytes.length!==size || crc32(bytes)!==crc)throw Error('ZIP CRC or length mismatch: '+name);
  const localCrc=archive.readUInt32LE(local+14);if(!(flags&8) && localCrc!==crc)throw Error('ZIP header CRC disagreement: '+name);
  const file=expected.get(name);
  if(file){if(bytes.length!==file.bytes || crypto.createHash('sha256').update(bytes).digest('hex')!==file.sha256)throw Error('Package payload differs from bundle manifest: '+name);found.add(name);}
  if(name==='lib/net45/build-receipt.json' || name==='lib/net45/engine/build-receipt.json')receipts.set(name,JSON.parse(bytes.toString('utf8')));
 }
 for(const name of expected.keys())if(!found.has(name))throw Error('Package omits bundle payload: '+name);
 if(source || version)for(const name of ['lib/net45/build-receipt.json','lib/net45/engine/build-receipt.json']){const receipt=receipts.get(name);if(!receipt || receipt.source!==source || receipt.version!==version)throw Error('Embedded receipt binding mismatch: '+name);}
 return {entries:count,payloadFiles:found.size,sha256:crypto.createHash('sha256').update(archive).digest('hex')};
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const result=validatePackage(...process.argv.slice(2));console.log('Package ZIP integrity and payload: PASS '+JSON.stringify(result));}catch(error){console.error(error.message);process.exitCode=1;}
}
