'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { compile, readAuthoredInputs, FACT_FIELDS } = require('./shared-release-truth.cjs');
const { serialize, sha256Hex } = require('../vendor/pf-shared-release-truth/pf-release-truth');
const root = path.resolve(__dirname, '..');
const model = JSON.parse(fs.readFileSync(path.join(root, 'release-truth.json'), 'utf8'));
const presentation = JSON.parse(fs.readFileSync(path.join(root, 'site-manifest.json'), 'utf8'));
const copy = value => JSON.parse(JSON.stringify(value));
const product = (value, id) => value.products.find(p => p.id === id);
const evidence = process.env.PF_WEBSITE_PREVIEW_EVIDENCE;
let fixtureNumber = 0;
function fixture() {
  assert.ok(evidence && path.isAbsolute(evidence), 'Explicit external website-preview evidence required.');
  const dir = path.join(evidence, `unit-fixture-${process.pid}-${++fixtureNumber}`);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'vendor/pf-shared-release-truth/provenance.json')));
  for (const file of [...manifest.files.map(f => f.destination), 'vendor/pf-shared-release-truth/provenance.json', 'site-manifest.json']) {
    const dest = path.join(dir, file);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(path.join(root, file), dest);
  }
  return dir;
}

test('website preview uses the remotely preserved seven-product model and exact website projection', () => {
  const result = readAuthoredInputs();
  assert.equal(result.manifest.products.length, 7);
  assert.equal(result.projection.modelSha256, '456810ca16c61872f982b54a9975858903bc209387f1b819ef26de39474aeb7a');
  assert.equal(crypto.createHash('sha256').update(result.projectionBytes).digest('hex'), '364d4e48b9fcec3a1b9b0595b692049e3045a1980bdd4657d08738d36567269d');
  assert.equal(result.provenance.mode, 'PREVIEW_ONLY');
  assert.equal(result.provenance.productionCutover, 'NOT_PERFORMED');
});
test('website preview has exactly one owner of release facts', () => {
  for (const p of presentation.products) for (const key of FACT_FIELDS) assert.equal(Object.hasOwn(p, key), false, p.id + '.' + key);
  for (const key of ['release', 'downloadUrl', 'artifacts', 'verification', 'state', 'platform']) {
    const p = copy(presentation); p.products[0][key] = 'contradictory authored fixture';
    assert.throws(() => compile(model, p), /Dual-authored release fact/);
  }
});
test('withdrawn Reality Gate has no public version or artifact URL in compiled consumer state', () => {
  const p = product(compile(model, presentation).manifest, 'reality-gate');
  assert.equal(p.state, 'withdrawn'); assert.equal(p.productStatus, 'WITHDRAWN');
  assert.equal(p.release.publicVersion, null); assert.equal(p.release.withdrawnVersion, '1.1.0');
  assert.match(p.release.withdrawalReason, /Security packaging defect/);
  assert.equal(p.downloadUrl, null); assert.equal(p.sha256Url, null);
  assert.ok(p.artifacts.every(a => a.downloadUrl === null && a.sha256Url === null));
});
test('Cleanroom candidate remains separate from its public artifact and reported qualification', () => {
  const p = product(compile(model, presentation).manifest, 'cleanroom');
  assert.equal(p.release.publicVersion, '1.0.7'); assert.equal(p.release.candidateVersion, '1.0.10');
  assert.equal(p.currentLocalVersion, '1.0.10'); assert.match(p.artifacts[0].filename, /1\.0\.7/);
  assert.equal(product(model, 'cleanroom').verification.version, '1.0.7');
});
test('Lights Out public companion and built-only companion never collapse into one channel', () => {
  const compiled = compile(model, presentation), p = product(compiled.manifest, 'lights-out');
  assert.equal(p.release.publicVersion, '11.1.3'); assert.equal(p.release.companionPublicVersion, '11.1.1');
  assert.equal(p.companionVersion, '11.1.3');
  const c = product(compiled.projection, 'lights-out').channels;
  assert.equal(c.find(x => x.platform === 'android' && x.track === 'BUILT').publicationState, 'BUILT_NOT_PUBLIC');
  assert.ok(p.artifacts.every(a => a.platform === 'Windows'));
});
test('Cache Vault failed CI and debug-build limits remain reported evidence', () => {
  const p = product(compile(model, presentation).manifest, 'cache-vault');
  assert.ok(p.tests.some(t => t.result.startsWith('FAILED')));
  assert.ok(p.limits.some(l => l.includes('debug-signed app')));
  assert.equal(compile(model, presentation).provenance.qualificationInterpretation, 'REPORTED_BY_AUTHORED_SOURCE');
});
test('ProofShot unresolved licensing finding and unknown artifact sizes stay explicit', () => {
  const compiled = compile(model, presentation);
  assert.ok(product(compiled.manifest, 'proofshot').limits.some(l => l.includes('licensing-authority finding remains unresolved')));
  for (const id of ['ghostlayer', 'cleanroom']) assert.equal(product(compiled.manifest, id).artifacts[0].sizeBytes, null);
});
test('canonical artifact change propagates without consulting any website fixture', () => {
  const changed = copy(model); product(changed, 'ghostlayer').channels[0].artifacts[0].sha256 = '1'.repeat(64);
  const result = compile(changed, presentation);
  assert.equal(product(result.manifest, 'ghostlayer').sha256, '1'.repeat(64));
  assert.equal(result.projection.modelSha256, sha256Hex(changed));
});
test('shadow transport omits irrelevant optional nulls without changing the complete projection', () => {
  const compiled = compile(model, presentation);
  const ghost = product(compiled.manifest, 'ghostlayer');
  assert.equal(Object.hasOwn(ghost.release, 'withdrawnVersion'), false);
  assert.equal(Object.hasOwn(ghost.verification, 'downloadAvailability'), false);
  assert.equal(product(compiled.projection, 'ghostlayer').release.withdrawnVersion, null);
  assert.equal(product(compiled.projection, 'ghostlayer').verification.report.downloadAvailability, null);
  assert.equal(product(compiled.manifest, 'cache-vault').release.companionCandidateVersion, null);
  assert.equal(product(compiled.manifest, 'reality-gate').release.withdrawnVersion, '1.1.0');
});
test('preview authority metadata has an explicit new truth version and leaves the shipped v1 contract unchanged', () => {
  const { execFileSync } = require('node:child_process');
  const shipped = execFileSync('git', ['show', 'c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce:schemas/public-truth-v1.schema.json'], { cwd: root, windowsHide: true });
  assert.ok(fs.readFileSync(path.join(root, 'schemas/public-truth-v1.schema.json')).equals(shipped));
  const schema = JSON.parse(fs.readFileSync(path.join(root, 'schemas/public-truth-v2.schema.json')));
  assert.equal(schema.$defs.truthIndex.properties.schemaVersion.const, 2);
  assert.equal(schema.$defs.productTruth.properties.schemaVersion.const, 2);
  assert.equal(schema.$defs.truthIndex.properties.schemaUrl.const, '/truth/schema-v2.json');
  assert.equal(schema.$defs.truthIndex.properties.generatedFrom.const, 'release-truth.json');
});
test('shared preview loader reads only authored inputs and pinned reducer bytes', () => {
  const original = fs.readFileSync;
  const allowed = new Set(['release-truth.json', 'site-manifest.json', 'vendor/pf-shared-release-truth/provenance.json', 'vendor/pf-shared-release-truth/pf-release-truth/index.js', 'vendor/pf-shared-release-truth/pf-store-core/src/shared/CanonicalJson.js'].map(f => path.join(root, f)));
  const reads = [];
  fs.readFileSync = function(file, ...args) { assert.ok(allowed.has(path.resolve(String(file))), 'Unexpected input read'); reads.push(String(file)); return original.call(this, file, ...args); };
  const signing = crypto.createSign, keys = crypto.generateKeyPairSync;
  crypto.createSign = crypto.generateKeyPairSync = () => { throw new Error('Signing is unavailable to this consumer.'); };
  try { assert.equal(readAuthoredInputs().manifest.products.length, 7); }
  finally { fs.readFileSync = original; crypto.createSign = signing; crypto.generateKeyPairSync = keys; }
  assert.ok(reads.length > 0);
});
test('projection and compiled state are byte-identical across independent locale/timezone processes', () => {
  const outputs = ['UTC', 'Pacific/Honolulu'].map((tz, index) => {
    const r = spawnSync(process.execPath, [path.join(__dirname, 'shared-release-truth.cjs')], { cwd: root, encoding: 'utf8', windowsHide: true, env: { ...process.env, TZ: tz, LANG: index ? 'fr_CA.UTF-8' : 'C' } });
    assert.equal(r.status, 0, r.stderr); return r.stdout;
  });
  assert.equal(outputs[0], outputs[1]);
});
test('missing or duplicate presentation identities fail closed', () => {
  const missing = copy(presentation); missing.products.pop(); assert.throws(() => compile(model, missing), /same product identities/);
  const duplicate = copy(presentation); duplicate.products.push(duplicate.products[0]); assert.throws(() => compile(model, duplicate), /same product identities/);
});
test('presentation cannot supply literal versions as lane selectors', () => {
  const p = copy(presentation); product(p, 'lights-out').releasePresentation.companionDisplayTrack = '11.1.3';
  assert.throws(() => compile(model, p), /Invalid companion lane/);
});
test('production signing authority and withdrawn public-channel tampering are rejected', () => {
  const authority = copy(model); authority.productionSigningAuthority = 'ACTIVE'; assert.throws(() => compile(authority, presentation), /HOLD/);
  const withdrawal = copy(model); product(withdrawal, 'reality-gate').channels[0].artifacts[0].downloadUrl = 'https://downloads.theprooffoundry.com/reality-gate/v1.1.0/withdrawn.zip';
  assert.throws(() => compile(withdrawal, presentation), /withdrawn downloads forbidden/);
});
test('source model or reducer custody drift is rejected before consumption', () => {
  const dir = fixture(); fs.appendFileSync(path.join(dir, 'release-truth.json'), '\n');
  assert.throws(() => readAuthoredInputs(dir), /custody digest mismatch/);
  const other = fixture(); fs.appendFileSync(path.join(other, 'vendor/pf-shared-release-truth/pf-release-truth/index.js'), '\n');
  assert.throws(() => readAuthoredInputs(other), /custody digest mismatch/);
});
test('missing vendor seals cannot silently disable component verification', () => {
  const dir = fixture(), file = path.join(dir, 'vendor/pf-shared-release-truth/provenance.json');
  const p = JSON.parse(fs.readFileSync(file)); p.files = []; fs.writeFileSync(file, JSON.stringify(p));
  assert.throws(() => readAuthoredInputs(dir), /Exact remotely preserved/);
});
test('candidate production deploy entry point refuses before build or credential use', () => {
  const r = spawnSync('pwsh', ['-NoProfile', '-File', path.join(root, 'deploy.ps1')], { cwd: root, encoding: 'utf8', windowsHide: true });
  assert.notEqual(r.status, 0); assert.match(r.stderr, /PREVIEW ONLY/);
  assert.doesNotMatch(r.stdout, /Building public|Deploying proof-foundry-site/);
});
test('candidate build needs explicit preview activation and rejects alternate state transports', () => {
  const r = spawnSync('pwsh', ['-NoProfile', '-File', path.join(__dirname, 'build-site.ps1'), '-ValidateOnly'], { cwd: root, encoding: 'utf8', windowsHide: true });
  assert.notEqual(r.status, 0); assert.match(r.stderr, /Explicit -SharedReleaseTruthPreview/);
  const other = spawnSync('pwsh', ['-NoProfile', '-File', path.join(__dirname, 'build-site.ps1'), '-SharedReleaseTruthPreview', '-StateSourcePath', 'unused.json', '-ValidateOnly'], { cwd: root, encoding: 'utf8', windowsHide: true });
  assert.notEqual(other.status, 0); assert.match(other.stderr, /cannot substitute/);
});
