// Actual built page, active cascade, JS-enhanced preview, desktop and mobile.
// Chrome runs headed with a disposable profile and an ephemeral CDP port.
// No dependencies, no source constants, no access to any existing browser.
import { createServer } from 'node:http';
import { readFile, stat, mkdtemp, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';
import os from 'node:os';

const publicDir = path.resolve(process.argv[2] || path.join(import.meta.dirname, '..', 'public'));
const negative = process.argv.includes('--negative-control');
const chromePath = process.env.PF_TEST_CHROME || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
await stat(path.join(publicDir, 'cache-vault', 'index.html'));
await stat(chromePath);
const mime = { '.html':'text/html', '.css':'text/css', '.js':'text/javascript', '.json':'application/json', '.svg':'image/svg+xml', '.png':'image/png', '.webp':'image/webp', '.woff2':'font/woff2' };
const server = createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    let file = path.resolve(publicDir, '.' + pathname);
    if (!file.startsWith(publicDir + path.sep)) throw new Error('Outside fixture');
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end('Not found'); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const profile = await mkdtemp(path.join(os.tmpdir(), 'pf-h6-headed-'));
const chrome = spawn(chromePath, ['--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--window-size=1440,1000', 'about:blank'], { stdio: 'ignore' });
let launchError;
chrome.on('error', error => { launchError = error; });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let socket;
let send;
try {
  let port;
  for (let attempt = 0; attempt < 150; attempt++) {
    if (launchError) throw launchError;
    try { port = (await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split(/\r?\n/)[0]; break; }
    catch { await sleep(100); }
  }
  if (!port) throw new Error('Independent headed Chrome did not expose CDP within 15 seconds');
  const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then(r => r.json());
  const target = targets.find(t => t.type === 'page' && t.url === 'about:blank');
  if (!target) throw new Error('Disposable Chrome initial page not found');
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  let sequence = 0;
  const pending = new Map();
  socket.onmessage = event => {
    const message = JSON.parse(event.data);
    if (message.method === 'Fetch.requestPaused') {
      const { requestId, request } = message.params;
      // Local fixture only; never follow a remote request from page script.
      send(request.url.startsWith(origin + '/') ? 'Fetch.continueRequest' : 'Fetch.failRequest',
        request.url.startsWith(origin + '/') ? { requestId } : { requestId, errorReason:'BlockedByClient' }).catch(() => {});
    }
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id);
    clearTimeout(entry.timer);
    message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
  };
  send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 15000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, awaitPromise:true, returnByValue:true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  await send('Page.enable');
  await send('Fetch.enable', { patterns:[{urlPattern:'*'}] });
  const results = [];
  for (const width of [1440, 390]) {
    await send('Emulation.setDeviceMetricsOverride', { width, height:900, deviceScaleFactor:1, mobile:false });
    await send('Page.navigate', { url:origin + '/cache-vault/' });
    let ready = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      ready = await evaluate(`location.pathname === '/cache-vault/' && document.readyState === 'complete' && !!document.querySelector('.archive-demo:not([hidden]) .sample-clips article')`);
      if (ready) break;
      await sleep(100);
    }
    if (!ready) throw new Error('Rendered Cache Vault preview did not initialize');
    await evaluate('document.fonts.ready.then(() => true)');
    for (const [selector, state] of [['.archive-demo .kicker','kicker'], ['.clip-status','initial status'], ['.clip-status','filtered status']]) {
      if (state === 'filtered status') {
        await evaluate(`(() => { const input=document.querySelector('#clip-search'); input.value='no-match-h6-control'; input.dispatchEvent(new Event('input',{bubbles:true})); })()`);
      }
      const result = await evaluate(`(${measure.toString()})(${JSON.stringify(selector)}, ${negative})`);
      result.label = `WCAG AA: ${width}px ${state}, ${result.ratio?.toFixed(2) ?? 'unmeasurable'}:1 (>= 4.50:1)`;
      result.width = width;
      result.state = state;
      if (state === 'filtered status' && !/^0\b/.test(result.text)) {
        result.pass = false; result.error = 'Search did not update the live status to zero results';
      }
      results.push(result);
    }
  }
  console.log(JSON.stringify(results));
} finally {
  if (send && socket?.readyState === WebSocket.OPEN) {
    try { await send('Browser.close'); } catch {}
    socket.close();
  }
  if (chrome.exitCode === null) {
    await Promise.race([new Promise(resolve => chrome.once('exit', resolve)), sleep(3000)]);
    if (chrome.exitCode === null) chrome.kill();
  }
  await new Promise(resolve => server.close(resolve));
  // Only our newly created temporary profile. No pre-existing profile is read.
  await rm(profile, { recursive:true, force:true, maxRetries:10, retryDelay:200 });
}

