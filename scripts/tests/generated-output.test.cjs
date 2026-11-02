'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const verify = output => spawnSync(process.execPath, [
  path.join(root, 'scripts/portfolio-review.cjs'), '--verify-generated', output
], { encoding: 'utf8' });

test('the normal public/ build can verify its generated directory', () => {
  const result = verify(path.join(root, 'public'));
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Editorial generated targets verified:/);
});

for (const target of ['.', 'products', 'assets', 'public/nested', 'public-sibling']) {
  test(`generated verification refuses authored-source target ${target}`, () => {
    const result = verify(path.resolve(root, target));
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Generated verification requires public\/ or an external output/);
  });
}
