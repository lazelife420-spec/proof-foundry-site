// Node half of scripts/check-home-receipt-truth.ps1. Runs the homepage's own
// pf-truth-receipt.js against the built same-origin records (/truth/ and
// /proof/index.json) and the built /proof/ page. Prints PASS/FAIL lines;
// exits 1 on any failure.
// usage: node scripts/home-receipt-truth.check.mjs <publicDir> <expectedInvalidJson>
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [publicDir, expectedArg] = process.argv.slice(2);
const expectedInvalid = JSON.parse(expectedArg || '{}');
const lib = await import(pathToFileURL(path.join(publicDir, 'pf-truth-receipt.js')).href);
const { validate, buildReceipt, indexEntries, verificationState, verificationChecks, codeSigningChecks, verificationStamp, STATE_WORDS, EVIDENCE_GATED_DIMENSIONS, EVIDENCE_CLASS_STATES, VERIFICATION_DIMENSIONS, VERIFICATION_LABELS, safeHref, verifyCommand, truthRecordUrl } = lib;

let failed = 0;
const assert = (name, condition, detail) => {
  if (condition) console.log(`PASS: ${name}`);
  else { failed++; console.log(`FAIL: ${name}${detail === undefined ? '' : ' :: ' + JSON.stringify(detail).slice(0, 400)}`); }
};
const read = (rel) => JSON.parse(fs.readFileSync(path.join(publicDir, rel), 'utf8'));
const clone = (v) => JSON.parse(JSON.stringify(v));

const schema = read('truth/schema-v1.json');
const index = read('truth/index.json');
const registry = read('proof/index.json');
const manifest = read('site-manifest.json');
const productFiles = fs.readdirSync(path.join(publicDir, 'truth/products')).filter((f) => f.endsWith('.json')).sort();
const records = Object.fromEntries(productFiles.map((f) => [f.replace(/\.json$/, ''), read(`truth/products/${f}`)]));

// ── 1. Every published v1 record against the published schema ─────────────
assert('index validates against /truth/schema-v1.json', validate(schema, index).valid, validate(schema, index).errors);
assert('index lists exactly the published product records', JSON.stringify(index.products.map((p) => p.id).sort()) === JSON.stringify(Object.keys(records).sort()) && index.productCount === productFiles.length);
for (const [id, record] of Object.entries(records)) {
  const result = validate(schema, record);
  const expected = expectedInvalid[id];
  if (!expected) assert(`${id}: record validates against /truth/schema-v1.json`, result.valid, result.errors);
  else {
    const paths = [...new Set(result.errors.map((e) => e.path))];
    assert(`${id}: documented inherited v1 exception still fails only at ${expected}`, !result.valid && paths.length === 1 && paths[0] === expected, { valid: result.valid, paths });
  }
  console.log(`RESULT ${id} ${result.valid ? 'valid' : 'invalid ' + result.errors.map((e) => e.path).join(',')}`);
}

// ── 2. The validator rejects what it must, and refuses what it cannot judge ─
const good = records.proofshot;
const mutations = {
  'malformed digest': (r) => { r.artifacts[0].sha256 = r.artifacts[0].sha256.toUpperCase(); },
  'short digest': (r) => { r.download.sha256 = 'abc123'; },
  'missing required field': (r) => { delete r.source; },
  'extra field': (r) => { r.marketing = 'Trusted!'; },
  'wrong schemaVersion': (r) => { r.schemaVersion = 2; },
  'wrong type': (r) => { r.tests[0].result = 262; },
  'null evidence URL': (r) => { r.evidence[0].url = null; },
  'non-https download URL': (r) => { r.artifacts[0].downloadUrl = 'http://example.invalid/file.exe'; },
  'bad commit identity': (r) => { r.source.commit = 'HEAD'; },
  'empty label': (r) => { r.evidence[0].label = ''; },
};
for (const [name, mutate] of Object.entries(mutations)) {
  const r = clone(good); mutate(r);
  assert(`validator rejects a record with ${name}`, !validate(schema, r).valid);
}
const indexMutated = clone(index); indexMutated.productCount = '7';
assert('validator rejects an index with a string productCount', !validate(schema, indexMutated).valid);
const unknownKeyword = clone(schema); unknownKeyword.$defs.productTruth.properties.id.format = 'uri';
assert('validator fails closed on a schema keyword it does not implement', !validate(unknownKeyword, good).valid && /Unsupported schema keyword/.test(validate(unknownKeyword, good).errors[0].message));
const remoteRef = clone(schema); remoteRef.oneOf[0] = { $ref: 'https://example.invalid/schema.json' };
assert('validator fails closed on a non-local $ref', !validate(remoteRef, good).valid);
assert('validator accepts both oneOf shapes only once', validate(schema, good).valid && validate(schema, index).valid);