function measure(selector, negative) {
  const el = document.querySelector(selector);
  const fail = error => ({ selector, pass:false, error });
  if (!el) return fail('Target is missing');
  el.scrollIntoView({block:'center'});
  const rect = el.getBoundingClientRect();
  if (!el.checkVisibility({checkOpacity:true, checkVisibilityCSS:true}) || !rect.width || !rect.height) return fail('Target is not rendered');
  function rgba(value) {
    const channels = value.match(/^rgba?\(([^)]+)\)$/)?.[1].split(/[, /]+/).map(Number);
    if (!channels || channels.length < 3 || channels.some(v => !Number.isFinite(v))) throw new Error('Unsupported computed color: ' + value);
    return [channels[0], channels[1], channels[2], channels[3] ?? 1];
  }
  function over(top, bottom) {
    const alpha = top[3] + bottom[3] * (1 - top[3]);
    return [...top.slice(0,3).map((v,i) => (v*top[3] + bottom[i]*bottom[3]*(1-top[3]))/alpha), alpha];
  }
  function luminance(color) {
    const linear = color.slice(0,3).map(v => { v /= 255; return v <= .04045 ? v / 12.92 : ((v+.055)/1.055)**2.4; });
    return linear[0]*.2126 + linear[1]*.7152 + linear[2]*.0722;
  }
  try {
    let background = [0,0,0,0];
    const surfaces = [];
    for (let ancestor = el; ancestor; ancestor = ancestor.parentElement) {
      const style = getComputedStyle(ancestor);
      if (style.opacity !== '1' || style.filter !== 'none' || style.mixBlendMode !== 'normal') return fail('Opacity/filter/blend requires a pixel audit');
      if (background[3] < 1) {
        if (style.backgroundImage !== 'none') return fail('Background image/gradient requires a pixel audit');
        for (const pseudo of ['::before','::after']) {
          const paint = getComputedStyle(ancestor, pseudo);
          if (!['none','normal'].includes(paint.content) && paint.display !== 'none' && (paint.backgroundImage !== 'none' || rgba(paint.backgroundColor)[3] > 0)) return fail('Painted pseudo-element requires a pixel audit');
        }
        const color = rgba(style.backgroundColor);
        surfaces.push({tag:ancestor.tagName, class:ancestor.className, color:style.backgroundColor});
        background = background[3] === 0 ? color : over(background, color);
      }
      // Ancestor opacity/filter still matters even after finding opaque paint.
    }
    if (background[3] < 1) return fail('No opaque rendered background; canvas assumption is forbidden');
    if (negative) el.style.setProperty('color', `rgb(${background.slice(0,3).join(',')})`, 'important');
    const foreground = rgba(getComputedStyle(el).color);
    const paintedForeground = over(foreground, background);
    const a = luminance(paintedForeground), b = luminance(background);
    const ratio = (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
    return {selector, text:el.textContent.trim(), pass:ratio >= 4.5, ratio, foreground, background, surfaces};
  } catch (error) { return fail(error.message); }
}
