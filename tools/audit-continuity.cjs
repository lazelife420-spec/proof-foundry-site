const fs = require('fs');
const path = require('path');

const publicDir = 'C:/Users/KickA/pf-v5-continuity/public';

function getHtmlFiles(dir) {
  let files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!entry.name.startsWith('__')) {
        files = files.concat(getHtmlFiles(full));
      }
    } else if (entry.name.endsWith('.html')) {
      files.push(full);
    }
  }
  return files;
}

const htmlFiles = getHtmlFiles(publicDir);
console.log(`Found ${htmlFiles.length} public HTML pages.`);

const summary = [];

for (const f of htmlFiles) {
  const rel = f.replace(publicDir, '').replace(/\\/g, '/');
  const html = fs.readFileSync(f, 'utf8');

  // Stylesheets
  const cssMatches = [...html.matchAll(/<link\b[^>]*\bhref=["']([^"']+\.css[^"']*)["'][^>]*>/gi)];
  const css = cssMatches.map(m => m[1]);

  // Header
  const headerMatch = html.match(/<header\b([^>]*)>([\s\S]*?)<\/header>/i);
  const headerTag = headerMatch ? headerMatch[1].trim() : 'NONE';
  const headerHtml = headerMatch ? headerMatch[2] : '';
  const hasBrandedLogo = headerHtml.includes('brand') || headerHtml.includes('foundry-logo') || headerHtml.includes('site-brand');
  const navAriaCurrent = [...headerHtml.matchAll(/<a\b[^>]*aria-current=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)].map(m => `${m[2].replace(/<[^>]+>/g, '').trim()} (${m[1]})`);
  const navLinks = [...headerHtml.matchAll(/<nav\b[^>]*>([\s\S]*?)<\/nav>/gi)].flatMap(nav => [...nav[1].matchAll(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)].map(a => `${a[1]}: ${a[2].replace(/<[^>]+>/g, '').trim()}`));

  // Footer
  const footerMatch = html.match(/<footer\b([^>]*)>([\s\S]*?)<\/footer>/i);
  const footerTag = footerMatch ? footerMatch[1].trim() : 'NONE';
  const footerHtml = footerMatch ? footerMatch[2] : '';
  const footerLinks = [...footerHtml.matchAll(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi)].map(a => `${a[1]}: ${a[2].replace(/<[^>]+>/g, '').trim()}`);

  // Fonts mentioned in inline style or body
  const bodyTag = (html.match(/<body\b([^>]*)>/i) || [])[1] || '';
  
  // Headings
  const h1Match = (html.match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i) || [])[1] || '';
  const cleanH1 = h1Match.replace(/<[^>]+>/g, '').trim().replace(/\s+/g, ' ');

  // Containers
  const mainMatch = (html.match(/<main\b([^>]*)>/i) || [])[1] || 'NONE';

  summary.push({
    route: rel,
    title: (html.match(/<title>([^<]*)<\/title>/i) || [])[1] || '',
    h1: cleanH1,
    css,
    headerTag,
    hasBrandedLogo,
    navAriaCurrent,
    footerTag,
    bodyTag: bodyTag.trim(),
    mainTag: mainMatch.trim()
  });
}

for (const s of summary) {
  console.log(`\n========================================`);
  console.log(`ROUTE: ${s.route}`);
  console.log(`TITLE: ${s.title}`);
  console.log(`H1: ${s.h1}`);
  console.log(`CSS (${s.css.length}): ${s.css.join(', ')}`);
  console.log(`HEADER: ${s.headerTag} | logo: ${s.hasBrandedLogo}`);
  console.log(`NAV ARIA-CURRENT: ${s.navAriaCurrent.join(', ') || 'NONE'}`);
  console.log(`FOOTER: ${s.footerTag}`);
  console.log(`MAIN: ${s.mainTag}`);
  console.log(`BODY: ${s.bodyTag}`);
}