// ── 3. The same-origin records come from the shared release authority ──────
assert('proof registry names release-truth.json as its authored release authority', registry.releaseFactsSource && registry.releaseFactsSource.authoredFile === 'release-truth.json');
assert('proof registry and truth records come from the same website source', registry.generatedAt === index.source.committedAt, { registry: registry.generatedAt, truth: index.source.committedAt });
assert('inspector labels are the site verification vocabulary', JSON.stringify(VERIFICATION_LABELS) === JSON.stringify(manifest.verificationLabels), { inspector: VERIFICATION_LABELS, site: manifest.verificationLabels });

// ── 4. Receipts for every homepage inspector product ───────────────────────
const home = fs.readFileSync(path.join(publicDir, 'index.html'), 'utf8');
const receiptIds = [...new Set([...home.matchAll(/data-receipt-open="([a-z0-9-]+)"/g)].map((m) => m[1]))];
assert('homepage offers receipts for the three featured releases', receiptIds.length === 3, receiptIds);
const proofHtml = fs.readFileSync(path.join(publicDir, 'proof/index.html'), 'utf8');
const proofCard = (id) => (proofHtml.match(new RegExp(`<article class="receipt-card" id="receipt-${id}"[\\s\\S]*?</article>`)) || [''])[0];
const proofMatrix = (id) => {
  const matrix = proofCard(id).match(/<dl class='receipt-fields verification-matrix'>([\s\S]*?)<\/dl>/);
  return matrix ? [...matrix[1].matchAll(/<dt>([^<]*)<\/dt><dd class="status-[^"]*">([^<]*)<\/dd>/g)].map((m) => [m[1], m[2]]) : null;
};
const labels = indexEntries(schema, index, receiptIds);
assert('tab labels come from the validated index', labels && labels.length === receiptIds.length && labels.every((l) => l.name === index.products.find((p) => p.id === l.id).name));
assert('no tab labels from an index that fails the schema', indexEntries(schema, { ...clone(index), productCount: 'seven' }, receiptIds) === null);
assert('no tab labels against a schema that is not Public Truth v1', indexEntries({ ...clone(schema), $id: 'https://example.invalid/other.json' }, index, receiptIds) === null);

for (const id of receiptIds) {
  const record = records[id];
  const result = buildReceipt({ id, schema, index, record, registry });
  const entry = registry.products.find((p) => p.id === id);
  if (expectedInvalid[id]) {
    assert(`${id}: inspector fails closed on the invalid record`, !result.ok && result.reason === 'record' && result.detail.includes(expectedInvalid[id]) && !('receipt' in result), result);
    continue;
  }
  assert(`${id}: inspector builds a receipt once index, record and registry agree`, result.ok && !result.receipt.withdrawn, result);
  if (!result.ok) continue;
  const r = result.receipt;
  const sameFacts = r.name === record.name && r.version === record.version && r.release.publishedAt === record.release.publishedAt
    && r.release.publicVersion === record.release.publicVersion && r.release.companionPublicVersion === (record.release.companionPublicVersion || null)
    && r.release.sourceCommit === record.release.sourceCommit && r.verifiedAt === record.verification.verifiedAt
    && r.checkedAt === (record.verification.checkedAt || null) && r.receiptId === record.verification.receiptId;
  assert(`${id}: version, dates, product source commit and receipt ID equal the record`, sameFacts);
  const pairs = (list) => JSON.stringify(list.map((a) => [a.filename, a.sha256, a.signingStatus, a.distType, a.platform, a.sizeBytes]));
  assert(`${id}: every artifact and SHA-256 equals the record and the proof registry`, pairs(r.artifacts) === pairs(record.artifacts) && pairs(r.artifacts) === pairs(entry.artifacts));
  assert(`${id}: every test result equals the record`, JSON.stringify(r.tests) === JSON.stringify(record.tests));
  const listed = [...new Set([...record.evidence.map((e) => e.url), ...record.proofLinks])];
  assert(`${id}: every evidence link the record lists is rendered once, and nothing else`, JSON.stringify(r.evidence.map((e) => e.url)) === JSON.stringify(listed) && r.evidence.every((e) => e.href === e.url), { rendered: r.evidence.map((e) => e.url), listed });
  assert(`${id}: limitations come from the proof registry`, JSON.stringify(r.limits) === JSON.stringify(entry.limits) && JSON.stringify(entry.limits) === JSON.stringify(manifest.products.find((p) => p.id === id).limits || []));
  assert(`${id}: source trail is the record's schema, commit, tree and committedAt, under release-truth.json`, r.trail.schemaId === schema.$id && r.trail.commit === record.source.commit && r.trail.tree === record.source.tree && r.trail.committedAt === record.source.committedAt && r.trail.recordUrl === truthRecordUrl(id) && r.trail.registryUrl === '/proof/index.json' && r.trail.authority === 'release-truth.json' && r.trail.authorityModelSha256 === registry.releaseFactsSource.modelSha256);
  assert(`${id}: website commit, product source commit and artifact digests stay separate`, r.trail.commit !== r.release.sourceCommit && r.artifacts.every((a) => a.sha256 !== r.trail.commit && a.sha256 !== r.release.sourceCommit));
  const matrix = proofMatrix(id);
  const mine = r.checks.map((c) => [c.label, c.value]);
  assert(`${id}: verification states match the /proof/ record exactly`, matrix && JSON.stringify(mine) === JSON.stringify(matrix), { inspector: mine, proof: matrix });
  assert(`${id}: verification and publication dates read as on /proof/`, proofCard(id).includes(`${r.verifiedLabel} \u2014 ${r.verifiedAt}`) && proofCard(id).includes(`Published \u2014 ${r.release.publishedAt}`), r.verifiedLabel);
  const vocabulary = new Set(['PUBLISHED', 'NOT_PUBLISHED', 'VERIFIED', 'PENDING', 'UNAVAILABLE', 'SIGNED', 'DEBUG SIGNED', 'UNSIGNED', 'AUTHORIZED', 'HOLD', 'PUBLIC_RELEASE', 'FROZEN']);
  assert(`${id}: verification values use the proof page vocabulary`, r.checks.every((c) => vocabulary.has(c.value)), mine);
  const withheld = Array.isArray(entry.unofferedArtifacts) ? entry.unofferedArtifacts : [];
  const offeredHere = r.artifacts.map((a, i) => Boolean(a.downloadUrl) && !withheld.includes(i));
  const count = withheld.length ? { here: offeredHere.filter(Boolean).length, more: offeredHere.filter((o) => !o).length } : null;
  const companion = r.artifacts.some((a, i) => i > 0 && offeredHere[i] && a.platform !== r.artifacts[0].platform);
  assert(`${id}: offered-file markers, the offered count and the companion wording follow the proof registry`, JSON.stringify(r.artifacts.map((a) => a.offered)) === JSON.stringify(offeredHere) && JSON.stringify(r.offerCount) === JSON.stringify(count) && r.companionOffered === companion, { offered: r.artifacts.map((a) => a.offered), offerCount: r.offerCount, companionOffered: r.companionOffered });
}

// ── 4b. Every non-withdrawn record reads exactly as /proof/ derives it ─────
const publicIds = Object.keys(records).filter((id) => !expectedInvalid[id] && records[id].release && records[id].release.releaseStatus !== 'WITHDRAWN');
assert('derived-state parity covers every non-withdrawn product, not only the featured three', receiptIds.every((id) => publicIds.includes(id)) && publicIds.length > receiptIds.length, publicIds);
for (const id of publicIds) {
  const result = buildReceipt({ id, schema, index, record: records[id], registry });
  const r = result.ok ? result.receipt : null;
  const entry = registry.products.find((p) => p.id === id);
  const mine = r ? r.checks.map((c) => [c.label, c.value]) : null;
  assert(`${id}: every derived state equals its /proof/ cell`, r && JSON.stringify(mine) === JSON.stringify(proofMatrix(id)), { inspector: mine, proof: proofMatrix(id) });
  assert(`${id}: the /proof/ date stamp is the one the inspector derives`, r && (!r.verifiedAt || proofCard(id).includes(`${r.verifiedLabel} — ${r.verifiedAt}`)), r && r.verifiedLabel);
  assert(`${id}: no release-authority state and no VERIFIED public download`, r && !r.checks.some((c) => c.dimension === 'RELEASE_AUTHORIZATION' || c.value === 'AUTHORIZED') && r.checks.find((c) => c.dimension === 'PUBLIC_DOWNLOAD').value !== 'VERIFIED');
  assert(`${id}: an evidence-gated check reads VERIFIED only on a published receipt`, r && r.checks.filter((c) => EVIDENCE_GATED_DIMENSIONS.includes(c.dimension) && c.value === 'VERIFIED').every((c) => entry.verification.evidenceClass[c.dimension] === 'PUBLISHED_RECEIPT' && safeHref(entry.verification.receiptUrl)));
}
const presented = Object.fromEntries(manifest.products.map((p) => [p.id, p.presentation || {}]));
assert('the registry copies each evidence class from the presentation, NONE where unset', registry.products.every((e) => { const ec = e.verification && e.verification.evidenceClass; const authored = presented[e.id].evidenceClass || {}; return ec && JSON.stringify(Object.keys(ec)) === JSON.stringify(EVIDENCE_GATED_DIMENSIONS) && EVIDENCE_GATED_DIMENSIONS.every((d) => ec[d] === (authored[d] || 'NONE') && Object.hasOwn(EVIDENCE_CLASS_STATES, ec[d])); }));
assert('the registry copies downloadUnavailable from the presentation', registry.products.every((e) => e.verification && e.verification.downloadUnavailable === Boolean(presented[e.id].downloadUnavailable)));
assert('inspector stamp words are the site labels', Boolean(manifest.labels) && Object.entries(STATE_WORDS).every(([k, v]) => manifest.labels[k] === v), { inspector: STATE_WORDS, site: manifest.labels });

// ── 5. Records that do not agree are refused, field by field ───────────────
const cv = records['cache-vault'];
const refusal = (name, inputs, reason, field) => {
  const result = buildReceipt(inputs);
  const named = !field || (result.conflicts || []).some((c) => c.field === field);
  assert(`refuses ${name}`, !result.ok && result.reason === reason && named && !('receipt' in result), result);
};
const registryWith = (mutate) => { const r = clone(registry); mutate(r.products.find((p) => p.id === 'cache-vault'), r); return r; };
refusal('a different product\'s record', { id: 'proofshot', schema, index, record: cv, registry }, 'disagreement', 'product ID');
const stale = clone(cv); stale.source.commit = '0'.repeat(40);
refusal('a stale record generated from another commit than the index', { id: 'cache-vault', schema, index, record: stale, registry }, 'disagreement', 'website source commit');
const renamed = clone(cv); renamed.name = 'Cache Vault Pro';
refusal('a record whose name disagrees with the index', { id: 'cache-vault', schema, index, record: renamed, registry }, 'disagreement', 'product name');
refusal('a registry on another public version', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.release.publicVersion = '0.3.0'; }) }, 'disagreement', 'public version');
refusal('a registry whose artifact digest differs', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[1].sha256 = 'f'.repeat(64); }) }, 'disagreement', 'artifact 2 SHA-256');
refusal('a registry with another artifact file', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[0].filename = 'CacheVault-v0.3.0-windows.zip'; }) }, 'disagreement', 'artifact 1 file');
refusal('a registry missing an artifact', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts.pop(); }) }, 'disagreement', 'artifact count');
refusal('a registry from another build', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p, r) => { r.generatedAt = '2026-01-01T00:00:00Z'; }) }, 'disagreement', 'website source time');
// Every fact the receipt shows or the release record states must agree, not
// only identity and digests (including the cases from the 2026-10-13 external
// parity review), and the record must agree with itself.
refusal('a registry with another signing status', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[0].signingStatus = 'PRODUCTION_SIGNED'; }) }, 'disagreement', 'artifact 1 signing status');
refusal('a registry with another download address', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[0].downloadUrl = 'https://example.invalid/other.zip'; }) }, 'disagreement', 'artifact 1 download address');
refusal('a registry with another checksum address', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[0].sha256Url = 'https://example.invalid/SHA256SUMS.txt'; }) }, 'disagreement', 'artifact 1 checksum address');
refusal('a registry with another artifact platform', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.artifacts[0].platform = 'macOS'; }) }, 'disagreement', 'artifact 1 platform');
refusal('a registry with another verification status', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.verification.status = 'PENDING'; }) }, 'disagreement', 'verification status');
refusal('a registry with other verification types', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.verification.verificationType = []; }) }, 'disagreement', 'verification types');
refusal('a registry with another test result', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.tests[0].result = 'FAILED'; }) }, 'disagreement', 'test results');
refusal('a registry with another product status', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.productStatus = 'HOLD'; }) }, 'disagreement', 'product status');
refusal('a registry listing evidence the record does not', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.evidence = [...p.evidence, { label: 'Extra', url: 'https://example.invalid/extra' }]; }) }, 'disagreement', 'evidence links');
const bumped = clone(cv); bumped.version = '0.3.2';
const bumpedIndex = clone(index); bumpedIndex.products.find((p) => p.id === 'cache-vault').version = '0.3.2';
refusal('a record whose version contradicts its own release version', { id: 'cache-vault', schema, index: bumpedIndex, record: bumped, registry }, 'disagreement', 'public version');
const offTarget = clone(cv); offTarget.download.sha256 = 'e'.repeat(64);
refusal('a record whose download digest differs from its own artifact', { id: 'cache-vault', schema, index, record: offTarget, registry }, 'disagreement', 'download SHA-256');
const moved = clone(index); moved.products.find((p) => p.id === 'cache-vault').pageUrl = '/cache-vault-old/';
refusal('an index whose page address differs from the record', { id: 'cache-vault', schema, index: moved, record: cv, registry }, 'disagreement', 'page address');
refusal('a registry not projected from release-truth.json', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p, r) => { delete r.releaseFactsSource; }) }, 'registry');
refusal('unreadable registry limitations', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.limits = ['']; }) }, 'registry');
refusal('a registry withholding a file the record does not list', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.unofferedArtifacts = [p.artifacts.length]; }) }, 'registry');
refusal('a registry with a malformed withheld-file list', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p) => { p.unofferedArtifacts = ['1']; }) }, 'registry');
refusal('a product the registry does not list', { id: 'cache-vault', schema, index, record: cv, registry: registryWith((p, r) => { r.products = r.products.filter((x) => x.id !== 'cache-vault'); }) }, 'registry');
const unlisted = clone(index); unlisted.products = unlisted.products.filter((p) => p.id !== 'cache-vault'); unlisted.productCount = unlisted.products.length;
refusal('a product the index does not list', { id: 'cache-vault', schema, index: unlisted, record: cv, registry }, 'index');
refusal('a missing record', { id: 'cache-vault', schema, index, record: undefined, registry }, 'record');
refusal('a missing index', { id: 'cache-vault', schema, index: undefined, record: cv, registry }, 'index');
refusal('a missing registry', { id: 'cache-vault', schema, index, record: cv, registry: undefined }, 'registry');
refusal('a schema that is not Public Truth v1', { id: 'cache-vault', schema: { ...clone(schema), $id: 'https://example.invalid/other.json' }, index, record: cv, registry }, 'schema');
refusal('an unsafe product name', { id: '../cache-vault', schema, index, record: cv, registry }, 'request');

