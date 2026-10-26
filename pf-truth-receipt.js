// Release receipts for the homepage inspector, read from the site's own
// generated records: Public Truth v1 (/truth/) and the proof registry
// (/proof/index.json), both projected by the build from release-truth.json.
//
// Pure functions: no DOM, no network, no stored release values. The page
// fetches the same-origin records; this module validates them against the
// published schema, checks that they agree and derives the receipt. Anything
// that cannot be loaded, validated or reconciled fails closed: the caller gets
// a reason (and, for disagreements, each conflicting field) and no partial
// receipt. scripts/check-home-receipt-truth.ps1 runs this same file against
// the built records and an independent validator.

export const TRUTH_SCHEMA_URL = '/truth/schema-v1.json';
export const TRUTH_INDEX_URL = '/truth/index.json';
export const PROOF_REGISTRY_URL = '/proof/index.json';
export const truthRecordUrl = (id) => `/truth/products/${id}.json`;

const SCHEMA_ID_SUFFIX = '/truth/schema-v1.json';
const AUTHORED_RELEASE_FILE = 'release-truth.json';

// ── JSON Schema 2020-12, the subset Public Truth v1 uses ────────────────────
// An unknown keyword is an error, never ignored: a schema this validator does
// not fully understand cannot vouch for a record.
const ANNOTATIONS = new Set(['$schema', '$id', '$comment', '$defs', 'title', 'description', 'examples', 'default']);
const ASSERTIONS = new Set(['$ref', 'type', 'const', 'enum', 'required', 'properties', 'additionalProperties', 'items', 'pattern', 'minLength', 'minimum', 'oneOf', 'anyOf', 'allOf']);

export class SchemaError extends Error {}

function kindOf(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (typeof value === 'number') return Number.isInteger(value) ? 'integer' : 'number';
  return typeof value;
}

function isType(value, type) {
  const kind = kindOf(value);
  if (type === 'number') return kind === 'number' || kind === 'integer';
  return kind === type;
}

function sameJson(a, b) {
  if (a === b) return true;
  const ka = kindOf(a);
  if (ka !== kindOf(b)) return false;
  if (ka === 'array') return a.length === b.length && a.every((v, i) => sameJson(v, b[i]));
  if (ka === 'object') {
    const keys = Object.keys(a);
    return keys.length === Object.keys(b).length && keys.every((k) => Object.prototype.hasOwnProperty.call(b, k) && sameJson(a[k], b[k]));
  }
  return false;
}

function resolveRef(root, ref) {
  if (typeof ref !== 'string' || !ref.startsWith('#')) throw new SchemaError(`Unsupported $ref ${ref}`);
  let node = root;
  for (const raw of ref.slice(1).split('/').slice(1)) {
    const key = decodeURIComponent(raw).replace(/~1/g, '/').replace(/~0/g, '~');
    if (!node || typeof node !== 'object' || !Object.prototype.hasOwnProperty.call(node, key)) throw new SchemaError(`Unresolvable $ref ${ref}`);
    node = node[key];
  }
  return node;
}

const show = (value) => (kindOf(value) === 'string' ? 'a string' : kindOf(value));

