'use strict';
// PROPOSED ADDITIVE SUITE. NOT RUN in CP-0175. No protected tests are replaced.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { validateReview, projectReview, renderReview } = require('../../vendor/pf-portfolio-review/index.cjs');
const original = JSON.parse(fs.readFileSync(path.join(__dirname, '../../portfolio-review.json'), 'utf8'));
const clone = () => JSON.parse(JSON.stringify(original));
const product = (m, id) => m.products.find(p => p.id === id);
test('all 11 distinct identities and 17 channel observations remain review-only for all consumers', () => {
  for (const consumer of ['website-review', 'store-review', 'portal-review', 'rg-review']) {
    const p = projectReview(clone(), consumer);
    assert.equal(p.products.length, 11);
    assert.equal(p.products.flatMap(x => x.channels).length, 17);
    assert.equal(p.installationAuthority, 'NONE');
    assert.equal(p.publicationAuthority, 'NONE');
    assert.deepEqual(p.products.filter(x => x.recordRoute).map(x => x.id).sort(),
      ['cache-vault','cleanroom','forgecast','ghostlayer','lights-out','proofshot','reality-gate'].sort());
    for (const c of p.products.flatMap(x => x.channels)) {
      assert.equal(c.downloadUrl, null); assert.equal(c.installAllowed, false);
      assert.equal(c.signingAllowed, false); assert.equal(c.publicationApproved, false);
    }
  }
});
test('projection is deterministic and leaves the input unchanged', () => {
  const m = clone(), before = JSON.stringify(m);
  assert.deepEqual(projectReview(m, 'website-review'), projectReview(m, 'website-review'));
  assert.equal(JSON.stringify(m), before);
});
const mutations = [
  ['activation', m => { m.activation = 'APPROVED'; }],
  ['review flag', m => { m.reviewOnly = false; }],
  ['schema', m => { m.schema = 'proof-foundry-release-truth/v2'; }],
  ['register pin', m => { m.registerSha256 = '0'.repeat(64); }],
  ['App reference', m => { m.appReferenceCommit = '0'.repeat(40); }],
  ['missing identity', m => { m.products.pop(); }],
  ['duplicate identity', m => { m.products[1].id = m.products[0].id; }],
  ['merged infrastructure', m => { product(m, 'crosspoint').id = 'hardline-zero'; }],
  ['extra channel', m => { m.products[0].channels.push(JSON.parse(JSON.stringify(m.products[0].channels[0]))); }],
  ['missing channel', m => { m.products[0].channels.pop(); }],
  ['unknown availability', m => { m.products[0].channels[0].availability = 'VERIFIED'; }],
  ['installer URL injection', m => { m.products[0].channels[0].downloadUrl = 'https://example.invalid/app.exe'; }],
  ['command injection field', m => { m.products[0].channels[0].command = 'run'; }],
  ['publication boolean', m => { m.products[0].channels[0].publicationApproved = true; }],
  ['unknown evidence', m => { m.products[0].channels[0].evidenceIds.push('INVENTED'); }],
  ['missing evidence', m => { m.products[0].channels[0].evidenceIds = []; }],
  ['invalid digest', m => { m.products[0].channels[0].artifacts[0].sha256 = 'abc'; }],
  ['runtime-hash claim', m => { m.products[0].channels[0].artifacts[0].hashProvenance = 'BINARY_VERIFIED'; }],
  ['artifact path', m => { m.products[0].channels[0].artifacts[0].filename = '../app.exe'; }],
  ['ProofShot feature', m => { product(m, 'proofshot').featured = 'UNDECIDED'; }],
  ['ProofShot licensing erased', m => { product(m, 'proofshot').holds = ['A27_MEDIA_HOLD','UNFEATURED_POLICY_ONLY']; }],
  ['ProofShot A27 erased', m => { product(m, 'proofshot').holds = ['LICENSING_AUTHORITY_HOLD','UNFEATURED_POLICY_ONLY']; }],
  ['Cleanroom conflict erased', m => { product(m, 'cleanroom').holds = []; }],
  ['Cleanroom auto-promotion', m => { product(m, 'cleanroom').channels[0].version = '1.0.10'; }],
  ['RG public reinstatement', m => { product(m, 'reality-gate').channels[0].availability = 'PUBLISHED_METADATA_ONLY_NO_BINARY_FETCH'; }],
  ['RG installed guess', m => { product(m, 'reality-gate').channels[1].version = '1.1.1'; }],
  ['Hardline public promotion', m => { product(m, 'hardline-zero').channels[0].availability = 'PUBLISHED_METADATA_ONLY_NO_BINARY_FETCH'; }],
  ['CrossPoint public promotion', m => { product(m, 'crosspoint').channels[0].availability = 'PUBLISHED_METADATA_ONLY_NO_BINARY_FETCH'; }],
  ['App public promotion', m => { product(m, 'proof-foundry-app').channels[0].availability = 'PUBLISHED_METADATA_ONLY_NO_BINARY_FETCH'; }],
  ['Sound Assist hold erased', m => { product(m, 'sound-assist').holds = []; }],
  ['unrecognized hold', m => { m.products[0].holds.push('FAKE_PASS'); }],
  ['invalid observation', m => { m.products[0].channels[0].observedAt = 'now'; }]
];
for (const [label, mutate] of mutations) test('reject: ' + label, () => {
  const m = clone(); mutate(m); assert.throws(() => validateReview(m));
});
test('rendered text is escaped and no new download or execution target is emitted', () => {
  const m = clone(); m.products[0].name = '<img src=x onerror=alert(1)>';
  const html = renderReview(m).software;
  assert.ok(html.includes('&lt;img')); assert.ok(!html.includes('<img src=x'));
  assert.ok(!/href=["'](?:https?:|javascript:|file:|pf:)/i.test(html));
  assert.ok(!/\bdownload(?:\s|=|>)/i.test(html));
});
test('signed catalog, platform projection and unknown consumer requests are refused', () => {
  for (const consumer of ['windows','android','website','signed-catalog','install','unknown']) {
    assert.throws(() => projectReview(clone(), consumer));
  }
});

test('research inventory does not automatically become a public lineup', () => {
  const slots = renderReview(clone());
  assert.equal(projectReview(clone(),'website-review').products.length,11);
  assert.ok(!slots.software.includes('id="portfolio-sound-assist"'));
  assert.ok(!slots.softwareRecords.includes('id="portfolio-sound-assist"'));
  assert.ok(!slots.home.includes('11 identities'));
  assert.deepEqual(slots.unfeaturedIds,['proofshot']);
});
test('named infrastructure has useful working destinations and separate roles', () => {
  const slots=renderReview(clone());
  for (const id of ['hardline-zero','crosspoint']) {
    assert.ok(slots.home.includes('href="/software/#portfolio-'+id+'"'));
    assert.ok(slots.software.includes('id="portfolio-'+id+'"'));
  }
  assert.ok(slots.software.includes('Work governance'));
  assert.ok(slots.software.includes('Agent coordination'));
  assert.ok(slots.software.includes('Internal development continues. Public v1.1.0 is withdrawn'));
});
test('ProofShot remains historical without a homepage promotional claim', () => {
  const slots=renderReview(clone());
  assert.ok(!slots.home.includes('ProofShot'));
  assert.ok(slots.homeHistory.includes('Preserved history'));
  assert.ok(slots.softwareRecords.includes('ProofShot · historical record'));
  assert.ok(slots.softwareRecords.includes('href="/proofshot/"'));
  assert.ok(!slots.home.includes('Sound Assist'));
});


// Additive main-site directory regressions. The 39 preceding tests are preserved byte-for-byte.
const { validateEditorial, renderDirectory } = require('../../vendor/pf-portfolio-review/index.cjs');
const directoryRoot=path.join(__dirname,'../..');
const editorial=JSON.parse(fs.readFileSync(path.join(directoryRoot,'site-editorial.json')));
const authority=JSON.parse(fs.readFileSync(path.join(directoryRoot,'release-truth.json')));
const site=JSON.parse(fs.readFileSync(path.join(directoryRoot,'site-manifest.json')));
const directoryContext={
  identities:original.products.map(p=>p.id),
  routes:new Set(['/',...site.products.map(p=>p.route),...['hardline-zero','crosspoint','reality-gate','proof-foundry-app'].map(id=>'/software/#portfolio-'+id)]),
  assets:new Set(editorial.entries.map(e=>e.artwork).filter(Boolean))
};
const copyDirectory=()=>structuredClone(editorial);
const renderDirectoryFixture=input=>renderDirectory(input,original,authority,site,directoryContext);
test('directory accepts empty, one and arbitrary known subsets without a fixed product quota',()=>{
 for(const n of [0,1,3,8]) {
  const input=copyDirectory();input.entries=input.entries.filter(e=>e.visible).slice(0,n);
  const output=renderDirectoryFixture(input);assert.equal(output.count,n);
  assert.equal((output.html.match(/data-directory-entry=/g)||[]).length,n);
 }
});
test('listing visibility, ordering and tie-break are deterministic without mutating release inputs',()=>{
 const input=copyDirectory(),facts=JSON.stringify(authority),model=JSON.stringify(original);
 const visible=input.entries.filter(e=>e.visible);visible.forEach((e,i)=>e.order=-i);
 input.entries=visible;
 const expected=[...visible].reverse().map(e=>e.id);
 assert.deepEqual(renderDirectoryFixture(input).selectedIds,expected);
 input.entries[0].visible=false;
 assert.equal(renderDirectoryFixture(input).count,visible.length-1);
 input.entries.forEach(e=>e.order=1);
 assert.deepEqual(renderDirectoryFixture(input).selectedIds,visible.filter(e=>e.visible).map(e=>e.id).sort());
 assert.equal(JSON.stringify(authority),facts);assert.equal(JSON.stringify(original),model);
});
test('explicit absent artwork and destination render without broken images or a dead anchor',()=>{
 const input=copyDirectory();input.entries=[{...input.entries[0],artwork:null,destination:null}];
 const output=renderDirectoryFixture(input);
 assert.equal(output.count,1);assert.doesNotMatch(output.html,/<img\b|<a\b/);
 assert.match(output.html,/Product page not yet available/);
});
test('editorial text is escaped while versions come only from release authority',()=>{
 const input=copyDirectory();input.entries=[input.entries[0]];
 input.entries[0].shortDescription='<script>alert(1)</script>';
 const output=renderDirectoryFixture(input);
 assert.match(output.html,/&lt;script&gt;/);assert.doesNotMatch(output.html,/<script>/);
 const expected=authority.products.find(p=>p.id===input.entries[0].id).channels.find(c=>c.track==='PUBLIC'&&c.publicationState==='PUBLIC_RELEASE');
 assert.match(output.html,new RegExp('v'+expected.version.replaceAll('.','\\.')));
});
test('ProofShot and Sound Assist stay out of discovery without deleting the underlying identity records',()=>{
 const output=renderDirectoryFixture(copyDirectory());
 assert.ok(!output.selectedIds.includes('proofshot')&&!output.selectedIds.includes('sound-assist'));
 assert.equal(original.products.length,11);
 assert.ok(site.products.some(p=>p.id==='proofshot'));
});
const editorialNegatives=[
 ['unknown identity',e=>e.entries[0].id='invented'],
 ['duplicate identity',e=>e.entries.push({...e.entries[0]})],
 ['unapproved version',e=>e.entries[0].version='100.0.0'],
 ['unapproved status',e=>e.entries[0].status='RELEASED'],
 ['unapproved hash',e=>e.entries[0].sha256='0'.repeat(64)],
 ['unapproved signing',e=>e.entries[0].signingAllowed=true],
 ['download authority',e=>e.entries[0].downloadUrl='https://example.invalid/file'],
 ['executable scheme',e=>e.entries[0].destination='javascript:alert(1)'],
 ['external destination',e=>e.entries[0].destination='https://example.invalid'],
 ['protocol-relative destination',e=>e.entries[0].destination='//example.invalid/'],
 ['parent traversal',e=>e.entries[0].destination='/../secret/'],
 ['encoded destination',e=>e.entries[0].destination='/%2e%2e/private/'],
 ['missing route',e=>e.entries[0].destination='/not-a-built-page/'],
 ['missing fragment',e=>e.entries[0].destination='/software/#not-a-section'],
 ['missing artwork',e=>e.entries[0].artwork='/assets/missing.png'],
 ['unsafe artwork',e=>e.entries[0].artwork='data:image/svg+xml,invalid'],
 ['wrong visibility type',e=>e.entries[0].visible='yes'],
 ['infinite order',e=>e.entries[0].order=Infinity],
 ['empty group',e=>e.entries[0].group=''],
 ['long description',e=>e.entries[0].shortDescription='x'.repeat(281)],
 ['unknown root field',e=>e.publicationApproved=true],
 ['ProofShot promotion',e=>e.entries.find(x=>x.id==='proofshot').visible=true],
 ['Sound Assist promotion',e=>e.entries.find(x=>x.id==='sound-assist').visible=true]
];
for (const [name,mutate] of editorialNegatives) test('editorial rejects '+name,()=>{
 const input=copyDirectory();mutate(input);assert.throws(()=>validateEditorial(input,directoryContext));
});
test('main-site sources and protected release facts are untouched by listing fixture rendering',()=>{
 const names=['index.html','partials/header.html','partials/footer.html','foundry-connections.css','release-truth.json','portfolio-review.json'];
 const before=names.map(n=>fs.readFileSync(path.join(directoryRoot,n)));
 for(const name of ['zero','one','hidden','reorder']) {
  const input=copyDirectory();
  if(name==='zero')input.entries=[];
  if(name==='one')input.entries=[input.entries[0]];
  if(name==='hidden')input.entries.forEach(e=>e.visible=false);
  if(name==='reorder')input.entries.forEach(e=>e.order=-e.order);
  renderDirectoryFixture(input);
 }
 names.forEach((n,i)=>assert.deepEqual(fs.readFileSync(path.join(directoryRoot,n)),before[i]));
});
