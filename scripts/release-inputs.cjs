'use strict';
const fs=require('node:fs'),path=require('node:path');
const {readAuthoredInputs}=require('./shared-release-truth.cjs');
const ROOT=path.resolve(__dirname,'..');
function readReleaseManifest(){
  const presentation=JSON.parse(fs.readFileSync(path.join(ROOT,'site-manifest.json'),'utf8'));
  return presentation.releaseFactsSource ? readAuthoredInputs().manifest : presentation;
}
function assertLegacyReleaseWriterDisabled(operation, submissionType){
  const presentation=JSON.parse(fs.readFileSync(path.join(ROOT,'site-manifest.json'),'utf8'));
  if(presentation.releaseFactsSource && ['materialize','publish-artifacts','promote','deploy-site'].includes(operation)){
    const error=new Error('SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED: legacy release writer is disabled before any proposal or promotion. Author release facts in release-truth.json through a separately qualified shared-model intake; site-manifest.json owns presentation only.');
    error.code='SHARED_RELEASE_AUTHORITY_MIGRATION_REQUIRED';throw error;
  }
}
module.exports={readReleaseManifest,assertLegacyReleaseWriterDisabled};
