import {readFileSync,readdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const [urlArg,rootArg]=process.argv.slice(2);
if(!urlArg||!rootArg) throw Error('Expected HTTPS home URL and built output directory');
const home=new URL(urlArg);
if(home.protocol!=='https:'||home.username||home.password||home.search||home.hash||!home.pathname.endsWith('/')) throw Error('Expected a public HTTPS directory URL');
const root=resolve(rootArg);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
function list(dir,prefix=''){
 return readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?list(join(dir,entry.name),prefix+entry.name+'/'):[prefix+entry.name]);
}
const files=list(root).sort();
const expected=files.map(path=>({path,sha256:hash(readFileSync(join(root,path)))}));
let cursor=0;const results=[];
await Promise.all(Array.from({length:6},async()=>{
 while(cursor<expected.length){
  const entry=expected[cursor++];
  try{
   const url=new URL(entry.path.split('/').map(encodeURIComponent).join('/'),home);
   const response=await fetch(url,{redirect:'error',signal:AbortSignal.timeout(15000)});
   const digest=hash(Buffer.from(await response.arrayBuffer()));
   results.push({path:entry.path,status:response.status,matched:response.ok&&digest===entry.sha256});
  }catch{results.push({path:entry.path,status:null,matched:false});}
 }
}));
results.sort((a,b)=>a.path.localeCompare(b.path));
const failures=results.filter(r=>!r.matched);
console.log(JSON.stringify({version:1,home:home.href,checkedAt:new Date().toISOString(),expectedManifestSha256:hash(JSON.stringify(expected)),filesChecked:results.length,failures},null,2));
if(failures.length)process.exitCode=1;
