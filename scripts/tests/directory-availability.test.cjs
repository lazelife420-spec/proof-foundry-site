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
