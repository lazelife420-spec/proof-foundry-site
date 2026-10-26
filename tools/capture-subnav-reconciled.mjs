import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import http from 'node:http';

const root = 'C:/Users/KickA/pf-v5-continuity';
const publicDir = path.join(root, 'public');
const outputDir = path.join(root, 'review', 'CONTINUITY_CAPTURES');
fs.mkdirSync(outputDir, { recursive: true });

function startServer(port) {
  const mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.json': 'application/json',
    '.xml': 'application/xml',
    '.txt': 'text/plain; charset=utf-8',
    '.webp': 'image/webp',
    '.woff2': 'font/woff2'
  };

  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath.endsWith('/')) reqPath += 'index.html';
      let filePath = path.join(publicDir, reqPath);

      if (!fs.existsSync(filePath) && fs.existsSync(filePath + '/index.html')) {
        filePath = filePath + '/index.html';
      }

      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath);
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
        fs.createReadStream(filePath).pipe(res);
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('404 Not Found');
      }
    });

    server.listen(port, () => resolve(server));
  });
}

function startBrowser(cdpPort) {
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'
  ];
  const browserPath = candidates.find(fs.existsSync);
  const browser = spawn(browserPath, [
    '--headless=new',
    '--disable-gpu',
    `--remote-debugging-port=${cdpPort}`,
    '--no-first-run',
    '--no-default-browser-check'
  ]);
  return browser;
}

async function connectCDP(cdpPort, targetUrl) {
  const cdpBase = `http://127.0.0.1:${cdpPort}`;
  const target = await fetch(`${cdpBase}/json/new?${encodeURIComponent(targetUrl)}`, { method: 'PUT' }).then(r => r.json());
  const ws = new WebSocket(target.webSocketDebuggerUrl);

  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });

  let id = 1;
  const callbacks = new Map();
  ws.onmessage = (evt) => {
    const msg = JSON.parse(evt.data);
    if (msg.id && callbacks.has(msg.id)) {
      const cb = callbacks.get(msg.id);
      callbacks.delete(msg.id);
      if (msg.error) cb.reject(new Error(msg.error.message));
      else cb.resolve(msg.result);
    }
  };

  const send = (method, params = {}) => {
    const msgId = id++;
    return new Promise((resolve, reject) => {
      callbacks.set(msgId, { resolve, reject });
      ws.send(JSON.stringify({ id: msgId, method, params }));
    });
  };

  return { send, ws, targetId: target.id };
}

async function captureScreen(cdpPort, url, outPath, width, height, selector = null) {
  const client = await connectCDP(cdpPort, url);
  const { send, ws, targetId } = client;

  try {
    await send('Page.enable');
    await send('DOM.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: width < 768
    });

    await send('Page.navigate', { url });
    await new Promise(r => setTimeout(r, 1200));

    let clip = { x: 0, y: 0, width, height: Math.min(height, 500), scale: 1 };

    if (selector) {
      try {
        const doc = await send('DOM.getDocument');
        const node = await send('DOM.querySelector', { nodeId: doc.root.nodeId, selector });
        if (node && node.nodeId) {
          const box = await send('DOM.getBoxModel', { nodeId: node.nodeId });
          if (box && box.model) {
            clip = {
              x: Math.max(0, box.model.border[0] - 10),
              y: Math.max(0, box.model.border[1] - 10),
              width: Math.min(width, box.model.width + 20),
              height: Math.min(height, box.model.height + 20),
              scale: 1
            };
          }
        }
      } catch (err) {
        console.warn(`Could not select ${selector} on ${url}:`, err.message);
      }
    }

    const screenshot = await send('Page.captureScreenshot', { format: 'png', clip });
    fs.writeFileSync(outPath, Buffer.from(screenshot.data, 'base64'));
  } finally {
    ws.close();
    await fetch(`http://127.0.0.1:${cdpPort}/json/close/${targetId}`).catch(() => {});
  }
}

(async () => {
  const port = 8089;
  const cdpPort = 9225;
  const server = await startServer(port);
  const browser = startBrowser(cdpPort);
  await new Promise(r => setTimeout(r, 2000));

  const site = `http://127.0.0.1:${port}`;

  console.log('\n=== Capturing Reconciled Product Subnavs (1440px) ===');
  await captureScreen(cdpPort, `${site}/proofshot/`, path.join(outputDir, 'proofshot-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  console.log('Captured proofshot-subnav-1440px.png');

  await captureScreen(cdpPort, `${site}/cache-vault/`, path.join(outputDir, 'cache-vault-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  console.log('Captured cache-vault-subnav-1440px.png');

  await captureScreen(cdpPort, `${site}/lights-out/`, path.join(outputDir, 'lights-out-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  console.log('Captured lights-out-subnav-1440px.png');

  await captureScreen(cdpPort, `${site}/cleanroom/`, path.join(outputDir, 'cleanroom-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  console.log('Captured cleanroom-subnav-1440px.png');

  await captureScreen(cdpPort, `${site}/reality-gate/`, path.join(outputDir, 'reality-gate-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  console.log('Captured reality-gate-subnav-1440px.png');

  console.log('\nAll reconciled subnav captures completed successfully.');
  browser.kill();
  server.close();
  process.exit(0);
})();