// A withdrawal stated consistently by all three records reads as withdrawn,
// with no artifact, digest or command.
const wRecord = clone(cv);
Object.assign(wRecord, { status: 'WITHDRAWN', state: 'withdrawn', version: null, artifacts: [] });
Object.assign(wRecord.release, { releaseStatus: 'WITHDRAWN', publicVersion: null, companionPublicVersion: null, withdrawnVersion: '0.3.1', withdrawalReason: 'Fixture withdrawal' });
Object.assign(wRecord.download, { available: false, url: null, sha256: null, sha256Url: null, label: null });
const wIndex = clone(index); Object.assign(wIndex.products.find((p) => p.id === 'cache-vault'), { status: 'WITHDRAWN', state: 'withdrawn', version: null });
const wRegistry = registryWith((p) => { p.productStatus = 'WITHDRAWN'; Object.assign(p.release, { releaseStatus: 'WITHDRAWN', publicVersion: null, withdrawnVersion: '0.3.1', withdrawalReason: 'Fixture withdrawal' }); p.artifacts = []; });
const withdrawn = buildReceipt({ id: 'cache-vault', schema, index: wIndex, record: wRecord, registry: wRegistry });
assert('a consistently withdrawn release reads as withdrawn with no artifacts or digests', withdrawn.ok && withdrawn.receipt.withdrawn === true && withdrawn.receipt.withdrawnVersion === '0.3.1' && !('artifacts' in withdrawn.receipt) && !('command' in withdrawn.receipt), withdrawn);

