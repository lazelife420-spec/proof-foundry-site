// Candidate visual qualification — serves candidate-public/ locally and captures
// real Chromium evidence at 1440/390/320px, plus the approved reference at 1440.
// Read-only: never modifies source, fixtures, or output. node scripts/capture-candidate-visual.mjs [outDir]
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = path.resolve(import.meta.dirname, '..');
const publicDir = fs.realpathSync(path.join(root, 'candidate-public'));
const outDir = path.resolve(root, process.argv[2] || 'receipts/candidate-qual-2026-11-13/shots');
const REF_BASE = 'https://cp0189-visual-approved.proof-foundry-site.pages.dev';
const sleep = ms => new Promise(r => setTimeout(r, ms));
const sha = f => createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.avif': 'image/avif', '.jpg': 'image/jpeg', '.json': 'application/json', '.woff2': 'font/woff2', '.ico': 'image/x-icon', '.xml': 'application/xml', '.txt': 'text/plain' };

const report = { startedAt: new Date().toISOString(), publicDir, outDir, checks: [], failures: [], captures: [], pages: [] };
function check(name, passed, details) { report.checks.push({ name, passed: !!passed, details }); if (!passed) { report.failures.push(name); console.error(`FAIL ${name}: ${JSON.stringify(details)}`); } }

// ── static server (mirrors capture-h9-binding: dir→index.html, 404 fallback, no traversal)
function startServer() {
  const server = http.createServer((req, res) => {
    try {
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
      const decoded = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
      let file = path.resolve(publicDir, `.${decoded}`);
      const rel = path.relative(publicDir, file);
      if (rel.startsWith('..') || path.isAbsolute(rel)) { res.writeHead(403).end(); return; }
      if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
      if (!fs.existsSync(file)) { const b = fs.readFileSync(path.join(publicDir, '404.html')); res.writeHead(404, { 'Content-Type': mime['.html'] }).end(req.method === 'HEAD' ? undefined : b); return; }
      const resolved = fs.realpathSync(file);
      if (!resolved.startsWith(publicDir)) { res.writeHead(403).end(); return; }
      const body = fs.readFileSync(resolved);
      res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'Content-Length': body.length });
      res.end(req.method === 'HEAD' ? undefined : body);
    } catch { res.writeHead(400).end(); }
  });
  return new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', () => resolve({ server, base: `http://127.0.0.1:${server.address().port}` })); });
}

