// Local, deterministic vector assets for the PF unified-logo review candidate.
// These are brand symbols, not verification, signing or installation claims.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const out = path.resolve(process.argv[2] || path.join(__dirname, '..', 'brand'));
fs.mkdirSync(out, { recursive: true });

// The shipped PF contours are retained exactly. Every derivative shares these
// paths, the same placement and the folded receipt in the P counter.
const p = 'M42 34H116C157 34 181 56 181 91C181 126 157 148 116 148H82V222H42V34ZM82 70V112H115C132 112 141 104 141 91C141 78 132 70 115 70H82Z';
const f = 'M146 34H226V72H186V106H218V143H186V222H146V34Z';
const bridge = 'M138 70H186V106H138Z';
const receipt = 'M90 77H109L118 86V106H90ZM109 77V86H118';
const placement = 'translate(31.52 35.84) scale(.72)';
const mono = 'ui-monospace,Consolas,monospace';
const title = (name, description) => `<title>${name}</title><desc>${description}</desc>`;
const wrap = (name, description, content, box = '0 0 256 256') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${box}" role="img" aria-label="${name}">\n${title(name, description)}\n${content}\n</svg>\n`;
const core = (ink, detail, embossed = false) => `<g data-pf-geometry="shipped-G" transform="${placement}">
  ${embossed ? `<g fill="#c4ceca" transform="translate(1.2 1.8)"><path d="${p}"/><path d="${f}"/><path d="${bridge}"/></g>` : ''}
  <g fill="${ink}"><path d="${p}"/><path d="${f}"/><path d="${bridge}"/></g>
  <path data-maker-mark="receipt-fold" d="${receipt}" fill="none" stroke="${detail}" stroke-width="2" stroke-linejoin="miter"/>
  ${embossed ? '<path d="M95 94H112M95 100H108" fill="none" stroke="#506164" stroke-width="1"/>' : ''}
  <path data-maker-mark="record-crossbar" d="M139 103.5H185" stroke="${detail}" stroke-width="3.1"/>
</g>`;
const register = (ink, width = 1.2) => `<g data-maker-mark="alignment" fill="none" stroke="${ink}" stroke-width="${width}"><path d="M128 7V13M243 128H249M128 243V249M7 128H13"/></g>`;
const stages = (ink) => `<g data-maker-mark="three-stages" fill="none" stroke="${ink}" stroke-width="1.2"><path d="M114 12V16M128 10V16M142 12V16"/></g>`;
const ring = `<g data-maker-mark="pressed-seal" fill="none">
  <circle cx="128" cy="129.1" r="119" stroke="#c1cbc6" stroke-width="1.15"/>
  <circle cx="128" cy="128" r="119" stroke="#27373c" stroke-width="1.5"/>
  <circle cx="128" cy="128.8" r="110" stroke="#c8d2cc" stroke-width=".65"/>
  <circle cx="128" cy="128" r="110" stroke="#35484e" stroke-width=".7"/>
  <circle cx="128" cy="128" r="99" stroke="#415358" stroke-width=".6"/>
</g>`;
const seal = `<defs>
  <path id="pf-maker-top" d="M21 128A107 107 0 0 1 235 128"/>
  <path id="pf-maker-bottom" d="M34 183A109 109 0 0 0 222 183"/>
</defs>
${ring}
${core('#18242a', '#b28c52', true)}
${register('#876d47')}
${stages('#78603b')}
<g fill="#35474c" font-family="${mono}" font-size="7.7" letter-spacing="1.05">
  <text data-maker-mark="source-artifact-record"><textPath href="#pf-maker-top" startOffset="50%" text-anchor="middle">SOURCE / ARTIFACT / RECORD</textPath></text>
  <text data-maker-mark="build-prove-ship" font-size="7.4" letter-spacing=".75"><textPath href="#pf-maker-bottom" startOffset="50%" text-anchor="middle">BUILD IT · PROVE IT · SHIP IT</textPath></text>
</g>
<text data-maker-mark="binary-pf" x="22" y="147" transform="rotate(-90 22 147)" fill="#415359" font-family="${mono}" font-size="3.3" letter-spacing=".55">01010000 01000110</text>
<text data-maker-mark="record-code" x="234" y="112" transform="rotate(90 234 112)" fill="#415359" font-family="${mono}" font-size="3.3" letter-spacing=".55">record(source, artifact)</text>`;

