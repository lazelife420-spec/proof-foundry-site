// Homepage behaviour: Inspect the Mark, Inspect the Receipt and the emblem's
// pointer highlights. Release facts are never stored here or in the page:
// a receipt is read from the site's own generated records when it is opened
// and is shown only after they validate and agree (pf-truth-receipt.js).
// Everything else on the page works without this file.
//
// The opened inspector shows the full SHA-256 of every listed artifact (owner
// decision, 2026-10-13). The static homepage keeps exactly one product digest,
// the release specimen's; test-h9-binding.ps1 enforces that.

import { TRUTH_SCHEMA_URL, TRUTH_INDEX_URL, PROOF_REGISTRY_URL, truthRecordUrl, buildReceipt, indexEntries } from './pf-truth-receipt.js';

const root = document.documentElement;
const motionOn = () => root.dataset.motion === 'on';
const finePointer = matchMedia('(hover: hover) and (pointer: fine)');
const live = () => finePointer.matches && motionOn();

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined && text !== null) node.textContent = String(text);
  return node;
}

const ARROW = 'M4 12h15m-6-6 6 6-6 6';
function arrow() {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', 'ledger-arrow');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '1.5');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('focusable', 'false');
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', ARROW);
  svg.append(path);
  return svg;
}

function link(href, text, { external = false, withArrow = false } = {}) {
  const a = el('a', null, text);
  a.href = href;
  if (external) {
    a.target = '_blank';
    a.rel = 'noopener';
    a.append(el('span', 'ledger-sr', ' (opens in a new tab)'));
  }
  if (withArrow) a.append(arrow());
  return a;
}

// ── dialogs ──────────────────────────────────────────────────────────────────
// Focus and scroll position return to whatever opened the dialog.
const returns = new WeakMap();

function openDialog(dialog, trigger) {
  if (dialog.open) return;
  returns.set(dialog, { trigger, x: scrollX, y: scrollY });
  if (typeof dialog.showModal === 'function') dialog.showModal();
  else dialog.setAttribute('open', '');
}

function wireDialog(dialog) {
  dialog.addEventListener('close', () => {
    const back = returns.get(dialog);
    returns.delete(dialog);
    if (!back) return;
    if (back.trigger && back.trigger.isConnected) back.trigger.focus({ preventScroll: true });
    scrollTo({ left: back.x, top: back.y, behavior: 'instant' });
  });
  dialog.addEventListener('click', (event) => { if (event.target === dialog) dialog.close(); });
  dialog.querySelectorAll('[data-dialog-close]').forEach((button) => button.addEventListener('click', () => dialog.close()));
  if (typeof dialog.showModal !== 'function') {
    dialog.addEventListener('keydown', (event) => { if (event.key === 'Escape') { dialog.removeAttribute('open'); dialog.dispatchEvent(new Event('close')); } });
  }
}

