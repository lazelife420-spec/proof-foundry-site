'use strict';

// Authored release facts only. Generated website observations belong to the
// separate reconciliation audit. Publication, qualification, artifact signing
// and private signing authority remain independent dimensions.
const { serialize, sha256Hex } = require('../pf-store-core/src/shared/CanonicalJson');
const SCHEMA = 'proof-foundry-release-truth/v2';
const PROJECTION_SCHEMA = 'proof-foundry-release-truth-projection/v2';
const PLATFORMS = ['windows','android'];
const STATES = {PUBLIC:'PUBLIC_RELEASE',CANDIDATE:'CANDIDATE',BUILT:'BUILT_NOT_PUBLIC',WITHDRAWN:'WITHDRAWN'};
const SHA256=/^[0-9a-f]{64}$/;
const COMMIT=/^[0-9a-f]{40}$/;
const ID=/^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const nonempty=value=>typeof value==='string' && value.trim().length>0;
const plain=value=>value!==null && typeof value==='object' && !Array.isArray(value) && (Object.getPrototypeOf(value)===Object.prototype || Object.getPrototypeOf(value)===null);
const clone=value=>JSON.parse(serialize(value));
function publicUrl(value,evidence=false) {
  try { const u=new URL(value); return nonempty(value) && u.protocol==='https:' && ['theprooffoundry.com','downloads.theprooffoundry.com','github.com'].includes(u.hostname) && !u.username && !u.password && !u.search && !u.port && (evidence || !u.hash); }
  catch (_) { return false; }
}
function channel(product,platform,track) { return product.channels.find(c=>plain(c) && c.platform===platform && c.track===track) || null; }