const micro = (dark) => {
  const ink = dark ? '#18242a' : '#f4f0e8';
  const edge = dark ? '#52656a' : '#829396';
  const detail = dark ? '#735927' : '#d6a84f';
  return `<path data-maker-mark="plate-edge" d="M17 7H239L249 17V239L239 249H17L7 239V17Z" fill="none" stroke="${edge}" stroke-width="7"/>
<g data-maker-mark="pressed-seal" fill="none" stroke="${edge}" stroke-width="4"><path d="M37 98A95 95 0 0 1 219 98M219 158A95 95 0 0 1 37 158"/></g>
${core(ink, detail)}
<path data-maker-mark="alignment" d="M128 9V20M236 128H247M128 236V247M9 128H20" stroke="${detail}" stroke-width="5"/>`;
};
const watermark = `<g fill="none" stroke="#293c41"><circle data-maker-mark="pressed-seal" cx="128" cy="128" r="119" stroke-width="1.8"/><circle cx="128" cy="128" r="110" stroke-width=".8"/></g>
${core('#293c41', '#886a36')}
${register('#886a36')}${stages('#886a36')}`;

const fasteners = [[24,24],[376,24],[24,416],[376,416]].map(([x,y], i) => `<g data-maker-mark="fastener-${i + 1}" transform="translate(${x} ${y})"><circle r="4.4" fill="#445257" stroke="#b0b9b3" stroke-width="1"/><path d="M-2.3 0H2.3" transform="rotate(${i === 1 || i === 2 ? -45 : 45})" stroke="#202e34" stroke-width="1.1"/></g>`).join('\n');
const plate = `<defs>
  <linearGradient id="pf-plate-steel" x1="0" y1="0" x2="1" y2=".8"><stop stop-color="#7d8788"/><stop offset=".23" stop-color="#a0a9a6"/><stop offset=".58" stop-color="#627174"/><stop offset="1" stop-color="#818f90"/></linearGradient>
  <filter id="pf-plate-grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".73" numOctaves="3" seed="31"/><feColorMatrix type="saturate" values="0"/></filter>
  <clipPath id="pf-plate-clip"><path d="M10 3H384L397 16V424L384 437H10L3 430V10Z"/></clipPath>
</defs>
<path data-maker-mark="plate-edge" d="M10 3H384L397 16V424L384 437H10L3 430V10Z" fill="url(#pf-plate-steel)" stroke="#b1bbb7" stroke-width="2"/>
<path d="M14 14H382V426H14Z" fill="none" stroke="#44585e" stroke-width="1"/>
<rect width="400" height="440" filter="url(#pf-plate-grain)" clip-path="url(#pf-plate-clip)" opacity=".06"/>
<g transform="translate(47 32) scale(1.1953125)">${seal}</g>
${fasteners}
<path d="M37 373H363" stroke="#405459"/>
<text x="200" y="360" text-anchor="middle" fill="#23363c" font-family="${mono}" font-size="17" font-weight="700" letter-spacing="1.5">THE PROOF FOUNDRY</text>
<text x="200" y="397" text-anchor="middle" fill="#273b40" font-family="${mono}" font-size="9.5" letter-spacing="1.1">BUILD IT · PROVE IT · SHIP IT</text>
<text x="200" y="416" text-anchor="middle" fill="#344b50" font-family="${mono}" font-size="7.5" letter-spacing="1.1">SOURCE / ARTIFACT / RECORD</text>`;

const assets = {
  'PF_MAKER_SEAL.svg': wrap('Proof Foundry pressed maker’s seal', 'The shipped PF cut into an embossed circular impression. Folded receipt, three stage notches, public PF binary and maker microtext. Brand symbolism only.', seal),
  'PF_HEADER_MARK.svg': wrap('Proof Foundry PF micro mark', 'Small-size plate and pressed-seal derivative. Same PF contours, receipt fold and record crossbar. No microtext.', micro(false)),
  'PF_HEADER_MARK_DARK.svg': wrap('Proof Foundry PF micro mark, dark', 'Dark small-size derivative using the same geometry. No microtext.', micro(true)),
  'PF_RECEIPT_WATERMARK.svg': wrap('Proof Foundry secondary receipt watermark', 'Secondary impression of the unified maker’s seal. Brand symbol only; not an approval or verification stamp.', watermark),
  'PF_MAKER_PLATE.svg': wrap('Proof Foundry forged maker’s plate', 'Unified forged-steel plate with the circular maker’s seal pressed into it. Four diagonal registration fasteners. Public maker inscriptions only.', plate, '0 0 400 440')
};
for (const [name, value] of Object.entries(assets)) fs.writeFileSync(path.join(out, name), value, 'utf8');
console.log(JSON.stringify({ assets: Object.keys(assets), output: out, deterministic: true }));
