// Deterministic layout probe: horizontal overflow, clipping detection, and element bounds.
(function () {
  const de = document.documentElement;
  const vw = window.innerWidth || de.clientWidth;
  const vh = window.innerHeight || de.clientHeight;

  const overflowers = [];
  const clippedElements = [];
  const probedBounds = {};

  const probeSelectors = {
    header: '.site-header',
    heroLockup: '.home-brand-lockup',
    kicker: '.home-copy > .kicker',
    headline: '#home-title',
    lede: '.home-lede',
    primaryCta: '.studio-actions .button-primary',
    releaseRecordAction: '.home-secondary-action',
    reassurance: '.home-reassurance',
    productTheater: '.product-theater',
    theaterText: '.theater-description',
    theaterControls: '.theater-controls'
  };

  for (const [key, sel] of Object.entries(probeSelectors)) {
    const el = document.querySelector(sel);
    if (el) {
      const r = el.getBoundingClientRect();
      probedBounds[key] = {
        left: Math.round(r.left),
        top: Math.round(r.top),
        right: Math.round(r.right),
        bottom: Math.round(r.bottom),
        width: Math.round(r.width),
        height: Math.round(r.height)
      };
    }
  }

  const textAndControlSelector = 'h1, h2, h3, h4, p, a:not(.catalog-image-link):not(.screenshot-link), button, label, input, select, dt, dd, span.kicker, .reassurance-index, .identity-index';
  const candidateElements = document.querySelectorAll(textAndControlSelector);

  for (const el of candidateElements) {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || cs.opacity === '0') continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;

    // Ignore decorative elements explicitly transformed/hidden by design
    if (el.closest('.theater-side-note')) continue;

    if (r.left < -1 || r.right > vw + 1) {
      clippedElements.push({
        tag: el.tagName.toLowerCase(),
        cls: (el.className && typeof el.className === 'string' ? el.className : '').substring(0, 60),
        text: (el.textContent || '').trim().substring(0, 40),
        left: Math.round(r.left),
        right: Math.round(r.right),
        vw: vw
      });
    }
  }

  const all = document.querySelectorAll('body *');
  for (const el of all) {
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden') continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    const overhang = Math.round(r.right - vw);
    if (overhang > 1) {
      overflowers.push({
        tag: el.tagName.toLowerCase(),
        cls: (el.className && typeof el.className === 'string' ? el.className : '').substring(0, 60),
        right: Math.round(r.right),
        overhang: overhang
      });
    }
  }

  return JSON.stringify({
    viewport: { width: vw, height: vh },
    windowInnerWidth: window.innerWidth,
    documentElementClientWidth: de.clientWidth,
    documentScrollWidth: de.scrollWidth,
    bodyScrollWidth: document.body.scrollWidth,
    horizontalOverflowPx: Math.max(0, de.scrollWidth - vw),
    hasHorizontalScroll: de.scrollWidth > vw + 1,
    fullPageHeight: de.scrollHeight,
    clippedTextOrControlCount: clippedElements.length,
    clippedTextOrControls: clippedElements.slice(0, 10),
    overflowingElementCount: overflowers.length,
    overflowingElements: overflowers.slice(0, 10),
    probedBounds: probedBounds
  }, null, 2);
})();
