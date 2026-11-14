import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import http from 'node:http';

const root = path.resolve(import.meta.dirname, '..');
const htmlDir = path.join(root, 'review', 'H9_STAGE1_DESIGN', 'html');
const publicDir = path.join(root, 'public');
const brandDir = path.join(root, 'brand');
const outputDir = path.join(root, 'review', 'H9_STAGE1_DESIGN');

fs.mkdirSync(outputDir, { recursive: true });

function startServer(port) {
  const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'text/javascript',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.json': 'application/json'
  };

  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      let filePath = '';

      if (reqPath.startsWith('/brand/')) {
        filePath = path.join(brandDir, reqPath.replace('/brand/', ''));
      } else if (reqPath.startsWith('/assets/')) {
        filePath = path.join(publicDir, reqPath);
      } else {
        if (reqPath === '/' || reqPath === '/concept-a') filePath = path.join(htmlDir, 'concept-a.html');
        else if (reqPath === '/concept-a-variant') filePath = path.join(htmlDir, 'concept-a-variant.html');
        else if (reqPath === '/concept-b') filePath = path.join(htmlDir, 'concept-b.html');
        else if (reqPath === '/concept-c') filePath = path.join(htmlDir, 'concept-c.html');
        else if (reqPath === '/software-wireframe') filePath = path.join(htmlDir, 'software-wireframe.html');
        else filePath = path.join(htmlDir, reqPath);
      }

      if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
        const ext = path.extname(filePath);
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
        fs.createReadStream(filePath).pipe(res);
      } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 Not Found: ' + reqPath);
      }
    });

    server.listen(port, () => resolve(server));
  });
}

function startChrome(cdpPort) {
  const chromePath = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
  return spawn(chromePath, [
    '--headless=new',
    '--disable-gpu',
    `--remote-debugging-port=${cdpPort}`,
    '--no-first-run',
    '--no-default-browser-check'
  ]);
}

async function connectCDP(cdpPort, targetUrl) {
  const cdpBase = `http://127.0.0.1:${cdpPort}`;
  const target = await fetch(`${cdpBase}/json/new?${encodeURIComponent(targetUrl)}`, { method: 'PUT' }).then(r => r.json());
  const ws = new WebSocket(target.webSocketDebuggerUrl);

  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });

  let seq = 0;
  const pending = new Map();

  ws.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data);
    if (!msg.id || !pending.has(msg.id)) return;
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(msg.error.message));
    else resolve(msg.result);
  });

  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++seq;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });

  return { ws, send };
}

async function captureBoard(cdpPort, url, outPath, width, height) {
  const { ws, send } = await connectCDP(cdpPort, url);
  await send('Page.enable');
  await send('Page.navigate', { url });
  await new Promise(r => setTimeout(r, 1200));

  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 768
  });

  await new Promise(r => setTimeout(r, 500));

  const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
  fs.writeFileSync(outPath, Buffer.from(data, 'base64'));
  ws.close();
}

(async () => {
  const httpPort = 8995;
  const cdpPort = 9228;

  console.log('Starting local HTTP preview server...');
  const server = await startServer(httpPort);
  const chrome = startChrome(cdpPort);
  await new Promise(r => setTimeout(r, 1500));

  const site = `http://127.0.0.1:${httpPort}`;

  console.log('Rendering Concept A Desktop 1440...');
  await captureBoard(cdpPort, `${site}/concept-a`, path.join(outputDir, 'concept-a-desktop-1440.png'), 1440, 900);

  console.log('Rendering Concept A Mobile 390...');
  await captureBoard(cdpPort, `${site}/concept-a`, path.join(outputDir, 'concept-a-mobile-390.png'), 390, 844);

  console.log('Rendering Concept A Hero Variant 1440...');
  await captureBoard(cdpPort, `${site}/concept-a-variant`, path.join(outputDir, 'concept-a-hero-variant-1440.png'), 1440, 600);

  console.log('Rendering Concept B Desktop 1440...');
  await captureBoard(cdpPort, `${site}/concept-b`, path.join(outputDir, 'concept-b-desktop-1440.png'), 1440, 900);

  console.log('Rendering Concept B Mobile 390...');
  await captureBoard(cdpPort, `${site}/concept-b`, path.join(outputDir, 'concept-b-mobile-390.png'), 390, 844);

  console.log('Rendering Concept C Desktop 1440...');
  await captureBoard(cdpPort, `${site}/concept-c`, path.join(outputDir, 'concept-c-desktop-1440.png'), 1440, 900);

  console.log('Rendering Concept C Mobile 390...');
  await captureBoard(cdpPort, `${site}/concept-c`, path.join(outputDir, 'concept-c-mobile-390.png'), 390, 844);

  console.log('Rendering Software Catalog Wireframe Desktop 1440...');
  await captureBoard(cdpPort, `${site}/software-wireframe`, path.join(outputDir, 'software-wireframe-desktop-1440.png'), 1440, 900);

  console.log('Rendering Software Catalog Wireframe Mobile 390...');
  await captureBoard(cdpPort, `${site}/software-wireframe`, path.join(outputDir, 'software-wireframe-mobile-390.png'), 390, 844);

  // Copy existing control screenshots into outputDir
  const controlSourceDesktop = path.join(root, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'screenshots', 'after', 'home-1440x900.png');
  const controlSourceMobile = path.join(root, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'screenshots', 'after', 'home-390x844-final.png');

  if (fs.existsSync(controlSourceDesktop)) {
    fs.copyFileSync(controlSourceDesktop, path.join(outputDir, 'control-desktop-1440.png'));
  }
  if (fs.existsSync(controlSourceMobile)) {
    fs.copyFileSync(controlSourceMobile, path.join(outputDir, 'control-mobile-390.png'));
  }

  chrome.kill();
  server.close();
  console.log('All H9 Stage 1 boards rendered successfully!');
})();
