import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { spawn, spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const publicDir = fs.realpathSync(path.join(root, 'public'));
const outputDir = path.resolve(root, process.argv[2] || 'receipts/ultimate-homepage/qualification');
const outputRoot = path.join(root, 'receipts', 'ultimate-homepage');
const within = (base, value) => { const rel = path.relative(base, value); return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel); };
if (!within(outputRoot, outputDir)) throw new Error('Capture output must remain inside receipts/ultimate-homepage/.');
if (fs.existsSync(outputDir)) throw new Error(`Refusing to overwrite existing capture directory: ${outputDir}`);
fs.mkdirSync(outputDir, { recursive: true });
const matrixDir = path.join(outputDir, 'viewport-matrix');
const scrollDir = path.join(outputDir, 'scroll-recordings');
fs.mkdirSync(matrixDir); fs.mkdirSync(scrollDir);

const mime = { '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.svg':'image/svg+xml', '.png':'image/png', '.webp':'image/webp', '.avif':'image/avif', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.woff2':'font/woff2', '.ico':'image/x-icon', '.json':'application/json', '.xml':'application/xml', '.txt':'text/plain' };
const server = http.createServer((req, res) => {
  if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
  const decoded = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  let file = path.resolve(publicDir, `.${decoded}`);
  if (file !== publicDir && !within(publicDir, file)) { res.writeHead(403).end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404).end(); return; }
  const resolved = fs.realpathSync(file);
  if (!within(publicDir, resolved) || !fs.statSync(resolved).isFile()) { res.writeHead(403).end(); return; }
  res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff' });
  if (req.method === 'HEAD') res.end(); else fs.createReadStream(resolved).pipe(res);
});

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let browser, profile, serverUrl, cdpBase, cdp;
const blockedOrigins = new Set();
const consoleErrors = [], pageExceptions = [], failedLocalRequests = [];
const matrix = [[390,844,'mobile390'],[820,1180,'tablet820'],[1440,900,'desktop1440'],[1920,1080,'desktop1920'],[2560,1440,'wide2560'],[3440,1440,'ultrawide3440']];
const scrollViewports = [[3440,1440,'ultrawide3440'],[1920,1080,'desktop1920'],[390,844,'mobile390']];
const report = {
  schema: 'PF_WEB_ULTIMATE_HOMEPAGE_CAPTURE_V1',
  capturedAt: new Date().toISOString(),
  candidateCommit: spawnSync('git', ['rev-parse','HEAD'], { cwd:root, encoding:'utf8' }).stdout.trim(),
  candidateTree: spawnSync('git', ['rev-parse','HEAD^{tree}'], { cwd:root, encoding:'utf8' }).stdout.trim(),
  worktreeStatus: spawnSync('git', ['status','--porcelain'], { cwd:root, encoding:'utf8' }).stdout.trim(),
  viewportMatrix: [],
  scrollRecordings: [],
  externalOriginsBlocked: [],
};

