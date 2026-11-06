'use strict';

// PROPOSAL: discovery data only. Never a release-truth or signed-catalog adapter.
const SCHEMA = 'pf.portfolio-discovery-review/v1';
const IDS = ['cache-vault', 'ghostlayer', 'lights-out', 'cleanroom', 'forgecast',
  'proofshot', 'reality-gate', 'hardline-zero', 'crosspoint', 'proof-foundry-app', 'sound-assist'];
const WORLDS = new Set(IDS.slice(0, 7));
const GROUPS = ['software', 'infrastructure', 'history'];
const LABELS = Object.freeze({
  PUBLISHED_METADATA_ONLY_NO_BINARY_FETCH: 'Published release metadata; binary not reverified',
  FIRST_PARTY_SITE_CLAIM_NO_INDEPENDENT_RELEASE_ASSET_CONFIRMATION: 'Website release claim; independent asset confirmation incomplete',
  FIRST_PARTY_PUBLIC_VERSION_CLAIM_NO_ARTIFACT_HASH: 'Public version claim; artifact hash unknown',
  INTERNAL_ONLY_NOT_PUBLIC: 'Internal only; no public release established',
  FIRST_PARTY_SITE_PUBLIC_CLAIM: 'Website public release record',
  GITHUB_PUBLIC_RELEASE_CONFLICTS_WITH_SITE_CHANNEL: 'Published on GitHub; website channel unresolved',
  PUBLISHED_METADATA_ONLY_NOT_FIELD_QUALIFIED: 'Historical release; field qualification incomplete',
  WITHDRAWN_DO_NOT_DISTRIBUTE: 'Withdrawn; do not distribute',
  LOCAL_DIRTY_NONCANONICAL: 'Historical working copy; not an engineering reference',
  UNVERIFIED: 'Historical identity; availability unverified'
});
const HOLD_COPY = Object.freeze({
  LICENSING_AUTHORITY_HOLD: 'ProofShot licensing authority remains unresolved.',
  A27_MEDIA_HOLD: 'Genuine released-application media is still required (A27; CP-0172).',
  UNFEATURED_POLICY_ONLY: 'Unfeatured in this review. The existing public page and release evidence remain preserved.',
  CLEANROOM_VERSION_CONFLICT: 'Website v1.0.7 and published GitHub v1.0.10 remain unreconciled. No promotion is proposed.',
  PUBLIC_RELEASE_WITHDRAWN: 'Reality Gate public v1.1.0 is withdrawn.',
  INSTALLED_PROVIDER_UNKNOWN: 'The active installed provider version and binary hash are unknown; historical v1.1.1 reports do not resolve them.',
  INTERNAL_NOT_PUBLIC: 'Internal operation does not establish a public release or installation permission.',
  SOURCE_REFERENCE_NOT_INSTALLER: 'Commit 1982486 is an engineering reference, not a released installer.',
  HISTORICAL_IDENTITY_UNVERIFIED: 'Current source, runtime version and public availability have not been established.',
  APP_VERSION_DIVERGENCE: 'The App reference records Lights Out 11.1.3; website metadata records 11.2.0. No catalog migration is implied.',
  STANDALONE_NOT_COMPANION: 'The Android standalone effort is distinct from the published companion and the recorded companion build.'
});
const fail = message => { throw new Error('PORTFOLIO_REVIEW_INVALID: ' + message); };
const plain = value => value !== null && typeof value === 'object' && !Array.isArray(value)
  && (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null);
