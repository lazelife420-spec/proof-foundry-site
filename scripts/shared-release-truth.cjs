'use strict';

// Preview adapter: the authored model owns release facts. The site manifest
// owns presentation, navigation, ordering and website-only evidence wording.
// Generated machine records are never read as upstream inputs.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { projectReleaseTruth, serialize, sha256Hex } = require('../vendor/pf-shared-release-truth/pf-release-truth');
const ROOT = path.resolve(__dirname, '..');
const FACT_FIELDS = ['name', 'state', 'productStatus', 'platform', 'platforms', 'version', 'publicVersion', 'release', 'artifacts', 'verification', 'tests', 'evidence', 'limits', 'downloadUrl', 'sha256', 'sha256Url', 'packageId', 'currentLocalVersion', 'companionVersion', 'lastVerified'];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function compile(model, presentation) {
  if (presentation.releaseFactsSource?.mode !== 'SHARED_RELEASE_TRUTH_PREVIEW_ONLY' || presentation.releaseFactsSource.authoredFile !== 'release-truth.json' || presentation.releaseFactsSource.productionCutover !== 'NOT_PERFORMED') {
    throw new Error('Explicit preview-only presentation authority required.');
  }
  const projection = projectReleaseTruth(model, 'website');
  const ids = presentation.products?.map(p => p.id);
  if (!ids || new Set(ids).size !== ids.length || serialize([...ids].sort()) !== serialize(projection.products.map(p => p.id).sort())) {
    throw new Error('Presentation and authored model must contain the exact same product identities.');
  }
  const products = presentation.products.map(authored => {
    if (FACT_FIELDS.some(key => Object.hasOwn(authored, key))) throw new Error('Dual-authored release fact in presentation: ' + authored.id);
    const p = projection.products.find(product => product.id === authored.id);
    const primary = model.products.find(product => product.id === p.id).primaryPlatform;
    const publicChannel = p.channels.find(c => c.platform === primary && c.track === 'PUBLIC');
    const historical = p.channels.find(c => c.platform === primary && c.track === 'WITHDRAWN');
    const artifact = (publicChannel || historical)?.artifacts[0] || null;
    const alias = authored.releasePresentation || {};
    if (Object.keys(alias).some(key => !['localVersionLane', 'companionDisplayTrack', 'showPackageIdentity', 'emitEmptyCompanionCandidate'].includes(key))) throw new Error('Unknown release presentation selector.');
    if (Object.hasOwn(alias, 'emitEmptyCompanionCandidate') && typeof alias.emitEmptyCompanionCandidate !== 'boolean') throw new Error('Invalid empty-field presentation selector.');
    if (Object.hasOwn(alias, 'localVersionLane') && alias.localVersionLane !== null && !['PUBLIC', 'CANDIDATE', 'BUILT'].includes(alias.localVersionLane)) throw new Error('Invalid local version lane.');
    if (Object.hasOwn(alias, 'companionDisplayTrack') && !['PUBLIC', 'CANDIDATE', 'BUILT'].includes(alias.companionDisplayTrack)) throw new Error('Invalid companion lane.');
    const platforms = ['windows', 'android'].filter(platform => p.channels.some(c => c.platform === platform)).map(platform => {
      if (platform === 'windows') return 'Windows';
      const publicArtifact = p.channels.find(c => c.platform === platform && c.track === 'PUBLIC')?.artifacts[0];
      return publicArtifact?.sourcePlatform || 'Android';
    });
    // Keep the existing website shadow transport's optional-field shape. The
    // complete shared projection remains intact, including explicit nulls.
    const release = { ...p.release };
    for (const key of ['sourceCommit', 'companionPublicVersion', 'withdrawnVersion', 'withdrawalReason']) {
      if (release[key] === null) delete release[key];
    }
    if (release.companionCandidateVersion === null && alias.emitEmptyCompanionCandidate !== true) delete release.companionCandidateVersion;
    const report = { ...p.verification.report };
    for (const key of ['checkedAt', 'downloadAvailability']) if (report[key] === null) delete report[key];
    const product = {
      ...authored, name: p.name, state: p.state, productStatus: p.status,
      platforms, platform: platforms.map(label => label.startsWith('Android') ? 'Android' : label).join(' + '), release, artifacts: p.artifacts,
      verification: report, tests: p.verification.tests,
      evidence: p.verification.evidence, limits: p.verification.limitations,
      downloadUrl: publicChannel ? artifact?.downloadUrl || null : null,
      sha256: artifact?.sha256 || null, sha256Url: publicChannel ? artifact?.sha256Url || null : null,
      lastVerified: p.verification.report.verifiedAt
    };
    if (Object.hasOwn(alias, 'localVersionLane')) product.currentLocalVersion = alias.localVersionLane ? p.channels.find(c => c.platform === primary && c.track === alias.localVersionLane)?.version || null : null;
    if (Object.hasOwn(alias, 'companionDisplayTrack')) product.companionVersion = p.channels.find(c => c.platform !== primary && c.track === alias.companionDisplayTrack)?.version || null;
    if (alias.showPackageIdentity === true) product.packageId = publicChannel?.packageIdentity?.packageName || null;
    delete product.releasePresentation;
    return product;
  });
  const provenance = {
    mode: 'PREVIEW_ONLY', authoredFile: 'release-truth.json',
    modelSha256: projection.modelSha256,
    websiteProjectionSha256: sha(serialize(projection) + '\n'),
    appSourceCommit: 'c5df5bb805f88af41456351e3a648063f3da03c8',
    websiteSourceBaseCommit: model.authority.currentWebsiteCommit,
    productionCutover: 'NOT_PERFORMED', productionSigningAuthority: 'HOLD',
    qualificationInterpretation: 'REPORTED_BY_AUTHORED_SOURCE'
  };
  return { manifest: { ...presentation, products }, projection, projectionBytes: serialize(projection) + '\n', provenance };
}

