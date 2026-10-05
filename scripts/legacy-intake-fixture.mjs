// Retain the complete historical publisher regression population without
// enabling its legacy release writer under the current authored authority.
// This ephemeral compatibility transport originates in the shared model;
// it is never a permanent source or a production qualification candidate.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {spawnSync,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import releaseInputs from './release-inputs.cjs';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function runLegacyIntakeRegression(url){
  const presentation=JSON.parse(fs.readFileSync(path.join(ROOT,'site-manifest.json'),'utf8'));
  if(!presentation.releaseFactsSource) return;
  const name=path.basename(fileURLToPath(url));
  assert.ok(['test-pf-product-p3-p5.mjs','test-pf-product-p6.mjs'].includes(name));
  for(const type of ['NEW_PRODUCT','NEW_VERSION','PRESENTATION_UPDATE']) assert.throws(()=>releaseInputs.assertLegacyReleaseWriterDisabled('materialize',type),/SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED/);
  assert.throws(()=>releaseInputs.assertLegacyReleaseWriterDisabled('promote'),/SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED/);
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'pf-legacy-intake-regression-'));
  const site=path.join(temp,'source');
  const git=(...args)=>execFileSync('git',args,{cwd:site,encoding:'utf8',windowsHide:true});
  try {
    execFileSync('git',['clone','--quiet','--no-checkout','--no-hardlinks',ROOT,site],{windowsHide:true,stdio:'pipe'});
    git('remote','remove','origin');
    git('config','core.autocrlf','false');
    const paths=execFileSync('git',['ls-files','-z'],{cwd:ROOT,encoding:'utf8',windowsHide:true}).split('\0').filter(Boolean);
    for(const helper of ['scripts/legacy-intake-fixture.mjs','scripts/release-inputs.cjs','scripts/qualification-authority.cjs','scripts/release-qualification.ps1','scripts/build-qualification-fixture.ps1']) if(!paths.includes(helper))paths.push(helper);
    for(const rel of paths){
      assert.ok(!rel.startsWith('/')&&!rel.split('/').includes('..'));
      const source=path.join(ROOT,rel),dest=path.join(site,rel);
      assert.ok(!fs.lstatSync(source).isSymbolicLink());
      fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(source,dest);
    }
    const transport=releaseInputs.readReleaseManifest();delete transport.releaseFactsSource;
    fs.writeFileSync(path.join(site,'site-manifest.json'),JSON.stringify(transport,null,2)+'\n');
    git('add','--all');
    git('-c','user.name=Qualification Fixture','-c','user.email=qualification@example.invalid','-c','commit.gpgsign=false','commit','--quiet','-m','Disposable legacy compatibility transport; never production authority');
    console.log('CURRENT AUTHORITY: legacy release proposal and promotion guards PASS; remaining assertions exercise a disposable legacy compatibility fixture.');
    const r=spawnSync(process.execPath,[path.join(site,'scripts',name)],{cwd:site,env:process.env,windowsHide:true,stdio:'inherit',timeout:3600000});
    if(r.error)throw r.error;
    assert.equal(git('status','--porcelain').trim(),'','Legacy regression fixture source remains unchanged');
    process.exitCode=r.status===0?0:1;
  } finally {
    const parent=path.resolve(os.tmpdir())+path.sep;
    assert.ok(path.resolve(temp).startsWith(parent)&&path.basename(temp).startsWith('pf-legacy-intake-regression-'));
    fs.rmSync(temp,{recursive:true,force:true});
  }
  return true;
}
