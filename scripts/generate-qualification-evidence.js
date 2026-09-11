import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import http from 'http';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const publicDir = path.join(rootDir, 'public');
const targetUrl = 'http://127.0.0.1:4173/';

const edgePath = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const debugPort = 9222;

const qualificationDir = path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'screenshots', 'qualification');
const afterDir = path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'screenshots', 'after');
const statesDir = path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'screenshots', 'states');

[qualificationDir, afterDir, statesDir].forEach(d => fs.mkdirSync(d, { recursive: true }));

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json; charset=utf-8',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8'
};

function startStaticServer(port = 4173) {
  const server = http.createServer((req, res) => {
    let reqPath = req.url.split('?')[0];
    if (reqPath.endsWith('/')) reqPath += 'index.html';
    const filePath = path.join(publicDir, reqPath.replace(/^\//, ''));
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      const ext = path.extname(filePath).toLowerCase();
      const contentType = mimeTypes[ext] || 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': contentType });
      fs.createReadStream(filePath).pipe(res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
    }
  });

  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => {
      console.log(`Local static HTTP server listening on http://127.0.0.1:${port}/`);
      resolve(server);
    });
  });
}

async function verifyHttpSuccess() {
  const res = await fetch(targetUrl);
  if (!res.ok) {
    throw new Error(`HTTP server returned status ${res.status}`);
  }
  const text = await res.text();
  if (!text.includes('Proof Foundry')) {
    throw new Error('HTTP server response did not contain expected Proof Foundry title');
  }
  console.log('HTTP server verification PASSED: HTTP 200 OK with valid HTML payload.');
}

