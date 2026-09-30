// Browser regression for comparison chip keyboard focus. Run with:
// node scripts/test-comparison-keyboard-focus.mjs
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { existsSync } from "node:fs";
import { mkdtemp, readFile, realpath, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const publicDir = path.join(root, "public");
const chromeCandidates = [
  process.env.CHROME_PATH,
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
].filter(Boolean);
const browserPath = chromeCandidates.find(existsSync);
assert.ok(browserPath, "Chrome or Edge is required (or set CHROME_PATH)");
assert.ok(existsSync(path.join(publicDir, "software", "index.html")), "Build public/ first");

const mime = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml" };
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    const file = pathname === "/experience.js"
      ? path.join(root, "experience.js")
      : path.resolve(publicDir, `.${pathname}`, pathname.endsWith("/") ? "index.html" : "");
    if (file !== path.join(root, "experience.js") && !file.startsWith(publicDir + path.sep)) {
      response.writeHead(403).end();
      return;
    }
    const body = await readFile(file);
    response.writeHead(200, { "Content-Type": mime[path.extname(file)] || "application/octet-stream" }).end(body);
  } catch {
    response.writeHead(404).end();
  }
});

const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(check, label) {
  for (let i = 0; i < 100; i++) {
    const value = await check();
    if (value) return value;
    await pause(100);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

async function connectCdp(url) {
  const socket = new WebSocket(url);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let nextId = 0;
  const pending = new Map();
  socket.addEventListener("message", event => {
    const message = JSON.parse(event.data);
    if (!message.id || !pending.has(message.id)) return;
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(message.error.message));
    else resolve(message.result);
  });
  return {
    call(method, params = {}) {
      const id = ++nextId;
      return new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
        socket.send(JSON.stringify({ id, method, params }));
      });
    },
    close() { socket.close(); },
  };
}

let browser;
let cdp;
let profile;
try {
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const pageUrl = `http://127.0.0.1:${server.address().port}/software/`;
  profile = await mkdtemp(path.join(tmpdir(), "pf-comparison-focus-"));
  browser = spawn(browserPath, [
    "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
    "--disable-extensions", "--remote-debugging-port=0", "--remote-allow-origins=*",
    "--window-size=1440,900", `--user-data-dir=${profile}`, pageUrl,
  ], { stdio: "ignore" });
  const portFile = path.join(profile, "DevToolsActivePort");
  const port = await until(async () => existsSync(portFile)
    ? Number((await readFile(portFile, "utf8")).split("\n")[0])
    : null, "Chrome DevTools port");
  const target = await until(async () => {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`).catch(() => null);
    if (!response?.ok) return null;
    return (await response.json()).find(item => item.type === "page" && item.url === pageUrl);
  }, "software page");
  cdp = await connectCdp(target.webSocketDebuggerUrl);
  await cdp.call("Page.bringToFront");
  await cdp.call("Emulation.setDeviceMetricsOverride", { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  const evaluate = async expression => {
    const result = await cdp.call("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  };
  const enter = async () => {
    const key = { key: "Enter", code: "Enter", windowsVirtualKeyCode: 13, nativeVirtualKeyCode: 13 };
    await cdp.call("Input.dispatchKeyEvent", { type: "rawKeyDown", ...key });
    await cdp.call("Input.dispatchKeyEvent", { type: "char", ...key, text: "\r", unmodifiedText: "\r" });
    await cdp.call("Input.dispatchKeyEvent", { type: "keyUp", ...key });
  };
  await until(() => evaluate("Boolean(document.querySelector('.compare-tray'))"), "comparison controls");

  await evaluate(`(() => {
    document.querySelector('[data-compare="cache-vault"] input').click();
    document.querySelector('[data-compare="ghostlayer"] input').click();
    document.querySelector('[aria-label="Remove Cache Vault from comparison"]').focus();
  })()`);
  assert.equal(await evaluate("document.activeElement?.getAttribute('aria-label')"), "Remove Cache Vault from comparison");
  await enter();
  assert.equal(await evaluate("document.activeElement?.getAttribute('aria-label')"), "Remove GhostLayer from comparison",
    "Removing one of two choices must focus the remaining removal button");
  assert.equal(await evaluate("document.querySelectorAll('.compare-chip').length"), 1);
  await enter();
  assert.equal(await evaluate("document.activeElement?.getAttribute('aria-label')"), "Compare GhostLayer",
    "Removing the last choice must return focus to its checkbox");
  assert.equal(await evaluate("document.querySelector('.compare-tray').hidden"), true);

  await evaluate(`(() => {
    document.querySelector('[data-compare="cache-vault"] input').click();
    document.querySelector('[data-compare="ghostlayer"] input').click();
    document.querySelector('[data-compare="lights-out"] input').click();
    document.querySelector('[aria-label="Remove GhostLayer from comparison"]').focus();
  })()`);
  await enter();
  assert.equal(await evaluate("document.activeElement?.getAttribute('aria-label')"), "Remove Lights Out from comparison",
    "Removing a middle choice must focus the next remaining removal button");
  assert.equal(await evaluate("document.querySelector('.compare-open').disabled"), false);
  console.log("PASS: comparison keyboard removal retains logical focus for 2→1, 1→0, and 3→2");
} finally {
  cdp?.close();
  browser?.kill();
  await new Promise(resolve => server.close(resolve));
  if (profile) {
    const resolvedProfile = await realpath(profile).catch(() => null);
    const resolvedTemp = await realpath(tmpdir());
    if (resolvedProfile && path.dirname(resolvedProfile) === resolvedTemp &&
        path.basename(resolvedProfile).startsWith("pf-comparison-focus-")) {
      await rm(resolvedProfile, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
    }
  }
}
