'use strict';
// PROPOSAL. Emits review markup to stdout only; release truth is never rewritten.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { renderReview, renderDirectory } = require('../vendor/pf-portfolio-review/index.cjs');
const verifyOnly=process.argv[2]==='--verify-generated' && process.argv.length===4;
if (process.argv.length!==2 && !verifyOnly) throw new Error('Only the bounded generated-directory verification is accepted');
const root = path.resolve(__dirname, '..');
const bytes = fs.readFileSync(path.join(root, 'portfolio-review.json'));
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
if (sha(bytes) !== 'ee22ac607237a0d4deb87e72b33ba677d2bc7ec4df50c0cb9e295f1f6bd3aac1') throw new Error('Reviewed discovery input changed');
const model = JSON.parse(bytes);
if (sha(fs.readFileSync(path.join(root, 'release-truth.json'))) !== model.websiteReleaseTruthSha256)
  throw new Error('Website release authority drift; do not reconcile automatically');
const slots=renderReview(model);
const editorial=JSON.parse(fs.readFileSync(path.join(root,'site-editorial.json')));
const manifest=JSON.parse(fs.readFileSync(path.join(root,'site-manifest.json')));
const releaseTruth=JSON.parse(fs.readFileSync(path.join(root,'release-truth.json')));
const assets=new Set();
function scan(dir) {
 for (const item of fs.readdirSync(path.join(root,dir),{withFileTypes:true})) {
  const name=dir+'/'+item.name;
  if (item.isSymbolicLink()) throw new Error('Asset symlink refused');
  if (item.isDirectory()) scan(name);
  else if (/\.(?:svg|png|jpe?g|webp|avif)$/i.test(name)) assets.add('/'+name);
 }
}
scan('assets');scan('brand');
const routes=new Set(['/','/software/','/proof/','/proof-standard/','/truth-files/','/about/','/support/']);
for (const item of manifest.products) {routes.add(item.route);routes.add('/truth-files/'+item.id+'/');}
for (const match of (slots.software+slots.softwareRecords).matchAll(/\bid="([^"]+)"/g)) routes.add('/software/#'+match[1]);
const context={identities:model.products.map(p=>p.id),assets,routes};
const directory=renderDirectory(editorial,model,releaseTruth,manifest,context);
if (verifyOnly) {
 const out=path.resolve(process.argv[3]);
 // Normal builds use public/. Fixtures may use an external output, but no
 // other authored-source directory is a valid generated artifact.
 if (out!==path.join(root,'public') && (out===root || out.startsWith(root+path.sep))) throw new Error('Generated verification requires public/ or an external output');
 const registryText=fs.readFileSync(path.join(out,'__h14/registry.json'),'utf8').trim();
 // The preserved PowerShell emitter writes no JSON tokens for an empty pipeline
 // and a single object for one item. Accept those shapes only with explicit
 // structural evidence; malformed nonempty JSON still fails closed.
 if (!registryText) {
  const truthIndex=JSON.parse(fs.readFileSync(path.join(out,'truth/index.json'),'utf8'));
  const state=JSON.parse(fs.readFileSync(path.join(out,'__h14/static-state.json'),'utf8'));
  if (truthIndex.productCount!==0 || !Array.isArray(state.products) || state.products.length!==0) throw new Error('Empty registry disagrees with generated product state');
 }
 const rawRegistry=registryText?JSON.parse(registryText):[];
 const registry=Array.isArray(rawRegistry)?rawRegistry:[rawRegistry];
 if (registry.some(x=>!x || typeof x.id!=='string' || !['visible','hidden'].includes(x.visibility))) throw new Error('Invalid generated registry shape');
 const visible=new Set(registry.filter(x=>x.visibility==='visible').map(x=>x.id));
 const hidden=new Set(fs.readdirSync(path.join(root,'products'),{withFileTypes:true}).filter(x=>x.isDirectory()&&!visible.has(x.name)).map(x=>x.name));
 const entries=editorial.entries.filter(x=>x.visible&&!hidden.has(x.id)).sort((a,b)=>a.order-b.order||a.id.localeCompare(b.id));
 const page=fs.readFileSync(path.join(out,'software/index.html'),'utf8');
 const rendered=[...page.matchAll(/data-directory-entry="([^"]+)"/g)].map(m=>m[1]);
 if (JSON.stringify(rendered)!==JSON.stringify(entries.map(x=>x.id))) throw new Error('Generated editorial identity/order mismatch');
 for (const entry of entries) {
  if (entry.artwork && !fs.existsSync(path.join(out,entry.artwork.slice(1)))) throw new Error('Generated artwork missing: '+entry.id);
  if (!entry.destination) continue;
  const [route,fragment]=entry.destination.split('#');
  const file=path.join(out,route.slice(1),route.endsWith('/')?'index.html':'');
  const content=fs.readFileSync(file,'utf8');
  if (fragment && !content.includes('id="'+fragment+'"')) throw new Error('Generated fragment missing: '+entry.id);
 }
 process.stdout.write('Editorial generated targets verified: '+entries.length+' entries\n');
} else {
 // Keep substantial existing systems content inspectable below the directory.
 const systemArticles=[...slots.software.matchAll(/<article id="portfolio-[\s\S]*?<\/article>/g)].map(m=>{
  const html=m[0],id=/id="([^"]+)"/.exec(html)[1],name=/<h3[^>]*>([\s\S]*?)<\/h3>/.exec(html)[1];
  return '<details class="directory-system-record" id="'+id+'"><summary>'+name+' <span>Purpose, workflow &amp; record</span></summary>'+html.replace('id="'+id+'"','data-preserved-system="'+id+'"')+'</details>';
 }).join('');
 slots.directory=directory.html;slots.directoryCount=directory.count;slots.directoryGroups=directory.groups;
 slots.directorySystems=systemArticles;slots.directoryRecords=slots.softwareRecords;
 process.stdout.write(JSON.stringify(slots));
}
