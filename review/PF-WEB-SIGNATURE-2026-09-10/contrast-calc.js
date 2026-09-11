// Deterministic WCAG 2.1 contrast ratio calculator
// For the .product-theater gradient background elements

function srgbToLinear(c) {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}

function luminance(r, g, b) {
  return 0.2126 * srgbToLinear(r) + 0.7152 * srgbToLinear(g) + 0.0722 * srgbToLinear(b);
}

function contrast(fg, bg) {
  const l1 = luminance(fg[0], fg[1], fg[2]);
  const l2 = luminance(bg[0], bg[1], bg[2]);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

function parseRgb(s) {
  const m = s.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  return m ? [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])] : null;
}

// Theater solid fallback: #17201f = rgb(23, 32, 31)
const solidBg = [23, 32, 31];

// Lightest gradient point 1 (linear gradient at 0%): brass tint 10% over solid
// 0.1*(214,168,79) + 0.9*(23,32,31) = (42, 46, 36) ≈ #2a2e24
const gradLightest1 = [42, 46, 36];

// Lightest gradient point 2 (radial at 82%,20%): green tint 22% over solid
// 0.22*(83,121,99) + 0.78*(23,32,31) = (36, 52, 46) ≈ #243429
const gradLightest2 = [36, 52, 46];

// Pressed button background: #efc978 = rgb(239, 201, 120)
const pressedBg = [239, 201, 120];

const cleanroomBg = [199, 213, 209]; // #c7d5d1

const elements = [
  { sel: '.theater-top .kicker', text: 'A working view from the collection', fg: 'rgb(192, 204, 189)', size: '10px', weight: '500', bgType: 'theater-gradient' },
  { sel: '.theater-context', text: 'Select a tool. See the real interface.', fg: 'rgb(152, 165, 158)', size: '11.2px', weight: '400', bgType: 'theater-gradient' },
  { sel: '.theater-index', text: '01 / 07', fg: 'rgb(239, 201, 120)', size: '11px', weight: '400', bgType: 'theater-gradient' },
  { sel: 'h2[data-theater-name]', text: 'Cache Vault', fg: 'rgb(242, 238, 228)', size: '27.2px', weight: '500', bgType: 'theater-gradient' },
  { sel: 'p[data-theater-line]', text: 'Your clipboard, with a memory.', fg: 'rgb(190, 201, 193)', size: '13.44px', weight: '400', bgType: 'theater-gradient' },
  { sel: 'a[data-theater-link]', text: 'Explore', fg: 'rgb(242, 238, 228)', size: '12.16px', weight: '400', bgType: 'theater-gradient+link-bg' },
  { sel: '.theater-film-link', text: 'See it in action', fg: 'rgb(189, 205, 189)', size: '10.72px', weight: '400', bgType: 'theater-gradient' },
  { sel: 'button[aria-pressed="true"] > span', text: 'Cache Vault (pressed)', fg: 'rgb(24, 32, 29)', size: '10.88px', weight: '400', bgType: 'pressed-button' },
  { sel: 'button:not([aria-pressed="true"]) > span', text: 'Reality Gate (unpressed)', fg: 'rgb(170, 184, 173)', size: '10.88px', weight: '400', bgType: 'theater-gradient' },
  { sel: '.card-cleanroom .card-explore', text: 'Explore Cleanroom ↗', fg: 'rgb(14, 40, 36)', size: '14.4px', weight: '650', bgType: 'cleanroom-card' },
  { sel: '.card-cleanroom .card-value', text: 'Reversible cleanup for project trees', fg: 'rgb(56, 82, 77)', size: '16px', weight: '400', bgType: 'cleanroom-card' },
  { sel: '.card-cleanroom .card-name a', text: 'Cleanroom', fg: 'rgb(13, 36, 32)', size: '28.8px', weight: '600', bgType: 'cleanroom-card' },
];

const largeTextThreshold = 4.5; // WCAG AA normal text
const largeTextAAThreshold = 3.0; // WCAG AA large text (>=18px or >=14px bold)
const aaaThreshold = 7.0; // WCAG AAA normal text

function isLargeText(size, weight) {
  const px = parseFloat(size);
  const isBold = parseInt(weight) >= 700;
  return (px >= 18) || (px >= 14 && isBold);
}

console.log('=== GRADIENT CONTRAST ADJUDICATION ===');
console.log('Theater background: linear-gradient + radial-gradient over solid #17201f');
console.log('Solid fallback: rgb(23, 32, 31)');
console.log('Lightest gradient point 1 (brass 10%): rgb(42, 46, 36)');
console.log('Lightest gradient point 2 (green 22%): rgb(36, 52, 46)');
console.log('');

for (const el of elements) {
  const fg = parseRgb(el.fg);
  if (!fg) { console.log(`SKIP ${el.sel}: cannot parse ${el.fg}`); continue; }

  const large = isLargeText(el.size, el.weight);
  const threshold = large ? largeTextAAThreshold : largeTextThreshold;
  const thresholdLabel = large ? 'AA large (3.0)' : 'AA normal (4.5)';

  let bgUsed, bgLabel;
  if (el.bgType === 'pressed-button') {
    bgUsed = pressedBg;
    bgLabel = 'pressed bg rgb(239,201,120)';
  } else if (el.bgType === 'cleanroom-card') {
    bgUsed = cleanroomBg;
    bgLabel = 'cleanroom card bg rgb(199,213,209)';
  } else {
    // Use the lightest gradient point (worst case for light text)
    const c1 = contrast(fg, gradLightest1);
    const c2 = contrast(fg, gradLightest2);
    bgUsed = c1 < c2 ? gradLightest1 : gradLightest2;
    bgLabel = `lightest gradient point rgb(${bgUsed.join(',')})`;
  }

  const ratioSolid = contrast(fg, solidBg);
  const ratioLightest = contrast(fg, bgUsed);
  const pass = ratioLightest >= threshold;
  const aaaPass = ratioLightest >= aaaThreshold;

  console.log(`Element: ${el.sel}`);
  console.log(`  Text: "${el.text}"`);
  console.log(`  Foreground: ${el.fg} | Size: ${el.size} | Weight: ${el.weight} | ${large ? 'LARGE' : 'NORMAL'} text`);
  console.log(`  Background: ${bgLabel}`);
  console.log(`  Contrast vs solid:    ${ratioSolid.toFixed(2)}:1`);
  console.log(`  Contrast vs lightest: ${ratioLightest.toFixed(2)}:1  (worst case)`);
  console.log(`  Threshold: ${thresholdLabel} → ${pass ? 'PASS' : 'FAIL'}`);
  console.log(`  AAA (7.0): ${aaaPass ? 'PASS' : 'FAIL'}`);
  console.log('');
}
