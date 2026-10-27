// Browser qualification of the V5 homepage: Inspect the Mark, Inspect the
// Receipt and its same-origin truth binding, failure states, keyboard and
// touch operation, layout width and the no-JavaScript fallback.
// Build public/ first, then:
//   node scripts/test-home-v5-browser.mjs [--shots <new-directory>]
// Serves public/ on loopback and drives Chrome over CDP. Failure states are
// injected into the page's own requests for /truth/ and /proof/index.json;
// production is never contacted. Which records should validate is decided by
// the built pf-truth-receipt.js, which check-home-receipt-truth.ps1 holds to
// an independent JSON Schema validator; everything shown is compared with the
// raw records.
import { spawn, spawnSync } from 'node:child_process';
import { inflateSync } from 'node:zlib';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readdirSync } from 'node:fs';
import { mkdtemp, readFile, realpath, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const publicDir = path.join(root, 'public');
const args = process.argv.slice(2);
const shotsDir = args.includes('--shots') ? path.resolve(args[args.indexOf('--shots') + 1] || '') : null;
if (shotsDir) {
  if (existsSync(shotsDir) && readdirSync(shotsDir).length) throw new Error('--shots needs a new or empty directory.');
  mkdirSync(shotsDir, { recursive: true });
}
if (process.env.PF_H9_BROWSER && !existsSync(process.env.PF_H9_BROWSER)) throw new Error(`PF_H9_BROWSER names a missing file: ${process.env.PF_H9_BROWSER}`);
const browserPath = [process.env.PF_H9_BROWSER, 'C:/Program Files/Google/Chrome/Application/chrome.exe'].filter(Boolean).find(existsSync);
if (!browserPath) throw new Error('Chrome is required (or set PF_H9_BROWSER to a Chrome executable).');
if (!existsSync(path.join(publicDir, 'index.html'))) throw new Error('Build public/ first.');

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const results = [];
function check(name, condition, evidence) {
  const pass = Boolean(condition);
  results.push({ name, pass, evidence });
  process.stdout.write(`${pass ? 'PASS' : 'FAIL'}: ${name}${pass ? '' : ` ${JSON.stringify(evidence).slice(0, 700)}`}\n`);
}
// Minimal PNG reader for CDP screenshots (8-bit RGB/RGBA, not interlaced) and
// a WCAG contrast count, so forced-colours visibility is measured, not assumed.
function decodePng(buf) {
  let pos = 8, width = 0, height = 0, bitDepth = 0, colorType = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { width = data.readUInt32BE(0); height = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; if (data[12]) throw new Error('interlaced PNG'); }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (bitDepth !== 8 || ![2, 6].includes(colorType)) throw new Error(`unsupported PNG ${bitDepth}/${colorType}`);
  const bpp = colorType === 6 ? 4 : 3, stride = width * bpp, raw = inflateSync(Buffer.concat(idat)), out = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, b = y ? out[(y - 1) * stride + x] : 0, c = x >= bpp && y ? out[(y - 1) * stride + x - bpp] : 0;
      const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
      out[y * stride + x] = (line[x] + [0, a, b, (a + b) >> 1, pa <= pb && pa <= pc ? a : pb <= pc ? b : c][filter]) & 255;
    }
  }
  return { width, height, bpp, data: out };
}
const luminance = ([r, g, b]) => { const f = (v) => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
const contrast = (x, y) => { const [hi, lo] = [luminance(x), luminance(y)].sort((m, n) => n - m); return (hi + 0.05) / (lo + 0.05); };
const within = (base, file) => { const r = path.relative(base, file); return r === '' || (!r.startsWith('..') && !path.isAbsolute(r)); };
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8' };

let cacheable = false;
const hits = new Map();
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
    hits.set(pathname, (hits.get(pathname) || 0) + 1);
    let file = path.resolve(publicDir, '.' + pathname);
    if (!within(publicDir, file)) { response.writeHead(403).end(); return; }
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    const real = await realpath(file);
    if (!within(publicDir, real)) { response.writeHead(403).end(); return; }
    const body = await readFile(real);
    // Only the JSON records become cacheable; images stay no-store so a later
    // forced-colours check never reads a cached, earlier rendering.
    if (cacheable && pathname.endsWith('.json')) {
      const etag = `"${createHash('sha256').update(body).digest('hex').slice(0, 16)}"`;
      if (request.headers['if-none-match'] === etag) { response.writeHead(304, { ETag: etag, 'Cache-Control': 'max-age=3600' }).end(); return; }
      response.writeHead(200, { 'Content-Type': mime[path.extname(real)] || 'application/octet-stream', 'Content-Length': body.length, 'Cache-Control': 'max-age=3600', ETag: etag }).end(body);
      return;
    }
    response.writeHead(200, { 'Content-Type': mime[path.extname(real)] || 'application/octet-stream', 'Content-Length': body.length, 'Cache-Control': 'no-store' }).end(body);
  } catch { response.writeHead(404, { 'Content-Type': 'text/plain' }).end('not found'); }
});

