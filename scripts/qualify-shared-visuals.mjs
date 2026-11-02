// Independent headed qualification; only loopback preview and a new disposable profile.
// Usage: node scripts/qualify-shared-visuals.mjs [http://127.0.0.1:5180]
import {spawn} from 'node:child_process';
import {mkdtemp,readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {inflateSync} from 'node:zlib';
const origin=process.argv[2]||'http://127.0.0.1:5180';
if(new URL(origin).hostname!=='127.0.0.1')throw Error('Loopback only');
const out=process.argv[3]?path.resolve(process.argv[3]):path.resolve(import.meta.dirname,'../review/main-finish/visual');
await mkdir(out,{recursive:true});
const profile=await mkdtemp(path.join(os.tmpdir(),'pf-shared-visual-'));
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--remote-debugging-port=0','--user-data-dir='+profile,'--no-first-run','--no-default-browser-check','--disable-background-networking','--force-color-profile=srgb','--window-size=1440,1000','about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
let socket;
const results={origin,headed:true,freshProfile:true,cold:[],pages:[],negative:null};
function decodePng(buf){
 let pos=8,width,height,type,depth;const chunks=[];
 while(pos<buf.length){const n=buf.readUInt32BE(pos),tag=buf.toString('ascii',pos+4,pos+8),d=buf.subarray(pos+8,pos+8+n);if(tag==='IHDR'){width=d.readUInt32BE(0);height=d.readUInt32BE(4);depth=d[8];type=d[9];if(d[12])throw Error('Interlaced PNG')}if(tag==='IDAT')chunks.push(d);pos+=n+12}
 if(depth!==8||![2,6].includes(type))throw Error('Unsupported PNG');
 const bpp=type===6?4:3,stride=width*bpp,raw=inflateSync(Buffer.concat(chunks)),data=Buffer.alloc(height*stride);
 for(let y=0;y<height;y++)for(let x=0;x<stride;x++){const f=raw[y*(stride+1)],v=raw[y*(stride+1)+x+1],a=x>=bpp?data[y*stride+x-bpp]:0,b=y?data[(y-1)*stride+x]:0,c=y&&x>=bpp?data[(y-1)*stride+x-bpp]:0,p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);data[y*stride+x]=(v+[0,a,b,(a+b)>>1,pa<=pb&&pa<=pc?a:pb<=pc?b:c][f])&255}
 return {width,height,bpp,data};
}
const lum=c=>c.map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((v,n,i)=>v+n*[.2126,.7152,.0722][i],0);
const ratio=(a,b)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
try{
 let port;for(let i=0;i<100;i++){try{port=(await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split(/\r?\n/)[0];break}catch{await pause(100)}}
 if(!port)throw Error('Disposable Chrome startup blocked');
 const tabs=await fetch(`http://127.0.0.1:${port}/json/list`).then(r=>r.json());
 socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{socket.onopen=r;socket.onerror=j});
 let id=0;const pending=new Map(),responses=new Map(),failures=[];
 const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id,timer=setTimeout(()=>{pending.delete(n);reject(Error('CDP timeout '+method))},20000);pending.set(n,{resolve,reject,timer});socket.send(JSON.stringify({id:n,method,params}))});
 socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(m.error.message)):p.resolve(m.result)}}else if(m.method==='Network.responseReceived')responses.set(m.params.response.url,{status:m.params.response.status,mime:m.params.response.mimeType,cache:!!m.params.response.fromDiskCache});else if(m.method==='Network.loadingFailed')failures.push(m.params.errorText)};
 const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
 await send('Page.enable');await send('Network.enable');await send('Network.setCacheDisabled',{cacheDisabled:true});
 await send('Network.setBlockedURLs',{urls:['https://*','http://localhost:*']});
 await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
 async function navigate(route,width){
  await send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:width<700});
  await send('Page.navigate',{url:'about:blank'});responses.clear();failures.length=0;await send('Network.clearBrowserCache');
  await send('Page.navigate',{url:origin+route});
  let ready=false;for(let i=0;i<120;i++){if(await evaluate(`location.pathname===${JSON.stringify(route)}&&document.readyState==='complete'`)){ready=true;break}await pause(50)}
  if(!ready)throw Error('Navigation timed out '+route);
  await evaluate('document.fonts.ready.then(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))))');
 }
 async function guard(){
  const r=await evaluate(`(()=>({sheets:[...document.querySelectorAll('link[rel=stylesheet]')].map(l=>{let rules=0;try{rules=l.sheet?.cssRules.length||0}catch{}return {url:l.href,loaded:!!l.sheet,rules}}),font:getComputedStyle(document.body).fontFamily,bg:getComputedStyle(document.body).backgroundColor,h1:document.querySelector('h1')?getComputedStyle(document.querySelector('h1')).fontSize:'0',opening:document.querySelector('.home-opening')?getComputedStyle(document.querySelector('.home-opening')).display:null}))()`);
  r.sheets=r.sheets.map(s=>({...s,network:responses.get(s.url)||null}));
  r.pass=r.sheets.length>=5&&r.sheets.every(s=>s.loaded&&s.rules>0&&s.network?.status===200&&s.network.mime==='text/css'&&!s.network.cache)&&r.font.includes('Archivo')&&r.bg!=='rgba(0, 0, 0, 0)'&&parseFloat(r.h1)>30&&r.opening==='grid';
  return r;
 }
 async function screenshot(file,png=false){const m=await send('Page.getLayoutMetrics');const r=await send('Page.captureScreenshot',{format:png?'png':'jpeg',...(png?{}:{quality:82}),captureBeyondViewport:true,clip:{x:0,y:0,width:m.cssContentSize.width,height:m.cssContentSize.height,scale:1}});const b=Buffer.from(r.data,'base64');if(file)await writeFile(path.join(out,file),b);return b}
 for(let i=1;i<=3;i++){await navigate('/',1320);const r=await guard();results.cold.push({run:i,...r});await screenshot(`home-cold-1320-${i}.jpg`);console.log('Cold',i,JSON.stringify(r))}
 await send('Network.setBlockedURLs',{urls:['https://*','*pf-home-ledger.css*']});await navigate('/',1320);const ng=await guard();results.negative={expected:'critical homepage CSS missing must fail',pass:!ng.pass,guard:ng};await screenshot('home-missing-css-negative.jpg');
 await send('Network.setBlockedURLs',{urls:['https://*']});
 const routes=[['home','/'],['products','/software/'],['proof-standard','/proof-standard/'],['proof','/proof/'],['truth-files','/truth-files/'],['about','/about/'],['support','/support/'],['roadmap','/roadmap/'],['founders','/founders/'],['404','/404.html'],['truth','/truth/']];
 for(const width of [1440,768,390])for(const [name,route]of routes){
  await navigate(route,width);
  const layout=await evaluate(`(()=>{const visible=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none'};const links=s=>[...document.querySelectorAll(s)].map(a=>({text:a.textContent.trim().replace(/\\s+/g,' '),href:a.getAttribute('href')}));return {title:document.title,width:innerWidth,scrollWidth:document.documentElement.scrollWidth,overflow:document.documentElement.scrollWidth>innerWidth+1,header:!!document.querySelector('.site-header'),footer:!!document.querySelector('footer'),nav:links('#primary-nav a'),primaryCount:document.querySelectorAll('nav[aria-label="Primary navigation"]').length,duplicateMenus:document.querySelectorAll('.top-nav,.nav-panel,.nav-toggle').length,footerLinks:links('footer a'),stations:[...document.querySelectorAll('.pf-chain-station')].map(e=>({text:e.textContent,visible:visible(e),x:e.getBoundingClientRect().x,right:e.getBoundingClientRect().right})),chain:links('.pf-route-chain a'),badHashLinks:[...document.querySelectorAll('a[href^="#"]')].filter(a=>a.hash.length>1&&!document.getElementById(decodeURIComponent(a.hash.slice(1)))).map(a=>a.hash),offenders:[...document.querySelectorAll('main *')].filter(e=>visible(e)&&e.getBoundingClientRect().right>innerWidth+1).slice(0,12).map(e=>({tag:e.tagName,class:e.className,right:e.getBoundingClientRect().right}))}})()`);
  const shot=`${name}-${width}.jpg`;await screenshot(shot);
  let menu=null;if(width<1000)menu=await evaluate(`(()=>{const b=document.querySelector('.nav-toggle');if(!b||getComputedStyle(b).display==='none')return null;b.click();const p=document.querySelector('#primary-nav'),r=p.getBoundingClientRect();const v={expanded:b.getAttribute('aria-expanded'),visible:getComputedStyle(p).display!=='none'&&r.height>0,within:r.right<=innerWidth+1};b.click();return v})()`);
  const entry={name,route,width,shot,layout,menu};results.pages.push(entry);
  if(width!==768){
   const texts=await evaluate(`(()=>{const out=[],w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){if(!n.textContent.trim()||!n.parentElement||n.parentElement.closest('script,style,svg,dialog,[hidden]'))continue;const el=n.parentElement,s=getComputedStyle(el);let hidden=false;for(let p=el;p;p=p.parentElement){if(p.tagName==='DETAILS'&&!p.open&&!p.querySelector(':scope>summary')?.contains(el))hidden=true;const c=getComputedStyle(p);if(c.display==='none'||c.visibility==='hidden')hidden=true}if(hidden)continue;const range=document.createRange();range.selectNodeContents(n);let complex=[],surface='solid';for(let p=el;p;p=p.parentElement){const c=getComputedStyle(p);if(+c.opacity<1||c.mixBlendMode!=='normal'||c.filter!=='none'||c.backdropFilter!=='none')complex.push(p.tagName+'.'+p.className);if(c.backgroundImage!=='none')surface=c.backgroundImage.includes('gradient(')?'gradient / screenshot sampled':'image / screenshot sampled'}const rgb=s.color.match(/[\\d.]+/g)?.map(Number);const size=parseFloat(s.fontSize),large=size>=24||(size>=18.66&&parseInt(s.fontWeight)>=700);for(const r of range.getClientRects()){if(r.width<1||r.height<1||r.x<0||r.right>innerWidth+1)continue;out.push({text:n.textContent.trim().slice(0,100),selector:el.tagName.toLowerCase()+(el.id?'#'+el.id:'.'+String(el.className).trim().replace(/\\s+/g,'.')),color:s.color,rgb,large,surface,complex,x:r.x,y:r.y+scrollY,w:r.width,h:r.height})}}return out})()`);
   await evaluate(`(()=>{const s=document.createElement('style');s.id='visual-background-audit';s.textContent='* { -webkit-text-fill-color:transparent!important;text-shadow:none!important;caret-color:transparent!important }';document.head.append(s)})()`);
   const bg=decodePng(await screenshot(null,true));
   await evaluate(`document.querySelector('#visual-background-audit').remove()`);
   const measured=texts.map(t=>{
    if(t.complex.length||!t.rgb||t.rgb.length<3)return {...t,status:'unmeasured effects'};
    let minimum=100,bgAt=null;const alpha=t.rgb[3]??1;
    // All pixels in each text fragment's rectangle, not an assumed flat gradient.
    for(let y=Math.max(0,Math.floor(t.y));y<Math.min(bg.height,Math.ceil(t.y+t.h));y++)for(let x=Math.max(0,Math.floor(t.x));x<Math.min(bg.width,Math.ceil(t.x+t.w));x++){const p=(y*bg.width+x)*bg.bpp,b=[...bg.data.subarray(p,p+3)],fg=b.map((v,i)=>t.rgb[i]*alpha+v*(1-alpha)),r=ratio(fg,b);if(r<minimum){minimum=r;bgAt=b}}
    return {...t,minimum,bgAt,threshold:t.large?3:4.5,status:minimum>=(t.large?3:4.5)?'pass':'review'};
   });
   entry.contrast={total:measured.length,pass:measured.filter(t=>t.status==='pass').length,review:measured.filter(t=>t.status==='review').length,unmeasured:measured.filter(t=>t.status.startsWith('unmeasured')).length,solid:measured.filter(t=>t.surface==='solid').length,gradientOrImage:measured.filter(t=>t.surface!=='solid').length};
   await writeFile(path.join(out,`${name}-${width}-contrast.json`),JSON.stringify(measured,null,2));
  }
  console.log(name,width,'overflow',layout.overflow,'contrast',entry.contrast||'tablet screenshot only');
 }
 await writeFile(path.join(out,'qualification.json'),JSON.stringify(results,null,2));
 const bad=results.pages.filter(p=>p.layout.primaryCount!==1||p.layout.nav.length!==6||p.layout.duplicateMenus!==0||p.layout.overflow||!p.layout.header||!p.layout.footer||p.layout.stations.length!==6||p.layout.stations.some(s=>!s.visible||s.x<0||s.right>p.width+1)||p.menu&&(!p.menu.visible||!p.menu.within||p.menu.expanded!=='true'));
 const contrast=results.pages.filter(p=>p.contrast).reduce((a,p)=>{for(const k of Object.keys(a))a[k]+=p.contrast[k]||0;return a},{total:0,pass:0,review:0,unmeasured:0,solid:0,gradientOrImage:0});
 const consistent=results.pages.every(p=>JSON.stringify(p.layout.nav)===JSON.stringify(results.pages[0].layout.nav)&&JSON.stringify(p.layout.footerLinks)===JSON.stringify(results.pages[0].layout.footerLinks));
 await writeFile(path.join(out,'visual qualification.md'),`# Shared-page visual qualification\n\nIsolated headed Chrome, fresh disposable profile; preview ${origin}; cache disabled; no build, owner browser, deployment, or source edits. Reduced motion; DPR 1; 1000px viewport height.\n\n- Captured 11 routes at 1440 / 768 / 390px: 33 full-page JPGs.\n- Cold homepage 1320px: ${results.cold.filter(r=>r.pass).length}/3 guards pass; stylesheet status, MIME, CSSOM and rendered-style assertions recorded in qualification.json. Missing-critical-CSS negative control: ${results.negative.pass?'correctly fails guard':'FAILED TO DETECT'}.\n- Layout/header/footer/stations/mobile-menu checks: ${bad.length?bad.map(p=>p.name+' '+p.width).join(', '):'all 33 pass'}.\n- Primary-navigation/footer link sets consistent: ${consistent}.\n- Chain 01–06 links name their destinations: Home → /; Products → /software/; Proof → /proof-standard/; Truth Files → /truth-files/; About → /about/; Support → /support/. These are page-navigation stations, not proof-stage certification. Actual links and hash-target findings are in qualification.json.\n- Rendered contrast (1440 and 390px): ${contrast.total} text fragments; ${contrast.pass} conservative passes; ${contrast.review} require review; ${contrast.unmeasured} effects not measured. Solid surfaces: ${contrast.solid}; gradient/image surfaces: ${contrast.gradientOrImage}. Per-page JSON contains text, colors, bounds, sampled worst ratio, AA threshold and exclusions.\n\n## Method and limits\n\nFor contrast, hide text fill only (preserving layout/currentColor), capture the actual background pixels, and compare computed foreground color (including its alpha) against every pixel in each text fragment rectangle. This handles gradients/textures as screenshot measurements rather than flat-background claims; bbox-wide minima are conservative and review results can include adjacent borders/art. CSS opacity/filter/blend/backdrop effects are explicitly unmeasured. Antialiased edge pixels are not treated as foreground colors; WCAG uses the intended foreground. Not an exhaustive interaction/state, imagery-text, SVG, pseudo-element, focus/hover or accessibility certification. Tablet has screenshots/layout checks, not contrast measurements. Screenshots require human inspection; automated geometry does not prove aesthetic quality.\n`);
 console.log(JSON.stringify({bad:bad.map(p=>[p.name,p.width]),consistent,contrast,cold:results.cold.map(r=>r.pass),negative:results.negative.pass}));
 if(bad.length||!consistent||results.cold.some(r=>!r.pass)||!results.negative.pass)process.exitCode=1;
}finally{socket?.close();chrome.kill()}
