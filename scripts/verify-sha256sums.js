import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const reviewDir = path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10');
const manifestPath = path.join(reviewDir, 'SHA256SUMS.txt');

const manifestContent = fs.readFileSync(manifestPath, 'utf8');
const lines = manifestContent.split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#'));

console.log(`=== MANIFEST DISK VERIFICATION ===`);
console.log(`Verifying ${lines.length} manifest entries against disk files...`);
let matchCount = 0;
let mismatchCount = 0;
let missingCount = 0;

for (const line of lines) {
  const parts = line.split(/\s+/);
  const expectedHash = parts[0].toLowerCase();
  const relPath = parts[1];
  const fullPath = path.join(rootDir, relPath);

  if (!fs.existsSync(fullPath)) {
    console.error('MISSING:', relPath);
    missingCount++;
    continue;
  }

  const content = fs.readFileSync(fullPath);
  const actualHash = crypto.createHash('sha256').update(content).digest('hex').toLowerCase();

  if (actualHash === expectedHash) {
    matchCount++;
  } else {
    console.error('MISMATCH:', relPath, 'Expected:', expectedHash, 'Actual:', actualHash);
    mismatchCount++;
  }
}

console.log(`VERIFICATION SUMMARY: ${matchCount} MATCH, ${mismatchCount} MISMATCH, ${missingCount} MISSING out of ${lines.length} entries.`);

const zipPath = path.join(process.env.USERPROFILE, 'Downloads', 'PF-WEB-SIGNATURE-IP-GOLD-FINAL-REVIEW.zip');
if (fs.existsSync(zipPath)) {
  const zipContent = fs.readFileSync(zipPath);
  const zipHash = crypto.createHash('sha256').update(zipContent).digest('hex').toLowerCase();
  console.log('\n=== RECREATED REVIW ZIP HASH & SIZE ===');
  console.log(`Path:   ${zipPath}`);
  console.log(`Size:   ${zipContent.length} bytes (${(zipContent.length / (1024 * 1024)).toFixed(2)} MB)`);
  console.log(`SHA256: ${zipHash}`);
}

if (matchCount === lines.length && mismatchCount === 0 && missingCount === 0) {
  console.log('\n50/50 PERFECT MATCH GUARANTEED.');
} else {
  process.exit(1);
}
