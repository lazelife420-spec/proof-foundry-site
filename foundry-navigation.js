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
  // Keep connected artwork inside the complete document snapshot. Extracting a
  // small coupling into its own snapshot can clip the surrounding maker detail.
  const name = el => { selected = el; };
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
      const query=finder.elements.query, group=finder.elements.group, availability=finder.elements.availability;
      const normalize=s=>s.normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      // The finder searches a fixed text per card (group, name, availability, purpose, state and note), read once, so a
      // query's result never depends on which parts of a card are currently rendered. A card with a public download also
      // answers to "installer" (its product page offers the installer), so a search for something to install finds the
      // installable products, not only the cards that say "No public installer". A card without a public download answers
      // to "no public installer" also where its group states that once instead of a badge on every card.
      const fields=new Map(cards.map(card=>[card,[card.dataset.directoryGroup||'',...[...card.querySelectorAll('h3,.directory-availability,.directory-purpose,.directory-state,.directory-state-note')].map(e=>e.textContent),card.dataset.availability==='download'?'installer':'no public installer'].map(s=>normalize(s).replace(/\s+/g,' ').trim()).filter(Boolean)]));
      const searchText=new Map(cards.map(card=>[card,fields.get(card).join(' ')]));
      // Words: runs of letters, digits and dots (so a version such as v0.3.1 stays whole; it is also indexed without its v).
      const words=s=>s.split(/[^\p{L}\p{N}.]+/u).map(w=>w.replace(/^\.+|\.+$/g,'')).filter(Boolean);
      const searchWords=new Map(cards.map(card=>[card,words(searchText.get(card)).flatMap(w=>/^v\d/.test(w)?[w,w.slice(1)]:[w])]));
      // Two or three consecutive words of one field written together ("lightsout", "cachevault", "prooffoundryapp").
      const compounds=new Map(cards.map(card=>[card,fields.get(card).flatMap(field=>{const w=words(field),out=[];
        for (let i=0;i<w.length;i++) for (let k=2;k<=3&&i+k<=w.length;k++) out.push({joined:w.slice(i,i+k).join(''),first:w[i].length});
        return out;})]));
      // A term of three or more characters matches anywhere in the card's text ("room", "clean room", "tool contract"),
      // also without its dots ("ghost.layer"), as consecutive words written together ("lightsout"; while typing, once it
      // reaches three letters into the second word) and, for a plural, as its singular ("downloads").
      // A one- or two-character fragment of a version ("1", "11", "v1") matches the start of a version. Any other one- or
      // two-character term must be a whole word ("no public" finds "No public installer", not "not offered here"), unless
      // it is still being typed (then it only has to start a word) or it joins a neighbouring term into text of the card
      // ("clean up" finds "cleanup").
      const termMatches=(card,terms,i,typing)=>{
        const t=terms[i], text=searchText.get(card), w=searchWords.get(card);
        if (t.length>2) {
          const forms=[t,t.replace(/\./g,'')];
          if (t.length>4&&/[^s]s$/.test(t)) forms.push(t.endsWith('ies')?t.slice(0,-3)+'y':t.slice(0,-1));
          return forms.some(f=>f&&(text.includes(f)||compounds.get(card).some(c=>c.joined===f||(c.joined.startsWith(f)&&f.length>=c.first+3))));
        }
        if (/\d/.test(t)) return w.some(x=>x.startsWith(t));
        return w.includes(t)||(i===terms.length-1&&typing&&w.some(x=>x.startsWith(t)))||
          (i>0&&text.includes(terms[i-1]+t))||(i<terms.length-1&&text.includes(t+terms[i+1]));
      };
      const update=()=>{
        const terms=words(normalize(query.value)), typing=!/\s$/.test(query.value);
        let count=0;
        for (const card of cards) {
          const match=(!group.value||card.dataset.directoryGroup===group.value)&&(!availability||!availability.value||card.dataset.availability===availability.value)&&
            terms.every((t,i)=>termMatches(card,terms,i,typing));
          card.hidden=!match;if(match)count++;
        }
        const filtering=terms.length>0||!!group.value||!!(availability&&availability.value);
        // No number at rest. Once a filter has been cleared, the status says so ("All shown"), so the reset is announced.
        const status=finder.querySelector('[data-directory-count]');
        status.textContent=filtering?count+' shown':(status.textContent?'All shown':'');
        for (const radio of finder.querySelectorAll('.directory-chip input')) radio.checked=radio.value===(availability?availability.value:'');
        document.querySelector('[data-directory-empty]').hidden=count!==0;
        // The history entry keeps the query and category, so Back restores them even without the page cache. It is saved
        // once typing pauses (and when the page is left), so the browser never throttles it.
        clearTimeout(saveTimer);saveTimer=setTimeout(save,400);
      };
      let saveTimer=0;
      const save=()=>{
        clearTimeout(saveTimer);
        const prev=history.state&&history.state.pfFinder;
        const now={query:query.value,group:group.value,availability:availability?availability.value:''};
        if (prev&&prev.query===now.query&&prev.group===now.group&&(prev.availability||'')===now.availability) return;
        try { history.replaceState({...(history.state||{}),pfFinder:now},''); } catch {}
      };
      addEventListener('pagehide',save);
      finder.addEventListener('submit',e=>e.preventDefault());
      finder.addEventListener('input',update);
      finder.addEventListener('change',update);
      finder.addEventListener('reset',()=>requestAnimationFrame(update));
      // The availability select (All products / Available downloads / No public installer) becomes one compact selector of
      // native radio buttons (one choice, one tab stop, arrow keys move between them); the select stays the source of
      // truth and the no-script form. The category select stays in the form, hidden: the two groups are labelled sections.
      // Each radio sets the select before the form's own input/change listener runs update().
      const groupField=group.closest('label');
      if (groupField) groupField.hidden=true;
      const availabilityField=availability&&availability.closest('label');
      if (availabilityField && availability.options.length>1) {
        const chips=document.createElement('div');
        chips.className='directory-chips';chips.setAttribute('role','radiogroup');chips.setAttribute('aria-label',(availabilityField.firstChild.textContent||'Show').trim());
        for (const option of availability.options) {
          const chip=document.createElement('label'), radio=document.createElement('input');
          chip.className='directory-chip';
          radio.type='radio';radio.name='directory-availability-chip';radio.value=option.value;radio.defaultChecked=option.value===availability.value;
          radio.setAttribute('aria-controls','directory-results');
          for (const type of ['input','change']) radio.addEventListener(type,()=>{if(radio.checked)availability.value=radio.value;});
          chip.append(radio,option.textContent);chips.append(chip);
        }
        availabilityField.after(chips);availabilityField.hidden=true;
      }
      // Back without the page cache: the query (autocomplete is off) and the category come back from the history entry,
      // before the first update() rewrites it; the browser restores the category itself only by pageshow, so the finder
      // re-reads its controls then.
      const saved=history.state&&history.state.pfFinder;
      if (saved) {
        query.value=String(saved.query||'');
        if ([...group.options].some(o=>o.value===saved.group)) group.value=saved.group;
        if (availability&&[...availability.options].some(o=>o.value===saved.availability)) availability.value=saved.availability;
      }
      finder.hidden=false;update();
      addEventListener('pageshow',update);
    }
  }, { once:true });
  // The compact section menu (data-quicknav) on pages other than Home: an open row of links from 901 px, a Menu
  // disclosure below that closes on Escape, an outside press or focus leaving it. Home's own script handles Home's.
  document.addEventListener('DOMContentLoaded', () => {
    const quickNav=document.querySelector('[data-quicknav]');
    if (!quickNav||document.body.classList.contains('pf-ledger-page')) return;
    const wide=matchMedia('(min-width: 901px)');
    const sync=()=>{ quickNav.open=wide.matches; };
    sync(); wide.addEventListener('change', sync);
    quickNav.addEventListener('keydown', e => { if (e.key!=='Escape'||wide.matches||!quickNav.open) return; quickNav.open=false; quickNav.querySelector('summary').focus(); });
    document.addEventListener('pointerdown', e => { if (!wide.matches&&quickNav.open&&!quickNav.contains(e.target)) quickNav.open=false; });
    quickNav.addEventListener('focusout', e => { if (!wide.matches&&quickNav.open&&e.relatedTarget&&!quickNav.contains(e.relatedTarget)) quickNav.open=false; });
    quickNav.addEventListener('click', e => {
      if (wide.matches||!quickNav.open||e.defaultPrevented||e.button!==0||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey||!e.target.closest('nav a[href]')) return;
      quickNav.open=false; quickNav.querySelector('summary').focus({ preventScroll:true });
    });
    addEventListener('pageshow', e => { if (e.persisted) sync(); });
  }, { once:true });
  addEventListener('hashchange', revealFragment);
  addEventListener('pageshow', syncRouteBearing);
  addEventListener('pageshow', e => { if (e.persisted) clear(); });
})();
