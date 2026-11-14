// Reference-site captures for side-by-side contact sheets (read-only, local disk only).
// node scripts/capture-ref-comparison.mjs [outDir]
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
const REF = 'https://cp0189-visual-approved.proof-foundry-site.pages.dev';
const outDir = path.resolve(process.argv[2] || 'receipts/candidate-qual-2026-11-13/shots-ref');
fs.mkdirSync(outDir, { recursive: true });
const exe = ['C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(fs.existsSync);
const prof = fs.mkdtempSync(path.join(os.tmpdir(), 'ref-cap-'));
const br = spawn(exe, ['--headless=new', '--disable-gpu', '--remote-debugging-port=0', `--user-data-dir=${prof}`, 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
br.stderr.on('data', () => { });
let cdp;
for (let i = 0; i < 100; i++) { const a = path.join(prof, 'DevToolsActivePort'); if (fs.existsSync(a)) { const p = Number(fs.readFileSync(a, 'utf8').split('\n')[0]); if (p) { cdp = `http://127.0.0.1:${p}`; break; } } await new Promise(r => setTimeout(r, 100)); }
const targets = await fetch(cdp + '/json/list').then(r => r.json());
const ws = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
let id = 0; const pend = new Map();
const send = (m, p = {}) => new Promise((res, rej) => { const i = ++id; pend.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method: m, params: p })); });
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pend.has(m.id)) pend.get(m.id).res(m.result); };
await new Promise(r => ws.onopen = r);
await send('Page.enable'); await send('Runtime.enable');
const routes = { 'home': '', 'software': 'software', 'truth-files': 'truth-files' };
const manifest = [];
for (const width of [1440, 390, 320]) {
  for (const [name, route] of Object.entries(routes)) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: width < 768 });
    await send('Page.navigate', { url: `${REF}/${route}/` });
    await new Promise(r => setTimeout(r, 2000));
    const m = await send('Page.getLayoutMetrics');
    const h = Math.min(Math.ceil(m.cssContentSize.height), 30000);
    const shot = await send('Page.captureScreenshot', { format: 'png', fromSurface: true, captureBeyondViewport: true, clip: { x: 0, y: 0, width, height: h, scale: 1 } });
    const file = `ref-${name}-${width}.png`;
    fs.writeFileSync(path.join(outDir, file), Buffer.from(shot.data, 'base64'));
    manifest.push({ file, docHeight: h, sha256: createHash('sha256').update(fs.readFileSync(path.join(outDir, file))).digest('hex') });
    console.log(`CAPTURE ${file} ${width}x${h}`);
  }
}
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 1));
br.kill(); process.exit(0);
