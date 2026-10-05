'use strict';
// Build-time derivative of the authored model and the v1 compatibility projection.
// This output is never used to construct or update release-truth.json.
const fs=require('node:fs'),path=require('node:path');
const {readAuthoredInputs}=require('./shared-release-truth.cjs');
const {serialize}=require('../vendor/pf-shared-release-truth/pf-release-truth');
function generate(out) {
  const {projection,provenance}=readAuthoredInputs();
  const read=file=>JSON.parse(fs.readFileSync(path.join(out,file),'utf8'));
  const write=(file,v)=>{const dest=path.join(out,file);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,serialize(v)+'\n');};
  const v1=read('truth/index.json');
  const source={...v1.source,releaseFactsSource:provenance};
  const index={...v1,schemaVersion:2,generatedFrom:'release-truth.json',schemaUrl:'/truth/schema-v2.json',source,products:v1.products.map(p=>({...p,truthUrl:'/truth/v2/products/'+p.id+'.json'}))};
  write('truth/v2/index.json',index);
  for(const product of projection.products) {
    const compat=read('truth/products/'+product.id+'.json');
    write('truth/v2/products/'+product.id+'.json',{...compat,schemaVersion:2,truthUrl:'/truth/v2/products/'+product.id+'.json',source,channels:product.channels,verificationEvidence:product.verification,installationAuthority:'NONE'});
  }
}
if(require.main===module){try{generate(path.resolve(process.argv[2]));}catch(error){console.error(error.message);process.exitCode=2;}}
module.exports={generate};
