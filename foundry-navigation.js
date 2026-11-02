/* Native same-origin document navigation. No intercepted links, router or delayed fetch. */
(() => {
  const root = document.documentElement;
  // Keep the JS-enhanced phone header at its final height from first paint.
  // If the navigation controller fails, DOMContentLoaded releases the normal
  // fully visible HTML fallback. The actual toggle is enabled by site.js.
  root.dataset.navShell = 'pending';
  document.addEventListener('DOMContentLoaded', () => { delete root.dataset.navShell; }, {once:true});
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches || matchMedia('(forced-colors: active)').matches;
  let off = reduced;
  try { off ||= localStorage.getItem('pf-motion') === 'off'; } catch {}
  root.dataset.travel = off ? 'off' : 'on';
  root.dataset.travelKind = 'junction';
  const updatePreference = () => {
    off = matchMedia('(prefers-reduced-motion: reduce)').matches || matchMedia('(forced-colors: active)').matches || root.dataset.motion === 'off';
    root.dataset.travel = off ? 'off' : 'on';
  };
  new MutationObserver(updatePreference).observe(root, {attributes:true,attributeFilter:['data-motion']});
  matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change', updatePreference);
  matchMedia('(forced-colors: active)').addEventListener('change', updatePreference);
  let selected = null;
  const name = el => { if (el) { el.style.viewTransitionName = 'foundry-joint'; selected = el; } };
  const clear = keep => {
    if (selected) selected.style.viewTransitionName = '';
    selected = null;
    document.querySelectorAll('[data-engaged]').forEach(el => { if (el !== keep) el.removeAttribute('data-engaged'); });
  };
  const direction = activation => activation?.navigationType === 'traverse' && activation.entry?.index < activation.from?.index ? 'back' : 'forward';
  document.addEventListener('pointerdown', e => {
    const a = e.target.closest('a[href]');
    if (a && e.button === 0) a.dataset.engaged = 'true';
  }, {passive:true});
  document.addEventListener('pointercancel', () => clear(), {passive:true});
  document.addEventListener('click', e => {
    const a = e.target.closest('a[href]');
    if (!a || e.defaultPrevented || e.button || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || a.target || a.hasAttribute('download')) return;
    const url = new URL(a.href);
    if (url.origin !== location.origin || url.pathname === location.pathname) return;
    const world = a.dataset.worldLink || url.pathname.split('/').filter(Boolean).at(-1) || 'home';
    const joint = a.querySelector('[data-joint]') || a.closest('[data-product]')?.querySelector('[data-joint]');
    const mount = joint?.getBoundingClientRect();
    const origin = mount ? {x:(mount.x + mount.width / 2) / innerWidth, y:(mount.y + mount.height / 2) / innerHeight} : null;
    try { sessionStorage.setItem('pf-travel', JSON.stringify({to:url.pathname, world, hasJoint:!!joint, origin, at:Date.now(), from:location.pathname})); } catch {}
    if (!off) {
      clear(a);
      a.dataset.engaged = 'true';
      name(joint);
      root.dataset.departure = world;
      root.dataset.travelKind = joint ? 'joint' : 'junction';
      root.dataset.travelDirection = 'forward';
    }
    performance.mark('foundry:navigation-selected');
  });
  addEventListener('pageswap', e => {
    if (!e.viewTransition || off) return;
    root.dataset.travelDirection = direction(e.activation);
    if (e.activation?.navigationType === 'traverse') {
      clear();
      root.dataset.travelKind = 'junction';
      // Chrome can reveal a history document before its snapshot is ready.
      // Keep native history/scroll restoration; animate selected-link travel only.
      e.viewTransition.ready.catch(() => { /* skipped history transition: static fallback */ });
      e.viewTransition.skipTransition();
    }
    e.viewTransition.finished.then(() => clear(), () => clear());
  });
  // Parser-blocking in the head: registered before the incoming document's first render.
  addEventListener('pagereveal', e => {
    let intent;
    try { intent = JSON.parse(sessionStorage.getItem('pf-travel')); sessionStorage.removeItem('pf-travel'); } catch {}
    if (!e.viewTransition || off) return;
    const activation = window.navigation?.activation;
    const validIntent = activation?.navigationType !== 'traverse' && intent?.to === location.pathname && Date.now() - intent.at < 15000;
    const world = document.body?.dataset.foundryWorld || 'home';
    const key = validIntent ? intent.world : world;
    root.dataset.arrival = key;
    root.dataset.travelDirection = direction(activation);
    root.dataset.travelKind = validIntent && intent.hasJoint ? 'joint' : 'junction';
    if (root.dataset.travelKind === 'joint') {
      name(document.querySelector('.hero-joint [data-joint],.record-joint[data-joint]') || document.querySelector('[data-joint="' + CSS.escape(key) + '"]'));
      // The arriving scene opens at the actual outgoing coupling, then follows
      // the native shared-element journey to its destination mounting point.
      const mount = selected?.getBoundingClientRect();
      const clamp = value => Math.max(0, Math.min(1, value));
      const origin = intent.origin;
      if (mount && Number.isFinite(origin?.x) && Number.isFinite(origin?.y)) {
        const x = clamp((mount.x + mount.width / 2) / innerWidth) * innerWidth;
        const y = clamp((mount.y + mount.height / 2) / innerHeight) * innerHeight;
        root.style.setProperty('--travel-from-x', `${clamp(origin.x) * innerWidth}px`);
        root.style.setProperty('--travel-from-y', `${clamp(origin.y) * innerHeight}px`);
        root.style.setProperty('--travel-to-x', `${x}px`);
        root.style.setProperty('--travel-to-y', `${y}px`);
        root.style.setProperty('--travel-radius', `${Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y)) + 1}px`);
      }
    }
    performance.mark('foundry:destination-reveal');
    e.viewTransition.ready.then(() => { if (selected) selected.style.viewTransitionName = ''; }, () => clear());
    e.viewTransition.finished.then(() => clear(), () => clear());
  });

  // Route engraving is a projection of the actual URL, not a release claim.
  // Only this presentation block changes; native navigation and history stay intact.
  const productStops = [
    ['cache-vault', 'CACHE VAULT'], ['proofshot', 'PROOFSHOT'],
    ['lights-out', 'LIGHTS OUT'], ['cleanroom', 'CLEANROOM'],
    ['ghostlayer', 'GHOSTLAYER'], ['forgecast', 'FORGECAST'],
    ['reality-gate', 'REALITY GATE']
  ];
  const junctions = {
    '/': ['ENTRY / HOME', 'HOME', .025],
    '/software/': ['JUNCTION / PRODUCTS', 'PRODUCTS', .5],
    '/proof/': ['METHOD / PROOF', 'PROOF', .5],
    '/proof-standard/': ['METHOD / PROOF STANDARD', 'PROOF', .5],
    '/truth-files/': ['RECORDS / TRUTH FILES', 'TRUTH', .5],
    '/about/': ['FOUNDRY / ABOUT', 'ABOUT', .5],
    '/support/': ['SERVICE / SUPPORT', 'HELP', .5]
  };
  const routePath = path => {
    const clean = path.replace(/\/index\.html$/, '/');
    return clean === '/' ? '/' : '/' + clean.split('/').filter(Boolean).join('/') + '/';
  };
  const syncRouteBearing = () => {
    const current = routePath(location.pathname);
    const parts = current.split('/').filter(Boolean);
    const reverse = parts[0] === 'truth-files';
    const index = productStops.findIndex(([slug]) => slug === (reverse ? parts[1] : parts[0]));
    const station = index >= 0 && (reverse ? parts.length === 2 : parts.length === 1);
    const label = station
      ? [(reverse ? 'REVERSE / ' : 'STATION / ') + productStops[index][1],
         String(index + 1).padStart(2, '0') + ' / ' + String(productStops.length).padStart(2, '0'),
         .05 + index * .15]
      : junctions[current] || ['PROOF FOUNDRY', 'INDEX', .5];
    const rail = document.querySelector('.pf-journey-rail');
    if (rail) {
      rail.style.setProperty('--pf-route-position', String(label[2]));
      const long = rail.querySelector('[data-pf-route-long]');
      const short = rail.querySelector('[data-pf-route-short]');
      if (long) long.textContent = label[0];
      if (short) short.textContent = label[1];
    }
    document.querySelectorAll('.top-nav a[href], .nav-cta[href], .pf-route-chain a[href]').forEach(a => {
      try {
        const url = new URL(a.href);
        if (url.origin === location.origin && routePath(url.pathname) === current) {
          a.setAttribute('aria-current', 'page');
        }
      } catch { /* A malformed optional link cannot affect ordinary navigation. */ }
    });
  };
  const revealFragment = () => {
    if (!location.hash) return;
    let target;
    try { target = document.getElementById(decodeURIComponent(location.hash.slice(1))); } catch {}
    if (!target) return;
    for (let node = target; node; node = node.parentElement) if (node.tagName === 'DETAILS') node.open = true;
  };
  document.addEventListener('DOMContentLoaded', () => {
    syncRouteBearing(); revealFragment();
    const finder=document.querySelector('[data-directory-finder]');
    if (finder) {
      const cards=[...document.querySelectorAll('[data-directory-entry]')];
      const query=finder.elements.query, group=finder.elements.group;
      const normalize=s=>s.normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      const update=()=>{
        const terms=normalize(query.value).trim().split(/\s+/).filter(Boolean);
        let count=0;
        for (const card of cards) {
          const match=(!group.value||card.dataset.directoryGroup===group.value)&&terms.every(t=>normalize(card.innerText).includes(t));
          card.hidden=!match;if(match)count++;
        }
        finder.querySelector('[data-directory-count]').textContent=count+' '+(count===1?'product':'products');
        document.querySelector('[data-directory-empty]').hidden=count!==0;
      };
      finder.addEventListener('submit',e=>e.preventDefault());
      finder.addEventListener('input',update);
      finder.addEventListener('change',update);
      finder.addEventListener('reset',()=>requestAnimationFrame(update));
      finder.hidden=false;update();
    }
  }, { once:true });
  addEventListener('hashchange', revealFragment);
  addEventListener('pageshow', syncRouteBearing);
  addEventListener('pageshow', e => { if (e.persisted) clear(); });
})();
