// Re-render the PF Mark G emblem, its light masks and the homepage header mark
// from render-lib.js and compare them with the shipped files in brand/emblem/.
// Never writes into brand/: outputs go to the directory you name. Local only;
// no network.
//   node scripts/pf-emblem/render-emblem.mjs <new-output-directory>
// Byte-identical output was recorded with Chrome 155.0.8059.40 and .41; other
// Chrome builds can encode WebP differently. See PF_MARK_G_EMBLEM_PROVENANCE.md.
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const outDir = process.argv[2] ? path.resolve(process.argv[2]) : null;
if (!outDir) throw new Error('Name a new output directory.');
if (outDir === path.join(root, 'brand') || outDir.startsWith(path.join(root, 'brand') + path.sep)) throw new Error('Refusing to write into brand/.');
if (existsSync(outDir) && readdirSync(outDir).length) throw new Error('Output directory must be new or empty.');
mkdirSync(outDir, { recursive: true });

// The options used for the approved V5 assets, one fresh page load per run.
const RUNS = [
  { options: { encode: true, hot: true, masks: ['eN', 'eE', 'eS', 'eW', 'bridge', 'brass', 'seal', 'eng'] },
    names: { base: 'PF_MARK_G_EMBLEM.webp', eN: 'LIGHT_NORTH.webp', eE: 'LIGHT_EAST.webp', eS: 'LIGHT_SOUTH.webp', eW: 'LIGHT_WEST.webp', bridge: 'LIGHT_BRIDGE.webp', brass: 'LIGHT_BRASS.webp', seal: 'LIGHT_SEAL.webp', eng: 'LIGHT_ENGRAVING.webp' } },
  { options: { encode: true, markOnly: true, width: 256, q: 0.92 }, names: { base: 'PF_MARK_G_HEADER.webp' } },
];

const browserPath = [process.env.PF_EMBLEM_BROWSER, 'C:/Program Files/Google/Chrome/Application/chrome.exe'].filter(Boolean).find(existsSync);
if (!browserPath) throw new Error('Set PF_EMBLEM_BROWSER to a Chrome executable.');
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const profile = mkdtempSync(path.join(tmpdir(), 'pf-emblem-'));
const browser = spawn(browserPath, ['--headless=new', '--allow-file-access-from-files', '--js-flags=--max-old-space-size=4096', '--no-first-run', '--no-default-browser-check', '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
browser.stderr.on('data', () => {});

let socket;
try {
  let port;
  for (let i = 0; i < 100 && !port; i++) {
    const portFile = path.join(profile, 'DevToolsActivePort');
    if (existsSync(portFile)) port = Number(readFileSync(portFile, 'utf8').split(/\r?\n/)[0]);
    else await pause(100);
  }
  if (!port) throw new Error('Browser CDP port unavailable.');
  const version = await fetch(`http://127.0.0.1:${port}/json/version`).then((r) => r.json());
  const target = await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' }).then((r) => r.json());
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const entry = pending.get(message.id);
    if (!entry) return;
    pending.delete(message.id);
    message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => { const id = ++sequence; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })); });
  const evaluate = async (expression) => {
    const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    return result.result.value;
  };
  console.log(version.Browser);
  let identical = 0, total = 0;
  for (const { options, names } of RUNS) {
    await send('Page.navigate', { url: pathToFileURL(path.join(here, 'render.html')).href });
    await pause(200);
    for (let i = 0; i < 100 && !(await evaluate('document.readyState === "complete" && !!window.PFRender')); i++) await pause(100);
    await evaluate('document.fonts.ready.then(() => true)');
    const res = await evaluate(`window.PFRender.run(${JSON.stringify(options)}).then((r) => ({ W: r.W, H: r.H, base: r.base, masks: r.masks }))`);
    const files = [['base', res.base], ...Object.entries(res.masks || {})];
    console.log(`${res.W} x ${res.H}`);
    for (const [key, dataUrl] of files) {
      const bytes = Buffer.from(dataUrl.slice(dataUrl.indexOf(',') + 1), 'base64');
      writeFileSync(path.join(outDir, names[key]), bytes);
      const shipped = path.join(root, 'brand/emblem', names[key]);
      const same = existsSync(shipped) && sha256(readFileSync(shipped)) === sha256(bytes);
      total++;
      if (same) identical++;
      console.log(`${same ? 'IDENTICAL' : 'DIFFERENT'} ${names[key]} ${sha256(bytes)}`);
    }
  }
  console.log(`${identical}/${total} byte-identical to brand/emblem/`);
  process.exitCode = identical === total ? 0 : 1;
} finally {
  socket?.close();
  browser.kill();
  await pause(300);
  try { rmSync(profile, { recursive: true, force: true }); } catch {}
}
