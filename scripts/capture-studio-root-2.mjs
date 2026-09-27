// Local-only desktop/mobile capture for the registry-driven studio root.
// Usage: node scripts/capture-studio-root-2.mjs receipts/studio-root-2/after
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { spawn, spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const publicDir = fs.realpathSync(path.join(root, 'public'));
const outputDir = path.resolve(root, process.argv[2] || 'receipts/studio-root-2/after');
const only = process.argv[3];
const within = (base, value) => { const rel = path.relative(base, value); return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel); };
if (!within(path.join(root, 'receipts', 'studio-root-2'), outputDir)) throw new Error('Capture output must stay in receipts/studio-root-2/.');
if (fs.existsSync(outputDir)) throw new Error(`Refusing to overwrite existing capture directory: ${outputDir}`);
fs.mkdirSync(outputDir, { recursive: true });

const mime = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.avif':'image/avif','.jpg':'image/jpeg','.jpeg':'image/jpeg','.woff2':'font/woff2','.ico':'image/x-icon','.json':'application/json','.xml':'application/xml','.txt':'text/plain'};
const server = http.createServer((req, res) => {
  if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
  const decoded = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
  let file = path.resolve(publicDir, `.${decoded}`);
  if (file !== publicDir && !within(publicDir, file)) { res.writeHead(403).end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404).end(); return; }
  const resolved = fs.realpathSync(file);
  if (!within(publicDir, resolved) || !fs.statSync(resolved).isFile()) { res.writeHead(403).end(); return; }
  res.writeHead(200, {'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff'});
  if (req.method === 'HEAD') res.end(); else fs.createReadStream(resolved).pipe(res);
});

let browser, profile, serverUrl, cdpBase;
const pauses = new Set();
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const report = { candidate: spawnSync('git', ['rev-parse', 'HEAD'], {cwd:root, encoding:'utf8'}).stdout.trim(), tree: spawnSync('git', ['rev-parse', 'HEAD^{tree}'], {cwd:root, encoding:'utf8'}).stdout.trim(), route:'/', captures:[], externalRequestsBlocked:true };

async function startServer() {
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  serverUrl = `http://127.0.0.1:${server.address().port}`;
}

async function startBrowser() {
  const executable = [process.env.PF_H9_BROWSER, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].filter(Boolean).find(fs.existsSync);
  if (!executable) throw new Error('No installed Chrome or Edge was found.');
  profile = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-studio-root-2-'));
  browser = spawn(executable, ['--headless=new','--disable-gpu','--disable-background-networking','--disable-component-update','--disable-sync','--disable-default-apps','--no-first-run','--no-default-browser-check','--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'], {windowsHide:true, stdio:['ignore','ignore','pipe']});
  browser.stderr.on('data', () => {});
  for (let i=0; i<120; i++) {
    const file = path.join(profile, 'DevToolsActivePort');
    if (fs.existsSync(file)) { const port = Number(fs.readFileSync(file, 'utf8').split(/\r?\n/)[0]); cdpBase = `http://127.0.0.1:${port}`; return; }
    if (browser.exitCode !== null) throw new Error('Browser exited before publishing a DevTools port.');
    await sleep(100);
  }
  throw new Error('Browser did not publish a DevTools port.');
}

async function connect() {
  const target = await fetch(`${cdpBase}/json/new?about:blank`, {method:'PUT'}).then(r => r.json());
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.addEventListener('open', resolve, {once:true}); ws.addEventListener('error', reject, {once:true}); });
  let seq = 0;
  const pending = new Map();
  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) { const p=pending.get(message.id); pending.delete(message.id); message.error ? p.reject(new Error(message.error.message)) : p.resolve(message.result); }
    else if (message.method === 'Fetch.requestPaused') {
      const request = message.params.request;
      const local = request.url.startsWith(`${serverUrl}/`) || /^(data:|blob:|about:)/.test(request.url);
      ws.send(JSON.stringify({id:++seq, method:local?'Fetch.continueRequest':'Fetch.failRequest', params:local?{requestId:message.params.requestId}:{requestId:message.params.requestId,errorReason:'BlockedByClient'}}));
      if (!local) pauses.add(new URL(request.url).origin);
    }
  });
  const send = (method, params={}) => new Promise((resolve,reject) => { const id=++seq; pending.set(id,{resolve,reject}); ws.send(JSON.stringify({id,method,params})); });
  const evaluate = async expression => { const result=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true}); if(result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text); return result.result.value; };
  return {send,evaluate,ws,target};
}