function readAuthoredInputs(root = ROOT) {
  const provenance = JSON.parse(fs.readFileSync(path.join(root, 'vendor/pf-shared-release-truth/provenance.json'), 'utf8'));
  const expectedFiles = ['release-truth.json', 'vendor/pf-shared-release-truth/pf-release-truth/index.js', 'vendor/pf-shared-release-truth/pf-store-core/src/shared/CanonicalJson.js'];
  if (provenance.sourceCommit !== 'c5df5bb805f88af41456351e3a648063f3da03c8' || provenance.sourceRepository !== 'lazelife420-spec/proof-foundry-app' || !Array.isArray(provenance.files) || provenance.files.length !== 3 || serialize(provenance.files.map(entry => entry.destination).sort()) !== serialize(expectedFiles.sort())) throw new Error('Exact remotely preserved shared component provenance required.');
  for (const entry of provenance.files) {
    if (!['release-truth.json', 'vendor/pf-shared-release-truth/pf-release-truth/index.js', 'vendor/pf-shared-release-truth/pf-store-core/src/shared/CanonicalJson.js'].includes(entry.destination)) throw new Error('Unexpected shared component input.');
    if (sha(fs.readFileSync(path.join(root, entry.destination))) !== entry.sha256) throw new Error('Shared component custody digest mismatch.');
  }
  const model = JSON.parse(fs.readFileSync(path.join(root, 'release-truth.json'), 'utf8'));
  if (sha256Hex(model) !== provenance.modelSha256) throw new Error('Authored model differs from remotely preserved foundation.');
  return compile(model, JSON.parse(fs.readFileSync(path.join(root, 'site-manifest.json'), 'utf8')));
}

if (require.main === module) {
  try { process.stdout.write(JSON.stringify(readAuthoredInputs())); }
  catch (error) { console.error(error.message); process.exitCode = 2; }
}
module.exports = { compile, readAuthoredInputs, FACT_FIELDS };
