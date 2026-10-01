// Current H9 qualification of actual built bytes. Local-only; never publishes.
// node scripts/capture-h9-binding.mjs [new-evidence-directory]
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';

const root = path.resolve(import.meta.dirname, '..');
const publicDir = fs.realpathSync(path.join(root, 'public'));
const outputDir = path.resolve(root, process.argv[2] || 'receipts/h9-binding-20260918/final-browser');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const within = (base, value) => {const rel=path.relative(base,value);return rel!==''&&!rel.startsWith('..')&&!path.isAbsolute(rel);};
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const report = {startedAt:new Date().toISOString(),root,outputDir,scope:'Loopback built-site qualification; no public downloads executed or deployment',checks:[],failures:[],captures:[],performance:[],accessibility:[],contrast:[],network:[],http:[]};
const viewports = [{width:1440,height:900},{width:1024,height:900},{width:430,height:932},{width:390,height:844},{width:360,height:800}];
const expected = ['cache-vault','cleanroom','forgecast','ghostlayer','lights-out','proofshot','reality-gate'];
let server,browser,profile,cdpBase,site,ownsOutput=false;
const sockets=new Set();
function check(name,passed,details=null,category='browser') {report.checks.push({name,passed:!!passed,details,category});if(!passed){report.failures.push(name);console.error(`FAIL ${name}: ${JSON.stringify(details)}`);}}
function fatal(name,error) {report.failures.push(`${name}: ${error.stack||error}`);console.error(`ERROR ${name}: ${error.stack||error}`);}
const mime={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.avif':'image/avif','.jpg':'image/jpeg','.jpeg':'image/jpeg','.json':'application/json','.woff2':'font/woff2','.ico':'image/x-icon','.xml':'application/xml','.txt':'text/plain','.mp4':'video/mp4'};
async function startServer() {
  const redirects=new Map(fs.readFileSync(path.join(publicDir,'_redirects'),'utf8').split(/\r?\n/).filter(line=>line.trim()&&!line.startsWith('#')).map(line=>{const [from,to,status]=line.trim().split(/\s+/);return [from,{to,status:Number(status)}];}));
  server=http.createServer((req,res)=>{
    try {
      if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
      const decoded=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
      if(redirects.has(decoded)){const {to,status}=redirects.get(decoded);res.writeHead(status,{Location:to}).end();return;}
      let file=path.resolve(publicDir,`.${decoded}`);
      if(file!==publicDir&&!within(publicDir,file)){res.writeHead(403).end();return;}
      if(fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');
      if(!fs.existsSync(file)){const body=fs.readFileSync(path.join(publicDir,'404.html'));res.writeHead(404,{'Content-Type':mime['.html'],'Content-Length':body.length}).end(req.method==='HEAD'?undefined:body);return;}
      const resolved=fs.realpathSync(file);
      if(!within(publicDir,resolved)||!fs.statSync(resolved).isFile()){res.writeHead(403).end();return;}
      const stat=fs.statSync(resolved),headers={'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Accept-Ranges':'bytes'};
      const range=req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);let start=0,end=stat.size-1;
      if(range){start=Number(range[1]);end=range[2]?Math.min(Number(range[2]),end):end;}
      if(start>end||start>=stat.size){res.writeHead(416,{'Content-Range':`bytes */${stat.size}`}).end();return;}
      headers['Content-Length']=end-start+1;if(range)headers['Content-Range']=`bytes ${start}-${end}/${stat.size}`;
      res.writeHead(range?206:200,headers);if(req.method==='HEAD')res.end();else fs.createReadStream(resolved,{start,end}).pipe(res);
    }catch{res.writeHead(400).end();}
  });
  server.on('connection',socket=>{sockets.add(socket);socket.on('close',()=>sockets.delete(socket));});
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
  return `http://127.0.0.1:${server.address().port}`;
}
async function startBrowser() {
  const executable=[process.env.PF_H9_BROWSER,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].filter(Boolean).find(fs.existsSync);
  if(!executable)throw new Error('No installed Chrome/Edge; set PF_H9_BROWSER.');
  profile=fs.mkdtempSync(path.join(os.tmpdir(),'pf-h9-binding-'));
  browser=spawn(executable,['--headless=new','--disable-gpu','--disable-background-networking','--disable-component-update','--disable-sync','--disable-default-apps','--no-first-run','--no-default-browser-check','--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{windowsHide:true,stdio:['ignore','ignore','pipe']});
  let error;browser.once('error',e=>{error=e;});browser.stderr.on('data',()=>{});
  for(let attempt=0;attempt<100;attempt++){
    if(error)throw error;if(browser.exitCode!==null)throw new Error(`Browser exited ${browser.exitCode}`);
    const active=path.join(profile,'DevToolsActivePort');
    if(fs.existsSync(active)){const port=Number(fs.readFileSync(active,'utf8').split(/\r?\n/)[0]);if(port>0&&port<65536){cdpBase=`http://127.0.0.1:${port}`;const version=await fetch(`${cdpBase}/json/version`).then(r=>r.json());report.browser={executable,version:version.Browser,protocol:version['Protocol-Version']};return;}}
    await sleep(100);
  }
  throw new Error('Browser failed to publish CDP port');
}
async function connect() {
  const target=await fetch(`${cdpBase}/json/new?about:blank`,{method:'PUT'}).then(r=>r.json());
  const ws=new WebSocket(target.webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
  let seq=0;const pending=new Map(),handlers=new Map();
  ws.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.id&&pending.has(m.id)){const p=pending.get(m.id);clearTimeout(p.timer);pending.delete(m.id);m.error?p.reject(new Error(m.error.message)):p.resolve(m.result);}else if(m.method)for(const cb of handlers.get(m.method)||[])cb(m.params);});
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq,timer=setTimeout(()=>{pending.delete(id);reject(new Error(`CDP timeout ${method}`));},30000);pending.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const result=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(result.exceptionDetails)throw new Error(result.exceptionDetails.exception?.description||result.exceptionDetails.text);return result.result.value;};
  const on=(method,cb)=>handlers.set(method,[...handlers.get(method)||[],cb]);
  const close=async()=>{await fetch(`${cdpBase}/json/close/${target.id}`);ws.close();for(const p of pending.values()){clearTimeout(p.timer);p.reject(new Error('Session closed'));}pending.clear();};
  return {send,evaluate,on,close};
}
const perfObserver=`(()=>{window.__h9perf={lcp:null,cls:0,longTasks:[],supported:PerformanceObserver.supportedEntryTypes};for(const type of ['largest-contentful-paint','layout-shift','longtask']){if(!PerformanceObserver.supportedEntryTypes.includes(type))continue;new PerformanceObserver(list=>{for(const e of list.getEntries()){if(type==='largest-contentful-paint')window.__h9perf.lcp={startTime:e.startTime,size:e.size,url:e.url,element:e.element?.tagName};if(type==='layout-shift'&&!e.hadRecentInput)window.__h9perf.cls+=e.value;if(type==='longtask')window.__h9perf.longTasks.push({startTime:e.startTime,duration:e.duration});}}).observe({type,buffered:true});}})();`;
async function prepare(viewport,{reduced=true,noJs=false}={}) {
  const cdp=await connect(),errors=[],networkErrors=[],external=[],resources=[];
  cdp.on('Runtime.exceptionThrown',e=>errors.push(e.exceptionDetails.exception?.description||e.exceptionDetails.text));
  cdp.on('Runtime.consoleAPICalled',e=>{if(e.type==='error')errors.push(e.args.map(a=>a.value||a.description).join(' '));});
  cdp.on('Log.entryAdded',e=>{if(e.entry.level==='error')errors.push(e.entry.text);});
  cdp.on('Network.responseReceived',e=>{resources.push({url:e.response.url,status:e.response.status,mime:e.response.mimeType});if(e.response.status>=400)networkErrors.push(`${e.response.status} ${e.response.url}`);});
  cdp.on('Network.loadingFailed',e=>{if(e.errorText!=='net::ERR_ABORTED')networkErrors.push(e.errorText);});
  cdp.on('Fetch.requestPaused',e=>{const local=e.request.url.startsWith(`${site}/`)||/^(data:|blob:|about:)/.test(e.request.url);if(!local)external.push(e.request.url);cdp.send(local?'Fetch.continueRequest':'Fetch.failRequest',local?{requestId:e.requestId}:{requestId:e.requestId,errorReason:'BlockedByClient'}).catch(err=>errors.push(err.message));});
  for(const domain of ['Page','Runtime','Log','Network'])await cdp.send(`${domain}.enable`);
  await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});await cdp.send('Fetch.enable',{patterns:[{urlPattern:'*'}]});
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:viewport.width,height:viewport.height,deviceScaleFactor:viewport.dpr||1,mobile:viewport.width<768});
  await cdp.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:reduced?'reduce':'no-preference'}]});
  await cdp.send('Page.addScriptToEvaluateOnNewDocument',{source:perfObserver});
  if(noJs)await cdp.send('Emulation.setScriptExecutionDisabled',{value:true});
  return Object.assign(cdp,{errors,networkErrors,external,resources});
}
async function navigate(cdp,route,{noJs=false}={}) {
  const nav=await cdp.send('Page.navigate',{url:`${site}${route}`});if(nav.errorText)throw new Error(nav.errorText);
  for(let i=0;i<150;i++){if(await cdp.evaluate('document.readyState === "complete"'))break;if(i===149)throw new Error('Page load timeout');await sleep(75);}
  if(!noJs)await cdp.evaluate('document.fonts.ready.then(()=>true)');await sleep(650);
}
async function settle(cdp,scroll=true) {
  await cdp.evaluate(`(async()=>{await document.fonts.ready;${scroll?`for(let y=0;y<document.documentElement.scrollHeight;y+=innerHeight*.8){scrollTo(0,y);await new Promise(r=>setTimeout(r,55));}scrollTo(0,0);`:''}const imgs=[...document.images].filter(i=>i.checkVisibility());await Promise.race([Promise.all(imgs.map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,8000))]);await new Promise(r=>setTimeout(r,300));})()`);
}
async function performance(cdp,label) {
  const data=await cdp.evaluate(`(()=>{const nav=performance.getEntriesByType('navigation')[0];return {observer:window.__h9perf,paint:performance.getEntriesByType('paint').map(e=>({name:e.name,startTime:e.startTime})),navigation:nav?{domContentLoaded:nav.domContentLoadedEventEnd,load:nav.loadEventEnd,responseStart:nav.responseStart,encodedBodySize:nav.encodedBodySize}:null,resources:performance.getEntriesByType('resource').map(e=>({name:e.name,type:e.initiatorType,duration:e.duration,transferSize:e.transferSize,encodedBodySize:e.encodedBodySize,decodedBodySize:e.decodedBodySize})),images:[...document.images].map(i=>({src:i.currentSrc,width:i.width,height:i.height,naturalWidth:i.naturalWidth,naturalHeight:i.naturalHeight,loading:i.loading}))};})()`);
  report.performance.push({label,method:'One cold-cache headless local sample; unthrottled loopback, reduced motion, initial viewport before scroll. Not Lighthouse, field CWV, or measured INP.',...data});
}
async function screenshot(cdp,file,viewport,{full=true,selector=null,state='default'}={}) {
  const metrics=await cdp.send('Page.getLayoutMetrics');let clip={x:full?0:metrics.cssVisualViewport.pageX,y:full?0:metrics.cssVisualViewport.pageY,width:viewport.width,height:full?Math.ceil(metrics.cssContentSize.height):viewport.height,scale:1};
  if(selector){const rect=await cdp.evaluate(`(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e)throw new Error('Missing closeup selector');const r=e.getBoundingClientRect(),x=Math.max(0,Math.floor(r.left+scrollX)),y=Math.max(0,Math.floor(r.top+scrollY));return {x,y,width:Math.ceil(Math.min(innerWidth,r.right+scrollX))-x,height:Math.ceil(r.bottom+scrollY)-y};})()`);Object.assign(clip,rect);}
  if(clip.height>50000||clip.height<1)throw new Error(`Invalid screenshot extent ${file}`);
  // Native CDP paint viewport expansion avoids offscreen nested-scroller culling.
  // Unlike changing the CSS viewport height, this preserves vh/media-query layout.
  // Protocol authority: ChromeDevTools/devtools-protocol browser_protocol.json.
  const metricsOverride={width:viewport.width,height:viewport.height,deviceScaleFactor:viewport.dpr||1,mobile:viewport.width<768};
  const geometryExpression=`JSON.stringify({width:innerWidth,height:innerHeight,sections:[...document.querySelectorAll('main > *, .h9-screen-scroll')].map(e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y+scrollY,width:r.width,height:r.height};})})`;
  let result,paintGeometry;
  try {
    if(full||selector){
      const before=await cdp.evaluate(geometryExpression);
      await cdp.send('Emulation.setDeviceMetricsOverride',{...metricsOverride,viewport:{x:0,y:0,width:viewport.width,height:Math.ceil(metrics.cssContentSize.height),scale:1}});
      await sleep(200);
      const after=await cdp.evaluate(geometryExpression);paintGeometry={before:JSON.parse(before),after:JSON.parse(after),unchanged:before===after};
      check(`capture ${file}: native expanded paint preserves CSS viewport and scene geometry`,before===after,paintGeometry);
    }
    result=await cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:full||!!selector,clip});
  } finally {if(full||selector)await cdp.send('Emulation.setDeviceMetricsOverride',metricsOverride);}
  const bytes=Buffer.from(result.data,'base64'),width=bytes.readUInt32BE(16),height=bytes.readUInt32BE(20);
  const expectedWidth=clip.width*(viewport.dpr||1),expectedHeight=clip.height*(viewport.dpr||1);
  if(width!==expectedWidth||height!==expectedHeight)throw new Error(`Capture extent mismatch ${file} ${width}x${height}`);
  const target=path.join(outputDir,file);fs.writeFileSync(target,bytes,{flag:'wx'});
  report.captures.push({file,state,viewport,clip,pngWidth:width,pngHeight:height,fullDocument:full&&!selector,paintMethod:full||selector?'CDP native visible-area expansion; CSS viewport and scene geometry independently unchanged':'Native viewport',paintGeometry,sha256:hash(target)});console.log(`CAPTURE ${file} ${width}x${height}`);
}
async function inspect(cdp,label) {
  const data=await cdp.evaluate(`(()=>{const visible=e=>e.checkVisibility({checkVisibilityCSS:true});const width=document.documentElement.clientWidth;const ids=[...document.querySelectorAll('[id]')].map(e=>e.id);return {width,scrollWidth:Math.max(document.documentElement.scrollWidth,document.body.scrollWidth),missingImages:[...document.images].filter(i=>visible(i)&&(!i.complete||!i.naturalWidth)).map(i=>i.currentSrc||i.src),overflowElements:[...document.querySelectorAll('main *')].filter(e=>visible(e)&&getComputedStyle(e).position!=='absolute'&&e.getBoundingClientRect().right>width+2).slice(0,15).map(e=>({tag:e.tagName,class:e.className,right:e.getBoundingClientRect().right})),h1:document.querySelectorAll('h1').length,main:document.querySelectorAll('main').length,duplicateIds:ids.filter((id,i)=>ids.indexOf(id)!==i),badLabels:[...document.querySelectorAll('[aria-labelledby]')].flatMap(e=>e.getAttribute('aria-labelledby').split(/\\s+/).filter(id=>!document.getElementById(id))),unlabelledInputs:[...document.querySelectorAll('input,select')].filter(e=>visible(e)&&!e.labels?.length&&!e.getAttribute('aria-label')&&!e.getAttribute('aria-labelledby')).map(e=>e.outerHTML),missingAlt:[...document.images].filter(i=>!i.hasAttribute('alt')).map(i=>i.src),headings:[...document.querySelectorAll('h1,h2,h3')].map(e=>({level:e.tagName,text:e.textContent.trim()})),smallTargets:[...document.querySelectorAll('main button,main input,main select,main a.button')].filter(visible).map(e=>({text:e.getAttribute('aria-label')||e.textContent.trim().slice(0,50),width:(e.matches('input[type=checkbox]')&&e.labels?.[0]?e.labels[0]:e).getBoundingClientRect().width,height:(e.matches('input[type=checkbox]')&&e.labels?.[0]?e.labels[0]:e).getBoundingClientRect().height})).filter(e=>e.width<24||e.height<24),mark:document.querySelector('link[rel="icon"]')?.href};})()`);
  check(`${label}: no horizontal document overflow`,data.scrollWidth<=data.width+1,data);
  check(`${label}: visible images decode`,data.missingImages.length===0,data.missingImages);
  check(`${label}: semantic landmarks and heading`,data.h1===1&&data.main===1,{h1:data.h1,main:data.main});
  check(`${label}: heading hierarchy has no skipped level`,data.headings.every((h,i)=>!i||Number(h.level[1])<=Number(data.headings[i-1].level[1])+1),data.headings);
  check(`${label}: labels, image alt and unique IDs`,!data.duplicateIds.length&&!data.badLabels.length&&!data.unlabelledInputs.length&&!data.missingAlt.length,data);
  check(`${label}: primary controls meet 24 CSS pixel target floor`,!data.smallTargets.length,data.smallTargets);
  report.accessibility.push({label,...data});return data;
}
async function contrast(cdp,label,selectors) {
  const readContrast = function(selectors) {
    const parse=s=>{const m=s.match(/^rgba?\(([^)]+)\)/);if(!m)return [0,0,0,0];const a=m[1].split(/[, /]+/).filter(Boolean).map(Number);return [a[0]/255,a[1]/255,a[2]/255,a[3]??1];};
    const over=(f,b)=>[f[0]*f[3]+b[0]*(1-f[3]),f[1]*f[3]+b[1]*(1-f[3]),f[2]*f[3]+b[2]*(1-f[3]),1];
    const lum=c=>{const v=c.slice(0,3).map(n=>n<=.04045?n/12.92:((n+.055)/1.055)**2.4);return v[0]*.2126+v[1]*.7152+v[2]*.0722;};
    function layers(text){let depth=0,start=0,out=[];for(let i=0;i<text.length;i++){if(text[i]==='(')depth++;if(text[i]===')')depth--;if(text[i]===','&&!depth){out.push(text.slice(start,i));start=i+1;}}out.push(text.slice(start));return out;}
    return selectors.map(selector=>{
      const e=document.querySelector(selector);if(!e||!e.checkVisibility())return {selector,missing:true};
      const chain=[];for(let p=e;p;p=p.parentElement)chain.push(p);let backgrounds=[[1,1,1,1]],opacity=1;const nonSolid=[];
      for(const p of chain.reverse()){
        const s=getComputedStyle(p);backgrounds=backgrounds.map(bg=>over(parse(s.backgroundColor),bg));opacity*=Number(s.opacity);
        if(s.backgroundImage!=='none'){
          nonSolid.push({tag:p.tagName,class:p.className,background:s.backgroundImage.slice(0,220)});
          for(const layer of layers(s.backgroundImage).reverse()){
            const stops=[...layer.matchAll(/rgba?\([^)]+\)/g)].map(m=>parse(m[0]));
            if(stops.length){const next=backgrounds.flatMap(bg=>stops.map(stop=>over(stop,bg)));backgrounds=[...new Map(next.map(bg=>[bg.map(n=>n.toFixed(4)).join(','),bg])).values()];}
          }
        }
      }
      const s=getComputedStyle(e),fg=parse(s.color);fg[3]*=opacity;
      const ratios=backgrounds.map(bg=>{const a=lum(over(fg,bg)),b=lum(bg);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);});
      const size=parseFloat(s.fontSize),weight=Number(s.fontWeight)||400,required=size>=24||(size>=18.66&&weight>=700)?3:4.5;
      return {selector,text:e.textContent.trim().slice(0,90),color:s.color,computedBackgroundCandidates:backgrounds.map(bg=>bg.slice(0,3).map(v=>Math.round(v*255))),fontSize:size,fontWeight:weight,nominalContrast:Math.min(...ratios),required,nonSolid,limitation:'Computed colors and CSS gradient stops; no raster, pseudo-element, anti-aliasing or backdrop sampling. Manual pixel review also required.'};
    });
  };
  const samples=await cdp.evaluate(`(${readContrast.toString()})(${JSON.stringify(selectors)})`);
  report.contrast.push({label,method:'Live computed text colors, ancestor alpha compositing and gradient-stop candidates. Report minimum candidate ratio; no blanket accessibility-conformance claim.',samples});
  check(`${label}: sampled text has sufficient nominal color contrast`,samples.every(s=>!s.missing&&s.nominalContrast>=s.required),samples);
}
async function key(cdp,key,code,vk,modifiers=0) {const text=key==='Enter'?'\r':key===' '?' ':undefined;await cdp.send('Input.dispatchKeyEvent',{type:text?'keyDown':'rawKeyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers,...text?{text,unmodifiedText:text}:{}});await cdp.send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers});await sleep(70);}
async function keyboard(cdp,label,mobile) {
  await cdp.evaluate('document.body.tabIndex=-1;document.body.focus();document.body.removeAttribute("tabindex");scrollTo(0,0)');
  await key(cdp,'Tab','Tab',9);
  check(`${label}: keyboard reaches visible skip link`,await cdp.evaluate(`document.activeElement.matches('.skip-link')&&document.activeElement.getBoundingClientRect().top>=0`));
  const focus=await cdp.evaluate(`(()=>{const s=getComputedStyle(document.activeElement);return {outline:s.outlineStyle,width:s.outlineWidth,boxShadow:s.boxShadow};})()`);
  check(`${label}: keyboard focus has visible treatment`,focus.outline!=='none'&&parseFloat(focus.width)>0||focus.boxShadow!=='none',focus);
  await key(cdp,'Enter','Enter',13);
  check(`${label}: skip link reaches main content`,await cdp.evaluate(`location.hash==='#main-content'`));
  if(mobile){await cdp.evaluate(`document.querySelector('.nav-toggle').focus()`);await key(cdp,'Enter','Enter',13);check(`${label}: keyboard opens mobile navigation`,await cdp.evaluate(`document.querySelector('.nav-toggle').getAttribute('aria-expanded')==='true'&&document.querySelector('.nav-panel').checkVisibility()`));await key(cdp,'Escape','Escape',27);check(`${label}: Escape closes mobile navigation`,await cdp.evaluate(`document.querySelector('.nav-toggle').getAttribute('aria-expanded')==='false'`));}
}
const cardsExpression=`[...document.querySelectorAll('#products [data-product]')].filter(e=>e.checkVisibility()).map(e=>e.dataset.product).sort()`;
async function cards(cdp,label,ids) {const result=await cdp.evaluate(`({ids:${cardsExpression},count:document.querySelector('.finder-count').textContent.trim()})`);check(`${label}: exact products and accurate count`,result.ids.join(',')===ids.join(',')&&result.count===`${ids.length} ${ids.length===1?'product':'products'}`,result);}
async function setSearch(cdp,value) {await cdp.evaluate(`(()=>{const e=document.querySelector('#product-search');e.value=${JSON.stringify(value)};e.dispatchEvent(new Event('input',{bubbles:true}));})()`);await sleep(220);}
async function catalog(cdp,viewport,{captures=true}={}) {
  const label=`software-${viewport.width}`;
  await cards(cdp,`${label}-default`,expected);
  if(captures)await screenshot(cdp,`software-${viewport.width}-default.png`,viewport);
  await cdp.evaluate(`document.querySelector('[data-intent="memory"]').click()`);await cards(cdp,`${label}-memory`,['cache-vault','cleanroom','ghostlayer']);
  await cdp.evaluate(`(()=>{const e=document.querySelector('#platform-filter');e.value='android';e.dispatchEvent(new Event('change',{bubbles:true}));})()`);await cards(cdp,`${label}-memory-android`,['cache-vault']);
  await cdp.evaluate(`document.querySelector('[data-filter-reset]').click()`);await cards(cdp,`${label}-reset`,expected);
  await cdp.evaluate(`document.querySelector('#product-search').focus()`);await cdp.send('Input.insertText',{text:'proofshot'});await sleep(220);await cards(cdp,`${label}-keyboard-search-name`,['proofshot']);
  await setSearch(cdp,'2.0.0');await cards(cdp,`${label}-exact-version-search`,['proofshot']);
  await setSearch(cdp,'vault windows');await cards(cdp,`${label}-search-tokens`,['cache-vault']);
  await setSearch(cdp,'nonexistent-zqyx');await cards(cdp,`${label}-empty`,[]);check(`${label}: empty state visible`,await cdp.evaluate(`document.querySelector('.finder-empty').checkVisibility()`));
  await cdp.evaluate(`document.querySelector('.finder-empty [data-filter-reset]').click()`);await cards(cdp,`${label}-empty-reset`,expected);
  await setSearch(cdp,'forgecast');await cdp.evaluate(`document.querySelector('#product-search-clear').click()`);await cards(cdp,`${label}-clear-search`,expected);
  await cdp.evaluate(`document.querySelector('[data-intent="build"]').focus()`);await key(cdp,'Enter','Enter',13);await cards(cdp,`${label}-keyboard-filter`,['proofshot','reality-gate']);
  check(`${label}: pressed state follows keyboard filter`,await cdp.evaluate(`document.querySelector('[data-intent="build"]').getAttribute('aria-pressed')==='true'`));
  await settle(cdp);await inspect(cdp,`${label}-filtered`);if(captures)await screenshot(cdp,`software-${viewport.width}-filtered.png`,viewport,{state:'Build & capture filter: ProofShot and Reality Gate'});
  await cdp.evaluate(`document.querySelector('[data-filter-reset]').click();document.querySelector('[data-compare="cache-vault"] input').focus()`);await key(cdp,' ','Space',32);
  check(`${label}: one selection cannot compare`,await cdp.evaluate(`document.querySelector('.compare-open').disabled`));
  await cdp.evaluate(`document.querySelector('[data-compare="proofshot"] input').click();document.querySelector('[data-compare="ghostlayer"] input').click()`);
  check(`${label}: comparison enforces three selection maximum`,await cdp.evaluate(`document.querySelectorAll('[data-compare] input:checked').length===3&&document.querySelectorAll('[data-compare] input:disabled').length===4`));
  await cdp.evaluate(`document.querySelector('[data-compare="ghostlayer"] input').click();document.querySelector('.compare-open').focus()`);await key(cdp,'Enter','Enter',13);await settle(cdp,false);
  const comparison=await cdp.evaluate(`(()=>{const e=document.querySelector('.compare-dialog');return {open:e.open,count:e.querySelectorAll('.comparison-product').length,text:e.innerText,scrollWidth:e.scrollWidth,clientWidth:e.clientWidth,focused:document.activeElement.className};})()`);
  check(`${label}: comparison shows current public releases`,comparison.open&&comparison.count===2&&comparison.text.includes('0.3.1')&&comparison.text.includes('2.0.0')&&!/no public release|in development/i.test(comparison.text),comparison);
  check(`${label}: comparison width contained`,comparison.scrollWidth<=comparison.clientWidth+1,comparison);
  check(`${label}: comparison opening focuses close control`,comparison.focused==='compare-close',comparison.focused);
  await contrast(cdp,`${label}-comparison`,['.comparison-product h3','.comparison-value','.comparison-product dt','.comparison-product dd','.compare-close']);
  for(let i=0;i<6;i++)await key(cdp,'Tab','Tab',9);
  check(`${label}: dialog traps keyboard focus`,await cdp.evaluate(`document.querySelector('.compare-dialog').contains(document.activeElement)`));
  await cdp.evaluate(`document.querySelector('.compare-dialog').scrollTop=0;document.querySelector('.compare-close').focus()`);
  if(captures)await screenshot(cdp,`software-${viewport.width}-compare.png`,viewport,{full:false,state:'Cache Vault + ProofShot comparison dialog'});
  await key(cdp,'Escape','Escape',27);
  check(`${label}: Escape closes dialog and restores opener focus`,await cdp.evaluate(`!document.querySelector('.compare-dialog').open&&document.activeElement.matches('.compare-open')`));
  await cdp.evaluate(`document.querySelector('.compare-clear').click()`);check(`${label}: clear removes selections and tray`,await cdp.evaluate(`document.querySelector('.compare-tray').hidden&&document.querySelectorAll('[data-compare] input:checked').length===0`));
  await cdp.evaluate(`document.querySelector('[data-compare="cache-vault"] input').click();document.querySelector('[data-intent="build"]').click();document.querySelector('.compare-clear').click()`);
  check(`${label}: clearing a filtered-out selection restores visible search focus`,await cdp.evaluate(`document.activeElement.id==='product-search'&&document.activeElement.checkVisibility()`));
  await cdp.evaluate(`document.querySelector('[data-filter-reset]').click()`);await cards(cdp,`${label}-final-reset`,expected);
}
async function finish(cdp,label) {check(`${label}: no console or JavaScript errors`,!cdp.errors.length,cdp.errors);check(`${label}: no failed assets/requests`,!cdp.networkErrors.length,cdp.networkErrors);check(`${label}: no third-party network requests`,!cdp.external.length,cdp.external);report.network.push({label,errors:cdp.errors,failed:cdp.networkErrors,external:cdp.external,resources:cdp.resources});}
async function bindingComposition(cdp,viewport) {
  const selectors=['.h9-hero','.h9-proof','.h9-scene-cache-vault','.h9-scene-forgecast','.h9-scene-reality','.h9-scene-ghostlayer','.h9-secondary-strip','.h9-final'];
  const scenes=await cdp.evaluate(`(${JSON.stringify(selectors)}).map(selector=>{const e=document.querySelector(selector);if(!e)return {selector,missing:true};const r=e.getBoundingClientRect();return {selector,x:r.x,y:r.y+scrollY,width:r.width,height:r.height,bottom:r.bottom+scrollY,heading:e.querySelector('h1,h2,h3')?.textContent.trim(),images:[...e.querySelectorAll('img')].map(i=>({src:i.currentSrc,width:i.getBoundingClientRect().width,height:i.getBoundingClientRect().height})),background:getComputedStyle(e).backgroundImage};})`);
  (report.composition||=[]).push({viewport,scenes,limitation:'Geometry verifies the specified composition, not creative fidelity. Every final capture must be opened and compared directly with binding references.'});
  const complete=scenes.every(s=>!s.missing&&s.width>0&&s.height>0);
  check(`binding-${viewport.width}: all eight required scenes render`,complete,scenes);
  if(!complete)return;
  const [hero,proof,cache,forge,reality,ghost,secondary,ending]=scenes;
  // VR1 order: hero → product scenes → secondary strip → proof → ending.
  check(`binding-${viewport.width}: major scenes follow hero and precede three-product strip`,Math.min(cache.y,forge.y,reality.y,ghost.y)>=hero.bottom-2&&secondary.y>=Math.max(cache.bottom,forge.bottom,reality.bottom,ghost.bottom)-2,{heroBottom:hero.bottom,secondaryTop:secondary.y});
  check(`binding-${viewport.width}: proof follows the portfolio strip and precedes the ending`,proof.y>=secondary.bottom-2&&ending.y>=proof.bottom-2,{secondaryBottom:secondary.bottom,proofTop:proof.y,endingTop:ending.y});
  const captionGeometry=await cdp.evaluate(`[...document.querySelectorAll('.h9-secondary-strip .h9-media-note')].map(e=>{const scene=e.closest('.h9-mini').getBoundingClientRect(),media=e.closest('.h9-mini-media').getBoundingClientRect(),range=document.createRange();range.selectNodeContents(e);return {text:e.innerText,sceneBottom:scene.bottom,mediaBottom:media.bottom,lines:[...range.getClientRects()].map(r=>({top:r.top,bottom:r.bottom}))};})`);
  check(`binding-${viewport.width}: all three provenance captions remain within their scene and media frame`,captionGeometry.length===3&&captionGeometry.every(c=>c.lines.length&&c.lines.every(r=>r.bottom<=Math.min(c.sceneBottom,c.mediaBottom)+1)),captionGeometry);
  const ghostBoundary=await cdp.evaluate(`document.querySelector('.h9-scene-ghostlayer .h9-scene-note').innerText.replace(/\\s+/g,' ').trim()`);
  check(`binding-${viewport.width}: GhostLayer disk-boundary phrase retains word separation`,ghostBoundary==='External editing may create temporary disk copies.',ghostBoundary);
  if(viewport.width>=1024){
    check(`binding-${viewport.width}: major scenes form authored two-by-two mosaic`,Math.abs(cache.y-forge.y)<=3&&Math.abs(reality.y-ghost.y)<=3&&reality.y>=cache.bottom-2&&cache.x<forge.x&&reality.x<ghost.x,{cache,forge,reality,ghost});
  }else{
    check(`binding-${viewport.width}: mobile scenes retain intended visual order`,forge.y>=cache.bottom-2&&reality.y>=forge.bottom-2&&ghost.y>=reality.bottom-2,{cache,forge,reality,ghost});
    const phone=forge.images.find(i=>/v030-today/.test(i.src));
    check(`binding-${viewport.width}: authentic phone retains substantial mobile scale`,phone&&phone.width>=viewport.width*.46&&phone.height>=viewport.width*.9,phone);
    const mobileType=await cdp.evaluate(`(()=>{const text=selector=>document.querySelector(selector).innerText.replace(/\\s+/g,' ').trim();const note=document.querySelector('.h9-scene-reality .h9-scene-note').getBoundingClientRect(),frame=document.querySelector('.h9-runroom-stage').getBoundingClientRect();const purpose=document.querySelector('.h9-mini-proof .h9-mini-copy > p'),media=document.querySelector('.h9-mini-proof .h9-mini-media').getBoundingClientRect();const range=document.createRange();range.selectNodeContents(purpose);return {cache:text('.h9-scene-cache-vault h2'),reality:text('.h9-scene-reality h2'),ghost:text('.h9-scene-ghostlayer h2'),runroomNoteBottom:note.bottom,runroomFrameTop:frame.top,proofPurposeLineRight:Math.max(...[...range.getClientRects()].map(r=>r.right)),proofMediaLeft:media.left};})()`);
    check(`binding-${viewport.width}: collapsed heading breaks preserve word separation`,mobileType.cache==='Keep what matters.'&&mobileType.reality==='Run. Inspect. Keep the record.'&&mobileType.ghost==='Stage the work. Make the call.',mobileType);
    check(`binding-${viewport.width}: Runroom boundary note clears inspection frame`,mobileType.runroomFrameTop-mobileType.runroomNoteBottom>=6,mobileType);
    check(`binding-${viewport.width}: ProofShot purpose text avoids authentic image overlap`,mobileType.proofPurposeLineRight<=mobileType.proofMediaLeft+2,mobileType);
  }
}
async function runPage(route,viewport) {
  const name=route==='/'?'homepage':'software',label=`${name}-${viewport.width}`,cdp=await prepare(viewport);
  try {
    await navigate(cdp,route);await performance(cdp,label);await settle(cdp);await inspect(cdp,label);
    if(viewport.width===1440)await contrast(cdp,label,name==='homepage'?['.h9-hero-copy > p','.h9-hero .button-primary','.h9-hero .h9-button-ghost','.h9-ledger-row h3','.h9-artifact-name','.h9-receipt-title > span','.h9-receipt-foot > span','.h9-receipt-stamp','.h9-mini-status']:['.card-value','.card-name','.card-availability','.h9-card-meta','.h9-product-finder label','[data-intent][aria-pressed="true"]','.compare-choice']);
    if(name==='homepage'){
      await bindingComposition(cdp,viewport);
      if([1440,390].includes(viewport.width))await screenshot(cdp,`homepage-${viewport.width}-first.png`,viewport,{full:false});
      if(viewport.width===1024){
        await cdp.evaluate(`(()=>{const r=document.querySelector('.h9-screen-scroll').getBoundingClientRect();scrollTo(0,Math.max(0,r.top+scrollY-(innerHeight-r.height)/2));})()`);await sleep(300);
        const diagnostic=await cdp.evaluate(`(()=>{const e=document.querySelector('.h9-screen-scroll'),i=e.querySelector('img'),r=e.getBoundingClientRect();return {scrollY,viewport:{width:innerWidth,height:innerHeight},region:{x:r.x,y:r.y,width:r.width,height:r.height},source:i.currentSrc,decoded:i.complete&&i.naturalWidth>0,naturalWidth:i.naturalWidth,scrollLeft:e.scrollLeft};})()`);
        report.runroom1024Diagnostic=diagnostic;
        check('homepage-1024: Runroom diagnostic is decoded and fully within native viewport',diagnostic.decoded&&diagnostic.region.y>=0&&diagnostic.region.y+diagnostic.region.height<=viewport.height,diagnostic);
        await screenshot(cdp,'runroom-1024-viewport.png',viewport,{full:false,state:'Native 1024x900 viewport, Runroom scrolled into view; diagnose offscreen full-document paint culling'});
        await cdp.evaluate('scrollTo(0,0)');await sleep(100);
      }
      await screenshot(cdp,`homepage-${viewport.width}-full.png`,viewport);
      if(viewport.width===1440)for(const [name,selector]of [['hero','.h9-hero'],['proof-artifact','.h9-proof'],['cache-vault','.h9-scene-cache-vault'],['forgecast','.h9-scene-forgecast'],['reality-gate','.h9-scene-reality'],['secondary-products','.h9-secondary-strip'],['ending','.h9-final'],['pf-mark-nav','.site-header']])await screenshot(cdp,`closeup-${name}.png`,viewport,{selector,state:`Actual built ${name} scene`});
      const focusGeometry=await cdp.evaluate(`(()=>{const e=document.querySelector('.h9-screen-scroll'),scene=e.closest('.h9-scene'),copy=scene.querySelector('.h9-scene-copy'),before={scrollLeft:scene.scrollLeft,copyX:copy.getBoundingClientRect().x};e.focus();const after={scrollLeft:scene.scrollLeft,copyX:copy.getBoundingClientRect().x};return {before,after,focused:document.activeElement===e};})()`);
      check(`${label}: focusing Runroom preserves adjacent scene copy position`,focusGeometry.focused&&Math.abs(focusGeometry.before.copyX-focusGeometry.after.copyX)<1&&focusGeometry.before.scrollLeft===focusGeometry.after.scrollLeft,focusGeometry);
      const scrollability=await cdp.evaluate(`(()=>{const e=document.querySelector('.h9-screen-scroll');return {before:e.scrollLeft,max:e.scrollWidth-e.clientWidth};})()`);
      if(scrollability.max>scrollability.before+2){await key(cdp,'ArrowRight','ArrowRight',39);await sleep(220);const after=await cdp.evaluate(`document.querySelector('.h9-screen-scroll').scrollLeft`);check(`${label}: Runroom controlled viewport scrolls with arrow key`,after>scrollability.before,{before:scrollability.before,after,max:scrollability.max});}
      check(`${label}: reduced motion reveals all editorial content`,await cdp.evaluate(`[...document.querySelectorAll('.h9-reveal')].every(e=>getComputedStyle(e).opacity==='1')`));
    }else await catalog(cdp,viewport);
    await keyboard(cdp,label,viewport.width<901);await finish(cdp,label);
  }finally{await cdp.close();}
}
async function supplementary() {
  for(const route of ['/','/software/']){
    const viewport={width:390,height:844},cdp=await prepare(viewport,{noJs:true});
    try{await navigate(cdp,route,{noJs:true});const height=await cdp.evaluate('document.documentElement.scrollHeight');for(let y=0;y<height;y+=650){await cdp.evaluate(`scrollTo(0,${y})`);await sleep(70);}await cdp.evaluate('scrollTo(0,0)');await sleep(350);const label=`${route}-no-JS`;await inspect(cdp,label);if(route==='/software/'){check(`${label}: all seven products accessible`,(await cdp.evaluate(cardsExpression)).join(',')===expected.join(','));check(`${label}: enhancement controls stay hidden`,await cdp.evaluate(`!document.querySelector('.h9-product-finder').checkVisibility()`));}else check(`${label}: all content visible without JavaScript`,await cdp.evaluate(`[...document.querySelectorAll('.h9-reveal')].every(e=>getComputedStyle(e).opacity==='1')`));await finish(cdp,label);}finally{await cdp.close();}
  }
  for(const route of ['/','/software/']){
    // 1440px display at 200% browser zoom has a 720 CSS pixel layout viewport.
    // This measures equivalent reflow; it does not claim to control browser UI zoom.
    const viewport={width:720,height:450,dpr:2},cdp=await prepare(viewport);
    try{await navigate(cdp,route);await settle(cdp);await inspect(cdp,`${route}-200-percent-equivalent-reflow`);if(route==='/software/')await cards(cdp,'software-200-percent-equivalent-reflow',expected);await finish(cdp,`${route}-200-percent-equivalent-reflow`);}finally{await cdp.close();}
  }
  await qualifyMotion();
}
const motionExpression=`(()=>{const elements=[...document.querySelectorAll('.h9-reveal')].map(e=>({class:e.className,opacity:Number(getComputedStyle(e).opacity),transitionDuration:getComputedStyle(e).transitionDuration,animations:e.getAnimations().map(a=>({playState:a.playState,pending:a.pending,currentTime:a.currentTime,duration:a.effect.getComputedTiming().duration,endTime:a.effect.getComputedTiming().endTime}))}));return {now:performance.now(),reduced:matchMedia('(prefers-reduced-motion: reduce)').matches,elements,active:elements.flatMap(e=>e.animations).filter(a=>a.pending||a.playState==='running').length,visible:elements.every(e=>e.opacity===1)};})()`;
async function qualifyMotion() {
  const cdp=await prepare({width:1440,height:900},{reduced:false});
  try{
    await navigate(cdp,'/');await settle(cdp);
    const samples=[];let stable=0;
    for(let elapsed=0;elapsed<=2500;elapsed+=50){const sample=await cdp.evaluate(motionExpression);samples.push(sample);stable=sample.visible&&sample.active===0?stable+1:0;if(stable>=2)break;await sleep(50);}
    (report.motion||=[]).push({phase:'normal completion',method:'Poll all reveal opacities and Web Animations states every50ms, bounded at2500ms, requiring two consecutive fully visible observations with no running or pending reveal animations.',samples});
    check('motion: normal mode reaches visible final content with zero pending animations',stable>=2,{samples});
    await navigate(cdp,'/');
    await cdp.evaluate(`(()=>{const r=document.querySelector('.h9-scene-ghostlayer .h9-reveal').getBoundingClientRect();scrollTo(0,r.top+scrollY-100);})()`);
    let activeSample;
    for(let elapsed=0;elapsed<=600;elapsed+=20){activeSample=await cdp.evaluate(motionExpression);if(activeSample.active>0)break;await sleep(20);}
    check('motion: normal preference produces a real finite reveal before interruption',activeSample.active>0&&activeSample.elements.flatMap(e=>e.animations).every(a=>Number.isFinite(a.endTime)&&a.duration<=350),activeSample);
    await cdp.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
    const reducedSamples=[];let reducedStable=0;
    for(let elapsed=0;elapsed<=1000;elapsed+=50){const sample=await cdp.evaluate(motionExpression);reducedSamples.push(sample);reducedStable=sample.reduced&&sample.visible&&sample.active===0?reducedStable+1:0;if(reducedStable>=2)break;await sleep(50);}
    report.motion.push({phase:'dynamic reduction during active animation',activeBeforePreferenceChange:activeSample,samples:reducedSamples});
    check('motion: dynamic reduced preference interrupts real active reveals and leaves content visible',reducedStable>=2,{samples:reducedSamples});
    await finish(cdp,'motion-switch');
  }finally{await cdp.close();}
}
async function markSheet() {
  const viewport={width:1440,height:580},cdp=await prepare(viewport);
  try{
    await navigate(cdp,'/');
    const images=(source)=>[16,24,32,64].map(size=>`<figure><img src="${site}/brand/${source}" alt="PF G at ${size} CSS pixels" width="${size}" height="${size}"><figcaption>${size} px</figcaption></figure>`).join('');
    const markup=`<!doctype html><html><head><meta charset="utf-8"><title>PF Mark G scale qualification</title><link rel="icon" type="image/svg+xml" href="${site}/brand/PF_MARK_G_MASTER.svg"><style>*{box-sizing:border-box}body{margin:0;background:#090e10;color:#eeeae1;font:16px system-ui;padding:34px 48px}h1{font:36px Georgia;margin:0 0 8px}p{color:#b9c5c6}section{display:flex;align-items:center;gap:54px;padding:24px 36px;margin-top:24px;border:1px solid #394245;height:152px}h2{font-size:16px;width:260px}figure{margin:0;min-width:80px;text-align:center}img{display:block;margin:0 auto 12px;object-fit:contain}figcaption{font:13px monospace}.light{background:#eeeae1;color:#111719}.light figcaption{color:#263236}</style></head><body><h1>PF Mark G / actual shipped SVG</h1><p>Native 16, 24, 32 and 64 CSS pixel rendering. These are brand-size checks, not redesigned logo candidates.</p><section><h2>Master · foundry black</h2>${images('PF_MARK_G_MASTER.svg')}</section><section class="light"><h2>Mono dark · receipt white</h2>${images('PF_MARK_G_MONO_DARK.svg')}</section></body></html>`;
    fs.writeFileSync(path.join(outputDir,'pf-mark-size-sheet.html'),markup.replaceAll(site,'http://127.0.0.1:8879'),{flag:'wx'});
    await cdp.evaluate(`document.open();document.write(${JSON.stringify(markup)});document.close()`);await settle(cdp,false);
    const sizes=await cdp.evaluate(`[...document.images].map(i=>({width:i.getBoundingClientRect().width,height:i.getBoundingClientRect().height,expected:Number(i.getAttribute('width')),decoded:i.complete&&i.naturalWidth>0,src:i.src}))`);
    check('identity: actual built G SVG decodes at 16/24/32/64 in both selected variants',sizes.length===8&&sizes.every(s=>s.decoded&&s.width===s.expected&&s.height===s.expected),sizes);
    await screenshot(cdp,'pf-mark-16-24-32-64.png',viewport,{full:false,state:'Native sized shipped master and mono-dark SVG evidence sheet'});
    await finish(cdp,'PF-G-size-sheet');
  }finally{await cdp.close();}
}
async function httpChecks() {
  const routes=['','software','proof-standard','proof','about','support','founders','roadmap',...expected];
  for(const route of routes){const url=`/${route}${route?'/':''}`,response=await fetch(site+url);const html=await response.text();report.http.push({url,status:response.status});check(`HTTP ${url}: rendered canonical page`,response.status===200&&html.includes(`href="https://theprooffoundry.com${url}"`)&&html.includes('GENERATED FILE - DO NOT EDIT'),{status:response.status},'http');}
  for(const route of routes.filter(Boolean))for(const ending of ['','.html']){const url=`/${route}${ending}`,response=await fetch(site+url,{redirect:'manual'});report.http.push({url,status:response.status,location:response.headers.get('location')});check(`HTTP ${url}: canonical 301`,response.status===301&&response.headers.get('location')===`/${route}/`,{status:response.status,location:response.headers.get('location')},'http');}
  const registry=await fetch(site+'/proof/index.json').then(r=>r.json());check('HTTP proof registry matches seven identities',registry.products.map(p=>p.id).sort().join(',')===expected.join(','),null,'http');
  const missing=await fetch(site+'/h9-qualification-intentionally-missing/');check('HTTP unknown route is real 404',missing.status===404,{status:missing.status},'http');
  const urls=new Set();for(const relative of ['index.html','software/index.html','proof-standard/index.html','proof/index.html']){const html=fs.readFileSync(path.join(publicDir,relative),'utf8');for(const m of html.matchAll(/(?:href|src)="(\/[^"#]*)"/g))urls.add(m[1].split('#')[0]);}
  for(const url of urls){const response=await fetch(site+url,{method:'HEAD'});report.http.push({url,status:response.status,kind:'referenced local route or asset'});check(`HTTP referenced ${url}: loads`,response.ok,{status:response.status},'http');}
}
function treeHashes(base) {return Object.fromEntries(fs.readdirSync(base,{recursive:true,withFileTypes:true}).filter(e=>e.isFile()).map(e=>{const file=path.join(e.parentPath,e.name);return [path.relative(base,file).replaceAll('\\','/'),hash(file)];}));}
try{
  if(!within(root,outputDir)||!/(?:receipts|review)[\\/]/.test(path.relative(root,outputDir)))throw new Error('Evidence output must stay in worktree receipts or review');
  if(fs.existsSync(outputDir))throw new Error(`Refusing to overwrite prior evidence: ${outputDir}`);
  fs.mkdirSync(outputDir,{recursive:true});ownsOutput=true;
  report.sourceHashes=Object.fromEntries(['index.html','software.html','site-manifest.json','h9-homepage.css','h9-homepage.js','h9-software.css','h9-software.js','experience.js','site.js','scripts/build-site.ps1','scripts/capture-h9-binding.mjs','brand/PF_MARK_G_MASTER.svg','brand/PF_MARK_G_FORGED.svg'].map(f=>[f,hash(path.join(root,f))]));report.builtHashes=treeHashes(publicDir);
  site=await startServer();report.loopbackOrigin=site;await startBrowser();
  if(process.argv.includes('--motion-probe')){for(let i=0;i<3;i++)await qualifyMotion();}
  else {
    await httpChecks();
    for(const viewport of viewports){try{await runPage('/',viewport);}catch(e){fatal(`homepage-${viewport.width}`,e);}}
    for(const viewport of [viewports[0],viewports[3]]){try{await runPage('/software/',viewport);}catch(e){fatal(`software-${viewport.width}`,e);}}
    try{await supplementary();}catch(e){fatal('supplementary',e);}
    try{await markSheet();}catch(e){fatal('PF G mark sheet',e);}
  }
  check('custody: source stable during browser evidence',Object.entries(report.sourceHashes).every(([f,h])=>hash(path.join(root,f))===h));
  check('custody: entire built tree stable during browser evidence',JSON.stringify(treeHashes(publicDir))===JSON.stringify(report.builtHashes));
}catch(e){fatal('runner',e);}
finally{
  if(browser&&browser.exitCode===null&&browser.signalCode===null){browser.kill();for(let i=0;i<50&&browser.exitCode===null&&browser.signalCode===null;i++)await sleep(100);}
  for(const socket of sockets)socket.destroy();if(server)await new Promise(resolve=>server.close(resolve));
  if(profile&&fs.existsSync(profile)){const resolved=fs.realpathSync(profile);if(within(fs.realpathSync(os.tmpdir()),resolved)&&path.basename(resolved).startsWith('pf-h9-binding-'))try{fs.rmSync(resolved,{recursive:true,force:true,maxRetries:5,retryDelay:200});}catch(e){fatal('profile cleanup',e);}else fatal('profile cleanup','Unexpected path');}
  report.finishedAt=new Date().toISOString();report.summary={assertions:report.checks.length,passed:report.checks.filter(c=>c.passed).length,failed:report.checks.filter(c=>!c.passed).length,fatalOrAssertionFailures:report.failures.length,captures:report.captures.length,browserAssertions:report.checks.filter(c=>c.category==='browser').length,httpAssertions:report.checks.filter(c=>c.category==='http').length};report.passed=!report.failures.length;
  if(ownsOutput)fs.writeFileSync(path.join(outputDir,'capture-report.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(report.summary));process.exitCode=report.passed?0:1;
}
