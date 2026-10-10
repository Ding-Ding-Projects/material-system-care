import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root=new URL('../dist/',import.meta.url);
const template=await readFile(new URL('index.html',root),'utf8');
const {articles}=JSON.parse(await readFile(new URL('articles.json',root),'utf8'));
const escape=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
await mkdir(new URL('articles/',root),{recursive:true});
const entries=[];
for(const article of articles){
 const name=createHash('sha256').update(article.path).digest('hex').slice(0,20)+'.html';
 const route='#/articles/'+encodeURIComponent(article.path);
 const html=template.replace('<head>','<head>\n<base href="../">').replace(/<title>[^<]*<\/title>/,'<title>'+escape(article.title)+' | Material System Care</title>')
   .replace(/<main class="initial-document">[\s\S]*?<\/main>/,'<main class="initial-document full-article">'+article.html+'</main>')
   .replace('<msc-site>','<msc-site data-initial-route="'+escape(route)+'">');
 await writeFile(new URL('articles/'+name,root),html);
 entries.push({path:article.path,url:'articles/'+name});
}
await writeFile(new URL('article-pages.json',root),JSON.stringify(entries));
console.log(`Prerendered ${entries.length} complete articles.`);
