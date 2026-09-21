// H14-WEB shadow runtime — product/catalog/truth surfaces rendered from live
// public-state API output at request time. Module registry stays the structural
// authority; the API supplies facts, never structure.
//
//   route → registry (deployed modules) → runtime public state → generic render
//
// The static H13 output remains production; this namespace is shadow only.
// Same security contract as the static path: state strings are escaped at
// emission, unsafe URL schemes/private hosts are rejected before any surface.

const API_VERSION = 1;
const FETCH_TIMEOUT_MS = 4000;
const MAX_STATE_BYTES = 2 * 1024 * 1024;
const MARKUP_TOKENS = new Set(['proofStrip','downloadBlock','hashBlock','releaseNoteBlock','limitsBlock','markSvg']);

// ── Context-appropriate escaping (ports build-site.ps1 Html-Attr) ─────────────
function esc(s) {
  if (s === null || s === undefined) return '';
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ── Public-state URL policy (ports Test-PublicUrlSafe) ────────────────────────
function assertPublicUrl(url, what) {
  if (url === null || url === undefined || url === '') return;
  url = String(url);
  if (url.startsWith('/')) return;
  if (/^https:\/\//i.test(url)) {
    let host;
    try { host = new URL(url).hostname; } catch { throw new Error(`${what}: malformed public URL state: ${url}`); }
    if (/^(localhost|127\.|0\.0\.0\.0|::1|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(host)
        || host === '::1' || host === '0:0:0:0:0:0:0:1' || host === '[::1]') {
      throw new Error(`${what}: unsafe host in public URL state: ${url}`);
    }
    return;
  }
  throw new Error(`${what}: unsafe scheme in public URL state: ${url}`);
}

function assertPublicStateUrls(products) {
  for (const p of products) {
    const tag = `product '${p.id}'`;
    for (const u of [p.downloadUrl, p.sha256Url]) assertPublicUrl(u, tag);
    for (const a of p.artifacts || []) if (a) for (const u of [a.url, a.downloadUrl, a.sha256Url]) assertPublicUrl(u, `${tag} artifact`);
    for (const e of p.evidence || []) if (e && e.url) assertPublicUrl(e.url, `${tag} evidence`);
    for (const l of p.proofLinks || []) assertPublicUrl(l, `${tag} proofLinks`);
    if (p.verification) assertPublicUrl(p.verification.receiptUrl, `${tag} verification`);
    if (p.presentation) assertPublicUrl(p.presentation.cardImage, `${tag} cardImage`);
  }
}

// ── Token derivation (ports ProductTokens + helpers from build-site.ps1) ──────
const isBlank = (v) => v === null || v === undefined || String(v).trim() === '';
const DOT = '·';

function versionLabel(p) {
  const v = (p.release && p.release.publicVersion) || p.publicVersion || p.version;
  return isBlank(v) ? '' : `v${v}`;
}
function candidateVersionLabel(p) {
  if (p.release && p.release.candidateVersion) return `v${p.release.candidateVersion}`;
  if (!isBlank(p.currentLocalVersion)) return `v${p.currentLocalVersion}`;
  return '';
}
function companionLabel(p) { return isBlank(p.companionVersion) ? '' : `Companion v${p.companionVersion}`; }
function companionPublicVersionLabel(p) {
  return (p.release && p.release.companionPublicVersion) ? `v${p.release.companionPublicVersion}` : '';
}
function platformLabel(p) {
  if (Array.isArray(p.platforms) && p.platforms.length) return p.platforms.join(' + ');
  return isBlank(p.platform) ? '' : p.platform;
}
function testStatusLabel(p) { return !isBlank(p.testStatus) ? p.testStatus : (!isBlank(p.testCount) ? p.testCount : ''); }
const STATE_LABELS = { release:'public release', candidate:'release candidate', proof:'in proof', concept:'in design' };
function stateLabel(s) { return STATE_LABELS[s] || s || ''; }
function isoDateLabel(iso) {
  if (isBlank(iso)) return '';
  const d = new Date(iso + 'T00:00:00Z');
  if (isNaN(d)) return '';
  return d.toLocaleDateString('en-GB', { day:'numeric', month:'long', year:'numeric', timeZone:'UTC' });
}
function visitorAvailability(p) {
  const pub = p.release ? p.release.publicVersion : null;
  return isBlank(pub) ? 'NO_PUBLIC_RELEASE' : 'AVAILABLE';
}
function visitorAvailabilityLabel(p, cfg) {
  const a = visitorAvailability(p);
  return (cfg.availabilityTaxonomy && cfg.availabilityTaxonomy.labels && cfg.availabilityTaxonomy.labels[a]) || a;
}
function visitorAvailabilitySlug(p, cfg) {
  return visitorAvailabilityLabel(p, cfg).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}
function productGroupId(p, cfg) {
  const a = visitorAvailability(p);
  for (const g of cfg.productGroups || []) if ((g.availability || []).includes(a)) return g.id;
  return '';
}
function cardVersionLabel(p) {
  return p.id === 'lights-out' ? `${versionLabel(p)} (Windows)` : versionLabel(p);
}
function cardDetailLine(p) {
  const rs = (p.release && p.release.releaseStatus) || '';
  const pub = (p.release && p.release.publicVersion) ? `v${p.release.publicVersion}` : '';
  const cand = (p.release && p.release.candidateVersion) ? `v${p.release.candidateVersion}` : '';
  switch (rs) {
    case 'RELEASE_CANDIDATE':
      if (pub) {
        if (p.presentation && p.presentation.downloadUnavailable) return `Candidate ${cand} ${DOT} downloads currently unavailable`;
        return `Candidate ${cand} available ${DOT} public release remains ${pub}`;
      }
      return cand ? `Release candidate ${cand}` : '';
    case 'HOLD':
      if (p.id === 'lights-out' && p.release && p.release.companionPublicVersion)
        return `Android companion public v${p.release.companionPublicVersion} ${DOT} Windows and Android ${cand} candidates on hold ${DOT} public downloads currently unavailable`;
      return cand ? `Candidate ${cand} on hold ${DOT} public download currently unavailable` : '';
    case 'ACTIVE_PROOF': return cand ? `${cand} candidate in proof` : '';
    case 'PUBLIC_RELEASE':
    case 'FROZEN': return (cand && (!pub || `v${cand}` !== pub)) ? `Next build ${cand} in progress` : '';
    case 'UNRELEASED': return cand ? `Engine ${cand} ${DOT} not yet packaged under this name` : 'No public release yet';
    default: return '';
  }
}
function cardCtaHref(p) { return `${p.route}#${isBlank(p.downloadUrl) ? 'release-status' : 'download'}`; }
function cardProofHref(p, cfg) { return `${String(cfg.proofRegistryPath || '').replace(/index\.json$/, '')}#receipt-${p.id}`; }
const isExternalUrl = (u) => /^https?:\/\//i.test(String(u || ''));
const isFileDownload = (u) => /\.(zip|exe|apk)$/i.test(String(u || ''));

function productTokens(p, cfg) {
  const t = {};
  const pub = (p.release && p.release.publicVersion) || p.version || '';
  const cand = (p.release && p.release.candidateVersion) || p.currentLocalVersion || '';
  t.id = p.id; t.name = p.name; t.displayName = p.displayName;
  t.homeName = p.homeName || p.name; t.route = p.route; t.state = p.state;
  t.statusLabel = stateLabel(p.state);
  t.productStatus = p.productStatus || '';
  t.productStatusLabel = (p.productStatus && cfg.statusTaxonomy && cfg.statusTaxonomy[p.productStatus]) || t.statusLabel;
  t.versionLabel = versionLabel(p);
  t.candidateVersionLabel = candidateVersionLabel(p);
  t.companionLabel = companionLabel(p);
  t.companionPublicVersionLabel = companionPublicVersionLabel(p);
  t.companionVersion = p.companionVersion || '';
  t.companionCandidateVersion = (p.release && p.release.companionCandidateVersion) || '';
  t.companionCandidateVersionLabel = t.companionCandidateVersion ? `v${t.companionCandidateVersion}` : '';
  t.sourceCommit = (p.release && p.release.sourceCommit) || '';
  t.receiptId = (p.verification && p.verification.receiptId) || '';
  t.packageId = p.packageId || '';
  t.publishedAtLabel = isoDateLabel(p.release && p.release.publishedAt);
  t.checkedAtLabel = isoDateLabel(p.verification && p.verification.checkedAt);
  t.version = p.version;
  t.visitorStatusLabel = visitorAvailabilityLabel(p, cfg);
  t.visitorStatusSlug = visitorAvailabilitySlug(p, cfg);
  t.groupId = productGroupId(p, cfg);
  t.cardVersionLabel = cardVersionLabel(p);
  t.cardDetailLine = cardDetailLine(p);
  t.cardCtaHref = cardCtaHref(p);
  t.cardProofHref = cardProofHref(p, cfg);
  t.valueLine = (p.presentation && p.presentation.valueLine) || p.cardSummary || '';
  t.cardImage = (p.presentation && p.presentation.cardImage) || '';
  t.cardImageWidth = (p.presentation && p.presentation.cardImageWidth) || '';
  t.cardImageHeight = (p.presentation && p.presentation.cardImageHeight) || '';
  t.cardImageAlt = (p.presentation && p.presentation.cardImageAlt) || '';
  t.cardCta = (p.presentation && p.presentation.cardCta) || p.cta || '';
  t.platform = platformLabel(p);
  t.summary = p.summary; t.cardSummary = !isBlank(p.cardSummary) ? p.cardSummary : p.summary;
  t.markSvg = p.markSvg || ''; t.cta = p.cta; t.distType = p.distType; t.build = p.build;
  t.testStatus = testStatusLabel(p); t.testCount = p.testCount; t.proofStatus = p.proofStatus;
  t.lastVerified = (p.verification && p.verification.verifiedAt) || p.lastVerified;
  t.downloadUrl = p.downloadUrl; t.downloadLabel = p.downloadLabel;
  t.sha256 = p.sha256; t.sha256Url = p.sha256Url; t.releaseNote = p.releaseNote;
  t.publicVersion = pub; t.candidateVersion = cand;
  t.releaseStatus = (p.release && p.release.releaseStatus) || '';
  t.publishedAt = (p.release && p.release.publishedAt) || '';
  t.verificationStatus = (p.verification && p.verification.status) || 'PENDING';
  // meta / statusLine
  t.meta = [t.versionLabel, t.platform].filter(Boolean).join(` ${DOT} `);
  const parts = [];
  if (t.productStatusLabel) parts.push(t.productStatusLabel);
  if (!pub && cand && t.releaseStatus === 'UNRELEASED') { parts.push('no public release', `engine v${cand}`); }
  else if (pub && cand && pub !== cand) { parts.push(`public v${pub}`, t.releaseStatus === 'PUBLIC_RELEASE' ? `next v${cand}` : `candidate v${cand}`); }
  else if (pub) parts.push(`v${pub}`);
  else if (cand) parts.push(`v${cand}`);
  if (t.platform) parts.push(t.platform);
  t.statusLine = parts.join(` ${DOT} `);
  // artifacts + indexed tokens
  let primary = null;
  for (const a of p.artifacts || []) { if (!isBlank(a.downloadUrl) || a.sha256) { primary = a; break; } }
  t.artifactFilename = primary ? (primary.filename || '') : '';
  t.artifactSha256 = primary ? primary.sha256 : (p.sha256 || '');
  t.artifactDownloadUrl = primary ? primary.downloadUrl : (p.downloadUrl || '');
  t.artifactSha256Url = primary ? primary.sha256Url : (p.sha256Url || '');
  (p.artifacts || []).forEach((a, i) => {
    t[`artifacts.${i}.sha256`] = a.sha256 || ''; t[`artifacts.${i}.filename`] = a.filename || '';
    t[`artifacts.${i}.downloadUrl`] = a.downloadUrl || ''; t[`artifacts.${i}.sha256Url`] = a.sha256Url || '';
    t[`artifacts.${i}.signingStatus`] = a.signingStatus || 'UNSIGNED'; t[`artifacts.${i}.platform`] = a.platform || '';
  });
  (p.proofLinks || []).forEach((l, i) => { t[`proofLinks.${i}`] = l; });
  (Array.isArray(p.tests) ? p.tests : []).forEach((e, i) => { t[`tests.${i}.label`] = e.label || ''; t[`tests.${i}.result`] = e.result || ''; });
  (Array.isArray(p.evidence) ? p.evidence : []).forEach((e, i) => {
    t[`evidence.${i}.label`] = (typeof e === 'string' ? String(e).split('/').pop() : e.label) || '';
    t[`evidence.${i}.url`] = (typeof e === 'string' ? e : e.url) || '';
  });
  // Markup blocks — leaves escaped here; the block itself passes raw.
  const pills = [
    `<span class="proof-pill"><strong>Status</strong> ${esc(t.statusLabel)}</span>`,
    `<span class="proof-pill"><strong>Version</strong> ${t.versionLabel ? esc(t.versionLabel) : '&mdash;'}</span>`,
  ];
  if (cand && cand !== pub) {
    const cl = (p.release && p.release.releaseStatus === 'PUBLIC_RELEASE') ? 'Next' : 'Candidate';
    pills.push(`<span class="proof-pill"><strong>${cl}</strong> v${esc(cand)}</span>`);
  }
  pills.push(`<span class="proof-pill"><strong>Platform</strong> ${esc(t.platform)}</span>`);
  if (t.testStatus) pills.push(`<span class="proof-pill"><strong>Tests</strong> ${esc(t.testStatus)}</span>`);
  pills.push(`<span class="proof-pill"><strong>Proof</strong> ${esc(p.proofStatus || '')}</span>`);
  if (t.lastVerified) pills.push(`<span class="proof-pill"><strong>Verified</strong> ${esc(t.lastVerified)}</span>`);
  t.proofStrip = `<div class="proof-strip">${pills.join('\n          ')}</div>`;
  // downloadBlock
  const dlUrl = t.artifactDownloadUrl || p.downloadUrl;
  if ((p.presentation && p.presentation.downloadUnavailable) || isBlank(dlUrl)) {
    const muted = (p.presentation && p.presentation.downloadUnavailable) ? 'Downloads currently unavailable'
      : (!isBlank(p.disabledDownloadLabel) ? p.disabledDownloadLabel : (p.state === 'proof' ? 'No public build yet' : 'Coming soon'));
    t.downloadBlock = `<span class="button button-muted" aria-disabled="true">${esc(muted)}</span>`;
  } else {
    const label = p.downloadLabel || 'Download';
    const ext = isExternalUrl(dlUrl) ? ' target="_blank" rel="noopener"' : '';
    const dl = isFileDownload(dlUrl) ? ' download' : '';
    t.downloadBlock = `<a class="button button-primary" href="${esc(dlUrl)}"${ext}${dl}>${esc(label)}</a>`;
    const shaLink = t.artifactSha256Url || p.sha256Url;
    if (!isBlank(shaLink)) t.downloadBlock += ` <a class="button button-secondary" href="${esc(shaLink)}" target="_blank" rel="noopener">SHA-256</a>`;
  }
  // hashBlock
  const primarySha = t.artifactSha256 || p.sha256;
  if (!isBlank(primarySha)) {
    const note = /Android/.test(t.platform)
      ? `<p class="note">Desktop verification: <code class="inline">Get-FileHash ".\\${esc(t.artifactFilename)}" -Algorithm SHA256</code> (Phone-native verification guidance is being prepared on the <a href="/support/#android" class="text-link">support hub</a>)</p>`
      : `<p class="note">Windows verification: <code class="inline">Get-FileHash ".\\${esc(t.artifactFilename)}" -Algorithm SHA256</code></p>`;
    const se = esc(primarySha);
    t.hashBlock = `<div class="code-block sha256-block" data-sha256="${se}">
  <code class="sha256-value">${se}</code>
  <button type="button" class="sha256-copy" aria-label="Copy SHA-256" title="Copy SHA-256">Copy</button>
</div>
${note}`;
  } else t.hashBlock = '';
  t.releaseNoteBlock = !isBlank(p.releaseNote) ? `<p class="note">${esc(p.releaseNote)}</p>` : '';
  t.limitsBlock = (p.limits && p.limits.length)
    ? `<ul class="limits-list">${p.limits.map(l => `<li>${esc(l)}</li>`).join('')}</ul>` : '';
  return t;
}

function replaceTokens(html, t) {
  for (const k of Object.keys(t)) {
    const v = MARKUP_TOKENS.has(k) ? String(t[k] ?? '') : esc(t[k]);
    html = html.split(`{{product.${k}}}`).join(v);
  }
  return html;
}
function replaceNamedTokens(html, statesById, cfg) {
  return html.replace(/\{\{products\.([a-z0-9-]+)\.([^}]+)\}\}/g, (m, id, key) => {
    const p = statesById[id];
    if (!p) return m;
    const t = productTokens(p, cfg);
    const v = t[key];
    if (v === undefined) return m;
    return MARKUP_TOKENS.has(key) ? String(v) : esc(v);
  });
}

// ── Card renderer (ports Render-ProductCard) ──────────────────────────────────
function renderCard(template, p, cfg) {
  const t = productTokens(p, cfg);
  let card = template;
  card = card.replace(/<!--\s*@if-version\s*-->[\s\S]*?<!--\s*@end-version\s*-->/g,
    t.cardVersionLabel ? (m) => m.replace(/<!--\s*@\w+-?version\s*-->/g, '') : '');
  card = card.replace(/<!--\s*@if-detail\s*-->[\s\S]*?<!--\s*@end-detail\s*-->/g,
    t.cardDetailLine ? (m) => m.replace(/<!--\s*@\w+-?detail\s*-->/g, '') : '');
  for (const k of ['homeName','name','route','state','statusLabel','summary','cardSummary','statusLine','id','meta','cta',
    'visitorStatusLabel','visitorStatusSlug','groupId','cardVersionLabel','cardDetailLine','cardCtaHref',
    'cardProofHref','valueLine','cardImage','cardImageAlt','cardImageWidth','cardImageHeight','cardCta','platform']) {
    card = card.split(`{{${k}}}`).join(esc(t[k]));
  }
  card = card.split('{{markSvg}}').join(String(t.markSvg));
  return card;
}

// ── Truth projection (ports Build-PublicTruthProduct) — same field whitelist ──
function truthProduct(p, source, id) {
  const rel = p.release ? {
    releaseStatus: p.release.releaseStatus,
    publicVersion: p.release.publicVersion || null,
    candidateVersion: p.release.candidateVersion || null,
    companionCandidateVersion: p.release.companionCandidateVersion || null,
    companionPublicVersion: p.release.companionPublicVersion || null,
    publishedAt: p.release.publishedAt || null,
    sourceCommit: p.release.sourceCommit || null,
  } : null;
  return {
    schemaVersion: 1, id: p.id, name: p.name, state: p.state,
    status: p.productStatus || null,
    version: (p.release && p.release.publicVersion) || null,
    platforms: p.platforms || [],
    packageId: p.packageId || null,
    pageUrl: `/__h14/${id}/`,
    truthUrl: `/__h14/truth/products/${id}.json`,
    release: rel,
    download: {
      available: !isBlank(p.downloadUrl),
      url: p.downloadUrl || null, sha256: p.sha256 || null,
      sha256Url: p.sha256Url || null, label: p.downloadLabel || null,
    },
    artifacts: (p.artifacts || []).map(a => ({
      filename: a.filename || null, sizeBytes: a.sizeBytes || null, sha256: a.sha256 || null,
      downloadUrl: a.downloadUrl || null, sha256Url: a.sha256Url || null,
      signingStatus: a.signingStatus || null, platform: a.platform || null, distType: a.distType || null,
    })),
    verification: p.verification ? {
      status: p.verification.status, verifiedAt: p.verification.verifiedAt || null,
      checkedAt: p.verification.checkedAt || null, verificationType: p.verification.verificationType || null,
      downloadAvailability: p.verification.downloadAvailability || null,
      receiptId: p.verification.receiptId || null, receiptUrl: p.verification.receiptUrl || null,
    } : null,
    tests: (p.tests || []).map(t => ({ label: t.label, result: t.result })),
    evidence: (p.evidence || []).map(e => typeof e === 'string'
      ? { label: String(e).split('/').pop(), url: e } : { label: e.label, url: e.url }),
    proofLinks: p.proofLinks || [],
    source,
  };
}

// ── Public-state client — revision-aware fetch with bounds ────────────────────
// The API origin comes ONLY from deployment config (env). Product data can
// never choose a fetch origin. Redirects are hard-rejected (redirect:'error') —
// the upstream contract has no legitimate redirect path, and following them is
// an SSRF pivot surface.
//
// isolateCache survives across requests in the same isolate: ETag revalidation
// (304 → reuse last-good) and the live→cached→static fallback chain. It is
// EPHEMERAL per-isolate memory — never presented as durable LKG.
const isolateCache = { etag: null, lastGood: null, revision: null };

// API base policy: public-host requests (production) require an https://
// public origin — loopback/private schemes fail closed. Loopback http is
// accepted ONLY when the request itself arrived on a loopback host (local dev
// fixture); it cannot be enabled accidentally in production because request
// Host on a public deployment is never loopback, and the base is config, not
// request-controlled.
function assertApiBaseAllowed(base, requestHost) {
  let u;
  try { u = new URL(base); } catch { throw new Error('API base not a URL'); }
  const devRequest = /^(localhost|127\.|::1|\[::1\])/.test(requestHost || '');
  if (devRequest) {
    // dev/test only: loopback http fixture allowed; non-http schemes rejected
    if (!/^https?:$/i.test(u.protocol)) throw new Error('API base must be http(s)');
    return;
  }
  if (u.protocol !== 'https:') throw new Error('API base must be https on public hosts');
  if (/^(localhost|127\.|0\.0\.0\.0|::1|\[::1\]|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/i.test(u.hostname)) {
    throw new Error('API base must not be a private/loopback host');
  }
}

// revisionSeq: required, integer, >=0, finite. No coercion — nonconforming
// documents are rejected as invalid-schema.
function assertRevisionSeq(v) {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < 0 || !Number.isFinite(v)) {
    throw new Error('revisionSeq must be an integer >= 0');
  }
}

async function fetchState(env, ctx, requestHost) {
  const base = (env.PF_PUBLIC_PRODUCT_API_BASE || '').replace(/\/+$/, '');
  if (!base) return { mode: 'no-api', state: null, revision: null };
  try { assertApiBaseAllowed(base, requestHost); }
  catch { return { mode: 'error', status: 'api-base-rejected', state: null, revision: null }; }
  if (ctx && ctx._stateCache) return ctx._stateCache;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const res = await fetch(`${base}/products`, {
      signal: controller.signal,
      // Hard rejection: redirects are never followed — a 3xx surfaces as a
      // non-2xx response and fails closed below (no Location is dereferenced).
      redirect: 'manual',
      headers: { 'Accept': 'application/json', ...(isolateCache.etag ? { 'If-None-Match': isolateCache.etag } : {}) },
      cf: { cacheTtl: 0 },
    });
    clearTimeout(timer);
    if (res.status === 304 && isolateCache.lastGood) {
      const out = { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      if (ctx) ctx._stateCache = out;
      return out;
    }
    if (!res.ok) {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: res.status, state: null, revision: null };
    }
    const body = await res.arrayBuffer();
    if (body.byteLength > MAX_STATE_BYTES) {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: 'oversized', state: null, revision: null };
    }
    let doc;
    try { doc = JSON.parse(new TextDecoder().decode(body)); }
    catch {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: 'invalid-json', state: null, revision: null };
    }
    if (!doc || doc.apiVersion !== API_VERSION || !Array.isArray(doc.products)) {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: 'invalid-schema', state: null, revision: null };
    }
    // revisionSeq is required and strictly typed — nonconforming docs rejected.
    try { assertRevisionSeq(doc.revisionSeq); }
    catch {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: 'invalid-schema', state: null, revision: null };
    }
    try { assertPublicStateUrls(doc.products); }
    catch (e) {
      if (isolateCache.lastGood) return { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      return { mode: 'error', status: 'state-rejected', state: null, revision: null };
    }
    const etag = res.headers.get('ETag');
    const revision = doc.revision || etag || 'unknown';
    const cur = doc.revisionSeq;
    const last = isolateCache.lastGood ? isolateCache.lastGood.revisionSeq : -1;
    // Identity coherence: same seq must carry the same revision label —
    // same seq + different revision is an inconsistent snapshot → reject.
    if (isolateCache.lastGood && cur === last && revision !== isolateCache.lastGood.revision) {
      const out = { mode: 'cache-inconsistent-rejected', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      if (ctx) ctx._stateCache = out;
      return out;
    }
    // Forward-only: a strictly lower revisionSeq is a stale/rollback candidate —
    // never silently adopted. Legitimate rollback is published as a NEW higher
    // revisionSeq whose content represents the older state.
    if (isolateCache.lastGood && cur < last) {
      const out = { mode: 'cache-stale-rejected', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      if (ctx) ctx._stateCache = out;
      return out;
    }
    const out = { mode: 'live', state: doc, revision, revisionSeq: cur, etag };
    if (etag) isolateCache.etag = etag;
    isolateCache.lastGood = out;
    if (ctx) ctx._stateCache = out;
    return out;
  } catch (e) {
    clearTimeout(timer);
    if (isolateCache.lastGood) {
      const out = { mode: 'cache', state: isolateCache.lastGood.state, revision: isolateCache.lastGood.revision };
      if (ctx) ctx._stateCache = out;
      return out;
    }
    return { mode: 'error', status: e.name === 'AbortError' ? 'timeout' : 'unreachable', state: null, revision: null };
  }
}

// Static fallback: deploy-time state snapshot + static-rendered surfaces.
async function staticState(env) {
  const res = await env.ASSETS.fetch(new Request('https://assets/__h14/static-state.json'));
  return res.json();
}
async function loadRegistry(env) {
  const res = await env.ASSETS.fetch(new Request('https://assets/__h14/registry.json'));
  return res.json();
}
async function loadConfig(env) {
  const res = await env.ASSETS.fetch(new Request('https://assets/__h14/site-config.json'));
  return res.json();
}
async function loadText(env, path) {
  const res = await env.ASSETS.fetch(new Request(`https://assets${path}`));
  return res.ok ? res.text() : null;
}

function statesById(doc) {
  const m = {};
  for (const p of (doc && doc.products) || []) m[p.id] = p;
  return m;
}

function respond(body, { type = 'text/html; charset=utf-8', mode, revision } = {}) {
  return new Response(body, {
    headers: {
      'Content-Type': type,
      'X-Robots-Tag': 'noindex, nofollow',
      'Cache-Control': 'no-cache, must-revalidate',
      'X-PF-State-Source': mode || 'unknown',
      'X-PF-State-Revision': revision || 'none',
    },
  });
}
const provenance = (mode, revision) => `\n<!-- h14-state: ${mode} revision=${esc(revision)} — shadow runtime output -->\n`;

function buildNavLinks(cfg) {
  const items = (cfg.navLinks || []);
  return items.map(i => `<a href="${esc(i.href)}">${esc(i.label)}</a>`).join('\n            ');
}
function buildNavCta(cfg) {
  const c = cfg.navCta || {};
  return `<a class="button button-primary nav-cta" href="${esc(c.href)}">${esc(c.label)}</a>`;
}
function buildFooter(footerPartial, states, cfg) {
  const items = states.map(p =>
    `<li><a href="${esc(p.route)}">${esc(p.displayName || p.homeName || p.name)}</a></li>`).join('\n            ');
  return footerPartial.split('{{footer-products}}').join(items);
}
function buildHeader(headerPartial, cfg) {
  return headerPartial
    .split('{{nav-links}}').join(buildNavLinks(cfg))
    .split('{{nav-cta}}').join(buildNavCta(cfg));
}

// Static fallback page fetch — the deployed H13 output for this product.
async function staticProductPage(env, id) {
  const res = await env.ASSETS.fetch(new Request(`https://assets/${id}/index.html`));
  return res.ok ? res.text() : null;
}

export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/__h14/, '') || '/';
  const ctx = {}; // per-request cache + coherence scope

  const cfg = await loadConfig(env).catch(() => null);
  const registry = await loadRegistry(env).catch(() => []);
  const visible = registry.filter(m => m.visibility === 'visible').sort((a, b) => a.order - b.order);

  // Resolve state once per request — catalog/page/truth share one revision.
  let fetched = await fetchState(env, ctx, url.hostname);
  let stateDoc = fetched.state;
  let mode = fetched.mode;
  if (!stateDoc) {
    stateDoc = await staticState(env);
    mode = mode === 'no-api' ? 'static' : 'static-fallback';
  }
  const byId = statesById(stateDoc);
  const orderedState = visible.map(m => byId[m.id]).filter(Boolean);

  // ── /__h14/ shadow index ──────────────────────────────────────────────────
  if (path === '/' || path === '') {
    const rows = visible.map(m =>
      `<li><a href="/__h14/${m.id}/">${esc(m.id)}</a> — state mode ${mode}, revision ${esc(fetched.revision || 'static')}</li>`).join('\n');
    return respond(`<!doctype html><html><head><meta charset="utf-8"><title>H14 shadow runtime</title></head>
<body><h1>H14 shadow runtime</h1><p>State mode: ${esc(mode)} · revision ${esc(fetched.revision || 'static')}</p>
<ul>${rows}</ul><p><a href="/__h14/software/">catalog</a> · <a href="/__h14/truth/">truth</a> · <a href="/__h14/truth/index.json">truth index JSON</a></p>
${provenance(mode, fetched.revision)}</body></html>`, { mode, revision: fetched.revision });
  }

  // ── /__h14/truth/index.json + /__h14/truth/products/<id>.json ─────────────
  if (path === '/truth/index.json') {
    const index = {
      schemaVersion: 1, generatedFrom: 'runtime-public-state-api',
      schemaUrl: '/truth/schema-v1.json', canonicalUrl: cfg.canonicalUrl,
      source: { mode, revision: fetched.revision || null },
      productCount: orderedState.length,
      products: orderedState.map(p => ({
        id: p.id, name: p.name, state: p.state, status: p.productStatus || null,
        version: (p.release && p.release.publicVersion) || null,
        pageUrl: `/__h14/${p.id}/`, truthUrl: `/__h14/truth/products/${p.id}.json`,
      })),
    };
    return respond(JSON.stringify(index, null, 2) + '\n', { type: 'application/json; charset=utf-8', mode, revision: fetched.revision });
  }
  const truthMatch = path.match(/^\/truth\/products\/([a-z0-9-]+)\.json$/);
  if (truthMatch) {
    const id = truthMatch[1];
    const mod = registry.find(m => m.id === id);
    if (!mod || mod.visibility !== 'visible') return respond('{}', { type: 'application/json', mode, revision: fetched.revision });
    let p = byId[id];
    let pMode = mode;
    if (!p) {
      // API-missing product → static deploy-time snapshot for that product only.
      p = statesById(await staticState(env))[id];
      pMode = 'static-fallback';
      if (!p) return respond('{}', { type: 'application/json', mode, revision: fetched.revision });
    }
    return respond(JSON.stringify(truthProduct(p, { mode: pMode, revision: fetched.revision || null }, id), null, 2) + '\n',
      { type: 'application/json; charset=utf-8', mode: pMode, revision: fetched.revision });
  }

  // ── /__h14/truth/ index page ──────────────────────────────────────────────
  if (path === '/truth/' || path === '/truth') {
    const tmpl = await loadText(env, '/__h14/pages/truth.html');
    const header = buildHeader(await loadText(env, '/__h14/partials/header.html'), cfg);
    const footer = buildFooter(await loadText(env, '/__h14/partials/footer.html'), orderedState, cfg);
    const cards = orderedState.map(p => {
      const st = (p.productStatus && cfg.statusTaxonomy && cfg.statusTaxonomy[p.productStatus]) || p.productStatus || '';
      const ver = (p.release && p.release.publicVersion) ? `v${p.release.publicVersion}` : 'Unreleased';
      const n = (p.artifacts || []).length;
      return `<article class="detail-card">
          <h3>${esc(p.name)}</h3>
          <p>${esc(st)} · ${esc(ver)} · ${n} public artifact${n === 1 ? '' : 's'}</p>
          <p><a class="text-link" href="/__h14/truth/products/${esc(p.id)}.json">View JSON ↗</a> · <a class="text-link" href="/__h14/${esc(p.id)}/">Product page ↗</a></p>
        </article>`;
    }).join('\n');
    let html = tmpl
      .replace(/<!--\s*@truth-products\s*-->/, cards)
      .replace(/<!--\s*@include header\s*-->/, header)
      .replace(/<!--\s*@include footer\s*-->/, footer)
      .replace('href="/truth/index.json"', 'href="/__h14/truth/index.json"');
    html = replaceNamedTokens(html, byId, cfg);
    html = html.replace('</head>', `<link href="/__h14/truth/index.json" rel="alternate" title="Public Truth" type="application/json"/>\n</head>`);
    html += provenance(mode, fetched.revision);
    return respond(html, { mode, revision: fetched.revision });
  }

  // ── /__h14/software/ catalog ──────────────────────────────────────────────
  if (path === '/software/' || path === '/software') {
    const tmpl = await loadText(env, '/__h14/pages/software.html');
    const header = buildHeader(await loadText(env, '/__h14/partials/header.html'), cfg);
    const footer = buildFooter(await loadText(env, '/__h14/partials/footer.html'), orderedState, cfg);
    const cardT = await loadText(env, '/__h14/partials/product-card.html');
    const cards = orderedState.map(p => renderCard(cardT, p, cfg)
      .replace('<h4 class="card-name">', '<h3 class="card-name">').replace('</h4>', '</h3>')).join('\n');
    let html = tmpl
      .replace(/<!--\s*@all-products\s*-->/, cards)
      .replace(/<!--\s*@products\s*-->/, cards)
      .replace(/<!--\s*@include header\s*-->/, header)
      .replace(/<!--\s*@include footer\s*-->/, footer);
    html = replaceNamedTokens(html, byId, cfg);
    // H12 reciprocal discovery — runtime catalog advertises the runtime index.
    html = html.replace('</head>', `<link href="/__h14/truth/index.json" rel="alternate" title="Public Truth" type="application/json"/>\n</head>`);
    html += provenance(mode, fetched.revision);
    return respond(html, { mode, revision: fetched.revision });
  }

  // ── /__h14/<id>/ product page ─────────────────────────────────────────────
  const prodMatch = path.match(/^\/([a-z0-9-]+)\/?$/);
  if (prodMatch) {
    const id = prodMatch[1];
    const mod = registry.find(m => m.id === id);
    // Registry is structural authority: unknown or hidden → not rendered.
    if (!mod || mod.visibility !== 'visible') return respond('Not found', { type: 'text/plain', mode, revision: fetched.revision });
    let p = byId[id];
    let pMode = mode;
    if (!p) {
      // API-missing product → static deploy-time state for that product only.
      const stat = await staticState(env);
      p = statesById(stat)[id];
      pMode = 'static-fallback';
      if (!p) return respond('Not found', { type: 'text/plain', mode, revision: fetched.revision });
    }
    const [shell, content, headerP, footerP] = await Promise.all([
      loadText(env, `/__h14/shells/${id}.html`),
      loadText(env, `/__h14/content/${id}.html`),
      loadText(env, '/__h14/partials/header.html'),
      loadText(env, '/__h14/partials/footer.html'),
    ]);
    if (!shell || !content) return respond('Shadow assets missing', { type: 'text/plain', mode, revision: fetched.revision });
    const t = productTokens(p, cfg);
    const crumb = `<nav class="product-breadcrumb" aria-label="Breadcrumb"><a href="/#products">All software</a><span aria-hidden="true">/</span><span>${esc(p.name)}</span></nav>`;
    const related = '<nav class="studio-related" aria-label="More software"><span>More from the foundry</span>'
      + visible.filter(m => m.id !== id).map(m => `<a href="/__h14/${m.id}/">${esc((byId[m.id] || {}).name || m.id)}</a>`).join('')
      + '</nav>';
    let page = shell
      .replace(/<!--\s*@page\s+\S+\s*-->\s*\r?\n?/, '')
      .replace(/<!--\s*@product\s+\S+\s*-->\s*\r?\n?/, '')
      .replace(/<!--\s*@include header\s*-->/, buildHeader(headerP, cfg));
    let c = content
      .replace(/<!--\s*@product-breadcrumb\s*-->/, crumb)
      .replace(/<!--\s*@product-related\s*-->/, related)
      .replace(/<!--\s*@include footer\s*-->/, buildFooter(footerP, orderedState, cfg));
    page = page.replace(/<!--\s*@product-content\s*-->/, c);
    page = replaceTokens(page, t);
    page = replaceNamedTokens(page, byId, cfg);
    // H12 reciprocal discovery — the runtime page advertises its runtime truth.
    page = page.replace('</head>',
      `<link href="/__h14/truth/products/${esc(id)}.json" rel="alternate" title="Public Truth" type="application/json"/>\n</head>`);
    page += provenance(pMode, fetched.revision);
    return respond(page, { mode: pMode, revision: fetched.revision });
  }

  return respond('Not found', { type: 'text/plain', mode, revision: fetched.revision });
}