await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
serverUrl = `http://127.0.0.1:${server.address().port}`;
const executable = [process.env.PF_H9_BROWSER, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].filter(Boolean).find(fs.existsSync);
if (!executable) throw new Error('No installed Chrome or Edge was found.');
profile = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-ultimate-homepage-'));
browser = spawn(executable, ['--headless=new','--disable-gpu','--disable-background-networking','--disable-component-update','--disable-sync','--disable-default-apps','--no-first-run','--no-default-browser-check','--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'], { windowsHide:true, stdio:['ignore','ignore','pipe'] });
browser.stderr.on('data', () => {});
for (let i=0; i<150; i++) {
  const portFile = path.join(profile, 'DevToolsActivePort');
  if (fs.existsSync(portFile)) { const port = Number(fs.readFileSync(portFile, 'utf8').split(/\r?\n/)[0]); cdpBase = `http://127.0.0.1:${port}`; break; }
  if (browser.exitCode !== null) throw new Error('Browser exited before publishing a DevTools port.');
  await sleep(100);
}
if (!cdpBase) throw new Error('Browser did not publish a DevTools port.');
const target = await fetch(`${cdpBase}/json/new?about:blank`, { method:'PUT' }).then(r => r.json());
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => { ws.addEventListener('open', resolve, { once:true }); ws.addEventListener('error', reject, { once:true }); });
let seq = 0; const pending = new Map(); let frameSink;
ws.addEventListener('message', event => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) { const p=pending.get(message.id); pending.delete(message.id); message.error ? p.reject(new Error(message.error.message)) : p.resolve(message.result); return; }
  if (message.method === 'Fetch.requestPaused') {
    const request=message.params.request, local=request.url.startsWith(`${serverUrl}/`) || /^(data:|blob:|about:)/.test(request.url);
    ws.send(JSON.stringify({ id:++seq, method:local?'Fetch.continueRequest':'Fetch.failRequest', params:local?{requestId:message.params.requestId}:{requestId:message.params.requestId,errorReason:'BlockedByClient'} }));
    if (!local) { try { blockedOrigins.add(new URL(request.url).origin); } catch {} }
  } else if (message.method === 'Page.screencastFrame') {
    const p=message.params;
    if (frameSink) frameSink(Buffer.from(p.data,'base64'),p.metadata);
    ws.send(JSON.stringify({ id:++seq, method:'Page.screencastFrameAck', params:{ sessionId:p.sessionId } }));
  } else if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') {
    consoleErrors.push({text:message.params.entry.text,url:message.params.entry.url || '',source:message.params.entry.source});
  } else if (message.method === 'Runtime.exceptionThrown') {
    const details=message.params.exceptionDetails;
    pageExceptions.push({text:details.exception?.description || details.text || 'Unspecified page exception',url:details.url || '',line:details.lineNumber});
  } else if (message.method === 'Network.loadingFailed') {
    const failed=message.params;
    if (failed.errorText !== 'net::ERR_ABORTED' && (!failed.blockedReason) && failed.type !== 'Other') {
      failedLocalRequests.push({requestId:failed.requestId,error:failed.errorText,type:failed.type});
    }
  }
});
const send = (method, params={}) => new Promise((resolve,reject) => { const id=++seq; pending.set(id,{resolve,reject}); ws.send(JSON.stringify({id,method,params})); });
const evaluate = async expression => { const result=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true}); if(result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text); return result.result.value; };
cdp = { send, evaluate, target, ws, setFrameSink: sink => { frameSink=sink; } };
await send('Page.enable'); await send('Runtime.enable'); await send('Log.enable'); await send('Network.enable'); await send('Fetch.enable',{patterns:[{urlPattern:'*'}]});
await send('Network.setCacheDisabled',{cacheDisabled:true});
await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});

async function navigate(width,height) {
  await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<768});
  await send('Page.navigate',{url:serverUrl + '/'});
  for(let i=0;i<180;i++){ if(await evaluate('document.readyState === "complete"')) break; await sleep(70); }
  const ready = await evaluate(`(async()=>{await document.fonts.ready; const h=document.documentElement.scrollHeight; for(let y=0;y<h;y+=Math.max(360,innerHeight*.72)){scrollTo({top:y,behavior:'instant'});await new Promise(r=>setTimeout(r,110));} scrollTo({top:0,behavior:'instant'}); await Promise.race([Promise.all([...document.images].map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,6500))]); await new Promise(r=>setTimeout(r,250)); return true;})()`);
  if (!ready) throw new Error('Page did not finish preparation.');
}