function check(root, schema, value, path, errors) {
  if (schema === true) return;
  if (schema === false) { errors.push({ path, message: 'no value is allowed here' }); return; }
  if (!schema || typeof schema !== 'object' || Array.isArray(schema)) throw new SchemaError(`Invalid schema at ${path || '/'}`);
  for (const key of Object.keys(schema)) {
    if (!ANNOTATIONS.has(key) && !ASSERTIONS.has(key)) throw new SchemaError(`Unsupported schema keyword "${key}"`);
  }
  const kind = kindOf(value);
  if ('$ref' in schema) check(root, resolveRef(root, schema.$ref), value, path, errors);
  if ('type' in schema) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((t) => isType(value, t))) { errors.push({ path, message: `expected ${types.join(' or ')}, found ${show(value)}` }); return; }
  }
  if ('const' in schema && !sameJson(value, schema.const)) errors.push({ path, message: `must equal ${JSON.stringify(schema.const)}` });
  if ('enum' in schema && !schema.enum.some((v) => sameJson(value, v))) errors.push({ path, message: 'is not one of the allowed values' });
  if (kind === 'string') {
    if ('pattern' in schema && !new RegExp(schema.pattern, 'u').test(value)) errors.push({ path, message: 'does not match the required format' });
    if ('minLength' in schema && [...value].length < schema.minLength) errors.push({ path, message: `must be at least ${schema.minLength} characters` });
  }
  if ((kind === 'number' || kind === 'integer') && 'minimum' in schema && value < schema.minimum) errors.push({ path, message: `must be at least ${schema.minimum}` });
  if (kind === 'object') {
    for (const key of schema.required || []) {
      if (!Object.prototype.hasOwnProperty.call(value, key)) errors.push({ path: `${path}/${key}`, message: 'is required' });
    }
    const properties = schema.properties || {};
    for (const key of Object.keys(value)) {
      const child = `${path}/${key}`;
      if (Object.prototype.hasOwnProperty.call(properties, key)) check(root, properties[key], value[key], child, errors);
      else if ('additionalProperties' in schema) {
        if (schema.additionalProperties === false) errors.push({ path: child, message: 'is not an allowed field' });
        else check(root, schema.additionalProperties, value[key], child, errors);
      }
    }
  }
  if (kind === 'array' && 'items' in schema) value.forEach((item, i) => check(root, schema.items, item, `${path}/${i}`, errors));
  if ('allOf' in schema) schema.allOf.forEach((sub) => check(root, sub, value, path, errors));
  for (const key of ['oneOf', 'anyOf']) {
    if (!(key in schema)) continue;
    const results = schema[key].map((sub) => { const e = []; check(root, sub, value, path, e); return e; });
    const passing = results.filter((e) => e.length === 0).length;
    if (key === 'oneOf' ? passing === 1 : passing > 0) continue;
    if (passing > 1) { errors.push({ path, message: 'matches more than one allowed shape' }); continue; }
    // Report the closest shape so the failure names the field that broke.
    errors.push(...results.reduce((best, e) => (e.length < best.length ? e : best)));
  }
}

// Returns { valid, errors: [{ path, message }] }. Never throws: an unusable
// schema is reported as an invalid result.
export function validate(schema, instance) {
  const errors = [];
  try { check(schema, schema, instance, '', errors); }
  catch (err) { return { valid: false, errors: [{ path: '', message: err instanceof SchemaError ? err.message : 'schema could not be evaluated' }] }; }
  return { valid: errors.length === 0, errors };
}

