import { readFile, mkdir, writeFile } from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {renderArticle} from './articles.mjs';
const root = new URL('../../', import.meta.url);
const ledgerPath = new URL('contracts/capabilities.json', root);
const publicRoot = new URL('../public/', import.meta.url);
await mkdir(publicRoot, { recursive: true });
let ledger;
try { ledger = JSON.parse(await readFile(ledgerPath, 'utf8')); }
catch { throw new Error('The reviewed capability ledger must exist before the website builds.'); }
await writeFile(new URL('coverage.json', publicRoot), JSON.stringify(ledger));
const tracked = execFileSync('git',['ls-files','-z'],{cwd:fileURLToPath(root),encoding:'utf8'}).split('\0').filter(Boolean);
const documents = tracked.filter(p=>p.endsWith('.md') && !p.startsWith('.github/') && p!=='AGENTS.md');
const inventory = new Set(documents);
const articles=[];
for(const file of documents){
  const markdown=await readFile(new URL(file,root),'utf8');
  const title=markdown.match(/^#\s+(.+)$/m)?.[1] || file;
  articles.push({path:file,title,html:renderArticle(markdown,file,inventory),text:markdown});
}
await writeFile(new URL('articles.json',publicRoot),JSON.stringify({version:1,articles}));
const referencedFiles=new Set();
for(const article of articles) for(const match of article.html.matchAll(/(?:href|src)="\.\/source-files\/([^"#]+)(?:#[^"]*)?"/g)) {
  const file=match[1].replaceAll('&amp;','&');
  if(!tracked.includes(file)) throw Error('Article references an unpublished file: '+file);
  referencedFiles.add(file);
}
// Copy only tracked public documentation assets. No private build or capture receipts.
for(const file of new Set([...referencedFiles,...tracked.filter(p=>/^(docs|contracts|design)\//.test(p) && /\.(png|jpg|jpeg|svg|json|md)$/i.test(p))])){
  const destination=new URL('source-files/'+file,publicRoot);
  await mkdir(new URL('.',destination),{recursive:true});
  await writeFile(destination,await readFile(new URL(file,root)));
}
const gallery=JSON.parse(await readFile(new URL('docs/captures/gallery.json',root),'utf8'));
if(gallery.screenshots.length!==40 || gallery.screenshots.some(s=>s.language!=='both')) throw Error('Expected forty reviewed bilingual screenshots.');
await writeFile(new URL('gallery.json',publicRoot),JSON.stringify(gallery));
for(const shot of gallery.screenshots){
  const destination=new URL(shot.webPath,publicRoot);
  await mkdir(new URL('.',destination),{recursive:true});
  await writeFile(destination,await readFile(new URL(shot.path,root)));
}