function validateReleaseTruth(model) {
  const errors=[];
  const fail=(at,message)=>errors.push(`${at}: ${message}`);
  function shape(value,keys,at) {
    if (!plain(value)) { fail(at,'plain object required'); return false; }
    for (const key of keys) if (!Object.hasOwn(value,key)) fail(at+'.'+key,'required field missing');
    for (const key of Object.keys(value)) if (!keys.includes(key)) fail(at+'.'+key,'unknown field');
    return true;
  }
  function digest(value,at,pattern=SHA256,required=false) { if ((required || value!==null) && (typeof value!=='string' || !pattern.test(value))) fail(at,'invalid or missing digest'); }
  function text(value,at,required=false) { if (required ? !nonempty(value) : value!==null && !nonempty(value)) fail(at,'invalid string'); }
  function date(value,at) { if (value!==null && (typeof value!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0,10)!==value)) fail(at,'valid YYYY-MM-DD or null required'); }
  const evidenceIds=new Map();
  function references(value,at) { if (!Array.isArray(value) || !value.length || value.some(id=>!evidenceIds.has(id)) || new Set(value).size!==value.length) fail(at,'unique known authored evidence references required'); }
  if (!shape(model,['schemaVersion','modelId','revision','authority','productionSigningAuthority','sourceEvidence','products'],'$')) return {valid:false,errors};
  if (model.schemaVersion!==SCHEMA) fail('$.schemaVersion','unsupported schema; no silent v1 migration');
  if (!nonempty(model.modelId) || !ID.test(model.modelId)) fail('$.modelId','invalid identity');
  if (!Number.isSafeInteger(model.revision) || model.revision<1) fail('$.revision','positive integer required');
  if (model.productionSigningAuthority!=='HOLD') fail('$.productionSigningAuthority','production authority remains HOLD');
  if (shape(model.authority,['facts','adoption','currentWebsiteSource','currentWebsiteCommit','currentWebsiteTree','canonicalCandidate','cutover'],'$.authority')) {
    for (const [key,value] of Object.entries({facts:'AUTHORED',adoption:'RECONCILED_CANDIDATE',currentWebsiteSource:'site-manifest.json',canonicalCandidate:'release-truth.json',cutover:'NOT_PERFORMED'})) if (model.authority[key]!==value) fail('$.authority.'+key,'unsupported authority assertion');
    digest(model.authority.currentWebsiteCommit,'$.authority.currentWebsiteCommit',COMMIT,true);
    digest(model.authority.currentWebsiteTree,'$.authority.currentWebsiteTree',COMMIT,true);
  }
  if (!Array.isArray(model.sourceEvidence) || !model.sourceEvidence.length) fail('$.sourceEvidence','authored evidence required');
  else for (const [i,s] of model.sourceEvidence.entries()) {
    const at=`$.sourceEvidence[${i}]`;
    if (!shape(s,['id','kind','role','uri','sha256','commit','tree','observedAt'],at)) continue;
    if (!nonempty(s.id) || !ID.test(s.id) || evidenceIds.has(s.id)) fail(at+'.id','invalid/duplicate source');
    evidenceIds.set(s.id,s);
    if (!['AUTHORED_SITE_MANIFEST','FROZEN_APP_FIXTURE'].includes(s.kind)) fail(at+'.kind','generated outputs cannot be authored inputs');
    if (s.role!=='AUTHORING_EVIDENCE') fail(at+'.role','unsupported source role');
    const uri=s.kind==='AUTHORED_SITE_MANIFEST' ? `https://github.com/lazelife420-spec/proof-foundry-site/blob/${s.commit}/site-manifest.json` : 'repo:proof-foundry-app/packages/pf-store-core/src/shared/fixtures/sharedCatalogFixture.js';
    if (s.uri!==uri) fail(at+'.uri','exact authored source URI required');
    digest(s.sha256,at+'.sha256',SHA256,true);
    digest(s.commit,at+'.commit',COMMIT,true);
    digest(s.tree,at+'.tree',COMMIT,true);
    if (!nonempty(s.observedAt) || !Number.isFinite(Date.parse(s.observedAt))) fail(at+'.observedAt','timestamp required');
  }
  const ids=new Set();
  if (!Array.isArray(model.products) || !model.products.length) fail('$.products','product array required');
  else for (const [i,p] of model.products.entries()) {
    const at=`$.products[${i}]`;
    if (!shape(p,['id','name','status','primaryPlatform','verification','channels'],at)) continue;
    if (!nonempty(p.id) || !ID.test(p.id) || ids.has(p.id)) fail(at+'.id','invalid/duplicate product');
    ids.add(p.id); text(p.name,at+'.name',true);
    if (!['PUBLIC_RELEASE','WITHDRAWN'].includes(p.status)) fail(at+'.status','unsupported product status');
    if (!PLATFORMS.includes(p.primaryPlatform)) fail(at+'.primaryPlatform','unsupported platform');
    const v=p.verification;
    if (shape(v,['qualificationState','scope','platform','version','report','tests','evidence','limitations','evidenceIds'],at+'.verification')) {
      if (v.qualificationState!=='REPORTED_BY_AUTHORED_SOURCE') fail(at+'.verification','reported qualification must not become an independent current PASS');
      if (v.scope!==(p.status==='WITHDRAWN' ? 'HISTORICAL_WITHDRAWN_RELEASE' : 'PRIMARY_RELEASE')) fail(at+'.verification.scope','qualification scope mismatch');
      if (v.platform!==p.primaryPlatform) fail(at+'.verification.platform','primary report platform must remain explicit');
      text(v.version,at+'.verification.version',true); references(v.evidenceIds,at+'.verification.evidenceIds');
      if (shape(v.report,['status','verifiedAt','checkedAt','downloadAvailability','verificationType','receiptId','receiptUrl'],at+'.verification.report')) {
        for (const key of ['status','downloadAvailability','receiptId']) text(v.report[key],at+'.verification.report.'+key);
        for (const key of ['verifiedAt','checkedAt']) date(v.report[key],at+'.verification.report.'+key);
        if (!Array.isArray(v.report.verificationType) || v.report.verificationType.some(x=>!nonempty(x)) || new Set(v.report.verificationType).size!==v.report.verificationType.length) fail(at+'.verification.report.verificationType','unique reported types required');
        if (v.report.receiptUrl!==null && !publicUrl(v.report.receiptUrl,true)) fail(at+'.verification.report.receiptUrl','public evidence URL required');
      }
      if (!Array.isArray(v.tests)) fail(at+'.verification.tests','test evidence required');
      else for (const [ti,row] of v.tests.entries()) if (shape(row,['label','result'],at+`.verification.tests[${ti}]`)) for (const key of ['label','result']) text(row[key],at+`.verification.tests[${ti}].${key}`,true);
      if (!Array.isArray(v.evidence)) fail(at+'.verification.evidence','evidence array required');
      else for (const [ei,row] of v.evidence.entries()) {
        if (typeof row==='string') { if (!publicUrl(row,true)) fail(at+`.verification.evidence[${ei}]`,'public evidence URL required'); }
        else if (shape(row,['label','url'],at+`.verification.evidence[${ei}]`)) {
          text(row.label,at+`.verification.evidence[${ei}].label`,true);
          if (row.url!==null && !publicUrl(row.url,true)) fail(at+`.verification.evidence[${ei}].url`,'public evidence URL required');
        }
      }
      if (!Array.isArray(v.limitations) || v.limitations.some(x=>!nonempty(x))) fail(at+'.verification.limitations','verbatim limitations required');
    }
    if (!Array.isArray(p.channels) || !p.channels.length) { fail(at+'.channels','channel records required'); continue; }
    const channelIds=new Set();
    for (const [ci,c] of p.channels.entries()) {
      const cp=at+`.channels[${ci}]`;
      if (!shape(c,['id','platform','track','version','publicationState','publishedAt','sourceCommit','artifacts','packageIdentity','withdrawal','verification','evidenceIds'],cp)) continue;
      if (!PLATFORMS.includes(c.platform) || !Object.hasOwn(STATES,c.track)) fail(cp,'unsupported platform/track');
      if (c.id!==`${c.platform}-${String(c.track).toLowerCase()}` || channelIds.has(c.id)) fail(cp+'.id','unique platform/track identity required');
      channelIds.add(c.id);
      if (c.publicationState!==STATES[c.track]) fail(cp+'.publicationState','track/state mismatch');
      text(c.version,cp+'.version',true); date(c.publishedAt,cp+'.publishedAt');
      if (['BUILT','CANDIDATE'].includes(c.track) && c.publishedAt!==null) fail(cp+'.publishedAt','unpublished channel cannot carry a publication date');
      digest(c.sourceCommit,cp+'.sourceCommit',COMMIT); references(c.evidenceIds,cp+'.evidenceIds');
      if (c.track==='WITHDRAWN') {
        if (shape(c.withdrawal,['withdrawnVersion','reason'],cp+'.withdrawal')) {
          if (c.withdrawal.withdrawnVersion!==c.version) fail(cp+'.withdrawal','identity mismatch');
          text(c.withdrawal.reason,cp+'.withdrawal.reason',true);
        }
      } else if (c.withdrawal!==null) fail(cp+'.withdrawal','withdrawal requires WITHDRAWN track');
      if (shape(c.verification,['qualificationState','scope','evidenceIds','note'],cp+'.verification')) {
        const primary=c.platform===p.primaryPlatform && ['PUBLIC','WITHDRAWN'].includes(c.track);
        const expected=primary ? 'PRIMARY_RELEASE_REPORT' : c.track==='BUILT' ? 'BUILT_ONLY_NOT_QUALIFIED' : 'NOT_ESTABLISHED';
        if (c.verification.qualificationState!==expected || c.verification.scope!=='THIS_CHANNEL_ONLY') fail(cp+'.verification','qualification cannot flow across channels or override withdrawal');
        references(c.verification.evidenceIds,cp+'.verification.evidenceIds'); text(c.verification.note,cp+'.verification.note',true);
      }
      const filenames=new Set();
      if (!Array.isArray(c.artifacts)) fail(cp+'.artifacts','artifact array required');
      else for (const [ai,a] of c.artifacts.entries()) {
        const ap=cp+`.artifacts[${ai}]`;
        if (!shape(a,['filename','sizeBytes','sha256','downloadUrl','sha256Url','signingStatus','distributionType','sourcePlatform'],ap)) continue;
        if (!nonempty(a.filename) || /[\\/]/.test(a.filename) || filenames.has(a.filename)) fail(ap+'.filename','unique plain filename required');
        filenames.add(a.filename);
        if (a.sizeBytes!==null && (!Number.isSafeInteger(a.sizeBytes) || a.sizeBytes<=0)) fail(ap+'.sizeBytes','positive integer size or null required');
        digest(a.sha256,ap+'.sha256');
        for (const key of ['downloadUrl','sha256Url']) if (a[key]!==null && !publicUrl(a[key])) fail(ap+'.'+key,'credential-free public HTTPS URL required');
        if (a.downloadUrl!==null && a.sha256===null) fail(ap,'download requires recorded digest');
        if (c.track!=='PUBLIC' && (a.downloadUrl!==null || a.sha256Url!==null)) fail(ap,'nonpublic/withdrawn downloads forbidden');
        if (!['UNSIGNED','PRODUCTION_SIGNED','UNKNOWN'].includes(a.signingStatus)) fail(ap+'.signingStatus','unknown signing state');
        if (c.platform==='windows' && a.signingStatus==='PRODUCTION_SIGNED') fail(ap+'.signingStatus','APK signing is not Windows Authenticode');
        if (c.platform==='windows' ? a.sourcePlatform!=='Windows' : !['Android','Android companion'].includes(a.sourcePlatform)) fail(ap+'.sourcePlatform','platform mismatch');
        text(a.distributionType,ap+'.distributionType',true);
      }
      const pkg=c.packageIdentity;
      if (c.platform==='windows') { if (pkg!==null) fail(cp+'.packageIdentity','Android identity on Windows'); }
      else if (shape(pkg,['packageName','versionName','versionCode','currentSignerSha256','signingHistory','artifactSha256','evidenceIds'],cp+'.packageIdentity')) {
        for (const key of ['packageName','versionName']) text(pkg[key],cp+'.packageIdentity.'+key);
        if (pkg.packageName!==null && !/^[a-zA-Z]\w*(?:\.[a-zA-Z]\w*)+$/.test(pkg.packageName)) fail(cp+'.packageIdentity.packageName','invalid package name');
        if (pkg.versionName!==null && pkg.versionName!==c.version) fail(cp+'.packageIdentity.versionName','version/channel mismatch');
        if (pkg.versionCode!==null && (!Number.isSafeInteger(pkg.versionCode) || pkg.versionCode<=0)) fail(cp+'.packageIdentity.versionCode','positive integer order identity or null required');
        digest(pkg.currentSignerSha256,cp+'.packageIdentity.currentSignerSha256'); digest(pkg.artifactSha256,cp+'.packageIdentity.artifactSha256'); references(pkg.evidenceIds,cp+'.packageIdentity.evidenceIds');
        if (([pkg.packageName,pkg.versionName,pkg.versionCode,pkg.currentSignerSha256].some(x=>x!==null) || (Array.isArray(pkg.signingHistory) && pkg.signingHistory.length)) && (!pkg.artifactSha256 || !Array.isArray(c.artifacts) || !c.artifacts.some(a=>a.sha256===pkg.artifactSha256))) fail(cp+'.packageIdentity','package facts require exact artifact digest binding');
        if (!Array.isArray(pkg.signingHistory)) fail(cp+'.packageIdentity.signingHistory','history array required');
        else {
          const signers=new Set();
          for (const [hi,h] of pkg.signingHistory.entries()) {
            const hp=cp+`.packageIdentity.signingHistory[${hi}]`;
            if (!shape(h,['signerSha256','retiredAtRelease','inPlaceUpdate'],hp)) continue;
            digest(h.signerSha256,hp+'.signerSha256',SHA256,true); text(h.retiredAtRelease,hp+'.retiredAtRelease',true);
            if (h.inPlaceUpdate!=='BLOCKED' || h.signerSha256===pkg.currentSignerSha256 || signers.has(h.signerSha256)) fail(hp,'retired signer updates remain blocked and unique');
            signers.add(h.signerSha256);
          }
          if (pkg.signingHistory.length && !pkg.artifactSha256) fail(cp+'.packageIdentity','signing history requires artifact binding');
        }
      }
    }
    const primary=channel(p,p.primaryPlatform,p.status==='WITHDRAWN' ? 'WITHDRAWN' : 'PUBLIC');
    if (!primary || (v && v.version!==primary.version)) fail(at,'primary release/report version mismatch');
    if (p.status==='WITHDRAWN' && p.channels.some(c=>c.track==='PUBLIC')) fail(at,'withdrawn product cannot have a public channel');
  }
  return {valid:errors.length===0,errors};
}
function requireValid(model) {
  const result=validateReleaseTruth(model);
  if (!result.valid) { const e=new Error('RELEASE_TRUTH_INVALID: '+result.errors.join('; ')); e.code='RELEASE_TRUTH_INVALID'; throw e; }
}
function websiteProduct(p) {
  const primary=channel(p,p.primaryPlatform,p.status==='WITHDRAWN' ? 'WITHDRAWN' : 'PUBLIC');
  const candidate=channel(p,p.primaryPlatform,'CANDIDATE');
  const other=p.primaryPlatform==='windows' ? 'android' : 'windows';
  const companion=channel(p,other,'PUBLIC');
  const companionCandidate=channel(p,other,'CANDIDATE');
  return {id:p.id,name:p.name,status:p.status,state:p.status==='WITHDRAWN' ? 'withdrawn' : 'available',version:p.status==='WITHDRAWN' ? null : primary.version,
    release:{releaseStatus:p.status,publicVersion:p.status==='WITHDRAWN' ? null : primary.version,candidateVersion:candidate ? candidate.version : null,companionPublicVersion:companion ? companion.version : null,companionCandidateVersion:companionCandidate ? companionCandidate.version : null,publishedAt:primary.publishedAt,sourceCommit:primary.sourceCommit,withdrawnVersion:primary.withdrawal ? primary.withdrawal.withdrawnVersion : null,withdrawalReason:primary.withdrawal ? primary.withdrawal.reason : null},
    artifacts:PLATFORMS.flatMap(platform=>p.channels.filter(c=>c.platform===platform && ['PUBLIC','WITHDRAWN'].includes(c.track)).flatMap(c=>c.artifacts.map(a=>({filename:a.filename,sizeBytes:a.sizeBytes,sha256:a.sha256,downloadUrl:a.downloadUrl,sha256Url:a.sha256Url,signingStatus:a.signingStatus,platform:a.sourcePlatform,distType:a.distributionType})))),
    verification:clone(p.verification),channels:clone(p.channels)};
}
function appProduct(p,platform) {
  const active=channel(p,platform,'PUBLIC'), withdrawn=channel(p,platform,'WITHDRAWN'), candidate=channel(p,platform,'CANDIDATE'), built=channel(p,platform,'BUILT');
  const release=active || withdrawn;
  const unresolved=[];
  if (!active) unresolved.push(release ? 'RELEASE_NOT_PUBLIC' : 'NO_PUBLIC_PLATFORM_RELEASE');
  if (!release || !release.artifacts.length) unresolved.push('ARTIFACT_IDENTITY_UNKNOWN');
  else for (const a of release.artifacts) for (const key of ['sizeBytes','sha256','downloadUrl']) if (a[key]===null) unresolved.push('ARTIFACT_'+key.toUpperCase()+'_UNKNOWN');
  if (platform==='android' && release) for (const key of ['packageName','versionName','versionCode','currentSignerSha256']) if (release.packageIdentity[key]===null) unresolved.push('ANDROID_'+key.toUpperCase()+'_UNKNOWN');
  return {id:p.id,name:p.name,status:p.status,publicVersion:active ? active.version : null,candidateVersion:candidate ? candidate.version : null,builtVersion:built ? built.version : null,publicationState:release ? release.publicationState : candidate ? candidate.publicationState : built ? built.publicationState : 'NOT_AVAILABLE_ON_PLATFORM',withdrawnVersion:withdrawn ? withdrawn.version : null,withdrawalReason:withdrawn ? withdrawn.withdrawal.reason : null,artifacts:release ? clone(release.artifacts) : [],packageIdentity:release ? clone(release.packageIdentity) : null,channels:clone(p.channels.filter(c=>c.platform===platform)),verification:clone(p.verification),publicDownloadRecorded:!!active && active.artifacts.some(a=>a.downloadUrl!==null),identityComplete:unresolved.length===0,unresolvedFields:[...new Set(unresolved)],installEligibility:'BLOCKED_PENDING_CONSUMER_INTEGRATION'};
}
function projectReleaseTruth(model,consumer) {
  requireValid(model);
  if (!['website',...PLATFORMS].includes(consumer)) throw new Error('Unsupported consumer');
  return {schemaVersion:PROJECTION_SCHEMA,consumer,modelId:model.modelId,modelRevision:model.revision,modelSha256:sha256Hex(model),authority:clone(model.authority),purpose:'LOCAL_RECONCILIATION_ONLY',runtimeActivation:'NOT_INTEGRATED',productionSigningAuthority:model.productionSigningAuthority,products:model.products.map(p=>consumer==='website' ? websiteProduct(p) : appProduct(p,consumer))};
}
function projectAll(model) { return Object.fromEntries(['website',...PLATFORMS].map(consumer=>[consumer,projectReleaseTruth(model,consumer)])); }
module.exports={SCHEMA,PROJECTION_SCHEMA,validateReleaseTruth,projectReleaseTruth,projectAll,serialize,sha256Hex,channel};
