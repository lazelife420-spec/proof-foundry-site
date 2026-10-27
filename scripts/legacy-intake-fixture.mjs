// Retain the complete historical publisher regression population without
// enabling its legacy release writer under the current authored authority.
// This ephemeral compatibility transport originates in the shared model;
// it is never a permanent source or a production qualification candidate.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {spawnSync,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import releaseInputs from './release-inputs.cjs';
import sharedTruth from './shared-release-truth.cjs';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const CONTEXT='.legacy-intake-context.json';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const git=(root,...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',windowsHide:true});
const pretty=value=>JSON.stringify(value,null,2)+'\n';
const samePath=(a,b)=>path.resolve(a).toLowerCase()===path.resolve(b).toLowerCase();
const excluded=rel=>/(^|\/)(\.wrangler|\.factory|node_modules|rg_mcp_runtime|claude-code-sessions)(\/|$)|(^|\/)(\.env(?:\..*)?|\.dev\.vars|connector\.json|owner-mcp-url\.txt|mcp-adapter-credential\.json|miniflare-wobs-trace-store)$/.test(rel);

function assertFixturePath(temp){
  assert.ok(samePath(path.dirname(temp),os.tmpdir())&&path.basename(temp).startsWith('pf-legacy-intake-regression-'),'Legacy fixture must be a generated direct child of the process temp directory');
  assert.ok(samePath(fs.realpathSync(temp),temp),'Legacy fixture cannot traverse a reparse point');
}
function transportBytes(canonical){
  const transport=sharedTruth.readAuthoredInputs(canonical).manifest;
  delete transport.releaseFactsSource;
  return Buffer.from(pretty(transport));
}

// No environment switch or arbitrary alternate root: two clean, remote-free
// snapshots share a canonical parent, identical code/tests and exact facts.
// Only the legacy lane substitutes the derived v1 transport for intake.
export function getLegacyRegressionRoot(root=ROOT){
  const marker=path.join(root,CONTEXT);
  if(!fs.existsSync(marker))return root;
  const temp=path.dirname(root),canonical=path.join(temp,'canonical');
  assertFixturePath(temp);
  assert.equal(path.basename(root),'source','Unexpected legacy fixture lane');
  for(const dir of [root,canonical]){
    assert.ok(samePath(fs.realpathSync(dir),dir),'Fixture lane cannot traverse a reparse point');
    assert.equal(git(dir,'remote').trim(),'','Fixture lanes have no Git remote');
    assert.equal(git(dir,'status','--porcelain','--untracked-files=all').trim(),'','Fixture lane source must remain clean');
  }
  const context=JSON.parse(fs.readFileSync(marker,'utf8'));
  assert.deepEqual(Object.keys(context).sort(),['canonicalCommit','canonicalRoot','canonicalTree','schema','transportSha256'].sort(),'Exact fixture context required');
  assert.equal(context.schema,'pf.legacy-intake-fixture/v1');
  assert.equal(context.canonicalRoot,'../canonical','Canonical fixture location is fixed');
  assert.equal(git(canonical,'rev-parse','HEAD').trim(),context.canonicalCommit,'Canonical source pin must match');
  assert.equal(git(canonical,'rev-parse','HEAD^{tree}').trim(),context.canonicalTree,'Canonical tree pin must match');
  git(root,'merge-base','--is-ancestor',context.canonicalCommit,'HEAD');
  assert.equal(git(root,'rev-list','--count',context.canonicalCommit+'..HEAD').trim(),'1','Only the transport fixture commit may follow the canonical snapshot');
  assert.deepEqual(git(root,'diff','--name-only',context.canonicalCommit,'HEAD').trim().split(/\r?\n/).sort(),[CONTEXT,'site-manifest.json'].sort(),'Fixture code and test bytes must equal canonical source');
  const bytes=fs.readFileSync(path.join(root,'site-manifest.json'));
  assert.equal(sha(bytes),context.transportSha256,'Legacy transport custody must match');
  assert.ok(bytes.equals(transportBytes(canonical)),'Legacy transport must preserve the exact canonical release projection');
  return canonical;
}

export function createLegacyIntakeFixture(){
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'pf-legacy-intake-regression-'));
  const canonical=path.join(temp,'canonical'),site=path.join(temp,'source');
  const cleanup=()=>{assertFixturePath(temp);fs.rmSync(temp,{recursive:true,force:true});};
  try{
    execFileSync('git',['clone','--quiet','--no-checkout','--no-hardlinks',ROOT,canonical],{windowsHide:true,stdio:'pipe'});
    git(canonical,'remote','remove','origin');git(canonical,'config','core.autocrlf','false');
    const paths=git(ROOT,'ls-files','-z').split('\0').filter(Boolean);
    for(const helper of ['scripts/legacy-intake-fixture.mjs','scripts/test-legacy-intake-fixture.mjs','scripts/release-inputs.cjs','scripts/qualification-authority.cjs','scripts/release-qualification.ps1','scripts/build-qualification-fixture.ps1'])if(!paths.includes(helper))paths.push(helper);
    for(const rel of paths){
      assert.ok(!rel.startsWith('/')&&!rel.split('/').includes('..')&&!excluded(rel),'Safe non-credential fixture inventory required');
      const source=path.join(ROOT,rel),dest=path.join(canonical,rel);
      assert.ok(!fs.lstatSync(source).isSymbolicLink());
      fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(source,dest);
    }
    git(canonical,'add','--all');
    git(canonical,'-c','user.name=Qualification Fixture','-c','user.email=qualification@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Disposable canonical website snapshot; never production authority');
    const canonicalCommit=git(canonical,'rev-parse','HEAD').trim(),canonicalTree=git(canonical,'rev-parse','HEAD^{tree}').trim();
    execFileSync('git',['clone','--quiet','--no-hardlinks',canonical,site],{windowsHide:true,stdio:'pipe'});
    git(site,'remote','remove','origin');git(site,'config','core.autocrlf','false');
    const bytes=transportBytes(canonical);
    fs.writeFileSync(path.join(site,'site-manifest.json'),bytes);
    fs.writeFileSync(path.join(site,CONTEXT),pretty({schema:'pf.legacy-intake-fixture/v1',canonicalRoot:'../canonical',canonicalCommit,canonicalTree,transportSha256:sha(bytes)}));
    git(site,'add','--all');
    git(site,'-c','user.name=Qualification Fixture','-c','user.email=qualification@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Disposable legacy transport bound to canonical website snapshot');
    assert.equal(getLegacyRegressionRoot(site),canonical);
    return {temp,site,canonical,cleanup};
  }catch(error){cleanup();throw error;}
}
export function runLegacyIntakeRegression(url){
  const presentation=JSON.parse(fs.readFileSync(path.join(ROOT,'site-manifest.json'),'utf8'));
  if(!presentation.releaseFactsSource) return;
  const name=path.basename(fileURLToPath(url));
  assert.ok(['test-pf-product-p3-p5.mjs','test-pf-product-p6.mjs'].includes(name));
  for(const type of ['NEW_PRODUCT','NEW_VERSION','PRESENTATION_UPDATE']) assert.throws(()=>releaseInputs.assertLegacyReleaseWriterDisabled('materialize',type),/SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED/);
  for(const operation of ['publish-artifacts','promote','deploy-site'])assert.throws(()=>releaseInputs.assertLegacyReleaseWriterDisabled(operation),/SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED/);
  const fixture=createLegacyIntakeFixture();
  try {
    console.log('CURRENT AUTHORITY: all legacy publication guards PASS; historical intake uses an isolated v1 transport, and all eleven regression authorities use its byte-bound canonical website snapshot.');
    const r=spawnSync(process.execPath,[path.join(fixture.site,'scripts',name)],{cwd:fixture.site,env:process.env,windowsHide:true,stdio:'inherit',timeout:3600000});
    if(r.error)throw r.error;
    assert.equal(getLegacyRegressionRoot(fixture.site),fixture.canonical,'Both fixture source lanes remain unchanged');
    process.exitCode=r.status===0?0:1;
  } finally {
    fixture.cleanup();
  }
  return true;
}
