import {LitElement,html,nothing} from 'lit';
import {unsafeHTML} from 'lit/directives/unsafe-html.js';

type Pair=readonly [string,string];
class EvidenceReader extends LitElement {
  static properties={mode:{type:String},translate:{attribute:false},items:{state:true},matches:{state:true},state:{state:true},selected:{state:true},theme:{state:true}};
  mode='articles'; translate=(p:Pair)=>p.join(' · ');items:any[]=[];matches:number[]=[];state='loading';selected='';theme='all';
  createRenderRoot(){return this;}
  private hash=()=>{const value=location.hash.split('/').slice(2).join('/');try{this.selected=decodeURIComponent(value.split('?')[0]);}catch{this.selected='';}this.requestUpdate();};
  connectedCallback(){super.connectedCallback();window.addEventListener('hashchange',this.hash);this.hash();void this.load();}
  disconnectedCallback(){window.removeEventListener('hashchange',this.hash);super.disconnectedCallback();}
  async load(){try{const response=await fetch(`${import.meta.env.BASE_URL}${this.mode}.json`);if(!response.ok)throw Error();const data=await response.json();this.items=this.mode==='gallery'?data.screenshots:data.articles;if(!Array.isArray(this.items))throw Error();this.matches=this.items.map((_,i)=>i);this.state='ready';}catch{this.state='unavailable';}}
  protected updated(){const match=location.hash.match(/\?heading=(.+)$/);if(match&&this.selected){try{this.querySelector('[id="'+CSS.escape(decodeURIComponent(match[1]))+'"]')?.scrollIntoView();}catch{}}}
  render(){const t=this.translate;const gallery=this.mode==='gallery';const article=!gallery?this.items.find(a=>a.path===this.selected):null;
    return html`<section class="document-heading"><h1>${t(gallery?['Bilingual screenshot gallery','雙語畫面圖庫']:['Complete documentation','完整文件'])}</h1><p>${t(gallery?['Reviewed views from real desktop builds, with per-image source and capture-time evidence.','已檢查嘅實際桌面建置畫面，每張保留來源同擷取時間證據。']:['Read the full published articles here. Internal article links stay on this website. Source wording is preserved.','在此閱讀完整已公開文章，內部文章連結留在本網站，內容保留來源原文。'])}</p></section>
    ${this.state!=='ready'?html`<p role="status">${t(this.state==='loading'?['Loading…','載入中…']:['Content is unavailable. Retry loading.','未能載入內容，請重試。'])}</p><md-outlined-button @click=${()=>this.load()}>${t(['Retry','重試'])}</md-outlined-button>`:nothing}
    ${gallery?html`<p>${t(['Each view proves only its stated scope, not complete interaction or physical display scaling. Earlier views have no verified capture time. Content outside the viewport is not shown.','每張畫面只證明所列範圍，並非完整操作或實體顯示縮放證明。較早畫面沒有已核實擷取時間，視窗以外內容亦未有顯示。'])}</p>`:nothing}
    ${article?html`<md-outlined-button href="#/articles">${t(['All articles','全部文章'])}</md-outlined-button><p class="fine">${article.path}</p><article class="full-article">${unsafeHTML(article.html)}</article>`:html`
    <msc-local-search .translate=${t} .items=${this.items.map(a=>gallery?[...a.title,a.theme,a.width,a.height,a.textScale].join(' '):a.title+' '+a.path+' '+a.text.slice(0,3000))} @matches=${(e:CustomEvent)=>this.matches=e.detail}></msc-local-search>
    ${!gallery&&this.selected?html`<p role="status">${t(['That article was not found. Choose an article below.','找不到該文章，請在下方選擇。'])}</p>`:nothing}
    <p role="status">${this.matches.length} / ${this.items.length}</p>
    <div class=${gallery?'evidence-gallery':'article-index'}>${this.matches.map(i=>{const a=this.items[i];return gallery?html`<figure><a href=${'./'+a.webPath}><img loading="lazy" src=${'./'+a.webPath} width=${a.width} height=${a.height} alt=${a.title.join(' · ')+' · '+a.theme+' · '+a.width+'×'+a.height+' · '+a.textScale+'×'}></a><figcaption><strong>${a.title.join(' · ')}</strong><p>${a.theme==='dark'?t(['Dark','深色']):t(['Light','淺色'])} · ${a.width} × ${a.height} · ${t(['Text','文字'])} ${a.textScale}×</p><p>${t(['Source','來源'])}: ${a.sourceCommit?.slice(0,12) ?? t(['Unavailable','未能提供'])}</p><p>${t(['Captured at UTC','擷取時間（UTC）'])}: ${a.capturedAt ?? t(['Unavailable','未能提供'])}</p><md-text-button href=${'./'+a.webPath}>${t(['Open original image','開啟原圖'])}</md-text-button></figcaption></figure>`:html`<md-text-button href=${'#/articles/'+encodeURIComponent(a.path)}>${a.title}<span class="article-path">${a.path}</span></md-text-button>`;})}</div>`}`;
  }
}
customElements.define('msc-evidence-reader',EvidenceReader);