// ── 6. Vocabulary derivation and safety helpers ─────────────────────────────
const held = clone(cv); held.release.releaseStatus = 'HOLD';
assert('HOLD reads as HOLD for release authority, as on /proof/', verificationState('RELEASE_AUTHORIZATION', held).value === 'HOLD');
const ce = registry.products.find((p) => p.id === 'cache-vault');
const withClass = (dimension, cls) => { const e = clone(ce); e.verification.evidenceClass[dimension] = cls; return e; };
assert('a published receipt reads VERIFIED only for a check the record lists', verificationState('ARTIFACT_CUSTODY', cv, withClass('ARTIFACT_CUSTODY', 'PUBLISHED_RECEIPT')).value === 'VERIFIED' && verificationState('REALITY_GATE', cv, withClass('REALITY_GATE', 'PUBLISHED_RECEIPT')).value === 'PENDING');
assert('manifest-only, owner-stamped and ID-only evidence reads NOT_PUBLISHED', ['MANIFEST_ONLY', 'OWNER_STAMPED_UNPUBLISHED', 'ID_ONLY'].every((c) => verificationState('ARTIFACT_CUSTODY', cv, withClass('ARTIFACT_CUSTODY', c)).value === 'NOT_PUBLISHED'));
assert('no evidence, unassessed scope, an unknown class or a missing registry entry never reads VERIFIED', ['NONE', 'RECEIPT_SCOPE_UNASSESSED', 'VERIFIED', 'bogus'].every((c) => verificationState('ARTIFACT_CUSTODY', cv, withClass('ARTIFACT_CUSTODY', c)).value === 'PENDING') && verificationState('ARTIFACT_CUSTODY', cv).value === 'PENDING');
const unavailable = clone(ce); unavailable.verification.downloadUnavailable = true;
assert('a download marked unavailable reads UNAVAILABLE, as on /proof/, and a published one PUBLISHED', verificationState('PUBLIC_DOWNLOAD', cv, unavailable).value === 'UNAVAILABLE' && verificationState('PUBLIC_DOWNLOAD', cv, ce).value === 'PUBLISHED');
const mixed = clone(records.proofshot); mixed.artifacts = [mixed.artifacts[0], { ...mixed.artifacts[0], platform: 'Fixture platform', signingStatus: 'PRODUCTION_SIGNED' }];
const mixedRows = codeSigningChecks(mixed);
assert('code signing is read per artifact when signing differs, and once when it agrees', mixedRows.length === 2 && mixedRows[0].label === `${VERIFICATION_LABELS.CODE_SIGNING} (${mixed.artifacts[0].platform})` && mixedRows[1].value === 'SIGNED' && codeSigningChecks(records.proofshot).length === 1);
assert('the date stamp names a check only when it reads VERIFIED', verificationStamp(cv) === STATE_WORDS.releaseReportStamp && verificationStamp(cv, withClass('ARTIFACT_CUSTODY', 'PUBLISHED_RECEIPT')) === STATE_WORDS.artifactVerifiedStamp);
assert('only https and same-site links become hrefs', safeHref('https://example.com/x') && safeHref('/proof/') && !safeHref('javascript:alert(1)') && !safeHref('//evil.example/x') && !safeHref('http://example.com') && !safeHref(null));
assert('verify command is offered only for plain file names', verifyCommand('ProofShot-Setup-2.0.0.exe') === 'Get-FileHash ".\\ProofShot-Setup-2.0.0.exe" -Algorithm SHA256' && verifyCommand('a"; Remove-Item -Recurse C:\\') === null && verifyCommand('../x.exe') === null);
assert('the proof page derives exactly eight states and no release-authority row', JSON.stringify(VERIFICATION_DIMENSIONS) === JSON.stringify(['ARTIFACT_HASH_PUBLISHED', 'ARTIFACT_HASH_VERIFIED', 'ARTIFACT_CUSTODY', 'RUNTIME_VALIDATION', 'REALITY_GATE', 'PUBLIC_DOWNLOAD', 'CODE_SIGNING', 'PUBLICATION_STATUS']));

console.log(`NODE RESULT: ${failed === 0 ? 'ok' : failed + ' failed'}`);
process.exit(failed ? 1 : 0);