// ── headless chrome + minimal CDP client
async function startBrowser() {
  const exe = [process.env.PF_H9_BROWSER, 'C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].filter(Boolean).find(fs.existsSync);
  if (!exe) throw new Error('No installed Chrome/Edge; set PF_H9_BROWSER.');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-cand-qual-'));
  const browser = spawn(exe, ['--headless=new', '--disable-gpu', '--disable-background-networking', '--disable-component-update', '--disable-sync', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  browser.stderr.on('data', () => { });
  for (let i = 0; i < 100; i++) {
    const active = path.join(profile, 'DevToolsActivePort');
    if (fs.existsSync(active)) {
      const port = Number(fs.readFileSync(active, 'utf8').split(/\r?\n/)[0]);
      if (port > 0) {
        const version = await fetch(`http://127.0.0.1:${port}/json/version`).then(r => r.json());
        report.browser = { exe, version: version.Browser };
        return { browser, profile, cdpBase: `http://127.0.0.1:${port}` };
      }
    }
    if (browser.exitCode !== null) throw new Error(`Browser exited ${browser.exitCode}`);
    await sleep(100);
  }
  throw new Error('Browser DevTools port never appeared');
}

function connectCdp(cdpBase) {
  return fetch(`${cdpBase}/json/list`).then(r => r.json()).then(targets => {
    const page = targets.find(t => t.type === 'page');
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    let id = 0; const pending = new Map(); const listeners = new Map();
    const cdp = {
      consoleErrors: [], networkErrors: [], external: [], ws,
      send(method, params = {}) {
        const mid = ++id;
        return new Promise((resolve, reject) => { pending.set(mid, { resolve, reject }); ws.send(JSON.stringify({ id: mid, method, params })); });
      },
      on(evt, cb) { if (!listeners.has(evt)) listeners.set(evt, []); listeners.get(evt).push(cb); }
    };
    ws.onmessage = e => {
      const m = JSON.parse(e.data);
      if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result); }
      else if (m.method && listeners.has(m.method)) listeners.get(m.method).forEach(cb => cb(m.params));
    };
    cdp.on('Runtime.consoleAPICalled', ev => { if (ev.type === 'error') cdp.consoleErrors.push(ev.args.map(a => a.value || a.description || '').join(' ').slice(0, 300)); });
    cdp.on('Network.loadingFailed', ev => cdp.networkErrors.push({ url: ev.errorText, type: ev.type, blocked: ev.blockedReason }));
    cdp.on('Network.responseReceived', ev => { try { const h = new URL(ev.response.url).hostname; if (!/^(127\.0\.0\.1|localhost)$/.test(h) && !h.endsWith('pages.dev')) cdp.external.push(ev.response.url.slice(0, 200)); } catch { } });
    return new Promise(res => ws.onopen = async () => {
      await cdp.send('Page.enable'); await cdp.send('Runtime.enable'); await cdp.send('Network.enable');
      res(cdp);
    });
  });
}

async function inspect(cdp, label, width) {
  const d = await cdp.send('Runtime.evaluate', { expression: `(()=>{const w=document.documentElement.clientWidth;const ids=[...document.querySelectorAll('[id]')].map(e=>e.id);return {clientWidth:w,scrollWidth:Math.max(document.documentElement.scrollWidth,document.body.scrollWidth),missingImages:[...document.images].filter(i=>i.checkVisibility({checkVisibilityCSS:true})&&(!i.complete||!i.naturalWidth)).map(i=>i.currentSrc||i.src),duplicateIds:ids.filter((x,i)=>ids.indexOf(x)!==i),missingAlt:[...document.images].filter(i=>!i.hasAttribute('alt')&&!/^offline-resources-/.test(i.id)).map(i=>i.outerHTML.slice(0,110)),badLabels:[...document.querySelectorAll('[aria-labelledby]')].flatMap(e=>e.getAttribute('aria-labelledby').split(/\\s+/).filter(id=>!document.getElementById(id))),overflowEls:[...document.querySelectorAll('main *')].filter(e=>e.checkVisibility({checkVisibilityCSS:true})&&getComputedStyle(e).position!=='absolute'&&e.getBoundingClientRect().right>w+2).slice(0,10).map(e=>({tag:e.tagName,cls:String(e.className).slice(0,60),right:Math.round(e.getBoundingClientRect().right)}))};})()`, returnByValue: true });
  const v = d.result.value;
  check(`${label}: no horizontal document overflow`, v.scrollWidth <= v.clientWidth + 1, { scrollWidth: v.scrollWidth, clientWidth: v.clientWidth, overflowEls: v.overflowEls });
  check(`${label}: all visible images decoded`, v.missingImages.length === 0, v.missingImages);
  check(`${label}: no duplicate ids`, v.duplicateIds.length === 0, v.duplicateIds);
  check(`${label}: every image has alt`, v.missingAlt.length === 0, v.missingAlt.slice(0, 5));
  check(`${label}: aria-labelledby targets exist`, v.badLabels.length === 0, v.badLabels);
  // keyboard focus: two Tabs, then read the focused element and its focus ring
  for (const phase of ['rawKeyDown', 'keyUp']) await cdp.send('Input.dispatchKeyEvent', { type: phase, key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
  for (const phase of ['rawKeyDown', 'keyUp']) await cdp.send('Input.dispatchKeyEvent', { type: phase, key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
  await sleep(150);
  const f = await cdp.send('Runtime.evaluate', { expression: `(()=>{const e=document.activeElement;if(!e||e===document.body)return {focused:null};const cs=getComputedStyle(e);return {focused:e.tagName+'.'+String(e.className).split(' ')[0],outline:cs.outlineStyle+','+cs.outlineWidth+','+cs.outlineColor,shadow:cs.boxShadow.slice(0,80)};})()`, returnByValue: true });
  report.pages.push({ label, width, facts: v, focus: f.result.value });
  return v;
}

async function shoot(cdp, url, file, vp) {
  await cdp.send('Emulation.setDeviceMetricsOverride', { width: vp.width, height: vp.height, deviceScaleFactor: 1, mobile: vp.width < 768 });
  cdp.consoleErrors.length = 0; cdp.networkErrors.length = 0;
  await cdp.send('Page.navigate', { url });
  await sleep(1400);
  // Trigger loading=lazy assets below the fold before the full-page capture.
  await cdp.send('Runtime.evaluate', { expression: `(async()=>{const h=document.body.scrollHeight;for(let y=0;y<h;y+=600){window.scrollTo(0,y);await new Promise(r=>setTimeout(r,60))}window.scrollTo(0,0);})()`, awaitPromise: true }).catch(() => { });
  await cdp.send('Runtime.evaluate', { expression: `Promise.race([Promise.allSettled([...document.images].filter(i=>!i.complete||!i.naturalWidth).map(i=>{i.loading='eager';return i.decode().catch(()=>{})})),new Promise(r=>setTimeout(r,8000))])`, awaitPromise: true }).catch(() => { });
  await sleep(300);
  await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 60, clip: { x: 0, y: 0, width: 1, height: 1 } }).catch(() => { }); // warm layout
  const metrics = await cdp.send('Page.getLayoutMetrics');
  const h = Math.ceil(metrics.cssContentSize.height);
  const result = await cdp.send('Page.captureScreenshot', { format: 'png', fromSurface: true, captureBeyondViewport: true, clip: { x: 0, y: 0, width: vp.width, height: Math.min(h, 30000), scale: 1 } });
  const target = path.join(outDir, file);
  fs.writeFileSync(target, Buffer.from(result.data, 'base64'));
  report.captures.push({ file, url, viewport: vp.width, docHeight: h, sha256: sha(target) });
  console.log(`CAPTURE ${file} ${vp.width}x${h}`);
  const facts = await inspect(cdp, `${file.replace(/\.png$/, '')}`, vp.width);
  check(`${file}: no console errors`, cdp.consoleErrors.length === 0, cdp.consoleErrors);
  check(`${file}: no failed requests`, cdp.networkErrors.length === 0, cdp.networkErrors);
  return facts;
}

async function pageFacts(cdp, url, label) {
  await cdp.send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  await cdp.send('Page.navigate', { url });
  await sleep(1200);
  const r = await cdp.send('Runtime.evaluate', { expression: `(()=>{const dl=[...document.querySelectorAll('a[href]')].map(a=>a.getAttribute('href'));const rg=document.querySelector('[data-directory-entry="reality-gate"]');return {dirCount:document.querySelectorAll('[data-directory-entry]').length,downloadCount:document.querySelectorAll('[data-availability="download"]').length,rgAvailability:rg?rg.dataset.availability:null,rgWithdrawn:rg?/v1\\.1\\.0 withdrawn/.test(rg.textContent):false,binLinks:dl.filter(h=>/\\.(zip|exe|apk|msi|dmg|pkg)(\\?|$)/i.test(h)),withdrawnText:document.body.innerText.includes('WITHDRAWN')||document.body.innerText.includes('withdrawn'),v1120:document.body.innerText.includes('11.2.0'),v1111:document.body.innerText.includes('11.1.1'),noOffer:document.body.innerText.includes('No download is offered')};})()`, returnByValue: true });
  report.pages.push({ label, url, productFacts: r.result.value });
  return r.result.value;
}

const products = ['cache-vault', 'cleanroom', 'forgecast', 'ghostlayer', 'lights-out', 'proofshot', 'reality-gate'];
const routes = ['', 'software', ...products, 'truth-files', 'truth-files/reality-gate'];
const viewports = [{ width: 1440, height: 900 }, { width: 390, height: 844 }, { width: 320, height: 780 }];
const slug = r => r === '' ? 'home' : r.replace(/\//g, '_');

const { server, base } = await startServer();
const { browser, profile, cdpBase } = await startBrowser();
try {
  const cdp = await connectCdp(cdpBase);
  fs.mkdirSync(outDir, { recursive: true });
  for (const vp of viewports) {
    for (const route of routes) {
      await shoot(cdp, route === '' ? `${base}/` : `${base}/${route}/`, `cand-${slug(route)}-${vp.width}.png`, vp);
    }
  }
  // Approved reference captures (1440 only) for side-by-side adjudication
  for (const route of ['', 'software', 'reality-gate', 'lights-out']) {
    await shoot(cdp, `${REF_BASE}/${route}/`, `ref-${slug(route)}-1440.png`, { width: 1440, height: 900 });
  }
  // Product-truth fact checks on candidate
  const sw = await pageFacts(cdp, `${base}/software/`, 'software-catalog');
  check('catalog: nine directory entries, five public downloads', sw.dirCount === 9 && sw.downloadCount === 5, { dirCount: sw.dirCount, downloadCount: sw.downloadCount });
  check('catalog: Reality Gate entry withdrawn without download', sw.rgAvailability === 'none' && sw.rgWithdrawn, { rgAvailability: sw.rgAvailability, rgWithdrawn: sw.rgWithdrawn });
  const rg = await pageFacts(cdp, `${base}/reality-gate/`, 'reality-gate');
  check('reality-gate: withdrawal unmistakable in page text', rg.withdrawnText && rg.noOffer, { withdrawnText: rg.withdrawnText, noOffer: rg.noOffer });
  check('reality-gate: no binary installer links', rg.binLinks.length === 0, rg.binLinks);
  const lo = await pageFacts(cdp, `${base}/lights-out/`, 'lights-out');
  check('lights-out: v11.2.0 public + v11.1.1 companion stated', lo.v1120 && lo.v1111, { v1120: lo.v1120, v1111: lo.v1111 });
  check('lights-out: binary link resolves to v11.2.0 release', lo.binLinks.some(h => /11\.2\.0/.test(h)), lo.binLinks);
  check('lights-out: no stale v11.1.3 binary link', !lo.binLinks.some(h => /11\.1\.3/.test(h)), lo.binLinks);
  await cdp.ws.close();
} finally {
  browser.kill(); server.close();
  try { fs.rmSync(profile, { recursive: true, force: true }); } catch { }
}
report.finishedAt = new Date().toISOString();
report.summary = { checks: report.checks.length, passed: report.checks.filter(c => c.passed).length, failed: report.failures.length, captures: report.captures.length };
fs.writeFileSync(path.join(outDir, '..', 'visual-qual-report.json'), JSON.stringify(report, null, 1));
console.log(JSON.stringify(report.summary));
process.exitCode = report.failures.length ? 1 : 0;