// ── Proof-page vocabulary ───────────────────────────────────────────────────
// Mirrors Get-VerificationStatus, Get-CodeSigningRows and Get-VerificationStamp
// in scripts/build-site.ps1, so a receipt reads the same as the matching /proof/
// record. The labels are the site's wording (verificationLabels and labels); the
// check script keeps both in step with /proof/.
// Tones: ok, pending, none.
export const VERIFICATION_DIMENSIONS = ['ARTIFACT_HASH_PUBLISHED', 'ARTIFACT_HASH_VERIFIED', 'ARTIFACT_CUSTODY', 'RUNTIME_VALIDATION', 'REALITY_GATE', 'PUBLIC_DOWNLOAD', 'CODE_SIGNING', 'PUBLICATION_STATUS'];
export const VERIFICATION_LABELS = {
  ARTIFACT_HASH_PUBLISHED: 'Artifact hash published',
  ARTIFACT_HASH_VERIFIED: 'Artifact hash verified',
  ARTIFACT_CUSTODY: 'Artifact custody',
  RUNTIME_VALIDATION: 'Runtime validation',
  REALITY_GATE: 'Reality Gate',
  PUBLIC_DOWNLOAD: 'Public download',
  CODE_SIGNING: 'Code signing',
  RELEASE_AUTHORIZATION: 'Release authority',
  PUBLICATION_STATUS: 'Publication status',
};
// Stamp words; equal to the site labels (checked by the check script).
export const STATE_WORDS = { releaseReportStamp: 'Release report', artifactVerifiedStamp: 'Artifact verified' };
// What backs a listed custody, runtime or qualification-tool check, as
// /proof/index.json verification.evidenceClass records it. Only a published,
// self-consistent receipt reads VERIFIED; a missing or unknown class reads
// PENDING, never VERIFIED.
export const EVIDENCE_GATED_DIMENSIONS = ['ARTIFACT_CUSTODY', 'RUNTIME_VALIDATION', 'REALITY_GATE'];
export const EVIDENCE_CLASS_STATES = { PUBLISHED_RECEIPT: 'VERIFIED', MANIFEST_ONLY: 'NOT_PUBLISHED', OWNER_STAMPED_UNPUBLISHED: 'NOT_PUBLISHED', ID_ONLY: 'NOT_PUBLISHED', RECEIPT_SCOPE_UNASSESSED: 'PENDING', NONE: 'PENDING' };
const STATE_TONES = { VERIFIED: 'ok', NOT_PUBLISHED: 'none', PENDING: 'pending' };
const SIGNING_LABELS = { PRODUCTION_SIGNED: 'SIGNED', DEBUG_SIGNED: 'DEBUG SIGNED', UNSIGNED: 'UNSIGNED' };
const PUBLIC_STATES = ['PUBLIC_RELEASE', 'FROZEN'];
const signingOf = (a) => (a && a.signingStatus) || 'UNSIGNED';
const signingTone = (s) => (s === 'PRODUCTION_SIGNED' ? 'ok' : s === 'DEBUG_SIGNED' ? 'pending' : 'none');

export function evidenceClassOf(dimension, entry) {
  const classes = entry && entry.verification && entry.verification.evidenceClass;
  const value = classes && typeof classes === 'object' ? classes[dimension] : undefined;
  return typeof value === 'string' && Object.prototype.hasOwnProperty.call(EVIDENCE_CLASS_STATES, value) ? value : 'NONE';
}

// record: the Public Truth v1 record. entry: its /proof/index.json entry; it is
// optional, and without it every evidence-gated check reads PENDING.
export function verificationState(dimension, record, entry) {
  const artifacts = record.artifacts || [];
  const types = (record.verification && record.verification.verificationType) || [];
  const releaseStatus = record.release ? record.release.releaseStatus : null;
  const hasHash = artifacts.some((a) => a.sha256) || Boolean(record.download && record.download.sha256);
  switch (dimension) {
    case 'ARTIFACT_HASH_PUBLISHED': return hasHash ? { value: 'PUBLISHED', tone: 'ok' } : { value: 'NOT_PUBLISHED', tone: 'none' };
    case 'ARTIFACT_HASH_VERIFIED': return hasHash && record.verification && record.verification.status === 'VERIFIED' ? { value: 'VERIFIED', tone: 'ok' } : { value: 'PENDING', tone: 'pending' };
    case 'ARTIFACT_CUSTODY':
    case 'RUNTIME_VALIDATION':
    case 'REALITY_GATE': {
      const value = types.includes(dimension) ? EVIDENCE_CLASS_STATES[evidenceClassOf(dimension, entry)] : 'PENDING';
      return { value, tone: STATE_TONES[value] };
    }
    case 'PUBLIC_DOWNLOAD': {
      if (entry && entry.verification && entry.verification.downloadUnavailable === true) return { value: 'UNAVAILABLE', tone: 'none' };
      const hasDownload = artifacts.some((a) => a.downloadUrl) || Boolean(record.download && record.download.url);
      return hasDownload ? { value: 'PUBLISHED', tone: 'ok' } : { value: 'NOT_PUBLISHED', tone: 'none' };
    }
    case 'CODE_SIGNING': {
      const signing = signingOf(artifacts[0]);
      return { value: SIGNING_LABELS[signing] || signing, tone: signingTone(signing) };
    }
    case 'RELEASE_AUTHORIZATION':
      if (releaseStatus === 'HOLD') return { value: 'HOLD', tone: 'pending' };
      return PUBLIC_STATES.includes(releaseStatus) ? { value: 'AUTHORIZED', tone: 'ok' } : { value: 'PENDING', tone: 'pending' };
    case 'PUBLICATION_STATUS':
      return { value: String(releaseStatus), tone: PUBLIC_STATES.includes(releaseStatus) ? 'ok' : releaseStatus === 'HOLD' ? 'pending' : 'none' };
    default: return { value: 'PENDING', tone: 'pending' };
  }
}

