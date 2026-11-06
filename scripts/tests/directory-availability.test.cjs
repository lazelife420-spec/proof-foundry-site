'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { renderDirectory } = require('../../vendor/pf-portfolio-review/index.cjs');
const root = path.resolve(__dirname, '../..');
const read = name => JSON.parse(fs.readFileSync(path.join(root, name)));
const editorial = read('site-editorial.json');
const model = read('portfolio-review.json');
const truth = read('release-truth.json');
const manifest = read('site-manifest.json');
const context = {
  identities: model.products.map(p => p.id),
  routes: new Set(editorial.entries.map(e => e.destination).filter(Boolean)),
  assets: new Set(editorial.entries.map(e => e.artwork).filter(Boolean))
};
test('recorded companion without a downloadable artifact is explicitly unoffered', () => {
  const html = renderDirectory(editorial, model, truth, manifest, context).html;
  const entry = id => new RegExp('<article\\b[^>]*data-directory-entry="' + id + '"[\\s\\S]*?</article>').exec(html)?.[0];
  assert.match(entry('lights-out'), /Android · v11\.1\.1 · not offered here/);
  assert.match(entry('cache-vault'), /Android · v0\.3\.1/);
  assert.doesNotMatch(entry('cache-vault'), /not offered here/);
});
// Owner decision 2026-11-05: each card says whether it has a public download, from the release record only.
const cardOf = (html, id) => new RegExp('<article\\b[^>]*data-directory-entry="' + id + '"[\\s\\S]*?</article>').exec(html)?.[0];
const badgeOf = card => /class="directory-availability directory-availability--(public|none)">([^<]+)</.exec(card || '')?.slice(1, 3);
// A public download is a public release with a verified public artifact: a download URL and a published SHA-256.
const verified = a => !!a.downloadUrl && /^[0-9a-f]{64}$/i.test(String(a.sha256 || ''));
const hasPublicDownload = (truthDoc, id) => (truthDoc.products.find(p => p.id === id)?.channels || [])
  .some(c => c.track === 'PUBLIC' && c.publicationState === 'PUBLIC_RELEASE' && c.artifacts.some(verified));
