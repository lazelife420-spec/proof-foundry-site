import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const reviewDir = path.join(rootDir, 'review', 'PF-WEB-SIGNATURE-2026-09-10');

function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);
  files.forEach(file => {
    const fullPath = path.join(dirPath, file);
    if (fs.statSync(fullPath).isDirectory()) {
      arrayOfFiles = getAllFiles(fullPath, arrayOfFiles);
    } else if (file !== 'SHA256SUMS.txt') {
      arrayOfFiles.push(fullPath);
    }
  });
  return arrayOfFiles;
}

const allFiles = getAllFiles(reviewDir);
const lines = [];

for (const filePath of allFiles) {
  const content = fs.readFileSync(filePath);
  const hash = crypto.createHash('sha256').update(content).digest('hex').toLowerCase();
  const relPath = path.relative(rootDir, filePath).replace(/\\/g, '/');
  lines.push(`${hash}  ${relPath}`);
}

lines.sort();
const header = '# SHA-256 manifest for PF-WEB-SIGNATURE-2026-09-10\n\n';
fs.writeFileSync(path.join(reviewDir, 'SHA256SUMS.txt'), header + lines.join('\n') + '\n', 'utf8');
console.log(`Updated SHA256SUMS.txt with ${lines.length} entries.`);