let browser, profile, socket;
try {
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  const local = async (p) => JSON.parse(await readFile(path.join(publicDir, p.replace(/^\//, '')), 'utf8'));
  const clone = (v) => JSON.parse(JSON.stringify(v));
  const { buildReceipt } = await import(pathToFileURL(path.join(publicDir, 'pf-truth-receipt.js')).href);

  profile = await mkdtemp(path.join(tmpdir(), 'pf-home-v5-browser-'));
  browser = spawn(browserPath, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--disable-background-networking', '--disable-component-update', '--disable-sync', '--no-first-run', '--no-default-browser-check', '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  browser.stderr.on('data', () => {});
  let port;
  for (let i = 0; i < 100 && !port; i++) {
    if (browser.exitCode !== null) throw new Error(`Browser exited ${browser.exitCode}`);
    const portFile = path.join(profile, 'DevToolsActivePort');
    if (existsSync(portFile)) port = Number((await readFile(portFile, 'utf8')).split(/\r?\n/)[0]);
    else await pause(100);
  }
  if (!port) throw new Error('Browser CDP port unavailable.');
  const browserVersion = await fetch(`http://127.0.0.1:${port}/json/version`).then((r) => r.json());
  check(`a real browser answers over CDP: ${browserVersion.Browser} (${path.basename(browserPath)})`, /^(HeadlessChrome|Chrome|Edg)\//.test(browserVersion.Browser || ''), browserVersion);
  const target = await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' }).then((r) => r.json());
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });

  let sequence = 0;
  const pending = new Map();
  const listeners = new Map();
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const entry = pending.get(message.id); pending.delete(message.id); clearTimeout(entry.timer);
      message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
    } else if (message.method) [...(listeners.get(message.method) || [])].forEach((fn) => fn(message.params));
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 60000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const on = (method, fn) => { listeners.set(method, [...(listeners.get(method) || []), fn]); return () => listeners.set(method, listeners.get(method).filter((f) => f !== fn)); };
  const next = (method, timeout = 30000) => new Promise((resolve, reject) => {
    const timer = setTimeout(() => { off(); reject(new Error(`No ${method} within ${timeout} ms`)); }, timeout);
    const off = on(method, (params) => { clearTimeout(timer); off(); resolve(params); });
  });
  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    return result.result.value;
  };
  const waitFor = async (expression, timeout = 15000) => {
    for (let waited = 0; waited < timeout; waited += 100) { if (await evaluate(expression)) return true; await pause(100); }
    return false;
  };

  const errors = [];
  on('Runtime.exceptionThrown', (p) => errors.push(p.exceptionDetails.exception?.description || p.exceptionDetails.text));
  on('Runtime.consoleAPICalled', (p) => { if (p.type === 'error') errors.push(p.args.map((a) => a.value).join(' ')); });
  await send('Page.enable');
  await send('Runtime.enable');

  // Faults: path -> { status, body } served in place of the page's own request,
  // or { fail: true } for a request that never reaches the server.
  let faults = null;
  const seen = new Map();
  on('Fetch.requestPaused', (p) => {
    const pathname = new URL(p.request.url).pathname;
    seen.set(pathname, (seen.get(pathname) || 0) + 1);
    const fault = faults && faults[pathname];
    if (!fault) { send('Fetch.continueRequest', { requestId: p.requestId }).catch(() => {}); return; }
    if (fault.delay) {
      const { delay, ...rest } = fault;
      setTimeout(() => { released.set(pathname, Date.now()); respond(p, Object.keys(rest).length ? rest : null); }, delay);
      return;
    }
    respond(p, fault);
  });
  const released = new Map();
  function respond(p, fault) {
    if (!fault) { send('Fetch.continueRequest', { requestId: p.requestId }).catch(() => {}); return; }
    if (fault.fail) { send('Fetch.failRequest', { requestId: p.requestId, errorReason: 'ConnectionRefused' }).catch(() => {}); return; }
    send('Fetch.fulfillRequest', { requestId: p.requestId, responseCode: fault.status || 200, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Cache-Control', value: 'no-store' }], body: Buffer.from(fault.body).toString('base64') }).catch(() => {});
  }
  async function setFaults(map) {
    faults = map;
    if (map) await send('Fetch.enable', { patterns: [{ urlPattern: '*/truth/*' }, { urlPattern: '*/proof/index.json' }] });
    else await send('Fetch.disable');
  }

  async function viewport(width, mobile = width < 768) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: mobile ? 844 : 900, deviceScaleFactor: 1, mobile });
    await send('Emulation.setTouchEmulationEnabled', { enabled: mobile, maxTouchPoints: mobile ? 5 : 1 });
  }
  async function go(route = '/') {
    errors.length = 0;
    const loaded = next('Page.loadEventFired');
    await send('Page.navigate', { url: origin + route });
    await loaded;
    await evaluate('document.fonts.ready.then(() => true)');
    await pause(250);
  }
  const KEYS = { Enter: [13, '\r'], ' ': [32, ' '], Escape: [27], ArrowRight: [39], ArrowLeft: [37], Home: [36], End: [35], Tab: [9] };
  async function key(name) {
    const [code, text] = KEYS[name];
    const base = { key: name, code: name === ' ' ? 'Space' : name, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code };
    await send('Input.dispatchKeyEvent', text ? { type: 'keyDown', text, unmodifiedText: text, ...base } : { type: 'rawKeyDown', ...base });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
    await pause(120);
  }
  const focus = (selector) => evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); e.scrollIntoView({ block: 'center', behavior: 'instant' }); e.focus(); return document.activeElement === e; })()`);
  async function tap(selector) {
    await waitFor(`!!document.querySelector(${JSON.stringify(selector)})`);
    const point = await evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); e.scrollIntoView({ block: 'center', behavior: 'instant' }); const r = e.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; })()`);
    await pause(100);
    await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: point.x, y: point.y, radiusX: 0.5, radiusY: 0.5, force: 0.5 }] });
    await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await pause(250);
  }
  // Pixels of an element, scrolled into view, drawn in the palette colour `ink`
  // (within 8 per channel) and at 3:1 or more against `canvas`. Matching the
  // palette colour, not just any contrast, proves forced colours were applied.
  async function paletteInk(selector, ink, canvas, inset = 0) {
    const rect = await evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); e.scrollIntoView({ block: 'center', behavior: 'instant' }); const b = e.getBoundingClientRect(); return { x: b.left + scrollX, y: b.top + scrollY, width: b.width, height: b.height }; })()`);
    await pause(120);
    const clip = { x: rect.x + inset, y: rect.y + inset, width: Math.max(1, rect.width - 2 * inset), height: Math.max(1, rect.height - 2 * inset), scale: 1 };
    const { data } = await send('Page.captureScreenshot', { format: 'png', clip });
    const img = decodePng(Buffer.from(data, 'base64'));
    let n = 0;
    for (let i = 0; i < img.data.length; i += img.bpp) {
      const px = [img.data[i], img.data[i + 1], img.data[i + 2]];
      if (px.every((v, k) => Math.abs(v - ink[k]) <= 8) && contrast(px, canvas) >= 3) n++;
    }
    return n;
  }
  async function shot(name) {
    if (!shotsDir) return;
    // Let finite animations (the dialog fade-in) finish so captures are settled.
    await evaluate(`Promise.race([Promise.all(document.getAnimations().filter((a) => a.effect && a.effect.getComputedTiming().endTime !== Infinity).map((a) => a.finished.catch(() => {}))), new Promise((r) => setTimeout(r, 2000))]).then(() => true)`);
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    await writeFile(path.join(shotsDir, `${name}.png`), Buffer.from(data, 'base64'));
  }
  const panelSettled = `(() => { const p = document.getElementById('pf-receipt-panel'); return !!p && !p.hasAttribute('aria-busy') && !!p.querySelector('.pf-rc-top, .pf-rc-fail'); })()`;
  const tabsBuilt = (count) => `document.querySelectorAll('#pf-receipt-dialog [role="tab"]').length === ${count}`;
  // artifactDigests: digests outside the source trail (which names the release
  // model's SHA-256), the disagreement table (which quotes each conflicting
  // value) and the limitations (authored text, which may quote a certificate
  // fingerprint). allDigests: every digest in the panel.
  const panelState = () => evaluate(`(() => {
    const d = document.getElementById('pf-receipt-dialog'), p = document.getElementById('pf-receipt-panel');
    const text = (el) => { if (!el) return null; const c = el.cloneNode(true); c.querySelectorAll('.ledger-sr').forEach((s) => s.remove()); return c.textContent.replace(/\\s+/g, ' ').trim(); };
    const dl = (root) => root ? Object.fromEntries([...root.querySelectorAll(':scope > dt')].map((dt) => [dt.textContent, text(dt.nextElementSibling)])) : {};
    const bare = p.cloneNode(true); bare.querySelectorAll('.pf-rc-src, .pf-rc-conflicts, .pf-rc-list').forEach((n) => n.remove());
    return {
      open: d.open, title: document.getElementById('pf-receipt-title').textContent,
      status: document.querySelector('[data-receipt-status]').textContent,
      receipt: !!p.querySelector('.pf-rc-top') && !p.querySelector('.pf-rc-fail'), failed: !!p.querySelector('.pf-rc-fail'),
      chip: text(p.querySelector('.pf-rc-top .pf-chip, .pf-rc-fail .pf-chip')),
      heading: text(p.querySelector('.pf-rc-fail h3')),
      artifacts: [...p.querySelectorAll('.pf-art')].map((a) => ({ file: text(a.querySelector('b')), sha: text(a.querySelector('.pf-art-row code')), size: Number((text(a.querySelector('.pf-art-meta')) || '').replace(/^.*?([0-9,]+) bytes.*$/, '$1').replace(/,/g, '')) || null })),
      copies: p.querySelectorAll('.pf-art .pf-copy').length,
      command: text(p.querySelector('.pf-rc-cmd code')),
      evidence: [...p.querySelectorAll('.pf-rc-ev > *')].map((n) => n.tagName === 'A' ? n.getAttribute('href') : 'TEXT:' + text(n)),
      tests: [...p.querySelectorAll('.pf-rc-tests > div')].map((r) => [text(r.querySelector('dt')), text(r.querySelector('dd'))]),
      limits: [...p.querySelectorAll('.pf-rc-list li')].map(text),
      trail: dl(p.querySelector('.pf-rc-src dl')),
      fetched: p.querySelector('.pf-rc-src time, .pf-rc-when time')?.dateTime || null,
      conflicts: [...p.querySelectorAll('.pf-rc-conflicts tbody th')].map(text),
      artifactDigests: (bare.textContent.match(/[0-9a-f]{64}/g) || []).length,
      allDigests: p.textContent.match(/[0-9a-f]{64}/g) || [],
      text: text(p).slice(0, 900),
      tabs: [...document.querySelectorAll('#pf-receipt-dialog [role="tab"]')].map((t) => ({ id: t.id, selected: t.getAttribute('aria-selected') })),
      tablist: document.querySelector('[data-receipt-tabs]').getAttribute('role'),
      focusInDialog: d.contains(document.activeElement),
    };
  })()`);
  const state = () => evaluate(`({ active: document.activeElement && (document.activeElement.id || document.activeElement.className), receipt: document.activeElement && document.activeElement.dataset.receiptOpen, y: Math.round(scrollY), markOpen: document.getElementById('pf-mark-dialog').open, receiptOpen: document.getElementById('pf-receipt-dialog').open })`);
  // Content past either viewport edge that no clipping ancestor inside the
  // viewport hides, plus the document's own scroll width.
  const overflow = () => evaluate(`(() => {
    const vw = document.documentElement.clientWidth, off = [];
    const clipped = (e) => { for (let a = e.parentElement; a && a !== document.documentElement; a = a.parentElement) { if (getComputedStyle(a).overflowX !== 'visible') { const r = a.getBoundingClientRect(); if (r.left >= -0.5 && r.right <= vw + 0.5) return true; } } return false; };
    for (const e of document.querySelectorAll('body *')) {
      if (e.closest('dialog:not([open]), .ledger-sr, .skip-link')) continue;
      const r = e.getBoundingClientRect();
      if (!r.width || !r.height || (r.right <= vw + 0.5 && r.left >= -0.5)) continue;
      if (!clipped(e)) off.push(e.tagName.toLowerCase() + (typeof e.className === 'string' && e.className ? '.' + e.className.trim().split(/\\s+/).join('.') : '') + ' ' + Math.round(r.left) + '..' + Math.round(r.right));
    }
    return { scroll: document.documentElement.scrollWidth, vw, off: off.slice(0, 8) };
  })()`);

  const schema = await local('/truth/schema-v1.json');
  const index = await local('/truth/index.json');
  const registry = await local('/proof/index.json');
  const home = await readFile(path.join(publicDir, 'index.html'), 'utf8');
  const receiptIds = [...new Set([...home.matchAll(/data-receipt-open="([a-z0-9-]+)"/g)].map((m) => m[1]))];
  const featureIds = [...home.matchAll(/data-ledger-feature="([a-z0-9-]+)"/g)].map((m) => m[1]);
  const specimenId = (home.match(/data-ledger-specimen="([a-z0-9-]+)"/) || [])[1];
  const records = Object.fromEntries(await Promise.all(receiptIds.map(async (id) => [id, await local(`/truth/products/${id}.json`)])));
  const expected = Object.fromEntries(receiptIds.map((id) => [id, buildReceipt({ id, schema, index, record: records[id], registry })]));
  check('the homepage offers receipts for its specimen and featured products', specimenId && featureIds.length === 3 && receiptIds.includes(specimenId) && featureIds.every((id) => receiptIds.includes(id)), { specimenId, featureIds, receiptIds });

  // ── Layout: no horizontal overflow, no script errors ─────────────────────
  for (const width of [360, 390, 768, 1024, 1440, 1920]) {
    await viewport(width);
    await go('/');
    const o = await overflow();
    check(`${width}px: no horizontal overflow`, o.scroll <= o.vw && o.off.length === 0, o);
    check(`${width}px: no script errors`, errors.length === 0, errors);
    await shot(`home-${width}`);
  }

  // ── Before anything opens: one product digest, no outside evidence ───────
  const page = await evaluate(`({ digests: document.body.innerText.match(/[0-9a-f]{64}/g) || [], external: [...document.querySelectorAll('body a[href^="http"]')].map((a) => a.href) })`);
  const specimenDigests = records[specimenId].artifacts.map((a) => a.sha256).filter(Boolean);
  check('the page shows one product digest, the specimen\'s, until a receipt is opened', page.digests.length === 1 && specimenDigests.includes(page.digests[0]), page.digests);
  check('the page links no outside evidence of its own', page.external.length === 0, page.external);

  // ── No JavaScript: the essential record stays readable, no dead controls ─
  for (const width of [390, 1440]) {
    await viewport(width);
    await send('Emulation.setScriptExecutionDisabled', { value: true });
    await go('/');
    const nojs = await evaluate(`(() => {
      const visible = (e) => !!e && e.getClientRects().length > 0 && getComputedStyle(e).visibility !== 'hidden';
      const spec = document.querySelector('[data-ledger-specimen]');
      const hash = spec && spec.querySelector('code.ledger-hash');
      return {
        triggers: [...document.querySelectorAll('[data-receipt-open], [data-mark-open]')].filter(visible).length,
        dialogsOpen: [...document.querySelectorAll('dialog')].filter((d) => d.open || visible(d)).length,
        hash: hash && visible(hash) ? hash.textContent : null,
        limitations: !!(spec && spec.querySelector('details summary')),
        specimenLinks: spec ? [...spec.querySelectorAll('a')].map((a) => a.getAttribute('href')) : [],
        featureLinks: [...document.querySelectorAll('[data-ledger-feature] a[href^="/truth-files/"]')].filter(visible).length,
        captions: [...document.querySelectorAll('[data-ledger-feature] figcaption')].filter(visible).map((c) => c.textContent.trim().length),
        overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      };
    })()`);
    check(`${width}px without JavaScript: no inspect control or dialog is shown`, nojs.triggers === 0 && nojs.dialogsOpen === 0, nojs);
    check(`${width}px without JavaScript: the specimen keeps its full SHA-256, limitations and record links`, specimenDigests.includes(nojs.hash) && nojs.limitations && nojs.specimenLinks.includes(`/proof/#receipt-${specimenId}`) && nojs.specimenLinks.includes(`/truth-files/${specimenId}/`), nojs);
    check(`${width}px without JavaScript: every featured product keeps its Truth File link and caption, with no overflow`, nojs.featureLinks === 3 && nojs.captions.length === 3 && nojs.captions.every((n) => n > 0) && !nojs.overflow, nojs);
    await shot(`no-js-${width}`);
    await send('Emulation.setScriptExecutionDisabled', { value: false });
  }

  // ── Inspect the Mark, by keyboard ────────────────────────────────────────
  await viewport(1440);
  await go('/');
  const lights = await evaluate(`({ motion: document.documentElement.dataset.motion, light: getComputedStyle(document.querySelector('.pf-lm')).display })`);
  check('desktop with motion on: the emblem highlights are available', lights.motion === 'on' && lights.light !== 'none', lights);
  await focus('[data-mark-open]');
  let before = await state();
  await key('Enter');
  await waitFor(`document.getElementById('pf-mark-dialog').open`);
  const mark = await evaluate(`({ pins: document.querySelectorAll('.pf-pin').length, items: document.querySelectorAll('.pf-mk-list button').length, focusInside: document.getElementById('pf-mark-dialog').contains(document.activeElement), first: document.querySelector('[data-mark-count]').textContent })`);
  check('Enter opens Inspect the Mark with ten points and focus inside', mark.pins === 10 && mark.items === 10 && mark.focusInside && mark.first === 'Point 1 of 10', mark);
  await focus('.pf-mk-list li:nth-child(6) button');
  await key(' ');
  const point = await evaluate(`({ count: document.querySelector('[data-mark-count]').textContent, title: document.querySelector('[data-mark-title]').textContent, loupe: !document.querySelector('.pf-loupe').hidden, overlay: document.querySelector('.pf-mk-svg').children.length, pressed: [...document.querySelectorAll('.pf-mk-list button')].map((b) => b.getAttribute('aria-pressed')).indexOf('true') })`);
  check('Space on a point updates the detail, loupe and outline', point.count === 'Point 6 of 10' && point.title.length > 0 && point.loupe && point.overlay > 0 && point.pressed === 5, point);
  await shot('mark-1440');
  await key('Escape');
  let after = await state();
  check('Escape closes Inspect the Mark and returns focus and scroll', !after.markOpen && /pf-inspect/.test(after.active) && after.y === before.y, { before, after });

  // ── Inspect the Receipt, by keyboard, with same-origin parity ────────────
  await evaluate(`(() => { window.__copied = []; navigator.clipboard.writeText = async (t) => { window.__copied.push(t); }; return true; })()`);
  await focus(`[data-ledger-specimen] [data-receipt-open]`);
  before = await state();
  await key('Enter');
  await waitFor(panelSettled);
  await waitFor(tabsBuilt(receiptIds.length));
  await waitFor(`document.querySelector('[data-receipt-status]').textContent.length > 0`);
  let s = await panelState();
  const specimenRecord = records[specimenId];
  check('Enter on the specimen opens its validated receipt with focus inside', s.open && s.receipt && s.focusInDialog && s.title === `${specimenRecord.name} v${specimenRecord.version} — public release record` && s.status === `${specimenRecord.name} v${specimenRecord.version}: record loaded and validated.`, s);
  check('receipt tabs are built from the validated index, specimen selected', s.tablist === 'tablist' && s.tabs.length === receiptIds.length && s.tabs.find((t) => t.selected === 'true')?.id === `pf-receipt-tab-${specimenId}`, s.tabs);
  await evaluate(`document.querySelector('#pf-receipt-panel .pf-art .pf-copy').click()`);
  const copied = await evaluate('window.__copied');
  check('Copy SHA-256 copies exactly the first published digest', copied.length === 1 && copied[0] === specimenRecord.artifacts[0].sha256, copied);
  await shot('receipt-1440');

  for (const id of receiptIds) {
    await evaluate(`document.getElementById('pf-receipt-tab-${id}').click()`);
    await waitFor(`document.getElementById('pf-receipt-tab-${id}').getAttribute('aria-selected') === 'true' && ${panelSettled}`);
    s = await panelState();
    const record = records[id];
    const want = expected[id];
    if (!want.ok) {
      const listedName = index.products.find((p) => p.id === id)?.name;
      check(`${id}: a record that does not validate shows no receipt and no digest`, s.failed && !s.receipt && s.artifactDigests === 0 && s.copies === 0 && s.text.includes(want.detail) && s.heading === `${listedName}: the public record could not be verified here.`, { want: want.detail, heading: s.heading, shown: s.text });
      await shot(`receipt-${id}-refused-1440`);
      continue;
    }
    const entry = registry.products.find((p) => p.id === id);
    const shape = (list) => list.map((a) => ({ file: a.filename, sha: a.sha256, size: a.sizeBytes ?? null }));
    check(`${id}: every artifact, full SHA-256 and size equals /truth/ and /proof/index.json`, s.receipt && JSON.stringify(s.artifacts) === JSON.stringify(shape(record.artifacts)) && JSON.stringify(s.artifacts) === JSON.stringify(shape(entry.artifacts)) && s.copies === record.artifacts.filter((a) => a.sha256).length, { shown: s.artifacts, record: shape(record.artifacts) });
    const primary = record.artifacts.find((a) => record.download && record.download.url && a.downloadUrl === record.download.url) || record.artifacts.find((a) => a.sha256);
    check(`${id}: the verify command names the primary artifact`, s.command === (primary ? `Get-FileHash ".\\${primary.filename}" -Algorithm SHA256` : null), s.command);
    const listed = [...new Set([...(record.evidence || []).map((e) => e.url), ...(record.proofLinks || [])].filter(Boolean))];
    check(`${id}: evidence links are exactly the record's, every one rendered`, JSON.stringify(s.evidence) === JSON.stringify(listed), { rendered: s.evidence, listed });
    check(`${id}: test results come from the record and limitations from /proof/index.json`, JSON.stringify(s.tests) === JSON.stringify((record.tests || []).map((t) => [t.label, t.result])) && JSON.stringify(s.limits) === JSON.stringify(entry.limits), { tests: s.tests, limits: s.limits });
    check(`${id}: source trail names the schema, record, release authority, website commit, tree and time`, s.trail.Schema === schema.$id && s.trail.Record === `/truth/products/${id}.json (listed in /truth/index.json)` && s.trail['Release context'] === '/proof/index.json' && s.trail['Release authority'] === `release-truth.json (model SHA-256 ${registry.releaseFactsSource.modelSha256})` && s.trail['Website commit'] === record.source.commit && s.trail['Website commit'] === index.source.commit && s.trail['Source tree'] === record.source.tree && s.trail.Committed === record.source.committedAt && s.trail.Committed === registry.generatedAt, s.trail);
    check(`${id}: website commit, product source commit and artifact digests stay separate`, (!record.release.sourceCommit || record.release.sourceCommit !== record.source.commit) && s.text.includes(`Product source commit`) === Boolean(record.release.sourceCommit), { website: record.source.commit, product: record.release.sourceCommit });
  }

  await focus(`#pf-receipt-tab-${receiptIds[0]}`);
  await key('ArrowRight');
  const movedTo = await evaluate('document.activeElement.id');
  await waitFor(panelSettled);
  check('ArrowRight moves to and shows the next receipt', movedTo === `pf-receipt-tab-${receiptIds[1]}` && (await panelState()).tabs.find((t) => t.selected === 'true')?.id === movedTo, movedTo);
  await key('End');
  check('End moves to the last receipt tab', (await evaluate('document.activeElement.id')) === `pf-receipt-tab-${receiptIds.at(-1)}`);
  await key('Home');
  check('Home moves to the first receipt tab', (await evaluate('document.activeElement.id')) === `pf-receipt-tab-${receiptIds[0]}`);
  await waitFor(panelSettled);
  await key('Escape');
  after = await state();
  check('Escape closes the receipt and returns focus and scroll to its trigger', !after.receiptOpen && after.receipt === specimenId && after.y === before.y, { before, after });
  await focus(`[data-ledger-feature="${featureIds[0]}"] [data-receipt-open]`);
  await key(' ');
  await waitFor(panelSettled);
  s = await panelState();
  check('Space on a featured product opens its receipt', s.open && s.tabs.find((t) => t.selected === 'true')?.id === `pf-receipt-tab-${featureIds[0]}`, s.tabs);
  await key('Escape');
  check('no script errors while inspecting', errors.length === 0, errors);

  // ── Missing, stale, conflicting, invalid and withdrawn records ───────────
  const featured = featureIds.find((id) => id !== specimenId && expected[id].ok && records[id].artifacts.some((a) => a.sha256));
  const record = records[featured];
  const recordPath = `/truth/products/${featured}.json`;
  const unverified = `${record.name}: the public record could not be verified here.`;
  const disagreeing = `${record.name}: the published records disagree.`;
  const scenarios = [
    { name: 'missing record', faults: { [recordPath]: { status: 404, body: 'not found' } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes(`${recordPath} answered HTTP 404.`) && /Try again/.test(s.text) && s.artifactDigests === 0 },
    // Try again must fetch every record afresh, not only the one that failed: here
    // the registry answered the first attempt with another build's digest.
    { name: 'record missing while the proof registry is stale', faults: { [recordPath]: { status: 404, body: 'not found' }, '/proof/index.json': { body: JSON.stringify((() => { const r = clone(registry); r.products.find((p) => p.id === featured).artifacts[0].sha256 = 'e'.repeat(64); return r; })()) } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes(`${recordPath} answered HTTP 404.`) && /Try again/.test(s.text) && s.artifactDigests === 0 },
    // Refresh: every load failure offers Try again, which fetches the records afresh.
    { name: 'record that is not JSON', faults: { [recordPath]: { body: '<!doctype html><title>Not found</title>' } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes(`${recordPath} is not valid JSON.`) && /Try again/.test(s.text) && s.artifactDigests === 0 && s.copies === 0 },
    { name: 'record that cannot be reached', faults: { [recordPath]: { fail: true } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes(`${recordPath} could not be reached.`) && /Try again/.test(s.text) && s.artifactDigests === 0 && s.copies === 0 },
    { name: 'schema answering HTTP 500', faults: { '/truth/schema-v1.json': { status: 500, body: 'error' } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.text.includes('/truth/schema-v1.json answered HTTP 500.') && /Try again/.test(s.text) && s.artifactDigests === 0 && s.copies === 0 },
    { name: 'proof registry answering HTTP 500', faults: { '/proof/index.json': { status: 500, body: 'error' } }, retry: true,
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.text.includes('/proof/index.json answered HTTP 500.') && /Try again/.test(s.text) && s.artifactDigests === 0 && s.copies === 0 },
    { name: 'stale record from an earlier build', retry: true, faults: { [recordPath]: { body: JSON.stringify({ ...clone(record), source: { commit: '0'.repeat(40), tree: '1'.repeat(40), committedAt: '2026-09-01T09:00:00-07:00' } }) } },
      expect: (s) => s.failed && s.title === 'Release records disagree' && s.heading === disagreeing && ['website source commit', 'website source tree', 'website source time'].every((f) => s.conflicts.includes(f)) && s.artifactDigests === 0 && s.copies === 0 },
    { name: 'proof registry stating a different digest', retry: true, faults: { '/proof/index.json': { body: JSON.stringify((() => { const r = clone(registry); r.products.find((p) => p.id === featured).artifacts[0].sha256 = 'f'.repeat(64); return r; })()) } },
      expect: (s) => s.failed && s.title === 'Release records disagree' && s.heading === disagreeing && JSON.stringify(s.conflicts) === JSON.stringify(['artifact 1 SHA-256']) && s.artifactDigests === 0 && s.copies === 0 && /do not use them to verify a download/.test(s.text) },
    { name: 'proof registry stating another signing status', retry: true, faults: { '/proof/index.json': { body: JSON.stringify((() => { const r = clone(registry); r.products.find((p) => p.id === featured).artifacts[0].signingStatus = 'PRODUCTION_SIGNED'; return r; })()) } },
      expect: (s) => s.failed && s.title === 'Release records disagree' && s.heading === disagreeing && JSON.stringify(s.conflicts) === JSON.stringify(['artifact 1 signing status']) && s.artifactDigests === 0 && s.copies === 0 && !/SIGNED/.test(s.chip || '') },
    { name: 'record without its optional artifacts list', retry: true, faults: { [recordPath]: { body: JSON.stringify((() => { const r = clone(record); delete r.artifacts; return r; })()) } },
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes('could not be checked in this browser') && s.artifactDigests === 0 },
    { name: 'proof registry from another build', retry: true, faults: { '/proof/index.json': { body: JSON.stringify({ ...clone(registry), generatedAt: '2026-09-01T09:00:00-07:00' }) } },
      expect: (s) => s.failed && s.title === 'Release records disagree' && s.heading === disagreeing && JSON.stringify(s.conflicts) === JSON.stringify(['website source time']) && s.artifactDigests === 0 },
    { name: 'record that is not schema-valid', retry: true, faults: { [recordPath]: { body: JSON.stringify({ ...clone(record), trustScore: 100 }) } },
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === unverified && s.text.includes('/trustScore is not an allowed field') && s.artifactDigests === 0 },
    { name: 'index that is not schema-valid', retry: true, faults: { '/truth/index.json': { body: JSON.stringify({ ...clone(index), productCount: 'seven' }) } },
      expect: (s) => s.failed && s.title === 'Release record not shown' && s.heading === 'This product: the public record could not be verified here.' && s.text.includes('/truth/index.json does not conform to /truth/schema-v1.json') && s.tabs.length === 0 && s.artifactDigests === 0 },
    { name: 'withdrawn release stated by every record',
      faults: (() => {
        const w = clone(record);
        Object.assign(w, { status: 'WITHDRAWN', state: 'withdrawn', version: null, artifacts: [] });
        Object.assign(w.release, { releaseStatus: 'WITHDRAWN', publicVersion: null, companionPublicVersion: null, withdrawnVersion: record.version, withdrawalReason: 'Fixture withdrawal' });
        Object.assign(w.download, { available: false, url: null, sha256: null, sha256Url: null, label: null });
        const i = clone(index); Object.assign(i.products.find((p) => p.id === featured), { status: 'WITHDRAWN', state: 'withdrawn', version: null });
        const r = clone(registry); const e = r.products.find((p) => p.id === featured); e.productStatus = 'WITHDRAWN'; Object.assign(e.release, { releaseStatus: 'WITHDRAWN', publicVersion: null, withdrawnVersion: record.version, withdrawalReason: 'Fixture withdrawal' }); e.artifacts = [];
        return { [recordPath]: { body: JSON.stringify(w) }, '/truth/index.json': { body: JSON.stringify(i) }, '/proof/index.json': { body: JSON.stringify(r) } };
      })(),
      expect: (s) => s.receipt && s.chip === 'WITHDRAWN' && s.title === `${record.name} — withdrawn release record` && s.artifactDigests === 0 && !s.allDigests.some((d) => record.artifacts.some((a) => a.sha256 === d)) && s.copies === 0 && !s.command && /Fixture withdrawal/.test(s.text) && /None\. The release is withdrawn\./.test(s.text) },
  ];
  for (const scenario of scenarios) {
    await viewport(1440);
    await setFaults(scenario.faults);
    await go('/');
    await evaluate(`document.querySelector('[data-ledger-feature="${featured}"] [data-receipt-open]').click()`);
    await waitFor(panelSettled);
    s = await panelState();
    check(`${scenario.name}: shown as such, never as a valid receipt`, scenario.expect(s), { title: s.title, chip: s.chip, conflicts: s.conflicts, digests: s.artifactDigests, text: s.text.slice(0, 400) });
    await shot(`state-${scenario.name.replace(/[^a-z]+/gi, '-').toLowerCase()}-1440`);
    if (scenario.retry) {
      const refusedAt = s.fetched;
      await setFaults(null);
      await pause(20);
      const offered = await evaluate(`(() => { const b = [...document.querySelectorAll('#pf-receipt-panel button')].find((x) => x.textContent === 'Try again'); if (b) b.click(); return !!b; })()`);
      if (offered) {
        await waitFor(`${panelSettled} && !!document.querySelector('#pf-receipt-panel .pf-rc-top')`);
        s = await panelState();
      }
      check(`${scenario.name}: Try again loads the record once it is served, with a later fetch time`, offered && s.receipt && s.artifacts.length === record.artifacts.length && s.title === `${record.name} v${record.version} — public release record` && !!refusedAt && Date.parse(s.fetched) > Date.parse(refusedAt), { offered, refusedAt, fetched: s.fetched, title: s.title, text: s.text.slice(0, 200) });
    }
    await setFaults(null);
  }

  // ── Refresh: every view is one freshly fetched, coherent snapshot ───────
  // A later deploy is simulated by serving a coherent build with the same
  // release facts but another website source identity.
  const snapUrls = (id) => ['/truth/schema-v1.json', '/truth/index.json', `/truth/products/${id}.json`, '/proof/index.json'];
  const countsOf = (id) => snapUrls(id).map((u) => seen.get(u) || 0);
  const deployOf = (src, ids) => {
    const map = { '/truth/index.json': { body: JSON.stringify({ ...clone(index), source: { ...index.source, ...src } }) }, '/proof/index.json': { body: JSON.stringify({ ...clone(registry), generatedAt: src.committedAt }) } };
    for (const id of ids) map[`/truth/products/${id}.json`] = { body: JSON.stringify({ ...clone(records[id]), source: { ...records[id].source, ...src } }) };
    return map;
  };
  const build2 = { commit: 'a'.repeat(40), tree: 'b'.repeat(40), committedAt: '2026-10-20T09:00:00-07:00' };
  const build3 = { commit: 'c'.repeat(40), tree: 'd'.repeat(40), committedAt: '2026-10-21T09:00:00-07:00' };
  const otherId = receiptIds.find((id) => id !== specimenId && expected[id].ok);
  const openSpecimen = () => evaluate(`document.querySelector('[data-ledger-specimen] [data-receipt-open]').click()`);
  await viewport(1440);
  await setFaults({});
  await go('/');
  seen.clear();
  let t = Date.now();
  await openSpecimen();
  await waitFor(`${panelSettled} && !!document.querySelector('#pf-receipt-panel .pf-rc-top')`);
  const firstView = await panelState();
  const firstCounts = countsOf(specimenId);
  check('first open fetches the schema, index, record and proof registry once each, stamped with that fetch', firstView.receipt && firstCounts.every((n) => n === 1) && Date.parse(firstView.fetched) >= t - 1000 && Date.parse(firstView.fetched) <= Date.now() + 1000, { firstCounts, fetched: firstView.fetched });
  await key('Escape');
  await pause(300);
  await setFaults(deployOf(build2, receiptIds));
  t = Date.now();
  await openSpecimen();
  await waitFor(`${panelSettled} && !!document.querySelector('#pf-receipt-panel .pf-rc-top')`);
  const reopened = await panelState();
  const reopenCounts = countsOf(specimenId);
  check('reopening after a successful view refetches every record and shows the later build, not the earlier view', reopened.receipt && reopenCounts.every((n) => n === 2) && reopened.trail['Website commit'] === build2.commit && reopened.trail.Committed === build2.committedAt && reopened.artifacts.length === records[specimenId].artifacts.length, { reopenCounts, trail: reopened.trail });
  check('the fetch time shown is the reopening\'s own, later than the first view\'s', Date.parse(reopened.fetched) >= t - 1000 && Date.parse(reopened.fetched) > Date.parse(firstView.fetched), { first: firstView.fetched, reopened: reopened.fetched });
  // A deploy that lands while the dialog is open: index and registry from a
  // newer build, the next record still from the older one. Never combined.
  const mixedBuilds = deployOf(build3, receiptIds.filter((id) => id !== otherId));
  mixedBuilds[`/truth/products/${otherId}.json`] = deployOf(build2, [otherId])[`/truth/products/${otherId}.json`];
  await setFaults(mixedBuilds);
  await evaluate(`document.getElementById('pf-receipt-tab-${otherId}').click()`);
  await waitFor(`document.getElementById('pf-receipt-tab-${otherId}').getAttribute('aria-selected') === 'true' && ${panelSettled}`);
  const mixed = await panelState();
  check('a tab switch fetches its own snapshot, and one mixing two builds is refused', countsOf(otherId)[2] === 1 && seen.get('/truth/index.json') === 3 && seen.get('/proof/index.json') === 3 && mixed.failed && mixed.title === 'Release records disagree' && ['website source commit', 'website source tree', 'website source time'].every((f) => mixed.conflicts.includes(f)) && mixed.artifactDigests === 0, { counts: countsOf(otherId), title: mixed.title, conflicts: mixed.conflicts });
  await setFaults(deployOf(build3, receiptIds));
  t = Date.now();
  const retried = await evaluate(`(() => { const b = [...document.querySelectorAll('#pf-receipt-panel button')].find((x) => x.textContent === 'Try again'); if (b) b.click(); return !!b; })()`);
  if (retried) await waitFor(`${panelSettled} && !!document.querySelector('#pf-receipt-panel .pf-rc-top')`);
  const healed = await panelState();
  check('Try again after a disagreement recovers with one coherent snapshot of the completed deploy', retried && healed.receipt && healed.trail['Website commit'] === build3.commit && countsOf(otherId)[2] === 2 && Date.parse(healed.fetched) >= t - 1000 && Date.parse(healed.fetched) > Date.parse(mixed.fetched), { retried, trail: healed.trail, fetched: healed.fetched });
  await key('Escape');
  await setFaults(null);
  const receiptShown = `${panelSettled} && !!document.querySelector('#pf-receipt-panel .pf-rc-top')`;
  // The fetch time is taken after the slowest response of the snapshot.
  await setFaults({ '/proof/index.json': { delay: 1500 } });
  await go('/');
  released.clear();
  await openSpecimen();
  await waitFor(receiptShown);
  const slow = await panelState();
  check('the fetch time is taken after the slowest of the four responses', slow.receipt && released.has('/proof/index.json') && Date.parse(slow.fetched) >= released.get('/proof/index.json') - 50, { fetched: slow.fetched, released: released.has('/proof/index.json') ? new Date(released.get('/proof/index.json')).toISOString() : null });
  // A slower earlier view never overwrites a later one.
  await setFaults({ [`/truth/products/${otherId}.json`]: { delay: 1500 } });
  await evaluate(`document.getElementById('pf-receipt-tab-${otherId}').click()`);
  await pause(150);
  await evaluate(`document.getElementById('pf-receipt-tab-${specimenId}').click()`);
  await pause(2300);
  const later = await panelState();
  check('a slower earlier view never overwrites the later one', later.receipt && later.title === `${records[specimenId].name} v${records[specimenId].version} — public release record` && later.tabs.find((tb) => tb.selected === 'true')?.id === `pf-receipt-tab-${specimenId}`, { title: later.title, tabs: later.tabs });
  // Tab labels follow the index of the snapshot just fetched.
  await key('Escape');
  await pause(200);
  const relabelled = clone(index); relabelled.products.find((entry) => entry.id === otherId).version = '9.9.9';
  await setFaults({ '/truth/index.json': { body: JSON.stringify(relabelled) } });
  await openSpecimen();
  await waitFor(receiptShown);
  const label = await evaluate(`document.getElementById('pf-receipt-tab-${otherId}').textContent`);
  check('tab labels follow the index of the snapshot just fetched', /v9\.9\.9/.test(label), label);
  // A reopen whose index cannot be fetched reuses nothing from the earlier view.
  await key('Escape');
  await pause(200);
  await setFaults({ '/truth/index.json': { fail: true } });
  await openSpecimen();
  await waitFor(panelSettled);
  const noIndex = await panelState();
  check('reopening with the index unreachable refuses and reuses nothing from the earlier view', noIndex.failed && !noIndex.receipt && noIndex.heading === 'This product: the public record could not be verified here.' && noIndex.text.includes('/truth/index.json could not be reached.') && noIndex.artifactDigests === 0, { heading: noIndex.heading, text: noIndex.text.slice(0, 300) });
  // Try again from the keyboard keeps focus inside the dialog and recovers.
  await setFaults(null);
  const tryFocused = await focus('#pf-receipt-panel .pf-rc-fail button');
  await key('Enter');
  await waitFor(receiptShown);
  const kb = await evaluate(`({ inDialog: document.getElementById('pf-receipt-dialog').contains(document.activeElement), active: document.activeElement ? (document.activeElement.id || document.activeElement.className || document.activeElement.tagName) : null })`);
  const kbState = await panelState();
  check('keyboard Try again keeps focus inside the dialog and recovers the receipt', tryFocused && kb.inDialog && kbState.receipt, { tryFocused, kb, title: kbState.title });
  await key('Escape');
  // With cacheable responses (max-age=3600, ETag) and no interception, the
  // browser must still ask the server for every record on each view.
  cacheable = true;
  await go('/');
  hits.clear();
  await openSpecimen();
  await waitFor(receiptShown);
  await key('Escape');
  await pause(200);
  await openSpecimen();
  await waitFor(receiptShown);
  const asked = snapUrls(specimenId).map((u) => hits.get(u) || 0);
  check('with cacheable responses the browser still revalidates all four records on a reopen', asked.every((n) => n === 2), { asked });
  cacheable = false;
  await key('Escape');

  // ── Touch: taps open, use and close both dialogs; nothing needs hover ────
  await viewport(390, true);
  await go('/');
  const touch = await evaluate(`({ hoverNone: matchMedia('(hover: none)').matches, coarse: matchMedia('(pointer: coarse)').matches, light: getComputedStyle(document.querySelector('.pf-lm')).display })`);
  check('390px touch: no hover, coarse pointer, highlights off', touch.hoverNone && touch.coarse && touch.light === 'none', touch);
  await tap(`[data-ledger-feature="${featureIds[0]}"] [data-receipt-open]`);
  await waitFor(panelSettled);
  await waitFor(tabsBuilt(receiptIds.length));
  s = await panelState();
  const sheet = await evaluate(`(() => { const f = document.querySelector('#pf-receipt-dialog .pf-dialog-frame').getBoundingClientRect(), sc = document.querySelector('#pf-receipt-dialog .pf-dialog-scroll'); return { w: Math.round(f.width), h: Math.round(f.height), vw: innerWidth, vh: innerHeight, sideways: sc.scrollWidth > sc.clientWidth }; })()`);
  check('390px touch: a tap opens the receipt as a full-screen sheet', s.open && sheet.w === sheet.vw && sheet.h === sheet.vh && !sheet.sideways, sheet);
  await shot('receipt-390');
  const other = receiptIds.find((id) => id !== featureIds[0]);
  await tap(`#pf-receipt-tab-${other}`);
  await waitFor(`document.getElementById('pf-receipt-tab-${other}').getAttribute('aria-selected') === 'true' && ${panelSettled}`);
  check('390px touch: tapping a tab switches the record', (await panelState()).tabs.find((t) => t.selected === 'true')?.id === `pf-receipt-tab-${other}`);
  await tap('#pf-receipt-dialog [data-dialog-close]');
  after = await state();
  check('390px touch: Close returns focus to the tapped trigger', !after.receiptOpen && after.receipt === featureIds[0], after);
  await tap('[data-mark-open]');
  await tap('.pf-mk-list li:nth-child(3) button');
  const touchMark = await evaluate(`(() => { const sc = document.querySelector('#pf-mark-dialog .pf-dialog-scroll'); return { open: document.getElementById('pf-mark-dialog').open, count: document.querySelector('[data-mark-count]').textContent, sideways: sc.scrollWidth > sc.clientWidth }; })()`);
  check('390px touch: Inspect the Mark opens and a tap selects a point', touchMark.open && touchMark.count === 'Point 3 of 10' && !touchMark.sideways, touchMark);
  await shot('mark-390');
  await tap('#pf-mark-dialog [data-dialog-close]');
  after = await state();
  check('390px touch: Close returns focus to Inspect the Mark', !after.markOpen && /pf-inspect/.test(after.active), after);
  check('390px touch: no script errors', errors.length === 0, errors);

  // ── Header mark: flush with the brand link; forced colours keep it visible ─
  for (const width of [1440, 390]) {
    await viewport(width);
    await go('/');
    const g = await evaluate(`(() => { const l = document.querySelector('.site-header .brand-lockup').getBoundingClientRect(), i = document.querySelector('.site-header .brand-mark'), m = i.getBoundingClientRect(); return { lockup: l.left, mark: m.left, w: m.width, h: m.height, src: i.currentSrc.split('/').pop() }; })()`);
    check(`${width}px: Home header mark is the PF Mark G render, flush with the brand link`, Math.abs(g.mark - g.lockup) < 0.5 && g.src === 'PF_MARK_G_HEADER.webp' && Math.round(g.w) === (width <= 480 ? 38 : 50) && g.h > g.w, g);
  }
  // Layout details V5 specifies: the hero copy's face, the phone menu's Support
  // button inside its panel, and a skip link that is hidden until focused.
  await viewport(1440);
  await go('/');
  const face = await evaluate(`getComputedStyle(document.querySelector('.ledger-hero-description')).fontFamily`);
  check('hero description is set in Archivo, as in V5', /^"?Archivo\b/.test(face), face);
  await viewport(1920);
  await go('/');
  const skipHidden = await evaluate(`(() => { const r = document.querySelector('.skip-link').getBoundingClientRect(); return { top: r.top, bottom: r.bottom }; })()`);
  await key('Tab');
  const skipShown = await evaluate(`(() => { const e = document.activeElement, r = e.getBoundingClientRect(); return { skip: e.classList.contains('skip-link'), top: r.top, bottom: r.bottom, vh: innerHeight }; })()`);
  check('1920px: the skip link is fully hidden until focused, then on screen', skipHidden.bottom <= 0 && skipShown.skip && skipShown.top >= 0 && skipShown.bottom <= skipShown.vh, { skipHidden, skipShown });
  await viewport(390, true);
  await go('/');
  await tap('.site-header .nav-toggle');
  const menu = await evaluate(`(() => { const p = document.querySelector('.site-header .nav-panel').getBoundingClientRect(), c = document.querySelector('.site-header .nav-panel .nav-cta').getBoundingClientRect(); return { panel: [p.left, p.right], cta: [c.left, c.right], vw: innerWidth }; })()`);
  check('390px: the open menu keeps its Support button inside the panel', menu.cta[0] >= menu.panel[0] - 0.5 && menu.cta[1] <= menu.panel[1] + 0.5 && menu.cta[1] <= menu.vw, menu);

  // Normal colours: no inline forced-colours fallback is drawn; the B emblem and the header and footer marks are.
  const normalFc = await evaluate(`({ seal: document.querySelector('.pf-seal-fc').checkVisibility(), emblem: document.querySelector('.pf-emblem-image').checkVisibility(), marks: [...document.querySelectorAll('.pf-mark-fc')].map((e) => e.checkVisibility()), header: document.querySelector('.site-header .brand-mark').checkVisibility(), footer: document.querySelector('.site-footer .footer-logo').checkVisibility() })`);
  check('normal colours: the inline forced-colours seal is not drawn and the hero emblem is', normalFc.seal === false && normalFc.emblem === true, normalFc);
  check('normal colours: the inline forced-colours micro marks are not drawn and the header and footer marks are', normalFc.marks.length === 2 && normalFc.marks.every((v) => v === false) && normalFc.header && normalFc.footer, normalFc);

  // Forced colours: every fallback (hero seal, header and footer micro marks) is an inline, same-document SVG drawn
  // in the user's palette, and the menu bars are CSS. Each palette is measured on ONE load, with no retry.
  for (const scheme of ['dark', 'light']) {
    await viewport(390, true);
    await send('Emulation.setEmulatedMedia', { features: [{ name: 'forced-colors', value: 'active' }, { name: 'prefers-color-scheme', value: scheme }] });
    await go('/');
    await pause(400);
    const fc = await evaluate(`(() => { const rgb = (c) => c.match(/\\d+/g).slice(0, 3).map(Number); const h = document.querySelector('.site-header'), t = document.querySelector('.site-header .nav-toggle'); const vis = (q) => document.querySelector(q).checkVisibility(); const ids = [...document.querySelectorAll('[id]')].map((e) => e.id); const svgs = [...document.querySelectorAll('.pf-seal-inline,.pf-mark-fc svg')]; return { canvas: rgb(getComputedStyle(h).backgroundColor), text: rgb(getComputedStyle(h).color), button: rgb(getComputedStyle(t).color), sealInline: vis('.pf-seal-inline'), sealImg: vis('.pf-emblem-image'), watermark: vis('.ledger-receipt-watermark'), headerImg: vis('.site-header .brand-mark'), footerImg: vis('.site-footer .footer-logo'), headerFc: vis('.pf-mark-fc--header'), footerFc: vis('.pf-mark-fc--footer'), inert: svgs.length === 3 && svgs.every((e) => e.getAttribute('focusable') === 'false' && !!e.closest('[aria-hidden="true"]')), duplicateIds: ids.length - new Set(ids).size }; })()`);
    fc.seal = fc.sealInline ? await paletteInk('.pf-seal-inline', fc.text, fc.canvas) : 0;
    fc.mark = fc.headerFc ? await paletteInk('.pf-mark-fc--header', fc.text, fc.canvas) : 0;
    fc.footer = fc.footerFc ? await paletteInk('.pf-mark-fc--footer', fc.text, fc.canvas) : 0;
    fc.bars = await paletteInk('.site-header .nav-toggle', fc.button, fc.canvas, 4);
    check(`forced colours (${scheme} palette): header and footer fall back to the vector micro mark, drawn in the palette's text colour`, fc.headerFc && fc.footerFc && !fc.headerImg && !fc.footerImg && fc.mark >= 100 && fc.footer >= 100, fc);
    check(`forced colours (${scheme} palette): the hero falls back to the vector seal, drawn in the palette's text colour`, fc.sealInline && !fc.sealImg && fc.seal >= 500 && fc.inert && fc.duplicateIds === 0, fc);
    check(`forced colours (${scheme} palette): the decorative doctrine watermark is not drawn`, fc.watermark === false, fc);
    check(`forced colours (${scheme} palette): the menu toggle shows its bars in the button text colour`, fc.bars >= 60, fc);
    await shot(`forced-colors-${scheme}-390`);
  }
  await send('Emulation.setEmulatedMedia', { features: [] });

  // ── Reduced motion ───────────────────────────────────────────────────────
  await viewport(1440);
  await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
  await go('/');
  const calm = await evaluate(`({ motion: document.documentElement.dataset.motion, light: getComputedStyle(document.querySelector('.pf-lm')).display })`);
  check('reduced motion turns off site motion and the emblem highlights', calm.motion === 'off' && calm.light === 'none', calm);
  await send('Emulation.setEmulatedMedia', { features: [] });
} catch (error) {
  check('browser qualification completed', false, String(error && error.stack || error));
} finally {
  try { socket?.close(); } catch {}
  // Kill the whole process tree: a browser launcher can outlive its first process.
  if (browser?.pid && process.platform === 'win32') spawnSync('taskkill', ['/pid', String(browser.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
  else browser?.kill();
  // Anything still using this run's private profile is ours; stop it too.
  if (profile && process.platform === 'win32') spawnSync('powershell', ['-NoProfile', '-Command', `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('${profile.replace(/'/g, "''")}') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`], { windowsHide: true, stdio: 'ignore' });
  server.close();
  await pause(300);
  if (profile) await rm(profile, { recursive: true, force: true }).catch(() => {});
}
const failed = results.filter((r) => !r.pass).length;
console.log(`=== HOME V5 BROWSER RESULT: ${results.length - failed} passed, ${failed} failed ===`);
process.exit(failed ? 1 : 0);
