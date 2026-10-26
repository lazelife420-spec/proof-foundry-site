/**
 * Independent, read-only adversarial tests of the Proof Foundry V5 receipt resolver.
 * Usage:
 *   node PF_V5_RECEIPT_PARITY_REGRESSIONS.mjs /path/to/repository
 *   node PF_V5_RECEIPT_PARITY_REGRESSIONS.mjs /path/to/extracted-review
 *
 * Expected after remediation: ALL checks pass. The reviewed 2026-10-13 candidate
 * fails multiple negative controls: mismatched records are accepted as coherent.
 */
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || process.cwd());
const source = [path.join(root, 'pf-truth-receipt.js'), path.join(root, 'source', 'pf-truth-receipt.js')].find(fs.existsSync);
const publicDir = [path.join(root, 'public'), path.join(root, 'built')].find(p => fs.existsSync(path.join(p, 'truth', 'index.json')));
if (!source || !publicDir) throw new Error('Need pf-truth-receipt.js and generated public/ or built/ Truth records.');
const code = fs.readFileSync(source, 'utf8');
const { buildReceipt } = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
const json = (p) => JSON.parse(fs.readFileSync(path.join(publicDir, p), 'utf8'));
const baseline = {
  id: 'proofshot',
  schema: json('truth/schema-v1.json'),
  index: json('truth/index.json'),
  record: json('truth/products/proofshot.json'),
  registry: json('proof/index.json'),
};
const clone = (v) => structuredClone(v);
const p = v => v.registry.products.find(x => x.id === 'proofshot');
const ix = v => v.index.products.find(x => x.id === 'proofshot');
const checks = [
  ['baseline published ProofShot is accepted', null, true],
  ['artifact SHA mismatch is refused', v => { p(v).artifacts[0].sha256 = '0'.repeat(64); }, false],
  ['signing-status mismatch is refused', v => { p(v).artifacts[0].signingStatus = 'PRODUCTION_SIGNED'; }, false],
  ['download-URL mismatch is refused', v => { p(v).artifacts[0].downloadUrl = 'https://example.invalid/other.exe'; }, false],
  ['checksum-URL mismatch is refused', v => { p(v).artifacts[0].sha256Url = 'https://example.invalid/checksums.txt'; }, false],
  ['verification-status mismatch is refused', v => { p(v).verification.status = 'PENDING'; }, false],
  ['verification-type mismatch is refused', v => { p(v).verification.verificationType = []; }, false],
  ['test-result mismatch is refused', v => { p(v).tests[0].result = 'FAILED'; }, false],
  ['record/index version conflicting with release version is refused', v => { v.record.version = '2.0.1'; ix(v).version = '2.0.1'; }, false],
  ['registry product status mismatch is refused', v => { p(v).productStatus = 'HOLD'; }, false],
];
let passed = 0, failed = 0;
for (const [name, edit, expectedAccept] of checks) {
  const v = clone(baseline);
  if (edit) edit(v);
  const result = buildReceipt(v);
  const ok = Boolean(result.ok) === expectedAccept;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}: ${result.ok ? 'ACCEPTED' : 'REFUSED'}${result.reason ? ` (${result.reason})` : ''}`);
  if (ok) passed++;
  else failed++;
}
console.log(`RESULT: ${passed} passed, ${failed} failed`);
if (failed) process.exitCode = 1;