// ── Inspect the Mark ─────────────────────────────────────────────────────────
// Positions are in emblem units (frame -26 -26 308 356); loupe = [u, v, zoom].
// The P, F and bridge outlines are PF_MARK_G_MASTER.svg's paths, verbatim.
const FRAME = { ox: -26, oy: -26, w: 308, h: 356, ar: 1849 / 1600 };
const CANON = {
  P: 'M42 34H116C157 34 181 56 181 91C181 126 157 148 116 148H82V222H42V34ZM82 70V112H115C132 112 141 104 141 91C141 78 132 70 115 70H82Z',
  F: 'M146 34H226V72H186V106H218V143H186V222H146V34Z',
  B: 'M138 70H186V106H138Z',
};
const LETTERS = 'translate(26.16 30.72) scale(.76)';
const NOTES = [
  { title: 'The approved silver P', u: 73, v: 160, shape: 'P',
    body: 'The P is drawn from the PF Mark G master contour, unaltered. It is rendered as satin-machined steel, brushed in one direction, with a crisp chamfer on every edge so the outline stays sharp at any size. P is for proof.' },
  { title: 'The brass F', u: 186, v: 71, shape: 'F',
    body: "The F is the second master component, finished as brushed brass with its grain running vertically. It sits over the P's bowl in the same paint order as the master artwork, so the silhouette matches the approved mark exactly. F is for foundry." },
  { title: 'The connecting bridge', u: 112, v: 97, shape: 'B', loupe: [150, 97, 3.0],
    body: "The master's bridge ties the two letters together. Here it is a steel key across the F stem with a thin brass inlay, fixed to the P by two short tack welds — the only welds on the mark, each with a small ring of temper colour. Proof and making, joined." },
  { title: 'Machined edges and thickness', u: 104, v: 214, shape: 'edge', loupe: [92, 196, 3.2],
    body: 'Every component carries a 45° chamfer cut inside its outline, so the letters read as substantial parts rather than flat artwork. A broad key light from the upper left, balanced by restrained fill, sets the highlights, edges and contact shadows, so depth reads consistently across the whole assembly.' },
  { title: "The maker's seal", u: 46, v: 197, shape: 'seal', loupe: [52, 186, 2.4],
    body: 'A blackened steel plate with a lathe-faced recess, held to the outer chassis by four countersunk screws. The ring, the recessed field and the chassis each carry a different finish, so the layers read as separate, assembled parts.' },
  { title: 'Binary engraving', u: 70, v: 0.5, shape: 'bin', loupe: [128, 1.5, 3.6],
    body: '01010000 01000110 is ASCII for P (0x50) and F (0x46), laser-marked along the upper rim of the chassis. Easy to miss at a glance; exact when you check it.' },
  { title: 'Upper inscription', u: 57, v: 49, shape: 'top', loupe: [128, 23, 2.7],
    body: "THE PROOF FOUNDRY™ — the maker's name, engraved into the upper arc of the seal ring." },
  { title: 'Lower inscription', u: 204, v: 204, shape: 'bot', loupe: [128, 233, 2.7],
    body: 'BUILD IT. PROVE IT. SHIP IT. — the working method, engraved into the lower arc of the seal ring.' },
  { title: 'Registration and finish', u: 256, v: 100, shape: 'ticks', loupe: [226, 128, 3.0],
    body: 'Radial ticks index the ring every 3°, with longer ticks every 15°. Brass inlays mark the four cardinal points. Fly-cut arcs on the plate, concentric tool paths in the recess and directional grain on the letters keep every surface distinct.' },
  { title: 'Identification plates', u: 8, v: 277, shape: 'plates', loupe: [128, 280, 2.2],
    body: 'SOURCE / ARTIFACT / RECORD names what every release should carry. The companion plate reads RECEIPTS OVER HYPE., and the rim below them reads IF IT MATTERS, KEEP THE RECEIPT.' },
];

function overlayShape(shape) {
  const ns = 'http://www.w3.org/2000/svg';
  const make = (tag, attrs) => { const n = document.createElementNS(ns, tag); for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v); n.setAttribute('class', 'hl'); return n; };
  switch (shape) {
    case 'P': case 'F': case 'B': return [make('path', { d: CANON[shape], transform: LETTERS })];
    case 'edge': return [make('path', { d: 'M82 214L82 222L42 222', transform: LETTERS })];
    case 'seal': return [make('circle', { cx: 128, cy: 128, r: 114, fill: 'none' }), make('circle', { cx: 128, cy: 128, r: 100 })];
    case 'bin': return [make('rect', { x: 82, y: -4.6, width: 92, height: 9.6, rx: 1.5 })];
    case 'top': return [make('path', { d: 'M83 37 A104 104 0 0 1 173 37 L178 27 A115 115 0 0 0 78 27 Z' })];
    case 'bot': return [make('path', { d: 'M68 218 A113 113 0 0 0 188 218 L182 210 A104 104 0 0 1 74 210 Z' })];
    case 'ticks': return [make('path', { d: 'M224 74 A112 112 0 0 1 224 182 L215 175 A101 101 0 0 0 215 81 Z' }), make('path', { d: 'M32 74 A112 112 0 0 0 32 182 L41 175 A101 101 0 0 1 41 81 Z' })];
    case 'plates': return [make('rect', { x: 19, y: 261, width: 154, height: 32, rx: 2 }), make('rect', { x: 179, y: 261, width: 58, height: 32, rx: 2 })];
    default: return [];
  }
}

