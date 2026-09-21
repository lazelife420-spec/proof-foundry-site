// H14 test fixture — deterministic public-state API. NOT the future real
// HZ/RG-connected service; a local provider shaped like its sanitized contract.
//   GET /products           → { apiVersion, revision, products[] } + ETag
//   GET /products?rev=B     → force revision B (test override)
//   GET /products?fault=X   → timeout|slow|500|badjson|big
//   If-None-Match honored: same revision → 304.
import http from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

const port = Number(process.env.PF_FIXTURE_PORT || 8799);
const stateFile = process.env.PF_FIXTURE_STATE; // JSON doc { revisions: { A:{...}, B:{...} } }
const doc = stateFile ? JSON.parse(readFileSync(stateFile, 'utf8')) : { revisions: {} };
// Revision pointer file — flipping it changes upstream state WITHOUT touching
// the website build/source (the no-redeploy control's only mutation point).
const revFile = stateFile ? join(dirname(stateFile), 'current-rev.txt') : null;
const faultFile = stateFile ? join(dirname(stateFile), 'fault.txt') : null;
function currentRev() {
  if (revFile && existsSync(revFile)) { const r = readFileSync(revFile, 'utf8').trim(); if (doc.revisions[r]) return r; }
  return 'A';
}
function currentFault(u) {
  if (u.searchParams.get('fault')) return u.searchParams.get('fault');
  if (faultFile && existsSync(faultFile)) { const f = readFileSync(faultFile, 'utf8').trim(); return f || null; }
  return null;
}

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  if (!u.pathname.startsWith('/products')) { res.writeHead(404); return res.end('{}'); }
  const fault = currentFault(u);
  if (fault === 'timeout') { setTimeout(() => { res.writeHead(500); res.end(); }, 15000); return; }
  if (fault === 'slow') { setTimeout(() => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(doc.revisions.A)); }, 6000); return; }
  if (fault === '500') { res.writeHead(500); return res.end('upstream failure'); }
  if (fault === 'badjson') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end('{not valid json'); }
  if (fault === 'big') { res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify({ apiVersion: 1, revision: 'big', revisionSeq: 90, products: [{ id: 'x', pad: 'y'.repeat(3 * 1024 * 1024) }] })); }
  // Redirect SSRF negative controls — every redirect target must be rejected.
  const redirectTargets = {
    'redir-public': 'https://example.com/products',
    'redir-loopback': 'http://127.0.0.1:8799/products',
    'redir-localhost': 'http://localhost:8799/products',
    'redir-rfc1918-10': 'http://10.0.0.1/products',
    'redir-rfc1918-192': 'http://192.168.1.1/products',
    'redir-file': 'file:///C:/Windows/win.ini',
    'redir-data': 'data:application/json,{}',
  };
  if (redirectTargets[fault]) { res.writeHead(302, { 'Location': redirectTargets[fault] }); return res.end(); }

  const rev = u.searchParams.get('rev') || currentRev();
  const body = doc.revisions[rev] || doc.revisions.A;
  const etag = `"pf-state-${rev}"`;
  if (req.headers['if-none-match'] === etag) { res.writeHead(304); return res.end(); }
  res.writeHead(200, { 'Content-Type': 'application/json', 'ETag': etag, 'Cache-Control': 'no-cache' });
  res.end(JSON.stringify(body));
}).listen(port, '127.0.0.1', () => console.log(`fixture public-state api on 127.0.0.1:${port}`));