const noteOf = (html, group) => new RegExp('data-directory-group-note="' + group + '">None of these has a public installer\\.<').test(html);
test('availability follows the release record, and a group with no public download says so once instead of on every card', () => {
  const html = renderDirectory(editorial, model, truth, manifest, context).html;
  const visible = editorial.entries.filter(e => e.visible);
  assert.ok(visible.length > 0);
  for (const g of [...new Set(visible.map(e => e.group))]) {
    const members = visible.filter(e => e.group === g), none = members.every(e => !hasPublicDownload(truth, e.id));
    assert.equal(noteOf(html, g), none, g);
    for (const e of members) {
      const card = cardOf(html, e.id), pub = hasPublicDownload(truth, e.id);
      assert.match(card, new RegExp('data-availability="' + (pub ? 'download' : 'none') + '"'), e.id);
      assert.deepEqual(badgeOf(card), pub ? ['public', 'Public download'] : (none ? undefined : ['none', 'No public installer']), e.id);
    }
  }
  // Today: five public downloads; the four Foundry systems share one note, and Reality Gate is among them.
  assert.equal((html.match(/directory-availability--public">Public download</g) || []).length, 5);
  assert.ok(noteOf(html, 'Foundry systems'));
  assert.equal(badgeOf(cardOf(html, 'reality-gate')), undefined);
});
test('a release without a download URL, or a withdrawn channel, gives "No public installer"', () => {
  const mutated = structuredClone(truth);
  for (const c of mutated.products.find(p => p.id === 'cache-vault').channels) for (const a of c.artifacts) delete a.downloadUrl;
  for (const c of mutated.products.find(p => p.id === 'lights-out').channels) c.track = 'WITHDRAWN';
  for (const c of mutated.products.find(p => p.id === 'ghostlayer').channels) for (const a of c.artifacts) delete a.sha256;
  const html = renderDirectory(editorial, model, mutated, manifest, context).html;
  assert.deepEqual(badgeOf(cardOf(html, 'ghostlayer')), ['none', 'No public installer']);
  assert.match(cardOf(html, 'ghostlayer'), /data-availability="none"/);
  assert.deepEqual(badgeOf(cardOf(html, 'cache-vault')), ['none', 'No public installer']);
  assert.deepEqual(badgeOf(cardOf(html, 'lights-out')), ['none', 'No public installer']);
  assert.deepEqual(badgeOf(cardOf(html, 'cleanroom')), ['public', 'Public download']);
});
test('each card names the platforms with a public download, from the release record only', () => {
  const html = renderDirectory(editorial, model, truth, manifest, context).html;
  for (const e of editorial.entries.filter(x => x.visible)) {
    const card = cardOf(html, e.id);
    const expected = [...new Set((truth.products.find(p => p.id === e.id)?.channels || [])
      .filter(c => c.track === 'PUBLIC' && c.publicationState === 'PUBLIC_RELEASE' && c.artifacts.some(verified))
      .map(c => String(c.platform).toLowerCase()))].join(' ');
    const got = /data-download-platforms="([^"]*)"/.exec(card)?.[1] ?? '';
    assert.equal(got, expected, e.id);
  }
  // Lights Out has a Windows download only (its Android build is not offered here).
  assert.equal(/data-download-platforms="([^"]*)"/.exec(cardOf(html, 'lights-out'))?.[1], 'windows');
  // The platform data is groundwork for later Windows and Android filters (owner, 2026-11-06); the finder does not use it yet.
});
// Owner decision 2026-11-05: no hard-coded product count; "N shown" only while a filter is active.
test('the finder searches the availability badge and states no product count at rest', () => {
  const js = fs.readFileSync(path.join(root, 'foundry-navigation.js'), 'utf8');
  const selector = /querySelectorAll\('([^']*\.directory-purpose[^']*)'\)/.exec(js)?.[1];
  assert.ok(selector, 'finder search selector');
  for (const part of ['h3', '.directory-availability', '.directory-purpose', '.directory-state', '.directory-state-note']) assert.ok(selector.split(',').includes(part), part);
  assert.match(js, /textContent=filtering\?count\+' shown':/);
  assert.match(js, /'All shown'/);
  assert.doesNotMatch(js, /'products?'|' products'/);
  assert.match(js, /dataset\.availability/);
  const page = fs.readFileSync(path.join(root, 'software.html'), 'utf8');
  // The availability filter offers exactly the owner's three choices.
  assert.match(page, /<select name="availability"[^>]*><option value="">All products<\/option><option value="download">Available downloads<\/option><option value="none">No public installer<\/option><\/select>/);
  assert.match(page, /<p data-directory-count role="status" aria-live="polite"><\/p>/);
  assert.doesNotMatch(page, /\b\d+ products\b/i);
  // The count is a live region: it stays rendered (in the accessibility tree) even when empty.
  const css = fs.readFileSync(path.join(root, 'h9-software.css'), 'utf8');
  assert.doesNotMatch(css, /\[data-directory-count\][^{]*\{[^}]*display:\s*none/);
});

// Visual verdict on 9fbdf92 (2026-11-06): in a group where not every card has a page, the pages that exist are offered as
// plain links, so the cards without one read as complete informational listings rather than cards missing a button.
test('a group where not every card has a page offers its pages as plain links, not buttons', () => {
  const html = renderDirectory(editorial, model, truth, manifest, context).html;
  const visible = editorial.entries.filter(e => e.visible);
  const escape = s => s.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
  for (const g of [...new Set(visible.map(e => e.group))]) {
    const members = visible.filter(e => e.group === g), allLinked = members.every(e => e.destination);
    for (const e of members) {
      const card = cardOf(html, e.id);
      if (!e.destination) { assert.doesNotMatch(card, /<a\b/, e.id); continue; }
      assert.match(card, new RegExp('<a class="' + (allLinked ? 'button button-secondary' : 'text-link directory-link') + '" href="' + escape(e.destination) + '">'), e.id);
    }
  }
  // Today: Reality Gate's page is a plain link and the five everyday products keep their buttons.
  assert.match(cardOf(html, 'reality-gate'), /<a class="text-link directory-link" href="\/reality-gate\/">Explore Reality Gate /);
  assert.equal((html.match(/<a class="button button-secondary"/g) || []).length, 5);
  // Were every Foundry system to have a page, the group would offer buttons again.
  const linked = JSON.parse(JSON.stringify(editorial));
  for (const e of linked.entries) if (e.visible && e.group === 'Foundry systems' && !e.destination) e.destination = '/reality-gate/';
  assert.match(cardOf(renderDirectory(linked, model, truth, manifest, context).html, 'crosspoint'), /<a class="button button-secondary" href="\/reality-gate\/">/);
});
