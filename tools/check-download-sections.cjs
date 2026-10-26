const fs = require('fs');

const products = ['cache-vault', 'cleanroom', 'forgecast', 'ghostlayer', 'lights-out', 'proofshot', 'reality-gate'];

for (const p of products) {
  const filePath = `C:/Users/KickA/pf-v5-continuity/public/${p}/index.html`;
  const html = fs.readFileSync(filePath, 'utf8');
  const dlMatch = html.match(/<section[^>]*id="download"[^>]*>([\s\S]*?)<\/section>/i);
  if (dlMatch) {
    const h2 = (dlMatch[1].match(/<h2\b[^>]*>([\s\S]*?)<\/h2>/i) || [])[1] || '';
    const kicker = (dlMatch[1].match(/<p\b[^>]*class="[^"]*kicker[^"]*"[^>]*>([\s\S]*?)<\/p>/i) || [])[1] || '';
    console.log(`${p}:`);
    console.log(`  kicker: "${kicker.trim()}"`);
    console.log(`  h2: "${h2.trim()}"`);
  }
}
