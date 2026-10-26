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

async function captureScreen(cdpPort, url, outPath, width, height, selectorToScroll = null) {
  const { ws, send } = await connectCDP(cdpPort, url);
  await send('Page.enable');
  await send('Page.navigate', { url });
  await new Promise(r => setTimeout(r, 1000));

  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 768
  });

  if (selectorToScroll) {
    await send('Runtime.evaluate', {
      expression: `const el = document.querySelector('${selectorToScroll}'); if (el) el.scrollIntoView({ block: 'start', inline: 'nearest' });`
    });
    await new Promise(r => setTimeout(r, 400));
  }

  const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.writeFileSync(outPath, Buffer.from(data, 'base64'));
  ws.close();
}

(async () => {
  const httpPort = 8998;
  const cdpPort = 9228;

  console.log('Starting HTTP server & headless browser...');
  const server = await startServer(httpPort);
  const browser = startBrowser(cdpPort);
  await new Promise(r => setTimeout(r, 2000));

  const site = `http://127.0.0.1:${httpPort}`;

  const viewports = [
    { name: '320px', width: 320, height: 640 },
    { name: '390px', width: 390, height: 844 },
    { name: '768px', width: 768, height: 1024 },
    { name: '1024px', width: 1024, height: 768 },
    { name: '1440px', width: 1440, height: 900 }
  ];

  const routes = [
    { slug: 'home', path: '/' },
    { slug: 'software', path: '/software/' },
    { slug: 'proofshot', path: '/proofshot/' },
    { slug: 'cache-vault', path: '/cache-vault/' },
    { slug: 'cleanroom', path: '/cleanroom/' },
    { slug: 'reality-gate', path: '/reality-gate/' },
    { slug: 'about', path: '/about/' },
    { slug: 'support', path: '/support/' },
    { slug: 'truth-files', path: '/truth-files/' },
    { slug: 'tf-proofshot', path: '/truth-files/proofshot/' }
  ];

  for (const vp of viewports) {
    console.log(`\n=== Capturing Viewport: ${vp.name} (${vp.width}x${vp.height}) ===`);
    for (const r of routes) {
      const outName = `${r.slug}-${vp.name}-header.png`;
      console.log(`  -> ${r.path} [header] -> ${outName}`);
      await captureScreen(
        cdpPort,
        `${site}${r.path}`,
        path.join(outputDir, outName),
        vp.width,
        vp.height
      );

      // Also capture footer on 1440px and 390px
      if (vp.name === '1440px' || vp.name === '390px') {
        const outFooter = `${r.slug}-${vp.name}-footer.png`;
        console.log(`  -> ${r.path} [footer] -> ${outFooter}`);
        await captureScreen(
          cdpPort,
          `${site}${r.path}`,
          path.join(outputDir, outFooter),
          vp.width,
          vp.height,
          '.site-footer'
        );
      }
    }
  }

  // Specific detail captures for product subnavigation and support sections
  console.log('\n=== Capturing Detail Features ===');
  await captureScreen(cdpPort, `${site}/proofshot/`, path.join(outputDir, 'proofshot-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  await captureScreen(cdpPort, `${site}/cache-vault/`, path.join(outputDir, 'cache-vault-subnav-1440px.png'), 1440, 900, '.pf-product-navigation');
  await captureScreen(cdpPort, `${site}/support/`, path.join(outputDir, 'support-report-1440px.png'), 1440, 900, '#report');

  console.log('\nAll captures completed successfully.');
  browser.kill();
  server.close();
  process.exit(0);
})();