async function collectMetrics(width,height,label) {
  return await evaluate(`(()=>{const root=document.documentElement; const cards=[...document.querySelectorAll('.studio-product-card[data-module]')]; const withdrawn=[...document.querySelectorAll('.studio-withdrawn-product[data-module]')]; const sections=[...document.querySelectorAll('main > section')].map(x=>x.className); const rect=s=>{const x=document.querySelector(s),r=x?.getBoundingClientRect();return r?{left:Math.round(r.left),right:Math.round(r.right),width:Math.round(r.width)}:null}; const overflow=[...document.querySelectorAll('main *')].filter(x=>{const r=x.getBoundingClientRect();return r.width>0&&r.height>0&&(r.left < -1 || r.right > root.clientWidth+1)}).slice(0,30).map(x=>({tag:x.tagName,className:typeof x.className==='string'?x.className:'',left:Math.round(x.getBoundingClientRect().left),right:Math.round(x.getBoundingClientRect().right),width:Math.round(x.getBoundingClientRect().width)})); const images=[...document.images].map(i=>({src:i.getAttribute('src'),loaded:i.complete&&i.naturalWidth>0,naturalWidth:i.naturalWidth})); const heroStyle=getComputedStyle(document.querySelector('.studio-hero-grid'));const portfolioStyle=getComputedStyle(document.querySelector('.studio-portfolio-grid'));return {label:${JSON.stringify(label)},viewport:{width:innerWidth,height:innerHeight},clientWidth:root.clientWidth,scrollWidth:root.scrollWidth,scrollHeight:root.scrollHeight,title:document.title,h1:document.querySelector('h1')?.innerText,sections,publicModules:cards.map(x=>x.dataset.module),withdrawnModules:withdrawn.map(x=>x.dataset.module),heroGrid:rect('.studio-hero-grid'),heroCopy:rect('.studio-hero-copy'),heroEmblemBox:rect('.studio-hero-emblem'),portfolioRail:rect('.studio-portfolio-grid'),heroGridComputedWidth:heroStyle.width,portfolioComputedWidth:portfolioStyle.width,heroImageLoaded:document.querySelector('.studio-forge-workbench img')?.naturalWidth>0,heroEmblem:!!document.querySelector('.studio-hero-emblem img'),allImagesLoaded:images.every(i=>i.loaded),unloadedImages:images.filter(i=>!i.loaded),outOfBounds:overflow,reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches,realityGateDownloadActions:document.querySelectorAll('.studio-withdrawn-product [data-commerce],.studio-withdrawn-product a[download]').length,ledgerRows:document.querySelectorAll('.studio-ledger-row').length};})()`);
}

function saveFrameSequence(videoName, frames, width, height) {
  const dir=path.join(scrollDir, videoName.replace(/\.mp4$/,'')); fs.mkdirSync(dir);
  for(let i=0;i<frames.length;i++) fs.writeFileSync(path.join(dir,`frame-${String(i).padStart(5,'0')}.jpg`),frames[i].data);
  if (!frames.length) throw new Error(`No real browser screencast frames captured for ${videoName}.`);
  const video=path.join(scrollDir,videoName);
  const result=spawnSync('ffmpeg',['-y','-loglevel','error','-framerate','15','-i',path.join(dir,'frame-%05d.jpg'),'-vf',`scale=${width}:${height}:flags=lanczos`,'-c:v','libx264','-preset','fast','-crf','24','-pix_fmt','yuv420p',video],{encoding:'utf8',windowsHide:true});
  if(result.status!==0) throw new Error(`ffmpeg failed for ${videoName}: ${result.stderr || result.error}`);
  return {video:path.relative(outputDir,video).replaceAll(path.sep,'/'),frameCount:frames.length,sizeBytes:fs.statSync(video).size};
}