function shape(value, keys, at) {
  if (!plain(value) || keys.some(key => !Object.hasOwn(value, key))
      || Object.keys(value).some(key => !keys.includes(key))) fail(at + ' has an unexpected shape');
}
function text(value, at) {
  if (typeof value !== 'string' || !value.trim() || value.length > 1600
      || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) fail(at + ' must be bounded text');
}
function unique(values, at) {
  if (!Array.isArray(values) || new Set(values).size !== values.length) fail(at + ' must be a unique array');
}
function digest(value, at) {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) fail(at + ' needs SHA-256');
}
function validateReview(model) {
  shape(model, ['schema', 'reviewOnly', 'activation', 'registerSha256', 'websiteReleaseTruthSha256',
    'appReferenceCommit', 'evidenceIds', 'products'], '$');
  if (model.schema !== SCHEMA || model.reviewOnly !== true || model.activation !== 'NOT_AUTHORIZED')
    fail('review-only state is mandatory');
  digest(model.registerSha256, 'registerSha256');
  digest(model.websiteReleaseTruthSha256, 'websiteReleaseTruthSha256');
  if (model.registerSha256 !== '29efa3120b7c2ea04b5ec21098f71a2e91c4a8dbb91605fa150421c75a6d7b85'
      || model.appReferenceCommit !== '1982486667749ebc6310e77738a0626e960e2690') fail('input identity drift');
  unique(model.evidenceIds, 'evidenceIds');
  for (const id of model.evidenceIds) text(id, 'evidence id');
  if (!Array.isArray(model.products) || model.products.length !== IDS.length) fail('11 identities required');
  unique(model.products.map(p => p.id), 'product ids');
  if (IDS.some(id => !model.products.some(p => p.id === id))) fail('product set changed');
  let channels = 0;
  for (const p of model.products) {
    shape(p, ['id', 'name', 'role', 'group', 'featured', 'holds', 'channels'], p.id);
    text(p.name, p.id + '.name'); text(p.role, p.id + '.role');
    if (!GROUPS.includes(p.group) || ![false, 'UNDECIDED'].includes(p.featured)) fail('unsupported editorial policy');
    unique(p.holds, p.id + '.holds');
    if (p.holds.some(h => !Object.hasOwn(HOLD_COPY, h))) fail('unknown hold');
    if (!Array.isArray(p.channels) || !p.channels.length) fail('channel records required');
    unique(p.channels.map(c => c.id), p.id + '.channels');
    channels += p.channels.length;
    for (const c of p.channels) {
      shape(c, ['id', 'platform', 'version', 'availability', 'observedAt', 'evidenceIds', 'artifacts'], p.id + '/' + c.id);
      if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(c.id)) fail('channel id');
      text(c.platform, 'platform');
      if (c.version !== null) text(c.version, 'version');
      if (!Object.hasOwn(LABELS, c.availability)) fail('unknown availability');
      if (c.observedAt !== null && (typeof c.observedAt !== 'string'
          || !/^\d{4}-\d{2}-\d{2}(?:T.*)?$/.test(c.observedAt) || !Number.isFinite(Date.parse(c.observedAt))))
        fail('observation date');
      unique(c.evidenceIds, 'channel evidence');
      if (!c.evidenceIds.length || c.evidenceIds.some(id => !model.evidenceIds.includes(id))) fail('unresolved evidence');
      if (!Array.isArray(c.artifacts)) fail('artifact array required');
      for (const a of c.artifacts) {
        shape(a, ['filename', 'sha256', 'hashProvenance'], 'artifact');
        text(a.filename, 'artifact filename');
        if (/[\\/]/.test(a.filename)) fail('artifact path must not be executable input');
        if (a.sha256 !== null) digest(a.sha256, 'artifact sha256');
        if (a.hashProvenance !== 'PUBLISHED_DIGEST_NOT_INDEPENDENTLY_REHASHED') fail('hash evidence escalation');
      }
    }
  }
  if (channels !== 17) fail('17 channel observations required');
  const get = id => model.products.find(p => p.id === id);
  const requireHolds = (id, holds) => { if (holds.some(h => !get(id).holds.includes(h))) fail(id + ' lost a hold'); };
  requireHolds('proofshot', ['LICENSING_AUTHORITY_HOLD', 'A27_MEDIA_HOLD', 'UNFEATURED_POLICY_ONLY']);
  if (get('proofshot').featured !== false) fail('ProofShot must remain unfeatured');
  requireHolds('cleanroom', ['CLEANROOM_VERSION_CONFLICT']);
  requireHolds('reality-gate', ['PUBLIC_RELEASE_WITHDRAWN', 'INSTALLED_PROVIDER_UNKNOWN']);
  for (const id of ['hardline-zero', 'crosspoint', 'proof-foundry-app']) {
    requireHolds(id, ['INTERNAL_NOT_PUBLIC']);
    if (get(id).group !== 'infrastructure' || get(id).channels.some(c =>
      !['INTERNAL_ONLY_NOT_PUBLIC', 'LOCAL_DIRTY_NONCANONICAL'].includes(c.availability))) fail(id + ' public promotion');
  }
  requireHolds('sound-assist', ['HISTORICAL_IDENTITY_UNVERIFIED']);
  const rgPublic = get('reality-gate').channels.find(c => c.id === 'public-withdrawn');
  const rgInternal = get('reality-gate').channels.find(c => c.id === 'internal-provider');
  if (!rgPublic || rgPublic.version !== '1.1.0' || rgPublic.availability !== 'WITHDRAWN_DO_NOT_DISTRIBUTE'
      || !rgInternal || rgInternal.version !== null || rgInternal.availability !== 'INTERNAL_ONLY_NOT_PUBLIC') fail('RG identity drift');
  const cr = get('cleanroom').channels;
  if (!cr.some(c => c.id === 'website-windows-public' && c.version === '1.0.7')
      || !cr.some(c => c.id === 'github-released-unreconciled' && c.version === '1.0.10'
        && c.availability === 'GITHUB_PUBLIC_RELEASE_CONFLICTS_WITH_SITE_CHANNEL')) fail('Cleanroom conflict erased');
  return model;
}
function projectReview(input, consumer) {
  const model = validateReview(input);
  if (!['website-review', 'store-review', 'portal-review', 'rg-review'].includes(consumer)) fail('unsupported consumer');
  return {
    schema: 'pf.portfolio-discovery-projection/v1', consumer, reviewOnly: true,
    activation: 'NOT_AUTHORIZED', installationAuthority: 'NONE', signingAuthority: 'HOLD',
    publicationAuthority: 'NONE', registerSha256: model.registerSha256,
    products: model.products.map(p => ({
      id: p.id, name: p.name, role: p.role, group: p.group, featured: p.featured,
      recordRoute: WORLDS.has(p.id) ? '/' + p.id + '/' : null,
      truthRoute: WORLDS.has(p.id) ? '/truth-files/' + p.id + '/' : null,
      holds: p.holds.map(h => ({ id: h, description: HOLD_COPY[h] })),
      channels: p.channels.map(c => ({
        id: c.id, platform: c.platform, version: c.version, availability: c.availability,
        label: LABELS[c.availability], observedAt: c.observedAt, evidenceIds: [...c.evidenceIds],
        artifacts: c.artifacts.map(a => ({ ...a })),
        downloadUrl: null, installAllowed: false, signingAllowed: false, publicationApproved: false
      }))
    }))
  };
}
const esc = value => String(value).replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
// Editorial placement is deliberately separate from the eleven-record research inventory.
// Existing product routes remain; no quota, automatic historical promotion or new route claim.
const EDITORIAL = Object.freeze({
  unfeaturedIds: Object.freeze(['proofshot']),
  excludedFromNavigation: Object.freeze(['sound-assist']),
  systems: Object.freeze(['hardline-zero','crosspoint','reality-gate','proof-foundry-app']),
  finalLineupSettled: false
});
const SYSTEM_COPY = {
  "hardline-zero": {
    "headline": "Know what the work is allowed to do.",
    "blocks": [
      {
        "key": "promise",
        "title": "One place to inspect work authority",
        "text": "Hardline Zero puts the active work contract, source alignment and participating agent identities in view. It helps an owner distinguish work that is current from work whose authority or source has drifted. Unknown and unavailable states stay visible rather than becoming a decorative green light.",
        "refs": [
          "HL_SHELL:13-27,104-159",
          "HL_TRUTH_HELPER:8-23"
        ]
      },
      {
        "key": "origin",
        "title": "A dedicated product emerged from the existing shell",
        "text": "The inspected repository contains older NeuralShell and ProofForge material, but that inherited history is not a Hardline Zero release history. September 2026 records introduce the Hardline operator cockpit and read-only Work Truth. October records establish a distinct Windows product identity and dedicated shell. The original personal conception story has not been established.",
        "refs": [
          "HISTORY:hardline-zero September/October commits",
          "HL_PRODUCT:1-2",
          "HL_README:legacy product identity"
        ]
      },
      {
        "key": "evolution",
        "title": "Make the authority readable",
        "text": "20 September 2026 — the cockpit and read-only Work Truth contract are recorded.\n23 September 2026 — source history records caller-bound identity and presence work.\n11 October 2026 — a dedicated shell and separate Hardline Zero Windows product flavor are recorded.\n26 October 2026 — the owner workflow adds assignment composition and thread notes through bounded channels.",
        "refs": [
          "HISTORY:hardline-zero"
        ]
      },
      {
        "key": "today",
        "title": "What the current source supports",
        "text": "The current internal shell shows authority verdicts, governed principals, CrossPoint coordination, recent assignments and work requiring attention. Those views use the underlying answers and preserve missing-data states. This is inspected internal source and observed coordination capability—not a verified public installer, version promise or universal control over every connected application.",
        "refs": [
          "HL_SHELL:104-159",
          "HL_TRUTH_HELPER:37-67",
          "REGISTER_FULL:/products/hardline-zero"
        ]
      },
      {
        "key": "workflow",
        "title": "Read the boundary, then choose the next step",
        "text": "Open the operator view, inspect the current source verdict and check the participating principals. Follow a task into its recorded authority and evidence. If the work is superseded or a required permission is missing, resolve that specific boundary before requesting execution. CrossPoint carries the assignment; the target project’s execution controls still decide what can run.",
        "refs": [
          "HL_SHELL:23-27,104-159",
          "CP_MODEL:1-16",
          "REGISTER_FULL:/products/hardline-zero"
        ]
      },
      {
        "key": "limits",
        "title": "Internal operation is not public availability",
        "text": "The reviewed evidence does not establish a public Hardline Zero installer or a current public release version. The legacy README’s ProofForge release information does not establish either. Work Truth alignment is evidence about a work contract, not proof that every downstream product is qualified or installable.",
        "refs": [
          "HL_README:legacy public version",
          "HL_PRODUCT:1-2",
          "REGISTER_FULL:/products/hardline-zero"
        ]
      }
    ]
  },
  "crosspoint": {
    "headline": "Give the handoff a record.",
    "blocks": [
      {
        "key": "promise",
        "title": "A task should survive the conversation",
        "text": "CrossPoint records bounded assignments between agents: who sent the work, who received it, whether it was retrieved and accepted, and what result or blocker was returned. It gives the owner an inspectable handoff rather than relying on an agent saying that another agent has started.",
        "refs": [
          "CP_MODEL:1-16,47-50",
          "HISTORY:hardline-zero coordination evolution"
        ]
      },
      {
        "key": "origin",
        "title": "A coordination core, not another executor",
        "text": "The first explicit CrossPoint implementation found in the surviving history is the offline coordination core dated 27 September 2026. Its model defines owner governance over AI participants and deliberately separates coordination records from execution authority. A broader personal origin story is not established.",
        "refs": [
          "HISTORY:4a9ce7d",
          "CP_MODEL:1-16"
        ]
      },
      {
        "key": "evolution",
        "title": "From assignments to a readable thread",
        "text": "27 September 2026 — the coordination core is recorded.\n30 September 2026 — events, cursors, awareness and bounded question/memo work follow.\n3 October 2026 — source history records authority binding that distinguishes task progress from whether its contract is still current.\n5 October 2026 — an owner-observer view is added.\n26 October 2026 — owner composition and thread notes become part of the dedicated interface.",
        "refs": [
          "HISTORY:hardline-zero CrossPoint commits"
        ]
      },
      {
        "key": "today",
        "title": "Delivery and completion are different facts",
        "text": "The internal system records assignment states, participant access, notes and results. Retrieval is an observable event; offering a task does not itself start its recipient. A completed coordination record also does not replace an independent review of the evidence it names. These distinctions are part of the working handoff used for this content review.",
        "refs": [
          "CP_MODEL:states and authority separation",
          "REGISTER_FULL:/products/crosspoint",
          "HISTORY:authority binding"
        ]
      },
      {
        "key": "workflow",
        "title": "Offer, retrieve, act within scope, return evidence",
        "text": "Send a bounded task to the intended principal. The recipient retrieves it, checks its own authority and accepts the permitted work. Keep questions and evidence references on the thread, then record the result or the exact blocker. Preserve terminal history when new evidence arrives rather than rewriting a past refusal into a success.",
        "refs": [
          "CP_MODEL:1-16,47-50",
          "HISTORY:CrossPoint notes and binding",
          "REGISTER_FULL:/products/crosspoint"
        ]
      },
      {
        "key": "limits",
        "title": "A handoff cannot grant a permission",
        "text": "CrossPoint is distinct from Hardline Zero’s work governance and Reality Gate’s native execution. It has no verified standalone public installer in this review. Assignment text is coordination data; it is not an execution token, an installation grant or publication approval. The CrossPoint / XrossPoint spelling still needs a single editorial choice before public adoption.",
        "refs": [
          "CP_MODEL:1-16",
          "REGISTER_FULL:/products/crosspoint"
        ]
      }
    ]
  },
  "proof-foundry-app": {
    "headline": "See what you have. Inspect what you are getting.",
    "blocks": [
      {
        "key": "promise",
        "title": "A software library with the record attached",
        "text": "Proof Foundry App brings catalog, library, update and proof views together. Its internal implementation separates a listed release from what has actually been detected on a machine, and keeps missing catalog data visible. The aim is a useful software library whose status can be inspected.",
        "refs": [
          "APP_UI:3-13,53-59",
          "APP_PROOF:187-201"
        ]
      },
      {
        "key": "origin",
        "title": "The catalog needed a path to the user",
        "text": "The September 2026 discovery report proposed a continuous path from finding software to checking its release and keeping a local record. At that point the Store was still a proposal. Subsequent source history records the Developer Portal and Windows implementation, so that early absence must not be repeated as the current state.",
        "refs": [
          "APP_DISCOVERY:discovery and loop",
          "REPOSITORIES:App history"
        ]
      },
      {
        "key": "evolution",
        "title": "From discovery to a bounded library",
        "text": "2 September 2026 — the discovery report maps the proposed software journey.\n4 September 2026 — Developer Portal work enters the source record.\n6 September 2026 — the first Windows Store tranche is recorded.\n4 October 2026 — shared release-truth projections are integrated.\n5 October 2026 — the clean 1982486 successor records bounded portable install-profile generalization.",
        "refs": [
          "APP_DISCOVERY:date",
          "REPOSITORIES:App earliest and recent histories",
          "APP_PROFILE:all"
        ]
      },
      {
        "key": "today",
        "title": "A real foundation, with a precise boundary",
        "text": "The clean engineering reference contains a Windows Store interface, a Developer Portal, an Android implementation and shared catalog/evidence code. The Windows source exposes Home, Library, Updates and Proof views, with bounded installed-state detection. Portable profile work is narrower than a general installer or launcher. The record does not establish a production signing service or an active App-specific Reality Gate execution bridge.",
        "refs": [
          "APP_UI:3-59",
          "APP_PROOF:187-240",
          "APP_PROFILE:all",
          "REGISTER_FULL:/products/proof-foundry-app",
          "CP173_RESULT:canonical completed result, 2026-11-01"
        ]
      },
      {
        "key": "workflow",
        "title": "Inspect the release before acting on it",
        "text": "In the internal review flow, browse a title, inspect its recorded artifact and qualification information, then compare that with the local machine state. A missing or invalid catalog stays visible. Developers have a separate submission and approval workflow; being listed in either interface does not grant native installation or signing permission.",
        "refs": [
          "APP_UI:3-13,30-59",
          "APP_PROOF:176-240",
          "APP_PROFILE:all",
          "REGISTER_FULL:/products/proof-foundry-app",
          "CP173_RESULT:canonical completed result, 2026-11-01"
        ]
      },
      {
        "key": "limits",
        "title": "Source reference, not a public download",
        "text": "1982486 is the selected engineering reference, not a marketed release version. General installation, launch, production signing and distribution remain on HOLD. Foundry Key or hardware-backed signing claims must not be inferred from the desktop adapter. Older Desktop work is preserved separately and is not silently promoted by this page.",
        "refs": [
          "APP_PROFILE:scope exclusions",
          "REGISTER_FULL:/products/proof-foundry-app",
          "APP_DISCOVERY:Foundry Key definition is discovery scope",
          "CP173_RESULT:canonical completed result, 2026-11-01"
        ]
      }
    ]
  }
};
function renderReview(model) {
  const projection = projectReview(model, 'website-review');
  const byId = id => { const p=projection.products.find(p => p.id === id); return id==='crosspoint'?{...p,name:'CrossPoint'}:p; };
  function channels(p) {
    return '<details class="pf-portfolio-channel-record"><summary>Release and availability records</summary><ul class="pf-portfolio-channels">'
      + p.channels.map(c=>'<li><h4>'+esc(c.platform)+'</h4><dl><dt>Recorded version</dt><dd>'+esc(c.version||'Not established')
        +'</dd><dt>Availability</dt><dd>'+esc(c.label)+'</dd><dt>Observed</dt><dd>'+esc(c.observedAt||'Undated historical record')
        +'</dd></dl>'+c.artifacts.map(a=>'<p>'+esc(a.filename)+'</p><p>Published SHA-256; binary not rehashed:</p><code>'+esc(a.sha256||'UNKNOWN')+'</code>').join('')
        +'<p class="pf-portfolio-evidence">Evidence: '+c.evidenceIds.map(esc).join(', ')+'</p></li>').join('')+'</ul></details>';
  }
  function system(id,index) {
    const p=byId(id),copy=SYSTEM_COPY[id];
    const purpose=id==='reality-gate'?'Keep execution tied to the project.':copy.headline;
    const intro=id==='reality-gate'?'Reality Gate connects a registered project, permitted operations and the evidence of each run. Its execution boundary is distinct from Hardline Zero’s work governance and CrossPoint’s assignments.':copy.blocks.find(b=>b.key==='promise').text;
    const workflow=id==='reality-gate'?'Inspect the registered source and project Truth, request a permitted named operation, then review the resulting evidence and receipt.':copy.blocks.find(b=>b.key==='workflow').text;
    const state=id==='reality-gate'?'Internal development continues. Public v1.1.0 is withdrawn; no public successor is established.':id==='proof-foundry-app'?'Internal engineering reference. Public distribution and signing remain on HOLD.':'Internal product. No verified public installer is offered.';
    const role={ 'hardline-zero':'Work governance',crosspoint:'Agent coordination','reality-gate':'Project execution','proof-foundry-app':'Software library' }[id];
    const story=copy?'<details class="pf-system-story"><summary>How '+esc(p.name)+' developed</summary>'
      +copy.blocks.filter(b=>['origin','evolution','today','limits'].includes(b.key)).map(b=>'<section><h4>'+esc(b.title)+'</h4>'+b.text.split('\n').map(t=>'<p>'+esc(t)+'</p>').join('')+'</section>').join('')+'</details>':
      '<a class="text-link" href="/reality-gate/">Enter the Reality Gate control room ↗</a>';
    return '<article id="portfolio-'+id+'" class="pf-system pf-system--'+id+'" aria-labelledby="system-'+id+'"><header><span class="pf-system-register">'+String(index+1).padStart(2,'0')+' / '+esc(role)+'</span><h3 id="system-'+id+'">'+esc(p.name)+'</h3><p class="pf-system-purpose">'+esc(purpose)+'</p><p class="pf-system-state">'+esc(state)+'</p></header>'
      +'<div class="pf-system-body"><p>'+esc(intro)+'</p><div class="pf-system-workflow"><h4>In use</h4><p>'+esc(workflow)+'</p></div>'+story+channels(p)+'</div></article>';
  }
  function history() {
    return '<section class="pf-portfolio-history" id="portfolio-history" aria-labelledby="portfolio-history-title"><h2 id="portfolio-history-title">Preserved product history</h2>'
      +'<details id="portfolio-proofshot"><summary>ProofShot · historical record</summary><p>From HyperSnatch to ProofShot: the capture history and release evidence remain available. ProofShot is not currently featured; licensing authority and qualified current-application imagery remain unresolved.</p>'
      +'<p class="pf-portfolio-links"><a href="/proofshot/">Read ProofShot’s history</a><a href="/truth-files/proofshot/">Historical Truth File</a></p></details></section>';
  }
  const home='<section class="pf-portfolio-home container" aria-labelledby="pf-systems-home-title"><header><p class="kicker">The work behind the work</p><h2 id="pf-systems-home-title">A contract. A handoff.<br>A record you can follow.</h2><p>Purpose-built tools for keeping work understandable across people, agents and projects.</p></header><div class="pf-system-entrances">'
    +['hardline-zero','crosspoint'].map(id=>{const p=byId(id);return '<article class="pf-system-entrance pf-system-entrance--'+id+'"><p class="kicker">'+(id==='hardline-zero'?'Work governance':'Agent coordination')+'</p><h3>'+esc(p.name)+'</h3><p>'+esc(SYSTEM_COPY[id].headline)+'</p><a class="button button-secondary" href="/software/#portfolio-'+id+'">Explore '+esc(p.name)+' ↗</a><p class="pf-system-state">Internal product · no public installer</p></article>';}).join('')
    +'</div><p class="pf-portfolio-links"><a href="/software/#portfolio-reality-gate">Reality Gate — project execution</a><a href="/software/#portfolio-proof-foundry-app">Proof Foundry App — software library</a></p></section>';
  const recordIndex='<section class="pf-portfolio-records" aria-labelledby="portfolio-records-title"><h2 id="portfolio-records-title">Release context</h2><p>These dated records describe availability; they do not select the website’s final product lineup.</p>'
    +projection.products.filter(p=>p.recordRoute&&!EDITORIAL.unfeaturedIds.includes(p.id)&&!EDITORIAL.systems.includes(p.id)).map(p=>'<details id="portfolio-'+p.id+'"><summary>'+esc(p.name)+'</summary>'
      +'<p>'+esc(p.role)+'</p>'+p.holds.map(h=>'<p>'+esc(h.description)+'</p>').join('')
      +'<p class="pf-portfolio-links"><a href="'+esc(p.recordRoute)+'">Product story</a><a href="'+esc(p.truthRoute)+'">Truth File</a></p>'+channels(p)+'</details>').join('')+'</section>';
  return {
    schema:'pf.portfolio-review-slots/v1',
    unfeaturedIds:[...EDITORIAL.unfeaturedIds],
    systemIds:[...EDITORIAL.systems],
    home,
    homeHistory:'<aside class="pf-portfolio-history container"><details><summary>Preserved history</summary><p>ProofShot is not currently featured. Its story and evidence remain available.</p><p class="pf-portfolio-links"><a href="/proofshot/">ProofShot history</a><a href="/truth-files/proofshot/">Historical Truth File</a><button type="button" class="ledger-receipt-button" data-receipt-open="proofshot" aria-haspopup="dialog" aria-controls="pf-receipt-dialog" hidden>Inspect historical receipt</button></p></details></aside>',
    software:'<section class="pf-portfolio h9-software-wrap" id="portfolio" aria-labelledby="portfolio-title"><header><p class="kicker">Foundry systems</p><h2 id="portfolio-title">Different responsibilities.<br>Connected work.</h2><p>Governance, coordination, execution and distribution each have their own job.</p></header>'
      +'<nav class="pf-portfolio-tabs" aria-label="Foundry systems">'+EDITORIAL.systems.map(id=>'<a href="#portfolio-'+id+'">'+esc(byId(id).name)+'</a>').join('')+'</nav>'
      +EDITORIAL.systems.map(system).join('')+'<nav class="pf-portfolio-links" aria-label="Software stories">'+projection.products.filter(p=>p.recordRoute&&!EDITORIAL.unfeaturedIds.includes(p.id)&&!EDITORIAL.systems.includes(p.id)).map(p=>'<a href="'+esc(p.recordRoute)+'">'+esc(p.name)+'</a>').join('')+'</nav></section>',
    softwareRecords:'<div class="pf-portfolio h9-software-wrap">'+recordIndex+history()+'</div>'
  };
}
module.exports = { SCHEMA, IDS, validateReview, projectReview, renderReview, EDITORIAL };