function initMark(dialog) {
  const figure = dialog.querySelector('.pf-mk-fig');
  const overlay = dialog.querySelector('.pf-mk-svg');
  const list = dialog.querySelector('.pf-mk-list');
  const detail = dialog.querySelector('.pf-mk-detail');
  if (!figure || !overlay || !list || !detail) return;
  const count = detail.querySelector('[data-mark-count]');
  const title = detail.querySelector('[data-mark-title]');
  const body = detail.querySelector('[data-mark-body]');
  const loupe = detail.querySelector('.pf-loupe');
  const pins = [];
  const items = [];

  function select(index) {
    const note = NOTES[index];
    pins.forEach((pin, i) => pin.setAttribute('aria-pressed', String(i === index)));
    items.forEach((item, i) => item.setAttribute('aria-pressed', String(i === index)));
    count.textContent = `Point ${index + 1} of ${NOTES.length}`;
    title.textContent = note.title;
    body.textContent = note.body;
    overlay.replaceChildren(...overlayShape(note.shape));
    if (note.loupe) {
      const [u, v, zoom] = note.loupe;
      const fx = (u - FRAME.ox) / FRAME.w, fy = (v - FRAME.oy) / FRAME.h, ar = 6.4 / 16;
      const px = ((0.5 - fx * zoom) / (1 - zoom)) * 100;
      const py = ((0.5 * ar - fy * zoom * FRAME.ar) / (ar - zoom * FRAME.ar)) * 100;
      loupe.style.backgroundSize = `${(zoom * 100).toFixed(1)}% auto`;
      loupe.style.backgroundPosition = `${px.toFixed(2)}% ${py.toFixed(2)}%`;
      loupe.setAttribute('aria-label', `Magnified detail: ${note.title}`);
      loupe.hidden = false;
    } else loupe.hidden = true;
  }

  NOTES.forEach((note, index) => {
    const pin = el('button', 'pf-pin', index + 1);
    pin.type = 'button';
    pin.style.left = `${(((note.u - FRAME.ox) / FRAME.w) * 100).toFixed(2)}%`;
    pin.style.top = `${(((note.v - FRAME.oy) / FRAME.h) * 100).toFixed(2)}%`;
    pin.setAttribute('aria-label', `Point ${index + 1}: ${note.title}`);
    pin.addEventListener('click', () => select(index));
    figure.append(pin);
    pins.push(pin);

    const item = el('button');
    item.type = 'button';
    item.append(el('span', 'k', index + 1), document.createTextNode(note.title));
    item.firstChild.setAttribute('aria-hidden', 'true');
    item.addEventListener('click', () => select(index));
    const li = el('li');
    li.append(item);
    list.append(li);
    items.push(item);
  });
  select(0);
}

// ── Living metal ─────────────────────────────────────────────────────────────
// The pointer stands in for the light: edges facing it brighten. Decorative,
// and only where a fine pointer can hover and motion is on.
function initLivingMetal(emblem) {
  let frame = 0;
  const reset = () => {
    cancelAnimationFrame(frame);
    for (const key of ['--lN', '--lS', '--lE', '--lW', '--lOn', '--mx', '--my', '--ang']) emblem.style.removeProperty(key);
  };
  emblem.addEventListener('pointermove', (event) => {
    if (!live() || event.pointerType !== 'mouse') return;
    const r = emblem.getBoundingClientRect();
    const x = (event.clientX - r.left) / r.width, y = (event.clientY - r.top) / r.height;
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      if (!live()) return reset();
      const dx = x - 0.5, dy = y - 0.43, len = Math.hypot(dx, dy) || 1, k = Math.min(1, 0.35 + len * 1.6);
      const s = emblem.style, lx = dx / len, ly = dy / len;
      s.setProperty('--lN', (Math.max(0, -ly) * k).toFixed(3));
      s.setProperty('--lS', (Math.max(0, ly) * k).toFixed(3));
      s.setProperty('--lE', (Math.max(0, lx) * k).toFixed(3));
      s.setProperty('--lW', (Math.max(0, -lx) * k).toFixed(3));
      s.setProperty('--lOn', '1');
      s.setProperty('--mx', `${(x * 100).toFixed(1)}%`);
      s.setProperty('--my', `${(y * 100).toFixed(1)}%`);
      s.setProperty('--ang', `${(Math.atan2(dy, dx) * 57.2958 + 90).toFixed(1)}deg`);
    });
  });
  emblem.addEventListener('pointerleave', reset);
  emblem.addEventListener('pointercancel', reset);
  new MutationObserver(() => { if (!motionOn()) reset(); }).observe(root, { attributes: true, attributeFilter: ['data-motion'] });
}

function initGlass(screen) {
  screen.addEventListener('pointermove', (event) => {
    if (!live() || event.pointerType !== 'mouse') return;
    const r = screen.getBoundingClientRect();
    screen.style.setProperty('--gx', `${(((event.clientX - r.left) / r.width) * 100).toFixed(1)}%`);
    screen.style.setProperty('--gy', `${(((event.clientY - r.top) / r.height) * 100).toFixed(1)}%`);
    screen.style.setProperty('--gOn', '1');
  });
  screen.addEventListener('pointerleave', () => screen.style.removeProperty('--gOn'));
}

