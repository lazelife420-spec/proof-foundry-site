const results = [];
const theater = document.querySelector('.product-theater');
if (!theater) { JSON.stringify({error: 'no .product-theater'}); }

const tbg = getComputedStyle(theater).backgroundColor;
const tbgImage = getComputedStyle(theater).backgroundImage;

const selectors = [
  '.theater-top .kicker',
  '.theater-context',
  '.theater-index',
  'h2[data-theater-name]',
  'p[data-theater-line]',
  'a[data-theater-link]',
  '.theater-film-link',
  'button[data-show-product] > span',
  'button[data-show-product][aria-pressed="true"] > span'
];

for (const sel of selectors) {
  const els = theater.querySelectorAll(sel);
  for (const el of els) {
    const cs = getComputedStyle(el);
    results.push({
      selector: sel,
      text: el.textContent.trim().substring(0, 40),
      color: cs.color,
      fontSize: cs.fontSize,
      fontWeight: cs.fontWeight,
      bg: getComputedStyle(el).backgroundColor,
      parentBg: getComputedStyle(el.parentElement).backgroundColor
    });
  }
}

JSON.stringify({theaterBg: tbg, theaterBgImage: tbgImage.substring(0, 200), elements: results}, null, 2);