// Presentation-only directory. Identity and release facts remain in their existing inputs.
function validateEditorial(input, context) {
  shape(input, ['schema','entries'], 'editorial');
  if (input.schema !== 'pf.site-editorial/v1' || !Array.isArray(input.entries) || input.entries.length > 200)
    fail('editorial schema or entries');
  const keys=['id','visible','order','group','shortDescription','artwork','destination'];
  unique(input.entries.map(e => e?.id), 'editorial ids');
  const ids=new Set(context.identities), routes=context.routes, assets=context.assets;
  for (const entry of input.entries) {
    shape(entry,keys,'editorial entry');
    if (!ids.has(entry.id)) fail('unknown editorial identity');
    if (typeof entry.visible !== 'boolean' || !Number.isFinite(entry.order)) fail('editorial visibility/order');
    text(entry.group,'editorial group'); text(entry.shortDescription,'editorial description');
    if (entry.group.length>60 || entry.shortDescription.length>280) fail('editorial text too long');
    for (const key of ['artwork','destination']) {
      const value=entry[key];
      if (value !== null && (typeof value!=='string' || !/^\/(?!\/)[a-zA-Z0-9_./#-]+$/.test(value)
          || value.includes('..') || value.includes('//') || value.includes('\\'))) fail('unsafe editorial '+key);
    }
    if (entry.artwork!==null && !assets.has(entry.artwork)) fail('missing editorial artwork');
    if (entry.destination!==null && !routes.has(entry.destination)) fail('missing editorial destination or fragment');
    if (['proofshot','sound-assist'].includes(entry.id) && entry.visible) fail('standing unfeatured/excluded policy');
  }
  return [...input.entries].sort((a,b)=>a.order-b.order||a.id.localeCompare(b.id,'en'));
}
function renderDirectory(input, model, releaseTruth, manifest, context) {
  validateReview(model);
  const entries=validateEditorial(input,context).filter(e=>e.visible);
  const identities=new Map(model.products.map(p=>[p.id,p]));
  const products=new Map(manifest.products.map(p=>[p.id,p]));
  const releases=new Map(releaseTruth.products.map(p=>[p.id,p]));
  const groups=[...new Set(entries.map(e=>e.group))];
  // Owner decision 2026-11-05: each editorial group is introduced by its own name, so the Foundry systems read as
  // their own row. Labels are not entries; the finder hides a label whose group has no visible card (CSS :has).
  let previousGroup=null;
  const html=entries.map(entry=>{
    const groupLabel=entry.group!==previousGroup?'<p class="directory-group-label" role="heading" aria-level="3" data-directory-group-label="'+esc(entry.group)+'">'+esc(entry.group)+'</p>':'';
    previousGroup=entry.group;
    const identity=identities.get(entry.id), product=products.get(entry.id), release=releases.get(entry.id);
    const name=entry.id==='crosspoint'?'CrossPoint':identity.name;
    const channels=release?.channels.filter(c=>c.track==='PUBLIC')||[];
    const released=channels.filter(c=>c.publicationState==='PUBLIC_RELEASE');
    let state=released.length?released.map(c=>c.platform[0].toUpperCase()+c.platform.slice(1)+' · v'+c.version+
      (c.artifacts.some(a=>a.downloadUrl)?'':' · not offered here')).join(' / '):'Internal product · no public installer';
    if (entry.id==='reality-gate') state='Internal development · public v1.1.0 withdrawn';
    // Owner decision 2026-11-05: a pending candidate is stated with the site's approved candidate sentence.
    let candidateNote=String(product?.candidateStatus||product?.presentation?.candidateStatus||'');
    // Reality Gate keeps its no-successor fact on its card (the same sentence its withheld record carried).
    if (entry.id==='reality-gate') candidateNote='Public v1.1.0 is withdrawn; no public successor is established.';
    const media=entry.artwork?'<figure class="directory-art"><img src="'+esc(entry.artwork)+'" alt="'+esc(product?.presentation?.cardImageAlt||name+' artwork')+'" loading="lazy" width="960" height="540"/></figure>':'<div class="directory-no-art" aria-hidden="true"><i></i><i></i><i></i></div>';
    const link=entry.destination?'<a class="button button-secondary" href="'+esc(entry.destination)+'">Explore '+esc(name)+' <span aria-hidden="true">↗</span></a>':'<p class="directory-no-route">Product page not yet available.</p>';
    return groupLabel+'<article class="directory-entry directory-entry--'+esc(entry.id)+'" data-directory-entry="'+esc(entry.id)+'" data-directory-group="'+esc(entry.group)+'"><header><p class="kicker">'+esc(entry.group)+'</p><h3>'+esc(name)+'</h3><p class="directory-purpose">'+esc(entry.shortDescription)+'</p></header>'+media+'<div class="directory-foot"><p class="directory-state">'+esc(state)+'</p>'+(candidateNote?'<p class="directory-state-note">'+esc(candidateNote)+'</p>':'')+link+'</div></article>';
  }).join('');
  return {
    count:entries.length,
    groups:groups.map(g=>'<option value="'+esc(g)+'">'+esc(g)+'</option>').join(''),
    html:html||'<p class="directory-zero">No products are listed here at the moment. Existing product pages and public records remain available.</p>',
    selectedIds:entries.map(e=>e.id)
  };
}
module.exports.validateEditorial=validateEditorial;
module.exports.renderDirectory=renderDirectory;