// One code-signing row, or one per (platform, status) when artifacts differ.
export function codeSigningChecks(record) {
  const artifacts = record.artifacts || [];
  if (artifacts.length < 2 || new Set(artifacts.map(signingOf)).size < 2) return [{ dimension: 'CODE_SIGNING', label: VERIFICATION_LABELS.CODE_SIGNING, ...verificationState('CODE_SIGNING', record) }];
  const seen = new Set();
  const rows = [];
  for (const a of artifacts) {
    const signing = signingOf(a);
    const platform = a.platform || a.filename;
    const key = `${platform}|${signing}`;
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push({ dimension: 'CODE_SIGNING', label: `${VERIFICATION_LABELS.CODE_SIGNING} (${platform})`, value: SIGNING_LABELS[signing] || signing, tone: signingTone(signing) });
  }
  return rows;
}

export function verificationChecks(record, entry) {
  return VERIFICATION_DIMENSIONS.flatMap((dimension) => (dimension === 'CODE_SIGNING'
    ? codeSigningChecks(record)
    : [{ dimension, label: VERIFICATION_LABELS[dimension], ...verificationState(dimension, record, entry) }]));
}

// As /proof/ dates it: a named check only when that check reads VERIFIED.
export function verificationStamp(record, entry) {
  if (verificationState('REALITY_GATE', record, entry).value === 'VERIFIED') return `${VERIFICATION_LABELS.REALITY_GATE} verified`;
  if (verificationState('ARTIFACT_CUSTODY', record, entry).value === 'VERIFIED') return STATE_WORDS.artifactVerifiedStamp;
  return STATE_WORDS.releaseReportStamp;
}

