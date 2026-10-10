import {marked} from 'marked';
import sanitizeHtml from 'sanitize-html';
import path from 'node:path';

export const articleRoute = file => '#/articles/' + encodeURIComponent(file);
export function resolveLocal(reference, file) {
  const own = reference.match(/^https:\/\/github\.com\/Ding-Ding-Projects\/material-system-care\/(?:blob|tree)\/main\/(.+)$/);
  if(own) return resolveLocal('./'+own[1],'README.md');
  if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(reference)) return null;
  const [raw, fragment=''] = reference.split('#');
  let decoded;
  try { decoded = decodeURIComponent(raw.split('?')[0]); } catch { return null; }
  const resolved = raw ? path.posix.normalize(path.posix.join(path.posix.dirname(file), decoded)) : file;
  if (resolved.startsWith('../') || resolved.startsWith('/') || resolved.includes('\\')) return null;
  return {file:resolved, fragment};
}
export function renderArticle(markdown, file, inventory) {
  let headingIds = new Map();
  const renderer = new marked.Renderer();
  renderer.heading = function(token) {
    const base = token.text.toLowerCase().replace(/<[^>]*>/g,'').replace(/[^\p{L}\p{N}\s_-]/gu,'').trim().replace(/\s+/g,'-') || 'section';
    const count = headingIds.get(base) || 0; headingIds.set(base,count+1);
    return `<h${token.depth} id="${base}${count?'-'+count:''}">${this.parser.parseInline(token.tokens)}</h${token.depth}>`;
  };
  return sanitizeHtml(marked.parse(markdown,{renderer,gfm:true}), {
    allowedTags:[...sanitizeHtml.defaults.allowedTags,'img','input'],
    allowedAttributes:{...sanitizeHtml.defaults.allowedAttributes,h1:['id'],h2:['id'],h3:['id'],h4:['id'],h5:['id'],h6:['id'],a:['href','title','rel'],img:['src','alt','title','loading'],input:['type','checked','disabled']},
    allowedSchemes:['https','http','mailto'], allowProtocolRelative:false,
    transformTags:{
      a:(tag,attrs)=> {
        const local=resolveLocal(attrs.href||'',file);
        if(local && inventory.has(local.file)) attrs.href=articleRoute(local.file)+(local.fragment?'?heading='+encodeURIComponent(local.fragment):'');
        else if(local && inventory.has(local.file+'/README.md')) attrs.href=articleRoute(local.file+'/README.md');
        else if(local) attrs.href='./source-files/'+local.file+(local.fragment?'#'+local.fragment:'');
        return {tagName:'a',attribs:{...attrs,rel:'noopener noreferrer'}};
      },
      img:(tag,attrs)=> { const local=resolveLocal(attrs.src||'',file); return {tagName:'img',attribs:local?{src:'./source-files/'+local.file,alt:attrs.alt||'',loading:'lazy'}:{alt:attrs.alt||''}}; },
      input:(tag,attrs)=>({tagName:'input',attribs:{type:'checkbox',disabled:'disabled',...('checked' in attrs?{checked:'checked'}:{})}})
    }
  });
}