// ── Inspect the Receipt ──────────────────────────────────────────────────────
class LoadError extends Error {}

async function fetchJson(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(url, { cache: 'no-cache', credentials: 'same-origin', signal: controller.signal, headers: { Accept: 'application/json' } });
    if (!response.ok) throw new LoadError(`${url} answered HTTP ${response.status}.`);
    const text = await response.text();
    try { return JSON.parse(text); } catch { throw new LoadError(`${url} is not valid JSON.`); }
  } catch (error) {
    if (error instanceof LoadError) throw error;
    throw new LoadError(error && error.name === 'AbortError' ? `${url} did not respond in time.` : `${url} could not be reached.`);
  } finally {
    clearTimeout(timer);
  }
}

// Every view of a receipt (opened, reopened, switched to or retried) fetches
// the schema, index, record and proof registry afresh as one snapshot, and the
// browser revalidates each with the server. Nothing is reused from an earlier
// view, so a later deploy can never be mixed with records read before it;
// buildReceipt refuses a snapshot whose records come from different builds.
// fetchedAt is when this snapshot's responses had all arrived.
async function loadSnapshot(id) {
  const settled = await Promise.allSettled([TRUTH_SCHEMA_URL, TRUTH_INDEX_URL, truthRecordUrl(id), PROOF_REGISTRY_URL].map(fetchJson));
  const fetchedAt = new Date();
  const [schema, index, record, registry] = settled.map((s) => (s.status === 'fulfilled' ? s.value : null));
  const failed = settled.find((s) => s.status === 'rejected');
  let result;
  if (failed) result = { ok: false, reason: 'load', detail: failed.reason instanceof LoadError ? failed.reason.message : 'The public record could not be loaded.' };
  else {
    try { result = buildReceipt({ id, schema, index, record, registry }); }
    catch { result = { ok: false, reason: 'record', detail: 'The published records could not be checked in this browser.' }; }
  }
  return { fetchedAt, schema, index, result };
}

function timeOf(date) {
  const time = el('time', null, `${date.toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'long' })} (this device's clock)`);
  time.dateTime = date.toISOString();
  return time;
}

const CHIP = { ok: 'pf-chip ok', pending: 'pf-chip pend', none: 'pf-chip neutral' };

function factList(rows) {
  const dl = el('dl', 'pf-rc-facts');
  for (const [term, value, mono] of rows) {
    if (value === null || value === undefined || value === '') continue;
    const dd = el('dd', mono ? 'pf-mono' : null);
    if (value instanceof Node) dd.append(value); else dd.textContent = String(value);
    dl.append(el('dt', null, term), dd);
  }
  return dl;
}

function block(heading, ...children) {
  const wrap = el('div', 'pf-rc-sec');
  wrap.append(el('h4', null, heading), ...children);
  return wrap;
}

function copyButton(label, text, accessibleName, announce) {
  const button = el('button', 'pf-copy', label);
  button.type = 'button';
  button.setAttribute('aria-label', accessibleName);
  let timer = 0;
  button.addEventListener('click', async () => {
    let copied = false;
    try { await navigator.clipboard.writeText(text); copied = true; }
    catch {
      try {
        const area = el('textarea');
        area.value = text;
        area.setAttribute('readonly', '');
        area.style.position = 'fixed';
        area.style.opacity = '0';
        (button.closest('dialog') || document.body).append(area);
        area.select();
        copied = document.execCommand('copy');
        area.remove();
      } catch { copied = false; }
    }
    button.textContent = copied ? 'Copied' : 'Select to copy';
    announce(copied ? 'Copied to clipboard.' : 'Copy was blocked; select the text to copy it.');
    clearTimeout(timer);
    timer = setTimeout(() => { button.textContent = label; }, 2600);
  });
  return button;
}