// ── Receipt derivation ──────────────────────────────────────────────────────
// Links are only followed when they are https or same-site paths.
export function safeHref(url) {
  if (typeof url !== 'string') return null;
  if (/^https:\/\/[^\s"'<>]+$/.test(url)) return url;
  if (/^\/(?!\/)[^\s"'<>]*$/.test(url)) return url;
  return null;
}

// A Windows command is offered only for plain file names; anything else is
// left for the visitor to type, never interpolated into a command.
export function verifyCommand(filename) {
  return typeof filename === 'string' && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(filename) ? `Get-FileHash ".\\${filename}" -Algorithm SHA256` : null;
}

function fail(reason, detail, extra = {}) { return { ok: false, reason, detail, ...extra }; }

const describe = (errors) => errors.slice(0, 3).map((e) => `${e.path || '/'} ${e.message}`).join('; ');
const isText = (v) => typeof v === 'string' && v.trim().length > 0;

// The proof registry has no published schema; check the shape this module
// relies on, and that it was projected from the authored release truth.
function registryEntry(registry, id) {
  if (!registry || typeof registry !== 'object' || !Array.isArray(registry.products)) return { error: `${PROOF_REGISTRY_URL} is not a proof registry.` };
  const authority = registry.releaseFactsSource;
  if (!authority || authority.authoredFile !== AUTHORED_RELEASE_FILE) return { error: `${PROOF_REGISTRY_URL} does not name ${AUTHORED_RELEASE_FILE} as its release authority.` };
  if (!isText(registry.generatedAt)) return { error: `${PROOF_REGISTRY_URL} has no generation identity.` };
  const entry = registry.products.find((p) => p && p.id === id);
  if (!entry) return { error: `${PROOF_REGISTRY_URL} does not list "${id}".` };
  const artifactsOk = Array.isArray(entry.artifacts) && entry.artifacts.every((a) => a && isText(a.filename) && (a.sha256 === null || typeof a.sha256 === 'string'));
  if (!entry.release || typeof entry.release !== 'object' || !artifactsOk) return { error: `${PROOF_REGISTRY_URL} has an unreadable release entry for "${id}".` };
  if (!Array.isArray(entry.limits) || !entry.limits.every(isText)) return { error: `${PROOF_REGISTRY_URL} lists unreadable limitations for "${id}".` };
  // Presentation may withhold recorded files from this site by index (no link,
  // no install guidance). Absent means every listed file with an address is offered.
  const withheld = entry.unofferedArtifacts === undefined ? [] : entry.unofferedArtifacts;
  if (!Array.isArray(withheld) || !withheld.every((i) => Number.isInteger(i) && i >= 0 && i < entry.artifacts.length) || new Set(withheld).size !== withheld.length) return { error: `${PROOF_REGISTRY_URL} lists unreadable unoffered-file indexes for "${id}".` };
  return { entry, authority };
}

// One conflict per field that two records state differently.
function conflicts(pairs, a, b) {
  return pairs.filter(([, x, y]) => !sameJson(x === undefined ? null : x, y === undefined ? null : y))
    .map(([field, x, y]) => ({ field, values: [{ source: a, value: x === undefined ? null : x }, { source: b, value: y === undefined ? null : y }] }));
}

// The registry states some lists as a single item when there is only one.
const listOf = (v) => (v === null || v === undefined ? [] : Array.isArray(v) ? v : [v]);
const linksOf = (list) => [...new Set(list.filter(isText))];
const ARTIFACT_FACTS = [['file', 'filename'], ['SHA-256', 'sha256'], ['size', 'sizeBytes'], ['download address', 'downloadUrl'], ['checksum address', 'sha256Url'], ['signing status', 'signingStatus'], ['platform', 'platform'], ['package type', 'distType']];

// inputs: { id, schema, index, record, registry } — parsed JSON, any of which
// may be missing. Returns { ok: true, receipt } or { ok: false, reason, detail
// [, errors | conflicts] }. Reasons: request, schema, index, record, registry,
// disagreement. A withdrawn release returns a receipt with withdrawn: true.
export function buildReceipt({ id, schema, index, record, registry }) {
  if (!/^[a-z0-9-]+$/.test(String(id))) return fail('request', 'The requested record name is not valid.');
  if (!schema || typeof schema.$id !== 'string' || !schema.$id.endsWith(SCHEMA_ID_SUFFIX)) return fail('schema', `The published schema at ${TRUTH_SCHEMA_URL} is not the Public Truth v1 contract.`);

  const indexResult = validate(schema, index);
  if (!indexResult.valid) return fail('index', `${TRUTH_INDEX_URL} does not conform to ${TRUTH_SCHEMA_URL}: ${describe(indexResult.errors)}.`, { errors: indexResult.errors });
  if (!index.products || index.schemaUrl !== TRUTH_SCHEMA_URL) return fail('index', `${TRUTH_INDEX_URL} is not a Public Truth v1 index.`);

  const url = truthRecordUrl(id);
  const recordResult = validate(schema, record);
  if (!recordResult.valid) return fail('record', `${url} does not conform to ${TRUTH_SCHEMA_URL}: ${describe(recordResult.errors)}.`, { errors: recordResult.errors });
  if (!record.release) return fail('record', `${url} is not a product release record.`);

  const listed = index.products.find((p) => p.id === id);
  if (!listed) return fail('index', `${TRUTH_INDEX_URL} does not list "${id}".`);
  const { entry, authority, error } = registryEntry(registry, id);
  if (error) return fail('registry', error);

  // Nothing is combined until the record agrees with itself, and the index,
  // the record and the registry agree on every fact the receipt shows or the
  // linked release record states.
  const said = record.verification || {};
  const stated = entry.verification || {};
  const offered = record.download || {};
  const offeredFile = offered.url ? record.artifacts.find((a) => a.downloadUrl === offered.url) : null;
  const results = (tests) => listOf(tests).map((t) => [t && t.label, t && t.result]);
  const found = [
    ...conflicts([
      ['product ID', id, record.id],
      ['record address', url, record.truthUrl],
      ['record address in the index', url, listed.truthUrl],
      ['product name', listed.name, record.name],
      ['public version', listed.version, record.version],
      ['release status', listed.status, record.status],
      ['lifecycle state', listed.state, record.state],
      ['page address', listed.pageUrl, record.pageUrl],
      ['website source commit', index.source.commit, record.source.commit],
      ['website source tree', index.source.tree, record.source.tree],
      ['website source time', index.source.committedAt, record.source.committedAt],
    ], TRUTH_INDEX_URL, url),
    ...conflicts([['public version', record.version, record.release.publicVersion]], `${url}#/version`, `${url}#/release/publicVersion`),
    ...conflicts([['release status', record.status, record.release.releaseStatus]], `${url}#/status`, `${url}#/release/releaseStatus`),
    ...(offered.url ? conflicts([
      ['download address', offered.url, offeredFile ? offeredFile.downloadUrl : null],
      ['download SHA-256', offered.sha256, offeredFile ? offeredFile.sha256 : null],
      ['download checksum address', offered.sha256Url, offeredFile ? offeredFile.sha256Url : null],
    ], `${url}#/download`, `${url}#/artifacts`) : []),
    ...conflicts([
      ['website source time', record.source.committedAt, registry.generatedAt],
      ['product name', record.name, entry.name],
      ['product status', record.status, entry.productStatus],
      ['release status', record.release.releaseStatus, entry.release.releaseStatus],
      ['public version', record.release.publicVersion, entry.release.publicVersion],
      ['candidate version', record.release.candidateVersion, entry.release.candidateVersion],
      ['publication date', record.release.publishedAt, entry.release.publishedAt],
      ['withdrawn version', record.release.withdrawnVersion, entry.release.withdrawnVersion],
      ['withdrawal reason', record.release.withdrawalReason, entry.release.withdrawalReason],
      ['verification status', said.status, stated.status],
      ['verification date', said.verifiedAt, stated.verifiedAt],
      ['verification types', said.verificationType, stated.verificationType],
      ['receipt ID', said.receiptId, stated.receiptId],
      ['receipt file', said.receiptUrl, stated.receiptUrl],
      ['test results', results(record.tests), results(entry.tests)],
      ['artifact count', record.artifacts.length, entry.artifacts.length],
      ...record.artifacts.flatMap((a, i) => {
        const b = entry.artifacts[i] || {};
        return ARTIFACT_FACTS.map(([label, key]) => [`artifact ${i + 1} ${label}`, a[key], b[key]]);
      }),
    ], url, PROOF_REGISTRY_URL),
  ];
  // Every evidence link the registry states must also be on the record, or the
  // receipt would leave out evidence that the release record shows.
  const recordLinks = linksOf([...listOf(record.evidence).map((e) => e && e.url), ...listOf(record.proofLinks)]);
  const registryLinks = linksOf(listOf(entry.evidence).map((e) => e && e.url));
  if (registryLinks.some((link) => !recordLinks.includes(link))) found.push({ field: 'evidence links', values: [{ source: url, value: recordLinks }, { source: PROOF_REGISTRY_URL, value: registryLinks }] });
  if (found.length) return fail('disagreement', `The published records disagree on ${found.map((c) => c.field).join(', ')}.`, { conflicts: found });

  const trail = {
    schemaId: schema.$id,
    schemaUrl: index.schemaUrl,
    indexUrl: TRUTH_INDEX_URL,
    recordUrl: url,
    registryUrl: PROOF_REGISTRY_URL,
    generatedFrom: index.generatedFrom,
    commit: record.source.commit,
    tree: record.source.tree,
    committedAt: record.source.committedAt,
    authority: AUTHORED_RELEASE_FILE,
    authorityModelSha256: isText(authority.modelSha256) ? authority.modelSha256 : null,
  };
  const links = { record: `/proof/#receipt-${id}`, truthFile: `/truth-files/${id}/`, page: safeHref(record.pageUrl), json: url };

  if (record.release.releaseStatus === 'WITHDRAWN') {
    return {
      ok: true,
      receipt: {
        id, withdrawn: true, name: record.name, status: record.status,
        withdrawnVersion: record.release.withdrawnVersion || null,
        withdrawalReason: record.release.withdrawalReason || null,
        publishedAt: record.release.publishedAt || null,
        limits: entry.limits.slice(), links, trail,
      },
    };
  }

  const verification = record.verification || {};
  const download = record.download || {};
  const withheld = entry.unofferedArtifacts || [];
  const artifacts = (record.artifacts || []).map((a, i) => ({
    filename: a.filename,
    distType: a.distType,
    platform: a.platform,
    signingStatus: a.signingStatus,
    sizeBytes: a.sizeBytes,
    sha256: a.sha256,
    downloadUrl: safeHref(a.downloadUrl),
    sha256Url: safeHref(a.sha256Url),
    primary: Boolean(download.url) && a.downloadUrl === download.url,
    offered: Boolean(safeHref(a.downloadUrl)) && !withheld.includes(i),
  }));
  const primary = artifacts.find((a) => a.primary) || artifacts.find((a) => a.sha256) || null;

  // Evidence, as /proof/ lists it: the record's evidence, then proof links not
  // already listed, labelled by file name.
  const evidence = [];
  const seen = new Set();
  for (const e of record.evidence || []) {
    if (e.url && !seen.has(e.url)) { seen.add(e.url); evidence.push({ label: e.label, url: e.url, href: safeHref(e.url) }); }
  }
  for (const link of record.proofLinks || []) {
    if (link && !seen.has(link)) { seen.add(link); evidence.push({ label: link.split('/').pop(), url: link, href: safeHref(link) }); }
  }

  return {
    ok: true,
    receipt: {
      id,
      withdrawn: false,
      name: record.name,
      version: record.version,
      platforms: record.platforms || [],
      status: record.status,
      release: {
        status: record.release.releaseStatus,
        publicVersion: record.release.publicVersion,
        companionPublicVersion: record.release.companionPublicVersion || null,
        candidateVersion: record.release.candidateVersion || null,
        companionCandidateVersion: record.release.companionCandidateVersion || null,
        publishedAt: record.release.publishedAt,
        sourceCommit: record.release.sourceCommit || null,
      },
      // As /proof/ dates it (verificationStamp).
      verifiedLabel: verificationStamp(record, entry),
      verifiedAt: verification.verifiedAt || null,
      checkedAt: verification.checkedAt || null,
      receiptId: verification.receiptId || null,
      receiptUrl: safeHref(verification.receiptUrl),
      checks: verificationChecks(record, entry),
      artifacts,
      // Shown only when presentation withholds a recorded file.
      offerCount: withheld.length ? { here: artifacts.filter((a) => a.offered).length, more: artifacts.filter((a) => !a.offered).length } : null,
      // A companion version reads as offered only with an offered file for another platform.
      companionOffered: artifacts.some((a, i) => i > 0 && a.offered && a.platform !== artifacts[0].platform),
      command: primary ? verifyCommand(primary.filename) : null,
      commandFile: primary ? primary.filename : null,
      tests: (record.tests || []).map((t) => ({ label: t.label, result: t.result })),
      evidence,
      limits: entry.limits.slice(),
      links,
      trail,
    },
  };
}

// Tab labels for the inspector, from an index that validates against the
// Public Truth v1 schema only (the same identity checks as buildReceipt).
export function indexEntries(schema, index, ids) {
  if (!schema || typeof schema.$id !== 'string' || !schema.$id.endsWith(SCHEMA_ID_SUFFIX)) return null;
  if (!validate(schema, index).valid || !Array.isArray(index.products) || index.schemaUrl !== TRUTH_SCHEMA_URL) return null;
  return ids.map((id) => index.products.find((p) => p.id === id)).filter(Boolean).map((p) => ({ id: p.id, name: p.name, version: p.version }));
}
