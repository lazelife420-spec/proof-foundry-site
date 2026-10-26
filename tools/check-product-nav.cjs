const fs = require('fs');
const path = require('path');

const products = ['cache-vault', 'cleanroom', 'forgecast', 'ghostlayer', 'lights-out', 'proofshot', 'reality-gate'];

for (const p of products) {
  const filePath = `C:/Users/KickA/pf-v5-continuity/public/${p}/index.html`;
  const html = fs.readFileSync(filePath, 'utf8');
  const acqMatch = html.match(/data-acquisition-available="([^"]*)"/i);
  const navMatch = html.match(/<nav class="pf-product-navigation"[^>]*>([\s\S]*?)<\/nav>/i);
  if (navMatch) {
    const links = [...navMatch[1].matchAll(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)].map(m => `${m[1]}: "${m[2].trim()}"`);
    console.log(`${p} (acq=${acqMatch ? acqMatch[1] : 'unknown'}):`);
    console.log('  ' + links.join(' | '));
  } else {
    console.log(`${p}: NO pf-product-navigation`);
  }
}