try {
  const truth=JSON.parse(fs.readFileSync(path.join(publicDir,'truth/index.json'),'utf8'));
  const states=new Map(truth.products.map(p=>[p.id,p.status]));
  const modules=fs.readdirSync(path.join(root,'products'),{withFileTypes:true}).filter(d=>d.isDirectory()).map(d=>JSON.parse(fs.readFileSync(path.join(root,'products',d.name,'module.json'),'utf8')));
  const ordered=modules.filter(m=>m.visibility==='visible'&&m.lifecycle==='public-eligible'&&m.homepage?.role==='studioPortfolio'&&m.homepage?.visibility==='visible').sort((a,b)=>a.homepage.order-b.homepage.order||a.order-b.order);
  report.expectedPublicModules=ordered.filter(m=>states.get(m.id)==='PUBLIC_RELEASE').map(m=>m.id);
  report.expectedWithdrawnModules=ordered.filter(m=>states.get(m.id)==='WITHDRAWN').map(m=>m.id);
  for(const [width,height,label] of matrix){
    await navigate(width,height);
    const metrics=await collectMetrics(width,height,label);
    const view=path.join(matrixDir,`${label}-${width}x${height}.png`);
    fs.writeFileSync(view,Buffer.from((await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false})).data,'base64'));
    const fullHeight=Math.ceil((await send('Page.getLayoutMetrics')).cssContentSize.height);
    let fullPageFile=null;
    if(fullHeight<=50000){
      fullPageFile=path.join(matrixDir,`${label}-full.png`);
      fs.writeFileSync(fullPageFile,Buffer.from((await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width,height:fullHeight,scale:1}})).data,'base64'));
    }
    report.viewportMatrix.push({...metrics,viewportFile:path.relative(outputDir,view).replaceAll(path.sep,'/'),fullPageFile:fullPageFile?path.relative(outputDir,fullPageFile).replaceAll(path.sep,'/'):null});
  }
  for(const [width,height,label] of scrollViewports){
    await navigate(width,height);
    const frames=[]; let lastScroll=0, scrollPhase='forward';
    cdp.setFrameSink((data,metadata)=>frames.push({data,metadata,phase:scrollPhase,scrollY:Number.isFinite(metadata?.scrollOffsetY)?Math.round(metadata.scrollOffsetY):lastScroll}));
    await send('Page.startScreencast',{format:'jpeg',quality:82,everyNthFrame:4,maxWidth:width,maxHeight:height});
    await sleep(650);
    const heightPx=await evaluate('document.documentElement.scrollHeight');
    const step=Math.max(260,Math.round(height*.64));
    const checkpoints=[];
    const animateTo=async(target,phase)=>{
      scrollPhase=phase;
      await evaluate(`(async()=>{const start=scrollY,target=${target},duration=680,beg=performance.now();await new Promise(done=>{function frame(now){const p=Math.min(1,(now-beg)/duration),e=p<.5?4*p*p*p:1-Math.pow(-2*p+2,3)/2;window.scrollTo(0,start+(target-start)*e);if(p<1)requestAnimationFrame(frame);else done();}requestAnimationFrame(frame);});return Math.round(scrollY);})()`);
      lastScroll=await evaluate('Math.round(scrollY)');
      checkpoints.push({direction:phase,scrollY:lastScroll,observedAt:new Date().toISOString()});
      await sleep(230);
    };
    const forward=[];
    for(let y=step;y<heightPx;y+=step) forward.push(Math.min(y,heightPx-height));
    const bottom=Math.max(0,heightPx-height);
    if(!forward.length||forward.at(-1)!==bottom)forward.push(bottom);
    for(const y of forward)await animateTo(y,'forward');
    const reverse=[];
    for(let y=bottom-step;y>0;y-=step)reverse.push(y);
    reverse.push(0);
    for(const y of reverse)await animateTo(y,'reverse');
    await sleep(550);
    await send('Page.stopScreencast'); cdp.setFrameSink(null);
    const video=saveFrameSequence(`${label}-scroll.mp4`,frames,width,height);
    const positions=[...new Set(frames.map(f=>f.scrollY))];
    const sidecar=path.join(scrollDir,`${label}-scroll.json`);
    const phases=[...new Set(frames.map(f=>f.phase))];
    const forwardCheckpoints=checkpoints.filter(x=>x.direction==='forward').map(x=>x.scrollY);
    const reverseCheckpoints=checkpoints.filter(x=>x.direction==='reverse').map(x=>x.scrollY);
    const directionAudit={forwardStartsNearTop:forwardCheckpoints[0]!==undefined&&forwardCheckpoints[0]<=step,forwardReachesBottom:forwardCheckpoints.at(-1)===bottom,reverseStartsAtBottom:reverseCheckpoints[0]!==undefined&&Math.abs(reverseCheckpoints[0]-Math.max(0,bottom-step))<=1,reverseReturnsToTop:reverseCheckpoints.at(-1)===0};
    fs.writeFileSync(sidecar,JSON.stringify({schema:'PF_WEB_ULTIMATE_REAL_BROWSER_SCROLL_V1',viewport:{width,height},scrollHeight:heightPx,maxScrollY:bottom,frameCount:frames.length,durationMs:frames.length/15*1000,phases,directionAudit,checkpoints,positions,video:video.video,candidateCommit:report.candidateCommit,candidateTree:report.candidateTree},null,2)+'\n');
    report.scrollRecordings.push({...video,viewport:{width,height},phases,directionAudit,scrollPositions:positions,sidecar:path.relative(outputDir,sidecar).replaceAll(path.sep,'/')});
  }
  report.externalOriginsBlocked=[...blockedOrigins].sort();
  report.qualification={
    allWidthsMatch:report.viewportMatrix.every(x=>x.clientWidth===x.scrollWidth),
    wideRailsUseViewport:report.viewportMatrix.filter(x=>x.viewport.width===2560||x.viewport.width===3440).every(x=>x.viewport.width===2560?(x.heroGrid.width>=2300&&x.portfolioRail.width>=1900):(x.heroGrid.width>=2700&&x.portfolioRail.width>=2600)),
    publicModulesMatch:report.viewportMatrix.every(x=>x.publicModules.join(',')===report.expectedPublicModules.join(',')),
    withdrawnModulesMatch:report.viewportMatrix.every(x=>x.withdrawnModules.join(',')===report.expectedWithdrawnModules.join(',')),
    heroLoaded:report.viewportMatrix.every(x=>x.heroImageLoaded&&x.heroEmblem),
    imagesLoaded:report.viewportMatrix.every(x=>x.allImagesLoaded),
    noOutOfBounds:report.viewportMatrix.every(x=>x.outOfBounds.length===0),
    reducedMotion:report.viewportMatrix.every(x=>x.reducedMotion),
    withdrawnHasNoDownload:report.viewportMatrix.every(x=>x.realityGateDownloadActions===0),
    allScrollRecordingsExist:report.scrollRecordings.length===3&&report.scrollRecordings.every(x=>x.frameCount>0&&x.sizeBytes>0),
    forwardAndReverseRecorded:report.scrollRecordings.length===3&&report.scrollRecordings.every(x=>x.phases.join(',')==='forward,reverse'&&Object.values(x.directionAudit).every(Boolean)),
    cleanBrowserConsole:consoleErrors.length===0&&pageExceptions.length===0&&failedLocalRequests.length===0,
  };
  report.visualGate=Object.values(report.qualification).every(Boolean);
  report.browserErrors={console:consoleErrors,exceptions:pageExceptions,failedLocalRequests};
  fs.writeFileSync(path.join(outputDir,'capture-summary.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({visualGate:report.visualGate,qualification:report.qualification,viewports:report.viewportMatrix.map(x=>({label:x.label,viewport:x.viewport,clientWidth:x.clientWidth,scrollWidth:x.scrollWidth,scrollHeight:x.scrollHeight,publicModules:x.publicModules.length,withdrawnModules:x.withdrawnModules.length,allImagesLoaded:x.allImagesLoaded,outOfBounds:x.outOfBounds.length})),scrollRecordings:report.scrollRecordings,blockedExternalOrigins:report.externalOriginsBlocked},null,2));
  if(!report.visualGate) process.exitCode=1;
} finally {
  if(cdp?.target?.id) await fetch(`${cdpBase}/json/close/${cdp.target.id}`).catch(()=>{});
  cdp?.ws?.close(); server.close();
  if(browser&&browser.exitCode===null){const exited=new Promise(resolve=>browser.once('exit',resolve));browser.kill();await Promise.race([exited,sleep(3000)]);}
  if(profile){const temp=path.resolve(os.tmpdir()),resolved=path.resolve(profile);if(path.basename(resolved).startsWith('pf-ultimate-homepage-')&&within(temp,resolved)){try{fs.rmSync(resolved,{recursive:true,force:true});}catch(error){if(error.code!=='EBUSY'&&error.code!=='EPERM')throw error;}}}
}