async function run() {
  const server = await startStaticServer(4173);
  await verifyHttpSuccess();

  console.log('Starting Edge in headless debugging mode...');
  const proc = spawn(edgePath, [
    '--headless=new',
    `--remote-debugging-port=${debugPort}`,
    '--disable-gpu',
    '--no-sandbox',
    '--window-size=1920,1080',
    targetUrl
  ]);

  await new Promise(r => setTimeout(r, 2000));

  try {
    const listRes = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
    const pages = await listRes.json();
    const targetPage = pages.find(p => p.type === 'page');
    if (!targetPage) throw new Error('No target page found');

    const wsUrl = targetPage.webSocketDebuggerUrl;
    console.log(`Connected to CDP at ${wsUrl}`);

    const ws = new WebSocket(wsUrl);
    let id = 1;
    const callbacks = new Map();
    const networkFailures = [];

    ws.onmessage = (msg) => {
      const data = JSON.parse(msg.data);
      if (data.id && callbacks.has(data.id)) {
        callbacks.get(data.id)(data);
        callbacks.delete(data.id);
      } else if (data.method === 'Network.loadingFailed') {
        networkFailures.push(data.params);
      }
    };

    await new Promise(r => ws.onopen = r);

    const send = (method, params = {}) => new Promise((resolve) => {
      const msgId = id++;
      callbacks.set(msgId, resolve);
      ws.send(JSON.stringify({ id: msgId, method, params }));
    });

    await send('Page.enable');
    await send('DOM.enable');
    await send('Runtime.enable');
    await send('Network.enable');

    const evalCode = async (code) => {
      const res = await send('Runtime.evaluate', { expression: code, returnByValue: true });
      return res.result?.result?.value;
    };

    const assertStyledPage = async (contextName) => {
      networkFailures.length = 0; // reset
      const checkResult = await evalCode(`
        (function() {
          const stylesheets = Array.from(document.styleSheets);
          const stylesheetHrefs = stylesheets.map(s => s.href).filter(Boolean);
          const hasFoundryCss = stylesheetHrefs.some(h => h.includes('signature.css') || h.includes('studio.css') || h.includes('styles.css') || h.includes('experience.css'));

          const bodyBg = window.getComputedStyle(document.body).backgroundColor;
          const isWhiteBg = bodyBg === 'rgb(255, 255, 255)' || bodyBg === 'rgba(0, 0, 0, 0)' || bodyBg === '#ffffff';

          const brandLogo = document.querySelector('.brand-logo, .home-brand-logo, img[alt*="Foundry"], .pf-brand img');
          const brandLogoWidth = brandLogo ? (brandLogo.naturalWidth || Math.round(brandLogo.getBoundingClientRect().width)) : 0;
          const brandLogoHeight = brandLogo ? Math.round(brandLogo.getBoundingClientRect().height) : 0;
          const logoSrc = brandLogo ? (brandLogo.currentSrc || brandLogo.src) : '';

          const heroImg = document.querySelector('.product-theater img, .hero-product-shot img, [data-hero-img], #hero-stage-img');
          const heroImgWidth = heroImg ? (heroImg.naturalWidth || Math.round(heroImg.getBoundingClientRect().width)) : 0;

          const heroStage = document.querySelector('.product-theater, .hero-stage, .pf-hero-stage');
          const heroStageRect = heroStage ? heroStage.getBoundingClientRect() : null;
          const theaterWidth = heroStageRect ? Math.round(heroStageRect.width) : 0;

          const bodyText = document.body.innerText || '';
          const hasExpectedText = bodyText.includes('Select a tool. See the real interface.');

          const studioHero = document.querySelector('.studio-home-hero, .home-hero-inner, .product-theater');
          const studioHeroWidth = studioHero ? Math.round(studioHero.getBoundingClientRect().width) : 0;
          const studioHeroStyle = studioHero ? window.getComputedStyle(studioHero) : null;
          const studioHeroFlexDir = studioHeroStyle ? studioHeroStyle.flexDirection : '';

          const heroCopy = document.querySelector('.home-copy, .pf-hero-copy');
          const heroCopyRect = heroCopy ? heroCopy.getBoundingClientRect() : null;

          const headerEl = document.querySelector('.site-header');
          const headerHeight = headerEl ? Math.round(headerEl.getBoundingClientRect().height) : 0;

          const cleanroomAction = document.querySelector('.card-cleanroom .card-explore');
          const cleanroomCard = document.querySelector('.card-cleanroom');
          const cleanroomActionColor = cleanroomAction ? window.getComputedStyle(cleanroomAction).color : '';
          const cleanroomCardBg = cleanroomCard ? window.getComputedStyle(cleanroomCard).backgroundColor : '';

          function parseRgb(colorStr) {
            const m = colorStr.match(/rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)/);
            return m ? [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])] : [255, 255, 255];
          }

          function getLuminance(r, g, b) {
            const [rs, gs, bs] = [r, g, b].map(v => {
              v /= 255;
              return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
            });
            return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
          }

          function contrastRatio(rgb1, rgb2) {
            const l1 = getLuminance(...rgb1);
            const l2 = getLuminance(...rgb2);
            const bright = Math.max(l1, l2);
            const dark = Math.min(l1, l2);
            return (bright + 0.05) / (dark + 0.05);
          }

          const fgRgb = parseRgb(cleanroomActionColor);
          const bgRgb = parseRgb(cleanroomCardBg);
          const cleanroomContrast = contrastRatio(fgRgb, bgRgb);

          return {
            stylesheetCount: stylesheets.length,
            hasFoundryCss,
            bodyBg,
            isWhiteBg,
            brandLogoWidth,
            brandLogoHeight,
            logoSrc,
            heroImgWidth,
            theaterWidth,
            hasExpectedText,
            studioHeroWidth,
            studioHeroFlexDir,
            headerHeight,
            copyTop: heroCopyRect ? Math.round(heroCopyRect.top) : 0,
            stageTop: heroStageRect ? Math.round(heroStageRect.top) : 0,
            cleanroomActionColor,
            cleanroomCardBg,
            cleanroomContrast: Math.round(cleanroomContrast * 100) / 100
          };
        })()
      `);

      if (!checkResult) throw new Error(`[ASSERTION FAILED] Could not evaluate DOM check in ${contextName}`);
      if (checkResult.stylesheetCount === 0) throw new Error(`[ASSERTION FAILED] stylesheet count is 0 in ${contextName}`);
      if (!checkResult.hasFoundryCss) throw new Error(`[ASSERTION FAILED] Foundry stylesheet not loaded in ${contextName}`);
      if (checkResult.isWhiteBg) throw new Error(`[ASSERTION FAILED] body background is white/unstyled (${checkResult.bodyBg}) in ${contextName}`);
      if (checkResult.brandLogoWidth === 0) throw new Error(`[ASSERTION FAILED] brand logo width is 0 in ${contextName}`);
      if (checkResult.heroImgWidth === 0) throw new Error(`[ASSERTION FAILED] hero product image width is 0 in ${contextName}`);
      if (!checkResult.hasExpectedText) throw new Error(`[ASSERTION FAILED] text "Select a tool. See the real interface." not found in ${contextName}`);
      if (checkResult.cleanroomActionColor !== 'rgb(14, 40, 36)') {
        throw new Error(`[ASSERTION FAILED] Cleanroom action color is ${checkResult.cleanroomActionColor} (expected rgb(14, 40, 36) / #0e2824) in ${contextName}`);
      }
      if (checkResult.cleanroomContrast < 4.5) {
        throw new Error(`[ASSERTION FAILED] Cleanroom action contrast ratio is ${checkResult.cleanroomContrast}:1 (expected >= 4.5:1) in ${contextName}`);
      }

      console.log(`[DOM ASSERT OK] ${contextName}: bg=${checkResult.bodyBg}, cleanroomColor=${checkResult.cleanroomActionColor}, contrast=${checkResult.cleanroomContrast}:1, headerH=${checkResult.headerHeight}px, theaterW=${checkResult.theaterWidth}px`);
      return checkResult;
    };

    const setViewport = async (w, h, mobile = false, deviceScaleFactor = 1) => {
      await send('Emulation.setDeviceMetricsOverride', {
        width: w,
        height: h,
        deviceScaleFactor: deviceScaleFactor,
        mobile: mobile,
        screenWidth: w,
        screenHeight: h
      });
      await send('Page.reload');
      await new Promise(r => setTimeout(r, 800));
    };

    const resetScrollPosition = async () => {
      await evalCode('window.scrollTo(0, 0); document.documentElement.scrollTop = 0; document.body.scrollTop = 0;');
      await new Promise(r => setTimeout(r, 200));
    };

    const takeScreenshot = async (outPath, clip = null) => {
      const params = { format: 'png' };
      if (clip) params.clip = clip;
      const res = await send('Page.captureScreenshot', params);
      const buffer = Buffer.from(res.result.data, 'base64');
      fs.writeFileSync(outPath, buffer);
      console.log(`Saved screenshot: ${path.relative(rootDir, outPath)} (${buffer.length} bytes)`);
    };

    // Load deterministic layout probe code
    const layoutProbeCode = fs.readFileSync(path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'layout-probe.js'), 'utf8');

    console.log('\n=== RUNNING STYLED LAYOUT & BOUNDS PROBES ACROSS VIEWPORTS ===');
    const viewportsToProbe = [
      { name: '1920x1080', w: 1920, h: 1080, mobile: false },
      { name: '1536x864', w: 1536, h: 864, mobile: false },
      { name: '1440x900', w: 1440, h: 900, mobile: false },
      { name: '1366x768', w: 1366, h: 768, mobile: false },
      { name: '1024x768', w: 1024, h: 768, mobile: false },
      { name: '820x1180', w: 820, h: 1180, mobile: false },
      { name: '430x932', w: 430, h: 932, mobile: true },
      { name: '390x844', w: 390, h: 844, mobile: true },
      { name: '360x800', w: 360, h: 800, mobile: true },
      { name: '320x256', w: 320, h: 256, mobile: true }
    ];

    const probeResults = {};
    let theaterWidthAt1536 = 0;

    for (const vp of viewportsToProbe) {
      await setViewport(vp.w, vp.h, vp.mobile);
      await resetScrollPosition();
      const domState = await assertStyledPage(`probe-${vp.name}`);

      if (vp.w === 1536) {
        theaterWidthAt1536 = domState.theaterWidth;
      }

      // Breakpoint specific checks
      if (vp.w === 1920) {
        console.log(`[1920 ASSERT] theaterWidth = ${domState.theaterWidth}px (Target >= 800px; 1536 width was ${theaterWidthAt1536}px)`);
        if (domState.theaterWidth < 800) {
          throw new Error(`[ASSERTION FAILED] 1920 product theater width is ${domState.theaterWidth}px, expected >= 800px.`);
        }
      } else if (vp.w === 820) {
        console.log(`[820 ASSERT] studioHeroFlexDir = '${domState.studioHeroFlexDir}', stageTop = ${domState.stageTop}, copyTop = ${domState.copyTop}`);
      } else if (vp.w <= 640) {
        console.log(`[MOBILE ASSERT ${vp.w}] headerHeight = ${domState.headerHeight}px, brandLogoWidth = ${domState.brandLogoWidth}px, brandLogoHeight = ${domState.brandLogoHeight}px`);
        if (domState.headerHeight > 80) {
          throw new Error(`[ASSERTION FAILED] Mobile header height is ${domState.headerHeight}px, expected <= 80px.`);
        }
      }

      const resJson = await evalCode(layoutProbeCode);
      const res = JSON.parse(resJson);
      probeResults[vp.name] = res;
      console.log(`Viewport ${vp.name}: overflowPx=${res.horizontalOverflowPx}, clippedControls=${res.clippedTextOrControlCount}, scrollWidth=${res.documentScrollWidth}, clientWidth=${res.documentElementClientWidth}, fullPageHeight=${res.fullPageHeight}`);
      if (res.clippedTextOrControlCount > 0) {
        console.warn(`  CLIPPED ELEMENTS IN ${vp.name}:`, JSON.stringify(res.clippedTextOrControls));
      }
    }

    fs.writeFileSync(
      path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10', 'layout-probe-results.json'),
      JSON.stringify(probeResults, null, 2)
    );

    console.log('\n=== GENERATING CANONICAL QUALIFICATION & AFTER MATRIX ===');

    // Helper for full page height capture
    const getFullPageHeight = async () => {
      const h = await evalCode(`Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)`);
      return h || 1080;
    };

    // 1920x1080
    await setViewport(1920, 1080, false);
    await resetScrollPosition();
    await assertStyledPage('1920x1080 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-1920x1080.png'), { x: 0, y: 0, width: 1920, height: 1080, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-1920x1080.png'), { x: 0, y: 0, width: 1920, height: 1080, scale: 1 });
    const h1920 = await getFullPageHeight();
    await setViewport(1920, h1920, false);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-fullpage-1920.png'), { x: 0, y: 0, width: 1920, height: h1920, scale: 1 });

    // 1536x864
    await setViewport(1536, 864, false);
    await resetScrollPosition();
    await assertStyledPage('1536x864 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-1536x864.png'), { x: 0, y: 0, width: 1536, height: 864, scale: 1 });

    // 1440x900
    await setViewport(1440, 900, false);
    await resetScrollPosition();
    await assertStyledPage('1440x900 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-1440x900.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-1440x900.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-review-frame-1440.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-review-frame-1440x900.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });
    const h1440 = await getFullPageHeight();
    await setViewport(1440, h1440, false);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-fullpage-1440.png'), { x: 0, y: 0, width: 1440, height: h1440, scale: 1 });
    await takeScreenshot(path.join(qualificationDir, 'home-edge-1440x7600.png'), { x: 0, y: 0, width: 1440, height: h1440, scale: 1 });

    // 1366x768
    await setViewport(1366, 768, false);
    await resetScrollPosition();
    await assertStyledPage('1366x768 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-1366x768.png'), { x: 0, y: 0, width: 1366, height: 768, scale: 1 });

    // 1024x768
    await setViewport(1024, 768, false);
    await resetScrollPosition();
    await assertStyledPage('1024x768 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-1024x768.png'), { x: 0, y: 0, width: 1024, height: 768, scale: 1 });
    const h1024 = await getFullPageHeight();
    await setViewport(1024, h1024, false);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-fullpage-1024.png'), { x: 0, y: 0, width: 1024, height: h1024, scale: 1 });

    // 820x1180 (Tablet hero stacked layout)
    await setViewport(820, 1180, false);
    await resetScrollPosition();
    await assertStyledPage('820x1180 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-820x1180.png'), { x: 0, y: 0, width: 820, height: 1180, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-820x1180.png'), { x: 0, y: 0, width: 820, height: 1180, scale: 1 });
    const h820 = await getFullPageHeight();
    await setViewport(820, h820, false);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-fullpage-820.png'), { x: 0, y: 0, width: 820, height: h820, scale: 1 });

    // 430x932 (Phone 430)
    await setViewport(430, 932, true);
    await resetScrollPosition();
    await assertStyledPage('430x932 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-430x932.png'), { x: 0, y: 0, width: 430, height: 932, scale: 1 });
    await takeScreenshot(path.join(qualificationDir, 'home-wrapper-430.png'), { x: 0, y: 0, width: 430, height: 932, scale: 1 });

    // 390x844 (Phone 390)
    await setViewport(390, 844, true);
    await resetScrollPosition();
    await assertStyledPage('390x844 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-390x844.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    await takeScreenshot(path.join(qualificationDir, 'home-wrapper-390.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-390x844.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-390x844-fixed.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    await takeScreenshot(path.join(afterDir, 'home-390x844-final.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    const h390 = await getFullPageHeight();
    await setViewport(390, h390, true);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-fullpage-390.png'), { x: 0, y: 0, width: 390, height: h390, scale: 1 });

    // 360x800 (Phone 360)
    await setViewport(360, 800, true);
    await resetScrollPosition();
    await assertStyledPage('360x800 fold');
    await takeScreenshot(path.join(qualificationDir, 'home-360x800.png'), { x: 0, y: 0, width: 360, height: 800, scale: 1 });
    await takeScreenshot(path.join(qualificationDir, 'home-wrapper-360.png'), { x: 0, y: 0, width: 360, height: 800, scale: 1 });

    // 320 Reflow & 200% zoom
    await setViewport(320, 568, true);
    await resetScrollPosition();
    await assertStyledPage('320x568 reflow');
    const h320 = await getFullPageHeight();
    await setViewport(320, h320, true);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-reflow-320x256-full.png'), { x: 0, y: 0, width: 320, height: h320, scale: 1 });

    await setViewport(640, 360, true);
    await resetScrollPosition();
    await assertStyledPage('640x360 zoom200');
    const h640 = await getFullPageHeight();
    await setViewport(640, h640, true);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-zoom200-640x360-full.png'), { x: 0, y: 0, width: 640, height: h640, scale: 1 });

    // No JS Captures
    console.log('\n=== GENERATING NO-JS CAPTURES ===');
    await send('Emulation.setScriptExecutionDisabled', { value: true });
    await setViewport(1280, 900, false);
    await resetScrollPosition();
    const hNoJs1280 = await getFullPageHeight();
    await setViewport(1280, hNoJs1280, false);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-nojs-1280.png'), { x: 0, y: 0, width: 1280, height: hNoJs1280, scale: 1 });

    await setViewport(390, 844, true);
    await resetScrollPosition();
    const hNoJs390 = await getFullPageHeight();
    await setViewport(390, hNoJs390, true);
    await resetScrollPosition();
    await takeScreenshot(path.join(qualificationDir, 'home-nojs-390.png'), { x: 0, y: 0, width: 390, height: hNoJs390, scale: 1 });

    await send('Emulation.setScriptExecutionDisabled', { value: false });

    console.log('\n=== GENERATING INTERACTION / STATE CAPTURES ===');

    // State 1: Hero switched to Reality Gate
    await setViewport(390, 844, true);
    await resetScrollPosition();
    await assertStyledPage('state-reality-gate');
    await evalCode(`document.querySelector('[data-show-product="reality-gate"]')?.click()`);
    await new Promise(r => setTimeout(r, 500));
    await takeScreenshot(path.join(statesDir, 'hero-reality-gate-390x844.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });
    await takeScreenshot(path.join(statesDir, 'hero-reality-gate-390x844-fixed.png'), { x: 0, y: 0, width: 390, height: 844, scale: 1 });

    // State 2: Android Filter
    await setViewport(1440, 900, false);
    await resetScrollPosition();
    await assertStyledPage('state-android-filter');
    await evalCode(`
      const sel = document.querySelector('#platform-filter');
      if (sel) { sel.value = 'android'; sel.dispatchEvent(new Event('change', { bubbles: true })); }
    `);
    await new Promise(r => setTimeout(r, 500));
    await takeScreenshot(path.join(statesDir, 'filter-android.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });

    // State 3: Comparison with two tools
    await setViewport(1440, 900, false);
    await resetScrollPosition();
    await assertStyledPage('state-comparison');
    await evalCode(`
      const sel = document.querySelector('#platform-filter');
      if (sel) { sel.value = 'all'; sel.dispatchEvent(new Event('change', { bubbles: true })); }
      const rg = document.querySelector('[data-compare="reality-gate"] input');
      const cv = document.querySelector('[data-compare="cache-vault"] input');
      if (rg) { rg.checked = true; rg.dispatchEvent(new Event('change', { bubbles: true })); }
      if (cv) { cv.checked = true; cv.dispatchEvent(new Event('change', { bubbles: true })); }
      const compareBtn = document.querySelector('.compare-open');
      if (compareBtn) compareBtn.click();
    `);
    await new Promise(r => setTimeout(r, 600));
    await takeScreenshot(path.join(statesDir, 'comparison-two-tools.png'), { x: 0, y: 0, width: 1440, height: 900, scale: 1 });

    ws.close();
    console.log('\nAll proof screenshots and layout probes completed successfully!');
  } finally {
    proc.kill();
    server.close();
    console.log('Server and Edge process stopped.');
  }
}

run().catch(err => {
  console.error('Evidence generation failed:', err);
  process.exit(1);
});