function sourceTrail(receipt, fetchedAt) {
  const trail = el('div', 'pf-rc-src');
  trail.append(el('h4', null, 'Source trail'), factList([
    ['Schema', receipt.trail.schemaId, true],
    ['Record', `${receipt.trail.recordUrl} (listed in ${receipt.trail.indexUrl})`, true],
    ['Release context', receipt.trail.registryUrl, true],
    ['Release authority', receipt.trail.authorityModelSha256 ? `${receipt.trail.authority} (model SHA-256 ${receipt.trail.authorityModelSha256})` : receipt.trail.authority, true],
    ['Website commit', receipt.trail.commit, true],
    ['Source tree', receipt.trail.tree, true],
    ['Committed', receipt.trail.committedAt, true],
    ['Fetched', timeOf(fetchedAt)],
    ['Checked here', `Validated in this browser against ${receipt.trail.schemaUrl}; the index, record and proof registry were fetched together and agree.`],
  ]), el('p', null, 'The linked release record is authoritative.'));
  return trail;
}

function renderReceipt(panel, receipt, { announce, fetchedAt }) {
  const doc = document.createDocumentFragment();
  const v = (version) => (version ? `v${version}` : null);

  const top = el('div', 'pf-rc-top');
  const heading = el('div');
  heading.append(el('h3', null, receipt.name), el('p', null, [v(receipt.version), receipt.platforms.join(' + ')].filter(Boolean).join(' · ')));
  const state = receipt.checks.find((c) => c.dimension === 'PUBLICATION_STATUS');
  top.append(heading, el('span', CHIP[state.tone], [receipt.release.status, receipt.release.publishedAt].filter(Boolean).join(' · ')));
  doc.append(top);

  const receiptId = receipt.receiptId ? el('span', null, receipt.receiptId) : null;
  if (receiptId && receipt.receiptUrl) receiptId.append(document.createTextNode(' '), link(receipt.receiptUrl, 'receipt file', { external: true }));
  const facts = factList([
    ['Public version', v(receipt.release.publicVersion)],
    ['Candidate version', v(receipt.release.candidateVersion)],
    ['Companion', receipt.release.companionPublicVersion ? `${v(receipt.release.companionPublicVersion)} (${receipt.companionOffered ? 'public' : 'recorded; not offered here'})` : 'None recorded'],
    ['Companion candidate', v(receipt.release.companionCandidateVersion)],
    ['Platform', receipt.platforms.join(' + ')],
    ['Published', receipt.release.publishedAt],
    [receipt.verifiedLabel, receipt.verifiedAt],
    ['Last checked', receipt.checkedAt],
    ['Product source commit', receipt.release.sourceCommit, true],
    ['Receipt ID', receiptId, true],
  ]);
  const chips = el('ul', 'pf-chips');
  for (const check of receipt.checks) {
    const li = el('li');
    li.append(el('span', null, check.label), el('span', CHIP[check.tone], check.value));
    chips.append(li);
  }
  const grid = el('div', 'pf-rc-grid');
  grid.append(block('Release', facts), block('Verification, as recorded', chips));
  doc.append(grid);

  const artifacts = block('Artifacts and published SHA-256');
  if (receipt.offerCount) {
    const { here, more } = receipt.offerCount;
    artifacts.append(el('p', 'pf-rc-caveat', `${here} ${here === 1 ? 'file' : 'files'} offered here · ${more} more recorded in the release record`));
  }
  for (const artifact of receipt.artifacts) {
    const card = el('div', 'pf-art');
    const head = el('div', 'pf-art-h');
    head.append(el('b', null, artifact.filename));
    if (artifact.distType) head.append(el('span', 'pf-chip neutral', artifact.distType));
    if (artifact.signingStatus) head.append(el('span', artifact.signingStatus === 'PRODUCTION_SIGNED' ? 'pf-chip ok' : 'pf-chip neutral', artifact.signingStatus.replace(/_/g, ' ')));
    if (receipt.offerCount) head.append(el('span', artifact.offered ? 'pf-chip ok' : 'pf-chip neutral', `Offered here: ${artifact.offered ? 'yes' : 'no'}`));
    card.append(head);
    const meta = [artifact.platform, Number.isInteger(artifact.sizeBytes) ? `${artifact.sizeBytes.toLocaleString('en-US')} bytes` : null].filter(Boolean).join(' · ');
    if (meta) card.append(el('p', 'pf-art-meta', meta));
    const row = el('p', 'pf-art-row');
    if (!artifact.sha256) row.append(el('span', null, 'No published SHA-256 for this file.'));
    else row.append(el('span', 'ledger-sr', `Published SHA-256 for ${artifact.filename}: `), el('code', null, artifact.sha256), copyButton('Copy SHA-256', artifact.sha256, `Copy SHA-256 for ${artifact.filename}`, announce));
    card.append(row);
    artifacts.append(card);
  }
  if (!receipt.artifacts.length) artifacts.append(el('p', 'pf-rc-caveat', 'This record lists no artifacts.'));
  doc.append(artifacts);

  if (receipt.command) {
    const command = el('div', 'pf-rc-cmd');
    command.append(el('code', null, receipt.command), copyButton('Copy command', receipt.command, `Copy the PowerShell command for ${receipt.commandFile}`, announce));
    doc.append(block('Verify your download (Windows PowerShell)', command,
      el('p', 'pf-rc-caveat', 'Compare the result with the published SHA-256 above; if they do not match exactly, do not run the file. A SHA-256 digest establishes file identity. It does not independently prove software safety, authenticated publisher identity, or freedom from malware.')));
  }

  const tests = el('dl', 'pf-rc-tests');
  for (const t of receipt.tests) {
    const row = el('div');
    row.append(el('dt', null, t.label), el('dd', null, t.result));
    tests.append(row);
  }
  const evidence = el('div', 'pf-rc-ev');
  for (const item of receipt.evidence) evidence.append(item.href ? link(item.href, item.label, { external: /^https:/.test(item.href) }) : el('span', null, item.label));
  const noEvidence = el('p', 'pf-rc-none');
  noEvidence.append(el('span', 'pf-chip none', 'Not listed yet'));
  const proof = el('div', 'pf-rc-grid');
  proof.append(
    block('Qualification evidence', receipt.tests.length ? tests : el('p', null, 'No test results are listed on this record.')),
    block('Evidence links', receipt.evidence.length ? evidence : noEvidence),
  );
  doc.append(proof);

  const limits = el('ul', 'pf-rc-list');
  for (const limit of receipt.limits) limits.append(el('li', null, limit));
  doc.append(block(`Known limitations (${receipt.limits.length})`, receipt.limits.length ? limits : el('p', null, 'No limitations are listed for this release.')));

  const links = el('div', 'pf-rc-links');
  links.append(link(receipt.links.record, 'Full release record', { withArrow: true }), link(receipt.links.truthFile, 'Truth File', { withArrow: true }));
  if (receipt.links.page) links.append(link(receipt.links.page, `${receipt.name} product page`, { withArrow: true }));
  doc.append(links);

  doc.append(sourceTrail(receipt, fetchedAt));
  panel.replaceChildren(doc);
}