async function capture(cdp, viewport, label) {
  await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  await cdp.send('Emulation.setDeviceMetricsOverride',{width:viewport.width,height:viewport.height,deviceScaleFactor:1,mobile:viewport.width<768});
  await cdp.send('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
  await cdp.send('Page.navigate',{url:serverUrl + '/'});
  for(let i=0;i<180;i++){if(await cdp.evaluate('document.readyState === "complete"'))break;await sleep(75);}
  const page = await cdp.evaluate(`(async()=>{await document.fonts.ready;for(let y=0;y<document.documentElement.scrollHeight;y+=Math.max(300,innerHeight*.8)){scrollTo(0,y);await new Promise(r=>setTimeout(r,70));}scrollTo(0,0);const visible=[...document.images].filter(i=>{const r=i.getBoundingClientRect();return r.bottom>=0&&r.top<=innerHeight;});await Promise.race([Promise.all(visible.map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,6000))]);await new Promise(r=>setTimeout(r,350));return {title:document.title,width:innerWidth,height:innerHeight,clientWidth:document.documentElement.clientWidth,scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight,h1:document.querySelector('h1')?.innerText,heroImage:document.querySelector('.studio-hero-product img')?.getAttribute('src'),heroImageLoaded:document.querySelector('.studio-hero-product img')?.naturalWidth>0,heroModules:[...document.querySelectorAll('.studio-hero-product[data-module]')].map(x=>x.dataset.module),portfolio:[...document.querySelectorAll('.studio-product-card[data-module]')].map(x=>({id:x.dataset.module,presentation:x.dataset.presentation})),sectionOrder:[...document.querySelectorAll('main > section')].map(x=>x.className),featuredCount:document.querySelectorAll('.studio-hero-product[data-presentation="feature"]').length};})()`);
  console.log(`CAPTURE ${label} ${viewport.width}x${viewport.height}`);
  const shot = await cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
  const file = path.join(outputDir, `${label}-${viewport.width}x${viewport.height}.png`);
  fs.writeFileSync(file, Buffer.from(shot.data,'base64'));
  const metrics = await cdp.send('Page.getLayoutMetrics');
  const fullHeight = Math.ceil(metrics.cssContentSize.height);
  if (fullHeight <= 50000) {
    const full = await cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:fullHeight,scale:1}});
    fs.writeFileSync(path.join(outputDir,`${label}-${viewport.width}-full.png`),Buffer.from(full.data,'base64'));
  }
  report.captures.push({label,viewport,dom:page,viewportFile:path.basename(file),fullPageHeight:fullHeight});
}

let cdp;
try {
  await startServer(); await startBrowser(); cdp = await connect();
  await cdp.send('Page.enable'); await cdp.send('Runtime.enable'); await cdp.send('Network.enable');
  await cdp.send('Fetch.enable',{patterns:[{urlPattern:'*'}]});
  await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  const viewports = only === 'mobile' ? [[{width:390,height:844},'mobile']] : only === 'desktop' ? [[{width:1440,height:900},'desktop']] : [[{width:1440,height:900},'desktop'],[{width:390,height:844},'mobile']];
  for (const [viewport,label] of viewports) await capture(cdp,viewport,label);
  report.externalOriginsBlocked=[...pauses];
  report.visualGate = report.captures.every(c => c.dom.scrollWidth === c.dom.clientWidth && c.dom.featuredCount === 1 && c.dom.heroImageLoaded && c.dom.portfolio.at(-1)?.id === 'forgecast' && c.dom.portfolio.at(-1)?.presentation === 'compact' && new Set([...c.dom.heroModules,...c.dom.portfolio.map(p=>p.id)]).size === 7);
  fs.writeFileSync(path.join(outputDir,'capture-summary.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({visualGate:report.visualGate,captures:report.captures.map(c=>({label:c.label,viewport:c.viewport,clientWidth:c.dom.clientWidth,scrollWidth:c.dom.scrollWidth,featuredCount:c.dom.featuredCount,heroImageLoaded:c.dom.heroImageLoaded,portfolioCount:c.dom.portfolio.length,last:c.dom.portfolio.at(-1)?.id,lastPresentation:c.dom.portfolio.at(-1)?.presentation,sectionOrder:c.dom.sectionOrder}))},null,2));
  if (!report.visualGate) process.exitCode = 1;
} finally {
  if (cdp?.target?.id) await fetch(`${cdpBase}/json/close/${cdp.target.id}`).catch(()=>{});
  cdp?.ws?.close();
  server.close();
  if (browser && browser.exitCode === null) {
    const exited = new Promise(resolve => browser.once('exit', resolve));
    browser.kill();
    await Promise.race([exited,sleep(3000)]);
  }
  if (profile) { const tmp=path.resolve(os.tmpdir()); const resolved=path.resolve(profile); if(path.basename(resolved).startsWith('pf-studio-root-2-') && within(tmp,resolved)) { try { fs.rmSync(resolved,{recursive:true,force:true}); } catch (error) { if(error.code!=='EBUSY'&&error.code!=='EPERM') throw error; } } }
}
