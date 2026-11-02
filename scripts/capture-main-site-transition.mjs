// Sample real cross-document view-transition frames in an isolated, headed
// Chrome on loopback CDP port 9331. Never attaches to an owner profile.
// Usage: node scripts/capture-main-site-transition.mjs <label>
import { writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
const label = process.argv[2] || 'after';
if (!/^[a-z0-9-]+$/.test(label)) throw new Error('Label must be a simple slug');
const root = path.resolve(import.meta.dirname, '..');
const output = path.join(root, 'review/main-finish/transition-frames');
await mkdir(output, { recursive: true });
const origin = 'http://127.0.0.1:5180';
const journeys = [['/', '/about/'], ['/about/', '/support/'], ['/', '/software/']];
const fractions = [0, .25, .5, .75, 1];
const targets = await fetch('http://127.0.0.1:9331/json/list').then(r => r.json());
const target = targets.find(t => t.type === 'page');
if (!target) throw new Error('Isolated browser has no page target');
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
let id = 0;
const pending = new Map();
socket.onmessage = event => {
  const message = JSON.parse(event.data), entry = pending.get(message.id);
  if (!entry) return;
  pending.delete(message.id);
  message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
};
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const key = ++id;
  pending.set(key, { resolve, reject });
  socket.send(JSON.stringify({ id: key, method, params }));
});
const evaluate = async expression => {
  const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
  return result.result.value;
};
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
// The requested sample point travels with the tab through window.name, which
// survives the same-tab document swap that a view transition spans.
const freezer = `
  addEventListener('pagereveal', event => {
    const match = /^pf-capture:([\\d.]+)$/.exec(window.name);
    if (!match || !event.viewTransition) return;
    window.name = '';
    event.viewTransition.ready.then(() => {
      const animations = document.getAnimations().filter(a => a.effect?.pseudoElement?.startsWith('::view-transition'));
      const end = Math.max(0, ...animations.map(a => a.effect.getComputedTiming().endTime));
      const at = Math.min(Number(match[1]) * end, end - 1);
      for (const a of animations) { a.pause(); a.currentTime = at; }
      const opacity = p => Number(getComputedStyle(document.documentElement, p).opacity);
      window.__pfFrame = { at, end, oldRoot: opacity('::view-transition-old(root)'), newRoot: opacity('::view-transition-new(root)'),
        animations: animations.map(a => ({ name: a.animationName, pseudo: a.effect.pseudoElement })) };
    });
  });`;
const results = [], sheets = [];
try {
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  const script = await send('Page.addScriptToEvaluateOnNewDocument', { source: freezer });
  for (const [from, to] of journeys) {
    const slug = (from === '/' ? 'home' : from.replaceAll('/', '')) + '-to-' + to.replaceAll('/', '');
    const frames = [];
    for (const fraction of fractions) {
      await send('Page.navigate', { url: origin + from });
      await delay(900);
      await evaluate(`window.name='pf-capture:${fraction}'; document.querySelector('.pf-route-chain a[href="${to}"]').click()`);
      let frame = null;
      for (let i = 0; i < 40 && !frame; i++) { await delay(50); try { frame = await evaluate('window.__pfFrame || null'); } catch { /* document swapping */ } }
      if (!frame) throw new Error(`No native transition captured for ${slug} at ${fraction}`);
      frame.route = await evaluate('location.pathname');
      frame.fraction = fraction;
      frame.doubleExposure = frame.oldRoot > 0.001 && frame.newRoot > 0.001;
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      const file = path.join(output, `${label}-${slug}-${String(fraction * 100).padStart(3, '0')}.png`);
      await writeFile(file, Buffer.from(shot.data, 'base64'));
      frames.push({ ...frame, file: path.relative(root, file) });
      await evaluate('document.getAnimations().forEach(a=>a.finish())');
    }
    results.push({ journey: `${from} -> ${to}`, frames });
    sheets.push(frames.map(f => path.join(root, f.file)));
  }
  await send('Page.removeScriptToEvaluateOnNewDocument', { identifier: script.identifier });
  await send('Emulation.clearDeviceMetricsOverride');
} finally {
  socket.close();
}
const inputs = sheets.flat().flatMap(file => ['-i', file]);
const count = sheets.flat().length;
const filter = sheets.flat().map((_, i) => `[${i}:v]scale=480:-1[s${i}]`).join(';') + ';' +
  sheets.flat().map((_, i) => `[s${i}]`).join('') + `xstack=inputs=${count}:layout=` +
  sheets.flat().map((_, i) => `${(i % 5) ? Array.from({ length: i % 5 }, () => 'w0').join('+') : '0'}_${Math.floor(i / 5) ? Array.from({ length: Math.floor(i / 5) }, () => 'h0').join('+') : '0'}`).join('|');
const sheet = path.join(root, `review/main-finish/${label}-transition-contact-sheet.png`);
const ff = spawnSync('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', filter, '-frames:v', '1', sheet], { encoding: 'utf8' });
if (ff.status !== 0) throw new Error('Contact sheet failed: ' + ff.stderr);
const failures = results.flatMap(r => r.frames.filter(f => f.doubleExposure || f.route !== r.journey.split(' -> ')[1]));
await writeFile(path.join(root, `review/main-finish/${label}-transition-frames.json`), JSON.stringify({ results, failures: failures.length }, null, 2) + '\n');
console.log(JSON.stringify(results.map(r => ({ journey: r.journey, frames: r.frames.map(f => [f.fraction, Math.round(f.at), +f.oldRoot.toFixed(3), +f.newRoot.toFixed(3), f.doubleExposure]) }))));
console.log(`RESULT: ${count - failures.length} frames clean, ${failures.length} double-exposed or misrouted`);
if (failures.length) process.exitCode = 1;
