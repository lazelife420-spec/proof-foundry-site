// Browser regression for the PF-WEB-R1 continuity defects. Build public/ first.
// Checks the rendered 320px Support layout, Truth File text contrast, and
// meaningful product metadata at desktop, mobile, and real browser zoom.
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, readFile, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const rootArg = args.indexOf('--root');
if (rootArg >= 0 && !args[rootArg + 1]) throw new Error('--root requires a checkout path.');
const root = rootArg >= 0 ? path.resolve(args[rootArg + 1]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const publicDir = path.join(root, 'public');
const browserPath = [
  process.env.PF_H9_BROWSER,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
].filter(Boolean).find(existsSync);
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const results = [];
function check(name, condition, evidence) {
  const pass = Boolean(condition);
  results.push({ name, pass, evidence });
  process.stdout.write(`${pass ? 'PASS' : 'FAIL'}: ${name}${pass ? '' : ` ${JSON.stringify(evidence)}`}\n`);
}
function parseColor(value) {
  const match = /^rgba?\(\s*([\d.]+)[, ]+([\d.]+)[, ]+([\d.]+)(?:[, /]+([\d.]+))?\s*\)$/.exec(value);
  if (!match) throw new Error(`Unsupported computed color ${value}`);
  return { rgb: match.slice(1, 4).map(Number), alpha: match[4] === undefined ? 1 : Number(match[4]) };
}
function luminance(rgb) {
  const linear = rgb.map(channel => {
    const x = channel / 255;
    return x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4;
  });
  return linear[0] * .2126 + linear[1] * .7152 + linear[2] * .0722;
}
function contrast(foreground, background) {
  const fg = parseColor(foreground), bg = parseColor(background);
  if (fg.alpha !== 1 || bg.alpha !== 1) return null;
  const a = luminance(fg.rgb), b = luminance(bg.rgb);
  return (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
}
function contrastOver(foreground, background, pageBackground) {
  const fg = parseColor(foreground), bg = parseColor(background), page = parseColor(pageBackground);
  if (fg.alpha !== 1 || page.alpha !== 1) return null;
  const effective = bg.rgb.map((channel, index) => channel * bg.alpha + page.rgb[index] * (1 - bg.alpha));
  const a = luminance(fg.rgb), b = luminance(effective);
  return (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
}
// Record rows can be transparent. Resolve the painted surface through their
// ancestors before checking link text or an offset focus outline.
const linkSurfaceExpression = selector => '(()=>{' +
  'const elements=[...document.querySelectorAll(' + JSON.stringify(selector) + ')];' +
  'const rgba=value=>{const m=/^rgba?\\(\\s*([\\d.]+)[, ]+([\\d.]+)[, ]+([\\d.]+)(?:[, /]+([\\d.]+))?\\s*\\)$/.exec(value);return m?{rgb:m.slice(1,4).map(Number),alpha:m[4]===undefined?1:Number(m[4])}:null};' +
  'const painted=element=>{const chain=[];for(let n=element;n;n=n.parentElement)chain.unshift(n);let rgb=[255,255,255],image=false;for(const node of chain){const s=getComputedStyle(node),c=rgba(s.backgroundColor);if(s.backgroundImage!=="none")image=true;if(!c)return null;rgb=c.rgb.map((channel,i)=>channel*c.alpha+rgb[i]*(1-c.alpha));}return {color:"rgb("+rgb.map(Math.round).join(", ")+")",image};};' +
  'return elements.map(element=>{const s=getComputedStyle(element),r=element.getBoundingClientRect(),p=element.parentElement;return {text:element.textContent.trim(),href:element.getAttribute("href"),color:s.color,background:painted(element),adjacentBackground:painted(p),outlineColor:s.outlineColor,outlineStyle:s.outlineStyle,outlineWidth:parseFloat(s.outlineWidth),outlineOffset:parseFloat(s.outlineOffset),focused:document.activeElement===element,focusVisible:element.matches(":focus-visible"),hovered:element.matches(":hover"),visible:element.checkVisibility({checkVisibilityCSS:true}),rect:{left:r.left,right:r.right,top:r.top,bottom:r.bottom},clientWidth:document.documentElement.clientWidth};});})()';
function within(parent, child) {
  const relative = path.relative(parent, child);
  return relative === '' || (relative !== '..' && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative));
}

if (!browserPath) throw new Error('Chrome or Edge required for continuity regression.');
if (!existsSync(path.join(publicDir, 'index.html'))) throw new Error('Build public/ first.');

const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp' };
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
    let file = path.resolve(publicDir, '.' + pathname);
    if (!within(publicDir, file)) { response.writeHead(403).end(); return; }
    const stat = await (await import('node:fs/promises')).stat(file);
    if (stat.isDirectory()) file = path.join(file, 'index.html');
    const real = await realpath(file);
    if (!within(publicDir, real)) { response.writeHead(403).end(); return; }
    const body = await readFile(real);
    response.writeHead(200, { 'Content-Type': mime[path.extname(real)] || 'application/octet-stream', 'Content-Length': body.length, 'Cache-Control': 'no-store' }).end(body);
  } catch { response.writeHead(404).end(); }
});