// The records agree that this release is withdrawn: say so, and offer no
// download, digest or command.
function renderWithdrawn(panel, receipt, fetchedAt) {
  const doc = document.createDocumentFragment();
  const top = el('div', 'pf-rc-top');
  const heading = el('div');
  heading.append(el('h3', null, receipt.name), el('p', null, receipt.withdrawnVersion ? `v${receipt.withdrawnVersion} withdrawn` : 'Withdrawn'));
  top.append(heading, el('span', 'pf-chip none', 'WITHDRAWN'));
  doc.append(top, block('Release', factList([
    ['Status', receipt.status],
    ['Withdrawn version', receipt.withdrawnVersion ? `v${receipt.withdrawnVersion}` : null],
    ['Reason', receipt.withdrawalReason],
    ['First published', receipt.publishedAt],
    ['Public download', 'None. The release is withdrawn.'],
  ])));
  const limits = el('ul', 'pf-rc-list');
  for (const limit of receipt.limits) limits.append(el('li', null, limit));
  if (receipt.limits.length) doc.append(block(`Known limitations (${receipt.limits.length})`, limits));
  const links = el('div', 'pf-rc-links');
  links.append(link(receipt.links.record, 'Full release record', { withArrow: true }), link(receipt.links.truthFile, 'Truth File', { withArrow: true }));
  doc.append(links, sourceTrail(receipt, fetchedAt));
  panel.replaceChildren(doc);
}

const showValue = (value) => (value === null || value === undefined ? 'not stated' : typeof value === 'object' ? JSON.stringify(value) : String(value));

