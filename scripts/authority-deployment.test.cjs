'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {validateReceipt,validateStage}=require('./authority-deployment.cjs');
const crypto=require('node:crypto');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
function fixture(){const hashes=['_routes.json','_worker.js','index.html','truth/v2/index.json'].map(file=>({file,sha256:'1'.repeat(64)}));return {disposition:'PASS',candidateCommit:'a'.repeat(40),candidateTree:'b'.repeat(40),sourceClean:true,determinism:{independentProcesses:2},semanticParity:'PASS',visualParity:'PASS',publicProducts:7,channels:11,signingAuthority:'HOLD',installationAuthority:'NONE',rollback:{commit:'c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce',deploymentId:'fbc586a2-2146-4db8-8052-0a074fc28276'},hashes,outputInventorySha256:hash(JSON.stringify(hashes))};}
const identity={commit:'a'.repeat(40),tree:'b'.repeat(40)};
test('exact sealed candidate receipt qualifies without touching network or credential stores',()=>{const r=fixture();assert.equal(validateReceipt(r,identity,r.hashes),true);});
for(const [name,mutate] of [
 ['wrong source commit',r=>r.candidateCommit='c'.repeat(40)],['wrong tree',r=>r.candidateTree='c'.repeat(40)],['dirty source',r=>r.sourceClean=false],['one generation',r=>r.determinism.independentProcesses=1],['failed visuals',r=>r.visualParity='HOLD'],['incomplete catalog',r=>r.publicProducts=6],['signing escalation',r=>r.signingAuthority='ACTIVE'],['install escalation',r=>r.installationAuthority='INSTALL'],['wrong rollback',r=>r.rollback.commit='c'.repeat(40)],['missing function bundle',r=>r.hashes=r.hashes.filter(x=>x.file!=='_worker.js')],['changed artifact population',r=>r.hashes.push({file:'unexpected.html',sha256:'2'.repeat(64)})]
])test('publication rejects '+name,()=>{const r=fixture(),actual=JSON.parse(JSON.stringify(r.hashes));mutate(r);assert.throws(()=>validateReceipt(r,identity,actual));});
function stage(r){return {disposition:'PASS',candidateCommit:r.candidateCommit,outputInventorySha256:r.outputInventorySha256,origin:'https://123abc.proof-foundry-site.pages.dev',environment:'preview',served:r.hashes.filter(x=>!x.file.startsWith('_')),runtimeParity:'PASS',runtime:Array.from({length:8},()=>({parity:'PASS'}))};}
test('only a complete immutable served preview permits production',()=>{const r=fixture();validateStage(stage(r),r);});
for(const [name,mutate] of [['unverified stage',s=>s.disposition='HOLD'],['mutable alias',s=>s.origin='https://preview.proof-foundry-site.pages.dev'],['missing served byte',s=>s.served.pop()],['unqualified runtime',s=>s.runtimeParity='HOLD'],['production substituted for preview',s=>s.environment='production'],['different candidate artifact',s=>s.outputInventorySha256='2'.repeat(64)]])test('production rejects '+name,()=>{const r=fixture(),s=stage(r);mutate(s);assert.throws(()=>validateStage(s,r));});
test('public deploy entry point refuses missing candidate or stage qualification before authentication',()=>{
  const file=path.resolve(__dirname,'../deploy.ps1');
  for(const args of [[],['-Mode','production','-Artifact','unused','-QualificationReceipt','unused']]){
    const r=spawnSync('pwsh',['-NoProfile','-File',file,...args],{encoding:'utf8',windowsHide:true});
    assert.notEqual(r.status,0);assert.match(r.stderr,/required|requires/);assert.doesNotMatch(r.stdout,/wrangler|Uploading|Building/);
  }
});