let browser, profile, socket;
try {
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  profile = await mkdtemp(path.join(tmpdir(), 'pf-continuity-regression-'));
  browser = spawn(browserPath, [
    '--headless=new', '--window-size=1440,900', '--force-device-scale-factor=1', '--disable-gpu',
    '--disable-background-networking', '--disable-component-update', '--disable-sync',
    '--no-first-run', '--no-default-browser-check', '--remote-debugging-address=127.0.0.1',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
  ], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  browser.stderr.on('data', () => {});
  let port;
  for (let i = 0; i < 100; i++) {
    if (browser.exitCode !== null) throw new Error(`Browser exited ${browser.exitCode}`);
    const portFile = path.join(profile, 'DevToolsActivePort');
    if (existsSync(portFile)) { port = Number((await readFile(portFile, 'utf8')).split(/\r?\n/)[0]); break; }
    await pause(100);
  }
  if (!port) throw new Error('Browser CDP port unavailable.');
  const base = `http://127.0.0.1:${port}`;
  const target = await fetch(base + '/json/new?about:blank', { method: 'PUT' }).then(response => response.json());
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (!pending.has(message.id)) return;
    const entry = pending.get(message.id);
    clearTimeout(entry.timer);
    pending.delete(message.id);
    message.error ? entry.reject(new Error(message.error.message)) : entry.resolve(message.result);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 30000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    return result.result.value;
  };
  const navigate = async route => {
    await send('Page.navigate', { url: origin + route });
    for (let i = 0; i < 100; i++) {
      if (await evaluate(`document.readyState === 'complete' && location.pathname === ${JSON.stringify(route)}`)) break;
      await pause(100);
    }
    if (!await evaluate(`document.readyState === 'complete' && location.pathname === ${JSON.stringify(route)}`)) throw new Error(`Navigation incomplete: ${route}`);
    await evaluate('document.fonts.ready');
  };
  const layout = () => evaluate(`(()=>{
    const d=document.documentElement;const scroll=document.scrollingElement;const prior=scroll.scrollLeft;
    scroll.scrollLeft=99999;const maxScrollX=scroll.scrollLeft;scroll.scrollLeft=prior;
    const grid=document.querySelector('.support-products-grid');
    const cards=[...document.querySelectorAll('.support-products-grid .detail-card')].map(e=>({left:e.getBoundingClientRect().left,right:e.getBoundingClientRect().right,width:e.getBoundingClientRect().width}));
    return {clientWidth:d.clientWidth,scrollWidth:Math.max(d.scrollWidth,document.body.scrollWidth),maxScrollX,grid:grid?{left:grid.getBoundingClientRect().left,right:grid.getBoundingClientRect().right,columns:getComputedStyle(grid).gridTemplateColumns}:null,cards};
  })()`);
  const typography = selector => evaluate(`(()=>[...document.querySelectorAll(${JSON.stringify(selector)})].filter(e=>e.checkVisibility({checkVisibilityCSS:true})).map(e=>{
    const s=getComputedStyle(e),r=e.getBoundingClientRect();return {fontSize:parseFloat(s.fontSize),scrollWidth:e.scrollWidth,clientWidth:e.clientWidth,scrollHeight:e.scrollHeight,clientHeight:e.clientHeight,rect:{left:r.left,right:r.right,width:r.width,height:r.height},text:e.textContent.trim()};
  }))()`);
  const surface = (surfaceSelector, textSelector) => evaluate(`(()=>{
    const surface=document.querySelector(${JSON.stringify(surfaceSelector)});
    if(!surface)return null;
    const background=getComputedStyle(surface).backgroundColor;
    const image=getComputedStyle(surface).backgroundImage;
    const candidates=${JSON.stringify(textSelector)}==='@self'?[surface]:[...surface.querySelectorAll(${JSON.stringify(textSelector)})];
    const texts=candidates.filter(e=>e.checkVisibility({checkVisibilityCSS:true})).map(e=>({text:e.textContent.trim().slice(0,80),color:getComputedStyle(e).color,fontSize:getComputedStyle(e).fontSize}));
    return {background,image,pageBackground:getComputedStyle(document.body).backgroundColor,pageImage:getComputedStyle(document.body).backgroundImage,texts};
  })()`);
  const linkMetrics = selector => evaluate(linkSurfaceExpression(selector));
  const textRatio = item => item?.background && !item.background.image
    ? contrast(item.color, item.background.color) : null;
  const outlineRatio = item => item?.adjacentBackground && !item.adjacentBackground.image
    ? contrast(item.outlineColor, item.adjacentBackground.color) : null;
  const pressTab = async () => {
    await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 });
  };
  const tabUntil = async selector => {
    for (let i = 0; i < 32; i++) {
      if (await evaluate('document.activeElement?.matches(' + JSON.stringify(selector) + ') && document.activeElement.matches(":focus-visible")')) return true;
      await pressTab();
    }
    return false;
  };
  const checkCleanroomLinks = async view => {
    const recordLinks = await linkMetrics('.tf-record-list a');
    check('Cleanroom Record links ' + view + ' default text contrast >=4.5',
      recordLinks.length === 6 && recordLinks.every(item => item.visible && (textRatio(item) ?? 0) >= 4.5),
      recordLinks.map(item => ({ text: item.text, color: item.color, background: item.background, ratio: textRatio(item) })));

    await evaluate('document.querySelector(".tf-record-list a").scrollIntoView({block:"center",behavior:"instant"});true');
    await pause(100);
    const point = await evaluate('(()=>{const r=document.querySelector(".tf-record-list a").getBoundingClientRect();return {x:(r.left+r.right)/2,y:(r.top+r.bottom)/2}})()');
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: point.x, y: point.y });
    const hovered = (await linkMetrics('.tf-record-list a'))[0];
    check('Cleanroom Record link ' + view + ' hover text contrast >=4.5',
      hovered?.hovered && (textRatio(hovered) ?? 0) >= 4.5,
      { hovered, ratio: textRatio(hovered) });
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 0, y: 0 });

    // Real same-origin visit/Back; Chromium masks :visited computed color for
    // privacy, so also require an authored visited rule equal to the measured
    // default foreground. Do not treat computed color alone as visited proof.
    await navigate('/proof/');
    await evaluate('history.back();true');
    for (let i = 0; i < 100; i++) {
      if (await evaluate('document.readyState === "complete" && location.pathname === "/truth-files/cleanroom/"')) break;
      await pause(100);
    }
    const visitedLink = (await linkMetrics('.tf-record-list a')).find(item => item.href === '/proof/');
    const visitedRule = await evaluate('(()=>{for(const sheet of document.styleSheets){let rules;try{rules=sheet.cssRules}catch{continue}for(const rule of rules){if(rule.selectorText?.includes(".tf-page.product-cleanroom .tf-record-list a:visited")){const probe=document.createElement("span");probe.style.color=rule.style.color;document.body.append(probe);const color=getComputedStyle(probe).color;probe.remove();return {selector:rule.selectorText,color};}}}return null})()');
    check('Cleanroom Record link ' + view + ' visited rule retains >=4.5 text contrast after Back',
      visitedLink && visitedRule?.color === visitedLink.color && (textRatio(visitedLink) ?? 0) >= 4.5,
      { visitedLink, visitedRule, ratio: textRatio(visitedLink) });

    await navigate('/truth-files/cleanroom/');
    const reached = await tabUntil('.tf-breadcrumb a');
    const focused = [];
    if (reached) {
      for (let i = 0; i < 8; i++) {
        focused.push((await linkMetrics('main a:focus-visible'))[0] || null);
        if (i < 7) await pressTab();
      }
    }
    const focusData = focused.map(item => ({ text: item?.text, color: item?.outlineColor, background: item?.adjacentBackground, ratio: outlineRatio(item), width: item?.outlineWidth, offset: item?.outlineOffset, focusVisible: item?.focusVisible }));
    check('Cleanroom main links ' + view + ' keyboard focus indicator contrast >=3',
      focused.length === 8 && focused.every(item => item?.focused && item.focusVisible && item.outlineStyle === 'solid' && item.outlineWidth >= 2 && (outlineRatio(item) ?? 0) >= 3),
      focusData);
    const focusedRecords = focused.filter(item => item?.href && recordLinks.some(record => record.href === item.href));
    check('Cleanroom Record links ' + view + ' keyboard-focus text contrast >=4.5',
      focusedRecords.length === 6 && focusedRecords.every(item => (textRatio(item) ?? 0) >= 4.5),
      focusedRecords.map(item => ({ text: item.text, ratio: textRatio(item) })));
    const machine = focused.at(-1);
    check('Cleanroom View JSON ' + view + ' focus outline contrasts with Machine panel >=3',
      machine?.href === '/truth/products/cleanroom.json' && machine.focusVisible && machine.outlineStyle === 'solid' && machine.outlineWidth >= 2 && (outlineRatio(machine) ?? 0) >= 3,
      { machine, ratio: outlineRatio(machine) });
    check('Cleanroom View JSON ' + view + ' label contrast and focus ring fit',
      machine && (textRatio(machine) ?? 0) >= 4.5 && machine.rect.left - machine.outlineWidth - machine.outlineOffset >= 0 && machine.rect.right + machine.outlineWidth + machine.outlineOffset <= machine.clientWidth + 1,
      { machine, textRatio: textRatio(machine) });
    // Start a fresh keyboard path with the Record list in view. This
    // reproduces the narrow-screen case where Shift+Tab could place its
    // focused last link entirely behind the sticky header.
    await navigate('/truth-files/cleanroom/');
    await evaluate('document.querySelector(".tf-record-list a").scrollIntoView({block:"center",behavior:"instant"});true');
    const machineReached = await tabUntil('.tf-machine a.button.button-secondary');
    await pause(700);
    await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9, modifiers: 8 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9, modifiers: 8 });
    await pause(300);
    const previous = (await linkMetrics('.tf-record-list a:focus-visible'))[0];
    const header = await evaluate('(()=>({bottom:document.querySelector(".site-header").getBoundingClientRect().bottom,height:innerHeight}))()');
    check('Cleanroom last Record link ' + view + ' backward-Tab focus clears sticky header',
      machineReached && previous?.href === '/cleanroom/' && previous.focused && previous.focusVisible &&
      previous.rect.top - previous.outlineWidth - previous.outlineOffset >= header.bottom - 1 &&
      previous.rect.bottom + previous.outlineWidth + previous.outlineOffset <= header.height + 1,
      { previous, header });
  };
  const checkCleanroomBadge = async view => {
    const badge = await surface('.tf-page.product-cleanroom .tf-fresh code.inline', '@self');
    const ratio = badge?.texts.length === 1 && badge.image === 'none' && badge.pageImage === 'none'
      ? contrastOver(badge.texts[0].color, badge.background, badge.pageBackground)
      : null;
    check('Cleanroom source-commit badge ' + view + ' retains its text', badge?.texts.length === 1 && /^[0-9a-f]{12}$/.test(badge.texts[0].text), badge);
    check('Cleanroom source-commit badge ' + view + ' contrast >=4.5', ratio !== null && ratio >= 4.5, { badge, ratio });
  };
  await send('Page.enable');
  await send('Runtime.enable');

  for (const width of [1440, 390, 320]) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: width === 1440 ? 900 : 844, deviceScaleFactor: 1, mobile: false });
    await navigate('/support/');
    const support = await layout();
    check(`Support ${width}px has no horizontal scroll`, support.maxScrollX === 0 && support.scrollWidth <= support.clientWidth + 1, support);
    check(`Support ${width}px cards fit their grid`, support.cards.length >= 7 && support.cards.every(card => card.right <= support.grid.right + 1 && card.right <= support.clientWidth + 1), support);

    await navigate('/truth-files/cleanroom/');
    await checkCleanroomBadge(String(width) + 'px');
    await checkCleanroomLinks(String(width) + 'px');
    for (const [name, selector, text] of [
      ['fact cards', '.tf-fact', 'dt,dd,.tf-sub'],
      ['verification cards', '.tf-verify-list li', 'span,strong,p'],
      ['limit cards', '.tf-limit-list li', '@self'],
      ['Machine Record', '.tf-machine', 'p,a'],
    ]) {
      const data = await surface(selector, text);
      check(`Cleanroom ${width}px ${name} has opaque surface`, data && parseColor(data.background).alpha === 1 && data.image === 'none', data);
      check(`Cleanroom ${width}px ${name} normal text contrast >=4.5`, data && data.texts.length > 0 && data.texts.every(item => (contrast(item.color, data.background) ?? 0) >= 4.5), data && { background: data.background, ratios: data.texts.map(item => ({ text: item.text, ratio: contrast(item.color, data.background) })) });
    }

    await navigate('/truth-files/forgecast/');
    const summary = await evaluate(`(()=>{const e=document.querySelector('.tf-product-summary');if(!e)return null;const s=getComputedStyle(e),r=e.getBoundingClientRect();return {background:s.backgroundColor,image:s.backgroundImage,color:s.color,width:r.width,right:r.right,clientWidth:document.documentElement.clientWidth}})()`);
    check(`ForgeCast ${width}px summary has an opaque backing across the gradient`, summary && parseColor(summary.background).alpha === 1 && summary.image === 'none', summary);
    check(`ForgeCast ${width}px summary contrast >=4.5`, summary && (contrast(summary.color, summary.background) ?? 0) >= 4.5, summary && { ...summary, ratio: contrast(summary.color, summary.background) });
    check(`ForgeCast ${width}px summary fits viewport`, summary && summary.right <= summary.clientWidth + 1, summary);

    for (const [route, selector, label] of [
      ['/cleanroom/', '.cleanup-status', 'Cleanroom status'],
      ['/ghostlayer/', '.staging-status', 'GhostLayer status'],
      ['/reality-gate/', '.pp-beat-label', 'Reality Gate story label'],
    ]) {
      await navigate(route);
      const data = await typography(selector);
      const horizontal = await evaluate('(()=>{const s=document.scrollingElement,p=s.scrollLeft;s.scrollLeft=99999;const n=s.scrollLeft;s.scrollLeft=p;return n})()');
      const expectedCount = route === '/reality-gate/' ? 3 : 1;
      check(`${label} ${width}px is at least 12px`, data.length >= expectedCount && data.every(item => item.fontSize >= 12), data);
      check(`${label} ${width}px fits without clipping or horizontal scroll`, data.length >= expectedCount && data.every(item => item.scrollWidth <= item.clientWidth + 1 && item.scrollHeight <= item.clientHeight + 1) && horizontal === 0, { data, horizontal });
    }
  }

  // Actual browser zoom, separate from a narrow or emulated viewport.
  await send('Emulation.clearDeviceMetricsOverride');
  await navigate('/');
  const before = await evaluate('({width:innerWidth,dpr:devicePixelRatio})');
  for (let i = 0; i < 5; i++) {
    await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', code: 'Equal', key: '+', windowsVirtualKeyCode: 187, nativeVirtualKeyCode: 187, modifiers: 2 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', code: 'Equal', key: '+', windowsVirtualKeyCode: 187, nativeVirtualKeyCode: 187, modifiers: 2 });
    await pause(90);
  }
  const after = await evaluate('({width:innerWidth,dpr:devicePixelRatio})');
  check('Actual browser zoom reached 200%', after.dpr / before.dpr >= 1.95 && after.dpr / before.dpr <= 2.05 && before.width / after.width >= 1.9, { before, after });
  for (const [route, selector, label] of [
    ['/cleanroom/', '.cleanup-status', 'Cleanroom status'],
    ['/ghostlayer/', '.staging-status', 'GhostLayer status'],
    ['/reality-gate/', '.pp-beat-label', 'Reality Gate story label'],
  ]) {
    await navigate(route);
    const data = await typography(selector);
    const expectedCount = route === '/reality-gate/' ? 3 : 1;
    check(`${label} at 200% browser zoom is at least 12 CSS px`, data.length >= expectedCount && data.every(item => item.fontSize >= 12), data);
    check(`${label} at 200% browser zoom is not clipped`, data.length >= expectedCount && data.every(item => item.scrollWidth <= item.clientWidth + 1 && item.scrollHeight <= item.clientHeight + 1), data);
  }
  await navigate('/truth-files/cleanroom/');
  await checkCleanroomBadge('at 200% browser zoom');
  await checkCleanroomLinks('at 200% browser zoom');
  const failed = results.filter(result => !result.pass).length;
  process.stdout.write(`RESULT: ${results.length - failed} passed, ${failed} failed\n`);
  if (failed) process.exitCode = 1;
} catch (error) {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 2;
} finally {
  socket?.close();
  if (browser && browser.exitCode === null) browser.kill();
  for (let i = 0; i < 50 && browser?.exitCode === null; i++) await pause(100);
  await new Promise(resolve => server.close(resolve));
  const resolved = profile && path.resolve(profile);
  const tempRoot = path.resolve(tmpdir()) + path.sep;
  if (resolved?.startsWith(tempRoot) && path.basename(resolved).startsWith('pf-continuity-regression-')) await rm(resolved, { recursive: true, force: true });
}