function renderFailure(panel, id, name, result, fetchedAt, retry) {
  const wrap = el('div', 'pf-rc-fail');
  const disagree = result.reason === 'disagreement';
  wrap.append(el('span', 'pf-chip none', disagree ? 'Sources disagree' : 'Record not shown'),
    el('h3', null, disagree ? `${name || 'This product'}: the published records disagree.` : `${name || 'This product'}: the public record could not be verified here.`));
  if (disagree) {
    // Each conflicting field, as each record states it. Nothing is combined.
    const table = el('table', 'pf-rc-conflicts');
    const head = el('tr');
    head.append(el('th', null, 'Field'), el('th', null, 'Stated by'), el('th', null, 'Value'));
    const thead = el('thead');
    thead.append(head);
    const body = el('tbody');
    for (const conflict of result.conflicts) {
      conflict.values.forEach((entry, i) => {
        const row = el('tr');
        if (i === 0) { const th = el('th', null, conflict.field); th.scope = 'row'; th.rowSpan = conflict.values.length; row.append(th); }
        row.append(el('td', 'pf-mono', entry.source), el('td', 'pf-mono', showValue(entry.value)));
        body.append(row);
      });
    }
    table.append(el('caption', 'ledger-sr', 'Conflicting fields between the published records'), thead, body);
    wrap.append(el('p', null, 'These records were generated for this site but state different facts, so none of them is shown as the receipt. Values below are listed only to show the conflict; do not use them to verify a download.'), table);
  } else wrap.append(el('p', null, result.detail || 'The public record could not be loaded.'));
  wrap.append(el('p', null, 'Nothing from this record is displayed as a receipt. The release record and its machine-readable sources remain available:'));
  const links = el('div', 'pf-rc-links');
  links.append(link(`/proof/#receipt-${id}`, 'Full release record', { withArrow: true }), link(`/truth-files/${id}/`, 'Truth File', { withArrow: true }), link(truthRecordUrl(id), 'Raw JSON record', { withArrow: true }));
  wrap.append(links);
  const checked = el('p', 'pf-rc-when', 'Checked ');
  checked.append(timeOf(fetchedAt), '. Try again fetches every record afresh.');
  const again = el('button', 'pf-copy', 'Try again');
  again.type = 'button';
  again.addEventListener('click', retry);
  wrap.append(checked, again);
  panel.replaceChildren(wrap);
}

function initReceipts(dialog, triggers) {
  const panel = dialog.querySelector('[data-receipt-panel]');
  const tabsHost = dialog.querySelector('[data-receipt-tabs]');
  const title = dialog.querySelector('#pf-receipt-title');
  const status = dialog.querySelector('[data-receipt-status]');
  const ids = [...new Set(triggers.map((t) => t.dataset.receiptOpen))];
  let tabs = [];
  let current = null;
  let generation = 0;
  const announce = (text) => { status.textContent = ''; requestAnimationFrame(() => { status.textContent = text; }); };

  // Tab labels come from the schema and index of the snapshot just loaded, so
  // they follow the same build as the receipt; labelling never fetches. Returns
  // the snapshot's validated entries, the only source of product names here.
  function labelTabs(snapshot) {
    if (ids.length < 2 || !snapshot.schema || !snapshot.index) return null;
    let entries = null;
    try { entries = indexEntries(snapshot.schema, snapshot.index, ids); } catch { entries = null; }
    if (!entries || entries.length !== ids.length) return null;
    if (tabs.length) {
      for (const entry of entries) tabs.find((tab) => tab.dataset.receiptTab === entry.id)?.replaceChildren(document.createTextNode(entry.name), el('span', 'v', entry.version ? ` v${entry.version}` : ''));
      return entries;
    }
    tabsHost.setAttribute('role', 'tablist');
    tabs = entries.map((entry) => {
      const tab = el('button');
      tab.type = 'button';
      tab.id = `pf-receipt-tab-${entry.id}`;
      tab.dataset.receiptTab = entry.id;
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-controls', panel.id);
      tab.append(document.createTextNode(entry.name), el('span', 'v', entry.version ? ` v${entry.version}` : ''));
      tab.addEventListener('click', () => show(entry.id));
      tab.addEventListener('keydown', (event) => {
        const i = ids.indexOf(entry.id);
        const next = { ArrowRight: (i + 1) % ids.length, ArrowLeft: (i + ids.length - 1) % ids.length, Home: 0, End: ids.length - 1 }[event.key];
        if (next === undefined) return;
        event.preventDefault();
        tabs[next].focus();
        show(ids[next]);
      });
      tabsHost.append(tab);
      return tab;
    });
    panel.setAttribute('role', 'tabpanel');
    syncTabs();
    return entries;
  }

  function syncTabs() {
    tabs.forEach((tab) => {
      const on = tab.dataset.receiptTab === current;
      tab.setAttribute('aria-selected', String(on));
      tab.tabIndex = on ? 0 : -1;
    });
    if (tabs.length) panel.setAttribute('aria-labelledby', `pf-receipt-tab-${current}`);
  }

  panel.tabIndex = -1;
  const retry = () => { panel.focus(); show(current); };

  async function show(id) {
    const ticket = ++generation;
    current = id;
    syncTabs();
    panel.setAttribute('aria-busy', 'true');
    title.textContent = 'Loading the public record';
    panel.replaceChildren(el('p', 'pf-rc-loading', `Loading ${truthRecordUrl(id)} and ${PROOF_REGISTRY_URL}, and validating them against ${TRUTH_SCHEMA_URL}.`));
    const snapshot = await loadSnapshot(id);
    if (ticket !== generation) return;
    // Before rendering, so a refusal can name the product from this snapshot's
    // validated index (never from an earlier one).
    const entries = labelTabs(snapshot);
    panel.removeAttribute('aria-busy');
    const { result, fetchedAt } = snapshot;
    const name = result.ok ? result.receipt.name : entries?.find((entry) => entry.id === id)?.name;
    if (result.ok && result.receipt.withdrawn) {
      const r = result.receipt;
      title.textContent = `${r.name} — withdrawn release record`;
      renderWithdrawn(panel, r, fetchedAt);
      announce(`${r.name}: the records agree this release is withdrawn. No download is offered.`);
    } else if (result.ok) {
      const r = result.receipt;
      title.textContent = `${r.name} v${r.version} — public release record`;
      renderReceipt(panel, r, { announce, fetchedAt });
      announce(`${r.name} v${r.version}: record loaded and validated.`);
    } else if (result.reason === 'disagreement') {
      title.textContent = 'Release records disagree';
      renderFailure(panel, id, name, result, fetchedAt, retry);
      announce(`${name || 'The'} records disagree, so no receipt is shown.`);
    } else {
      title.textContent = 'Release record not shown';
      renderFailure(panel, id, name, result, fetchedAt, retry);
      announce(`${name || 'The'} record could not be verified, so nothing from it is shown.`);
    }
  }

  triggers.forEach((trigger) => {
    trigger.hidden = false;
    trigger.addEventListener('click', () => {
      openDialog(dialog, trigger);
      show(trigger.dataset.receiptOpen);
    });
  });
}

