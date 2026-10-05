'use strict';
// Deploy an already qualified immutable artifact. Never rebuild at publication.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {execFileSync,spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',windowsHide:true}).trim();
function files(dir,prefix=''){return fs.readdirSync(path.join(dir,prefix),{withFileTypes:true}).flatMap(e=>{assert.ok(!e.isSymbolicLink(),'Artifact symlinks forbidden');return e.isDirectory()?files(dir,path.posix.join(prefix,e.name)):[path.posix.join(prefix,e.name)];}).sort();}
function inventory(dir){return files(dir).map(file=>({file,sha256:sha(fs.readFileSync(path.join(dir,file)))}));}
function validateReceipt(receipt,identity,actual){
  assert.equal(receipt.disposition,'PASS','Qualified candidate required');
  assert.equal(receipt.candidateCommit,identity.commit,'Candidate commit mismatch');
  assert.equal(receipt.candidateTree,identity.tree,'Candidate tree mismatch');
  assert.equal(receipt.sourceClean,true,'Committed clean source required');
  assert.equal(receipt.determinism.independentProcesses,2,'Two independent generations required');
  assert.equal(receipt.semanticParity,'PASS','Seven-product parity required');
  assert.equal(receipt.visualParity,'PASS','Visual qualification required');
  assert.equal(receipt.publicProducts,7);assert.equal(receipt.channels,11);
  assert.equal(receipt.signingAuthority,'HOLD');assert.equal(receipt.installationAuthority,'NONE');
  assert.equal(receipt.rollback.commit,'c7d8a49972e95aa2dd9e4edd8c2085ae1d9f30ce','Pinned rollback required');
  assert.equal(receipt.rollback.deploymentId,'fbc586a2-2146-4db8-8052-0a074fc28276');
  assert.deepEqual(actual,receipt.hashes,'Artifact bytes or file population changed');
  assert.equal(sha(JSON.stringify(actual)),receipt.outputInventorySha256,'Artifact inventory digest mismatch');
  assert.ok(actual.some(row=>row.file==='_worker.js'),'Sealed Pages function bundle required');
  assert.ok(actual.some(row=>row.file==='_routes.json'),'Sealed function routing required');
  assert.ok(actual.some(row=>row.file==='truth/v2/index.json'),'Rich v2 projection required');
  return true;
}
function validateStage(stage,qualification){
  assert.equal(stage.disposition,'PASS','Exact served stage verification required');
  assert.equal(stage.candidateCommit,qualification.candidateCommit);
  assert.equal(stage.outputInventorySha256,qualification.outputInventorySha256);
  assert.match(stage.origin,/^https:\/\/[a-f0-9]+\.proof-foundry-site\.pages\.dev$/,'Immutable stage deployment URL required');
  assert.equal(stage.environment,'preview');
  assert.deepEqual(stage.served,qualification.hashes.filter(r=>!['_worker.js','_routes.json','_headers','_redirects'].includes(r.file)),'Every public candidate byte must have been verified');
  assert.equal(stage.runtimeParity,'PASS','Existing Pages runtime parity required');
}
function load(artifact,receiptFile){
  assert.equal(git('status','--porcelain=v1','--untracked-files=all'),'','Dirty source cannot be deployed');
  const receipt=JSON.parse(fs.readFileSync(receiptFile,'utf8'));
  validateReceipt(receipt,{commit:git('rev-parse','HEAD'),tree:git('rev-parse','HEAD^{tree}')},inventory(artifact));
  return receipt;
}
function deploy(mode,artifact,receiptFile,stageFile){
  assert.ok(['stage','production'].includes(mode),'Explicit stage or production action required');
  const receipt=load(artifact,receiptFile);
  if(mode==='production')validateStage(JSON.parse(fs.readFileSync(stageFile,'utf8')),receipt);
  const branch=mode==='stage'?'pf-release-truth-authority-preview':'main';
  const cli=path.join(root,'node_modules/wrangler/bin/wrangler.js');
  assert.equal(JSON.parse(fs.readFileSync(path.join(root,'node_modules/wrangler/package.json'))).version,'4.105.0','Pinned Wrangler required');
  // _worker.js freezes the compiled, unchanged Pages handlers. --no-bundle
  // prevents stage/production from silently producing different worker code.
  const result=spawnSync(process.execPath,[cli,'pages','deploy',path.resolve(artifact),'--project-name','proof-foundry-site','--branch',branch,'--commit-hash',receipt.candidateCommit,'--commit-dirty=false','--no-bundle'],{cwd:root,encoding:'utf8',windowsHide:true,maxBuffer:8*1024*1024});
  process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
  if(result.status!==0)throw new Error('Upload outcome requires inspection; do not automatically retry a publication.');
}
if(require.main===module){try{deploy(...process.argv.slice(2));}catch(error){console.error(error.message);process.exitCode=2;}}
module.exports={inventory,validateReceipt,validateStage,load,deploy,sha};
