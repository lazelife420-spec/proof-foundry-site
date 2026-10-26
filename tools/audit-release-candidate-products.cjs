'use strict';
const fs = require('node:fs');
const path = require('node:path');

const root = 'C:/Users/KickA/pf-v5-continuity';
const publicDir = path.join(root, 'public');

const manifest = JSON.parse(fs.readFileSync(path.join(root, 'site-manifest.json'), 'utf8'));
const proofRegistry = JSON.parse(fs.readFileSync(path.join(publicDir, 'proof', 'index.json'), 'utf8'));

const products = ['proofshot', 'cache-vault', 'lights-out', 'cleanroom', 'ghostlayer', 'forgecast', 'reality-gate'];

console.log('=== PRODUCT-BY-PRODUCT RELEASE AUDIT ===\n');

const auditResults = [];

for (const id of products) {
  const pageHtml = fs.readFileSync(path.join(publicDir, id, 'index.html'), 'utf8');
  const truthJson = JSON.parse(fs.readFileSync(path.join(publicDir, 'truth', 'products', `${id}.json`), 'utf8'));
  const tfHtml = fs.readFileSync(path.join(publicDir, 'truth-files', id, 'index.html'), 'utf8');
  const regEntry = proofRegistry.products.find(p => p.id === id);

  // Check subnav wayfinding label for #download
  const navMatch = pageHtml.match(/<nav class="pf-product-navigation"[^>]*>([\s\S]*?)<\/nav>/i);
  let subnavLabel = 'MISSING';
  if (navMatch) {
    const dlMatch = navMatch[1].match(/<a[^>]*data-product-section="download"[^>]*>(.*?)<\/a>/i);
    if (dlMatch) subnavLabel = dlMatch[1].trim();
  }

  // Check body acquisition eligibility
  const acqMatch = pageHtml.match(/data-acquisition-available="([^"]*)"/i);
  const acqAvailable = acqMatch ? acqMatch[1] : 'unknown';

  // Check hero primary action
  const heroActionMatch = pageHtml.match(/<div class="studio-actions">([\s\S]*?)<\/div>/i);
  let heroPrimary = 'MISSING';
  if (heroActionMatch) {
    const btnMatch = heroActionMatch[1].match(/<a[^>]*class="button[^"]*"[^>]*>(.*?)<\/a>/i);
    if (btnMatch) heroPrimary = btnMatch[1].trim();
  }

  // Check download section & offered download links
  const downloadSectionMatch = pageHtml.match(/<section[^>]*id="download"[^>]*>([\s\S]*?)<\/section>/i);
  const downloadLinks = downloadSectionMatch
    ? [...downloadSectionMatch[1].matchAll(/href="(https:\/\/downloads\.theprooffoundry\.com\/[^"]+)"/g)].map(m => m[1])
    : [];

  // Check artifact hashes presence in pageHtml
  const artifacts = regEntry.artifacts || [];
  const hashesVerified = artifacts.every(a => {
    if (!a.sha256) return true;
    return pageHtml.includes(a.sha256);
  });

  // Check special disclosures
  const hasProofshotLicensing = id === 'proofshot'
    ? pageHtml.includes('Open finding: licensing authority') && pageHtml.includes('60/60')
    : 'N/A';

  const hasRealityGateWithdrawal = id === 'reality-gate'
    ? pageHtml.includes('permanently withdrawn') && downloadLinks.length === 0
    : 'N/A';

  auditResults.push({
    id,
    releaseStatus: regEntry.release ? regEntry.release.releaseStatus : 'UNKNOWN',
    publicVersion: regEntry.release ? regEntry.release.publicVersion : (regEntry.release.withdrawnVersion ? `Withdrawn v${regEntry.release.withdrawnVersion}` : 'None'),
    acqAvailable,
    subnavLabel,
    heroPrimary,
    downloadCount: downloadLinks.length,
    downloadUrls: downloadLinks,
    hashesVerified,
    hasProofshotLicensing,
    hasRealityGateWithdrawal
  });
}

console.table(auditResults.map(r => ({
  Product: r.id,
  Status: r.releaseStatus,
  Version: r.publicVersion,
  AcqAvailable: r.acqAvailable,
  Subnav: r.subnavLabel,
  HeroCTA: r.heroPrimary,
  Downloads: r.downloadCount,
  HashesMatch: r.hashesVerified,
  SpecialGuard: r.id === 'proofshot' ? `Licensing: ${r.hasProofshotLicensing}` : (r.id === 'reality-gate' ? `Withdrawn: ${r.hasRealityGateWithdrawal}` : 'OK')
})));

// Print details
for (const r of auditResults) {
  console.log(`\n--- ${r.id} ---`);
  console.log(`  Download URLs: ${r.downloadUrls.join(', ') || 'NONE'}`);
}
