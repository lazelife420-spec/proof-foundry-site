import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createLegacyIntakeFixture,getLegacyRegressionRoot} from './legacy-intake-fixture.mjs';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const git=(root,...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',windowsHide:true});
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');

test('legacy regression snapshot binding rejects substituted authorities',async t=>{
  assert.equal(getLegacyRegressionRoot(ROOT),ROOT,'ordinary source has no alternate regression authority');
  const fixture=createLegacyIntakeFixture();
  const marker=path.join(fixture.site,'.legacy-intake-context.json');
  const originalContext=fs.readFileSync(marker);
  const amend=()=>{
    git(fixture.site,'add','--all');
    git(fixture.site,'-c','user.name=Qualification Fixture','-c','user.email=qualification@example.invalid','-c','commit.gpgsign=false','commit','--quiet','--amend','--no-edit');
  };
  async function mutate(files,action,expected){
    const originals=files.map(f=>[f,fs.readFileSync(f)]);
    try{action();amend();assert.throws(()=>getLegacyRegressionRoot(fixture.site),expected);}
    finally{for(const[f,bytes]of originals)fs.writeFileSync(f,bytes);amend();}
    assert.equal(getLegacyRegressionRoot(fixture.site),fixture.canonical,'restoring exact bytes restores the valid binding');
  }
  try{
    await t.test('canonical presentation, model and all original test bytes are preserved',()=>{
      assert.equal(getLegacyRegressionRoot(fixture.site),fixture.canonical);
      for(const rel of ['site-manifest.json','release-truth.json','scripts/test-pf-product-p3-p5.mjs','scripts/test-pf-product-p6.mjs','scripts/test-h9-binding.ps1','scripts/test-home-v5-browser.mjs'])assert.ok(fs.readFileSync(path.join(fixture.canonical,rel)).equals(fs.readFileSync(path.join(ROOT,rel))),rel);
      const canonical=JSON.parse(fs.readFileSync(path.join(fixture.canonical,'site-manifest.json')));
      const legacy=JSON.parse(fs.readFileSync(path.join(fixture.site,'site-manifest.json')));
      assert.ok(canonical.releaseFactsSource);
      assert.ok(!legacy.releaseFactsSource);
      assert.equal(git(fixture.site,'remote').trim(),'');assert.equal(git(fixture.canonical,'remote').trim(),'');
    });
    await t.test('an arbitrary canonical path is rejected',()=>mutate([marker],()=>{
      const v=JSON.parse(originalContext);v.canonicalRoot='../../unrelated';fs.writeFileSync(marker,JSON.stringify(v,null,2)+'\n');
    },/location is fixed/));
    await t.test('a different canonical commit is rejected',()=>mutate([marker],()=>{
      const v=JSON.parse(originalContext);v.canonicalCommit='0'.repeat(40);fs.writeFileSync(marker,JSON.stringify(v,null,2)+'\n');
    },/source pin must match/));
    await t.test('a changed test cannot be hidden in the legacy snapshot',()=>{
      const file=path.join(fixture.site,'scripts/test-h9-binding.ps1');
      return mutate([file],()=>fs.appendFileSync(file,'\n# deliberately changed guard\n'),/code and test bytes must equal/);
    });
    await t.test('changing both transport facts and their checksum still fails semantic binding',()=>{
      const file=path.join(fixture.site,'site-manifest.json');
      return mutate([file,marker],()=>{
        const v=JSON.parse(fs.readFileSync(file));v.products[0].release.publicVersion='99.0.0';
        const bytes=Buffer.from(JSON.stringify(v,null,2)+'\n');fs.writeFileSync(file,bytes);
        const c=JSON.parse(originalContext);c.transportSha256=sha(bytes);fs.writeFileSync(marker,JSON.stringify(c,null,2)+'\n');
      },/exact canonical release projection/);
    });
    await t.test('uncommitted changes in the canonical snapshot are rejected',()=>{
      const file=path.join(fixture.canonical,'index.html'),bytes=fs.readFileSync(file);
      try{fs.appendFileSync(file,'\n');assert.throws(()=>getLegacyRegressionRoot(fixture.site),/source must remain clean/);}
      finally{fs.writeFileSync(file,bytes);}
    });
    await t.test('a canonical snapshot with a remote is rejected',()=>{
      try{git(fixture.canonical,'remote','add','fixture-probe','https://example.invalid/never-contacted');assert.throws(()=>getLegacyRegressionRoot(fixture.site),/no Git remote/);}
      finally{git(fixture.canonical,'remote','remove','fixture-probe');}
    });
    await t.test('a context outside the generated temporary fixture cannot redirect tests',()=>{
      const outside=path.join(fixture.temp,'outside'),source=path.join(outside,'source'),file=path.join(source,'.legacy-intake-context.json');
      fs.mkdirSync(source,{recursive:true});fs.writeFileSync(file,originalContext);
      try{assert.throws(()=>getLegacyRegressionRoot(source),/generated direct child/);}
      finally{fs.unlinkSync(file);fs.rmdirSync(source);fs.rmdirSync(outside);}
      assert.equal(getLegacyRegressionRoot(fixture.site),fixture.canonical);
    });
  }finally{fixture.cleanup();}
});