// ── Decorative images that fail ──────────────────────────────────────────────
// A decorative image (alt="") that cannot be fetched or decoded is taken out of
// the layout, so the browser draws no broken-image frame, and the part that only
// exists to hold it (the hero emblem, the proof chain artwork, the doctrine seal)
// is marked so the CSS lays it out without the picture. The proof chain's
// numbered list stays in place. Images with alt text keep the browser's
// alt-text fallback. Without this script a failed image keeps its frame, but
// every word on the page is still HTML text.
const ART_HOSTS = '.ledger-hero-grid, .ledger-chain-machine, .ledger-seal';
const decorative = (node) => node instanceof HTMLImageElement && node.getAttribute('alt') === '' && !node.closest('dialog');
function artFailed(img) {
  if (img.dataset.pfImg === 'failed') return;
  img.dataset.pfImg = 'failed';
  img.closest(ART_HOSTS)?.setAttribute('data-art-failed', '');
}
// Errors do not bubble; capture catches later failures (lazy images included).
document.addEventListener('error', (event) => { if (decorative(event.target)) artFailed(event.target); }, true);
// Failures that happened before this module ran.
for (const img of document.images) if (decorative(img) && img.complete && img.currentSrc && img.naturalWidth === 0) artFailed(img);

// ── start ────────────────────────────────────────────────────────────────────
for (const dialog of document.querySelectorAll('dialog.pf-dialog')) wireDialog(dialog);

const markDialog = document.getElementById('pf-mark-dialog');
if (markDialog) {
  initMark(markDialog);
  document.querySelectorAll('[data-mark-open]').forEach((trigger) => {
    trigger.hidden = false;
    trigger.addEventListener('click', () => openDialog(markDialog, trigger));
  });
}

const receiptDialog = document.getElementById('pf-receipt-dialog');
const receiptTriggers = [...document.querySelectorAll('[data-receipt-open]')];
if (receiptDialog && receiptTriggers.length) initReceipts(receiptDialog, receiptTriggers);

document.querySelectorAll('[data-living-metal]').forEach(initLivingMetal);
document.querySelectorAll('.ledger-feature-media').forEach(initGlass);
