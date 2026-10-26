const fs = require('fs');

const cssFiles = [
  'styles.css',
  'studio.css',
  'foundry-world.css',
  'pf-site-ledger.css',
  'pf-foundry-system.css',
  'pf-home-ledger.css',
  'product-page.css',
  'truth-files.css'
];

for (const file of cssFiles) {
  const content = fs.readFileSync(`C:/Users/KickA/pf-v5-continuity/${file}`, 'utf8');
  console.log(`\n=== ${file} ===`);
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.match(/\.(site-header|nav-row|brand-lockup|brand-mark|brand-name|top-nav|nav-cta|site-footer|footer-grid|footer-brand)/)) {
      console.log(`  L${i+1}: ${line.trim().slice(0, 150)}`);
    }
  }
}
