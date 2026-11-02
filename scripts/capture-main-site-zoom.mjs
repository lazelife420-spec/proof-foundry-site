// Native Chrome page zoom, not a deviceScaleFactor substitute.
// Uses only the isolated headed review browser on port 9331.
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
const label = process.argv[2] || 'after';
if (!/^[a-z0-9-]+$/.test(label)) throw new Error('Invalid evidence label');
const root = path.resolve(import.meta.dirname, '..');
const target = (await fetch('http://127.0.0.1:9331/json/list').then(r => r.json())).find(t => t.type === 'page');
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
let id = 0; const pending = new Map();
ws.onmessage = e => { const m = JSON.parse(e.data), p = pending.get(m.id); if (!p) return; pending.delete(m.id); m.error ? p.reject(Error(m.error.message)) : p.resolve(m.result); };
const send = (method, params = {}) => new Promise((resolve, reject) => { const key = ++id; pending.set(key, { resolve, reject }); ws.send(JSON.stringify({ id: key, method, params })); });
const evaluate = async expression => { const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }); if (r.exceptionDetails) throw Error(r.exceptionDetails.text); return r.result.value; };
const navigate = async url => {
  await send('Page.navigate', { url });
  for (let n = 0; n < 100; n++) {
    await new Promise(r => setTimeout(r, 50));
    try { if (await evaluate(`location.href === ${JSON.stringify(url)} && document.readyState === 'complete'`)) return; } catch {}
  }
  throw Error('Navigation did not settle');
};
const results = [];
try {
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  await navigate('chrome://settings/appearance');
  await evaluate('chrome.settingsPrivate.setDefaultZoom(2)');
  const zoom = await evaluate('new Promise(r => chrome.settingsPrivate.getDefaultZoom(r))');
  if (zoom !== 2) throw Error('Native 200% zoom not established');
  for (const [slug, route] of [['home', '/'], ['software', '/software/']]) {
    await navigate('http://127.0.0.1:5180' + route);
    await evaluate('document.fonts.ready');
    const data = await evaluate(`(() => {
      const chain = document.querySelector('.pf-route-chain');
      const rect = e => { const r = e.getBoundingClientRect(); return { x:r.x, y:r.y, width:r.width, height:r.height, bottom:r.bottom }; };
      return { width:innerWidth, height:innerHeight, dpr:devicePixelRatio, overflow:document.documentElement.scrollWidth-innerWidth,
        chain:rect(chain), links:[...chain.querySelectorAll('a')].map(a => ({ route:a.getAttribute('href'), tabIndex:a.tabIndex, station:getComputedStyle(a.querySelector('.pf-chain-station')).display, rect:rect(a) })),
        kicker:document.querySelector('.h9-software-kicker') ? rect(document.querySelector('.h9-software-kicker')) : null,
        heading:rect(document.querySelector('h1')) };
    })()`);
    await evaluate(`document.querySelector('.pf-route-chain a').focus()`);
    data.keyboardOrder = [await evaluate('document.activeElement.getAttribute("href")')];
    for (let n = 0; n < 5; n++) {
      await send('Input.dispatchKeyEvent', { type:'keyDown', key:'Tab', code:'Tab', windowsVirtualKeyCode:9 });
      await send('Input.dispatchKeyEvent', { type:'keyUp', key:'Tab', code:'Tab', windowsVirtualKeyCode:9 });
      data.keyboardOrder.push(await evaluate('document.activeElement.getAttribute("href")'));
    }
    await evaluate('document.activeElement.blur(); scrollTo(0,0)');
    const shot = await send('Page.captureScreenshot', { format:'png' });
    await writeFile(path.join(root, `review/main-finish/${label}-native-zoom-200-${slug}.png`), Buffer.from(shot.data, 'base64'));
    results.push({ slug, nativeZoom:zoom, viewportCaveat:'CDP base viewport 1440x900; native Chrome zoom 200%', ...data });
  }
} finally {
  await navigate('chrome://settings/appearance');
  await evaluate('chrome.settingsPrivate.setDefaultZoom(1)');
  ws.close();
}
await writeFile(path.join(root, `review/main-finish/${label}-native-zoom-200.json`), JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify(results, null, 2));
