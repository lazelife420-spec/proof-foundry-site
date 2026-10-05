'use strict';
const {execFileSync}=require('node:child_process');
const path=require('node:path');
const {compile}=require('./shared-release-truth.cjs');
const root=path.resolve(__dirname,'..');
const revision=process.argv[2];
if(!revision || revision.startsWith('-')) throw new Error('Explicit source revision required');
const read=file=>JSON.parse(execFileSync('git',['show',revision+':'+file],{cwd:root,encoding:'utf8',windowsHide:true}));
const presentation=read('site-manifest.json');
// The historical preview used the same authored model with a preview-only
// adoption label. Only route-input comparison normalizes that obsolete label.
if(presentation.releaseFactsSource?.mode==='SHARED_RELEASE_TRUTH_PREVIEW_ONLY') presentation.releaseFactsSource.mode='SHARED_RELEASE_TRUTH_AUTHORITY';
process.stdout.write(JSON.stringify(presentation.releaseFactsSource ? compile(read('release-truth.json'),presentation).manifest : presentation));
