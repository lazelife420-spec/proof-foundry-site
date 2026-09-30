// Progressive, local-only website experiences. No product or release state is synthesized.
(() => {
"use strict";
const products = {"cache-vault": {"name": "Cache Vault", "tab": "Keep", "line": "Your clipboard, with a memory.", "route": "/cache-vault/", "film": "/cache-vault/#film", "image": {"src": "/assets/studio/cv-quick-paste-700.webp", "srcset": "/assets/studio/cv-quick-paste-480.webp 480w, /assets/studio/cv-quick-paste-700.webp 700w", "original": "/assets/cache-vault/cv-quick-paste.png", "width": 700, "height": 682, "alt": "Cache Vault Quick Paste showing searchable sample clips."}, "category": "Local clipboard archive"}, "reality-gate": {"name": "Reality Gate", "tab": "Build", "line": "Local builds. A control room of your own.", "route": "/reality-gate/", "film": "/reality-gate/#film", "image": {"src": "/assets/studio/08-ci-run-complete-1440.ba292332e91dbc87.webp", "srcset": "/assets/studio/08-ci-run-complete-480.4e2f84d1f47b8fc7.webp 480w, /assets/studio/08-ci-run-complete-960.5845d5f575adae9f.webp 960w, /assets/studio/08-ci-run-complete-1440.ba292332e91dbc87.webp 1440w", "original": "/assets/reality-gate/08-ci-run-complete.50deeeef7e10fbe8.png", "width": 1440, "height": 900, "alt": "Reality Gate Runroom showing a completed run and its record."}, "tour": [{"title": "Orient", "description": "See the repository, its dependencies and continuity status.", "image": {"src": "/assets/studio/01-home-continuity-1440.6164ffb655310c8c.webp", "srcset": "/assets/studio/01-home-continuity-480.a570c621fae64392.webp 480w, /assets/studio/01-home-continuity-960.56f4f49417c2ae16.webp 960w, /assets/studio/01-home-continuity-1440.6164ffb655310c8c.webp 1440w", "original": "/assets/reality-gate/01-home-continuity.71b20e418bbf3799.png", "width": 1440, "height": 900, "alt": "Reality Gate Home showing repository continuity status."}}, {"title": "Run", "description": "Follow an execution in the Runroom, with the log and record alongside it.", "image": {"src": "/assets/studio/08-ci-run-complete-1440.ba292332e91dbc87.webp", "srcset": "/assets/studio/08-ci-run-complete-480.4e2f84d1f47b8fc7.webp 480w, /assets/studio/08-ci-run-complete-960.5845d5f575adae9f.webp 960w, /assets/studio/08-ci-run-complete-1440.ba292332e91dbc87.webp 1440w", "original": "/assets/reality-gate/08-ci-run-complete.50deeeef7e10fbe8.png", "width": 1440, "height": 900, "alt": "Reality Gate Runroom with a completed execution and log."}}, {"title": "Recover", "description": "Inspect the recorded recovery drill and bundle details, including its stated outcome.", "image": {"src": "/assets/studio/04-recovery-bundle-verified-1440.895de80d181b111e.webp", "srcset": "/assets/studio/04-recovery-bundle-verified-480.dd9e1fb2e5090026.webp 480w, /assets/studio/04-recovery-bundle-verified-960.c96b6f2132b8009f.webp 960w, /assets/studio/04-recovery-bundle-verified-1440.895de80d181b111e.webp 1440w", "original": "/assets/reality-gate/04-recovery-bundle-verified.b93fd52611a64d33.png", "width": 1440, "height": 900, "alt": "Reality Gate recorded recovery drill and bundle details."}}, {"title": "Review", "description": "Return to the ledger to inspect records from previous operations.", "image": {"src": "/assets/studio/09-proof-ledger-1440.webp", "srcset": "/assets/studio/09-proof-ledger-480.webp 480w, /assets/studio/09-proof-ledger-960.webp 960w, /assets/studio/09-proof-ledger-1440.webp 1440w", "original": "/assets/reality-gate/09-proof-ledger.png", "width": 1440, "height": 900, "alt": "Reality Gate Proof Ledger showing recorded operations."}}], "category": "Local execution & recovery"}, "lights-out": {"name": "Lights Out", "tab": "Night", "line": "A calmer ending to your day.", "route": "/lights-out/", "image": {"src": "/assets/studio/tonight-active-hero-1600.webp", "srcset": "/assets/studio/tonight-active-hero-480.webp 480w, /assets/studio/tonight-active-hero-960.webp 960w, /assets/studio/tonight-active-hero-1600.webp 1600w", "original": "/assets/lights-out/tonight-active-hero.png", "width": 1600, "height": 902, "alt": "Lights Out desktop showing an active countdown."}, "category": "A nightly shutdown ritual"}, "cleanroom": {"name": "Cleanroom", "tab": "Clean", "line": "Clear the clutter. Keep a way back.", "route": "/cleanroom/", "image": {"src": "/assets/studio/cleanroom-review-1280.webp", "srcset": "/assets/studio/cleanroom-review-480.webp 480w, /assets/studio/cleanroom-review-960.webp 960w, /assets/studio/cleanroom-review-1280.webp 1280w", "original": "/assets/cleanroom/cleanroom-review.png", "width": 1280, "height": 760, "alt": "Cleanroom dashboard with review, archive and restore controls."}, "category": "Reversible Windows cleanup"}, "ghostlayer": {"name": "GhostLayer", "tab": "Stage", "line": "Keep it temporary. Make the call.", "route": "/ghostlayer/", "image": {"src": "/assets/studio/gl-staged-files-1125.webp", "srcset": "/assets/studio/gl-staged-files-480.webp 480w, /assets/studio/gl-staged-files-960.webp 960w, /assets/studio/gl-staged-files-1125.webp 1125w", "original": "/assets/ghostlayer/gl-staged-files.png", "width": 1125, "height": 814, "alt": "GhostLayer RAM staging with commit and discard controls."}, "category": "Volatile file staging"}, "forgecast": {"name": "ForgeCast", "tab": "Weather", "line": "Know what to wear. Know when to go.", "route": "/forgecast/", "image": {"src": "/assets/studio/v030-today-1080.webp", "srcset": "/assets/studio/v030-today-480.webp 480w, /assets/studio/v030-today-960.webp 960w, /assets/studio/v030-today-1080.webp 1080w", "original": "/assets/forgecast/v030-today.png", "width": 1080, "height": 2340, "alt": "ForgeCast Today with weather and clothing guidance."}, "category": "Weather for your everyday"}, "proofshot": {"name": "ProofShot", "tab": "Capture", "line": "Capture context. Keep a verifiable record.", "route": "/proofshot/", "image": {"src": "/assets/studio/workbench-home-1440.webp", "srcset": "/assets/studio/workbench-home-480.webp 480w, /assets/studio/workbench-home-960.webp 960w, /assets/studio/workbench-home-1440.webp 1440w", "original": "/assets/proofshot/workbench-home.png", "width": 1440, "height": 900, "alt": "ProofShot engine workbench preview, still branded HyperSnatch."}, "tour": [{"title": "Workbench", "description": "Start with the capture workspace and its current artifact context.", "image": {"src": "/assets/studio/workbench-home-1440.webp", "srcset": "/assets/studio/workbench-home-480.webp 480w, /assets/studio/workbench-home-960.webp 960w, /assets/studio/workbench-home-1440.webp 1440w", "original": "/assets/proofshot/workbench-home.png", "width": 1440, "height": 900, "alt": "ProofShot engine workbench in an earlier HyperSnatch-branded preview."}}, {"title": "Candidates", "description": "Inspect the candidates view before progressing through the capture workflow.", "image": {"src": "/assets/studio/candidates-plan-1440.webp", "srcset": "/assets/studio/candidates-plan-480.webp 480w, /assets/studio/candidates-plan-960.webp 960w, /assets/studio/candidates-plan-1440.webp 1440w", "original": "/assets/proofshot/candidates-plan.png", "width": 1440, "height": 900, "alt": "ProofShot engine candidates view with the sample workspace welcome panel."}}, {"title": "Export", "description": "Inspect the artifact tree and the recorded export result together.", "image": {"src": "/assets/studio/export-complete-1440.webp", "srcset": "/assets/studio/export-complete-480.webp 480w, /assets/studio/export-complete-960.webp 960w, /assets/studio/export-complete-1440.webp 1440w", "original": "/assets/proofshot/export-complete.png", "width": 1440, "height": 900, "alt": "ProofShot engine showing a completed sample export and artifact tree."}}, {"title": "Records", "description": "Keep the captured context and its proof cards within reach.", "image": {"src": "/assets/studio/workbench-proof-cards-1440.webp", "srcset": "/assets/studio/workbench-proof-cards-480.webp 480w, /assets/studio/workbench-proof-cards-960.webp 960w, /assets/studio/workbench-proof-cards-1440.webp 1440w", "original": "/assets/proofshot/workbench-proof-cards.png", "width": 1440, "height": 900, "alt": "ProofShot engine workbench with proof cards."}}], "category": "Structural capture & proof bundles"}};
const $ = (s, root = document) => root.querySelector(s);
const $$ = (s, root = document) => [...root.querySelectorAll(s)];
const root = document.documentElement;
const motionQuery = matchMedia('(prefers-reduced-motion: reduce)');
let motionPreference = 'on';
try { motionPreference = localStorage.getItem('pf-motion') || 'on'; } catch (_) {}
const motionButton = document.createElement('button');
motionButton.type = 'button';
motionButton.className = 'motion-toggle';
function applyMotion() {
  const active = !motionQuery.matches && motionPreference === 'on';
  root.dataset.motion = active ? 'on' : 'off';
  motionButton.textContent = motionQuery.matches ? 'Reduced motion' : `Motion ${active ? 'on' : 'off'}`;
  motionButton.setAttribute('aria-pressed', String(active));
  motionButton.setAttribute('aria-label', motionQuery.matches ? 'Reduced motion follows your device setting' : 'Website motion');
  motionButton.disabled = motionQuery.matches;
  if (!active) {
    $$('[data-tilt]').forEach(e => e.style.transform = '');
    document.getAnimations?.().forEach(animation => animation.cancel());
  }
}
applyMotion();
motionQuery.addEventListener('change', applyMotion);
motionButton.addEventListener('click', () => {
  motionPreference = motionPreference === 'on' ? 'off' : 'on';
  try { localStorage.setItem('pf-motion', motionPreference); } catch (_) {}
  applyMotion();
});
$('.footer-bottom')?.append(motionButton);

// Change only after the real screen loads, retaining the current view if it fails.
const pendingScreens = new WeakMap();
function waitForImage(image) {
  return new Promise((resolve, reject) => {
    const finish = () => image.naturalWidth ? resolve() : reject(new Error('Image has no natural width'));
    if (image.complete) {
      finish();
      return;
    }
    image.addEventListener('load', finish, { once: true });
    image.addEventListener('error', () => reject(new Error('Image failed to load')), { once: true });
  });
}
async function changeScreen(container, screen, done) {
  const request = Symbol('screen');
  pendingScreens.set(container, request);
  container.setAttribute('aria-busy', 'true');
  const image = new Image();
  const target = $('img', container);
  image.sizes = target.sizes;
  image.srcset = screen.srcset;
  image.src = screen.src;
  try {
    await waitForImage(image);
    if (pendingScreens.get(container) !== request) return;
    target.srcset = screen.srcset;
    target.src = screen.src;
    target.width = screen.width;
    target.height = screen.height;
    target.alt = screen.alt;
    const link = $('[data-screenshot]', container);
    link.href = screen.original;
    link.setAttribute('aria-label', `Enlarge: ${screen.alt}`);
    $('.experience-error', container)?.replaceChildren();
    done();
    if (root.dataset.motion === 'on') target.animate([{ opacity: .3, transform: 'translateY(8px)' }, { opacity: 1, transform: 'translateY(0)' }], { duration: 380, easing: 'ease-out' });
  } catch (_) {
    if (pendingScreens.get(container) === request && $('.experience-error', container)) $('.experience-error', container).textContent = 'This screen couldn’t load. Try again, or explore the product below.';
  } finally {
    if (pendingScreens.get(container) === request) container.removeAttribute('aria-busy');
  }
}
const theater = $('[data-theater]');
if (theater) {
  const choices=$$('[data-show-product]',theater);
  choices.forEach((choice,index)=>choice.addEventListener('keydown',event=>{
    if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;
    event.preventDefault();
    const next=event.key==='Home'?0:event.key==='End'?choices.length-1:(index+(event.key==='ArrowRight'?1:-1)+choices.length)%choices.length;
    choices[next].focus();choices[next].click();
  }));
  $$('[data-show-product]', theater).forEach((button, index) => button.addEventListener('click', () => {
    const id = button.dataset.showProduct, product = products[id];
    changeScreen(theater, product.image, () => {
      theater.dataset.product = id;
      $('[data-theater-name]', theater).textContent = product.name;
      $('[data-theater-category]', theater).textContent = product.category;
      $('[data-theater-line]', theater).textContent = product.line;
      $('[data-theater-link]', theater).href = product.route;
      $('[data-theater-link]', theater).setAttribute('aria-label', `Explore ${product.name}`);
      const filmLink = $('[data-theater-film]', theater);
      filmLink.hidden = !product.film;
      if (product.film) {
        filmLink.href = product.film;
        filmLink.setAttribute('aria-label', `See the ${product.name} product film`);
      }
      $('.theater-index', theater).textContent = `0${index + 1} / 07`;
      $$('[data-show-product]', theater).forEach(b => b.setAttribute('aria-pressed', String(b === button)));
    });
  }));
}
$$('[data-tour]').forEach(tour => {
  const steps = products[tour.dataset.tour].tour;
  $$('[data-tour-step]', tour).forEach(button => button.addEventListener('click', () => {
    const step = steps[Number(button.dataset.tourStep)];
    changeScreen($('.tour-screen', tour), step.image, () => {
      $('[data-tour-caption]', tour).textContent = step.description;
      $$('[data-tour-step]', tour).forEach(b => b.setAttribute('aria-pressed', String(b === button)));
    });
  }));
});
const finder = $('.product-finder');
if (finder) {
  const groups = { 'reality-gate': ['build', 'windows'], 'cache-vault': ['memory', 'windows', 'android'], 'lights-out': ['everyday', 'windows', 'android'], cleanroom: ['memory', 'windows'], ghostlayer: ['memory', 'windows'], forgecast: ['everyday', 'android'], proofshot: ['build', 'windows'] };
  let intent = 'all';
  const platform = $('#platform-filter');
  const cards = $$('#products [data-product]');
  // H7A-R mobile curation: on small screens the catalog leads with the featured
  // tool and the first two cards; the rest sit behind a "See all 7 tools"
  // disclosure. No product is removed - the toggle, any finder use, or a wider
  // viewport always reveals everything.
  const catalogToggle = $('[data-catalog-toggle]');
  const deferredCards = $$('.product-card').slice(2);
  const mobileCatalog = window.matchMedia('(max-width: 700px)');
  let curated = mobileCatalog.matches;
  function syncToggle() {
    if (!catalogToggle) return;
    catalogToggle.hidden = false;
    catalogToggle.setAttribute('aria-expanded', String(!curated));
    catalogToggle.textContent = curated ? 'See all 7 tools' : 'Show featured tools';
  }
  function uncurate() {
    if (curated) { curated = false; syncToggle(); }
  }
  function filter() {
    let count = 0;
    cards.forEach(card => {
      const tags = groups[card.dataset.product];
      card.hidden = !(intent === 'all' || tags.includes(intent)) || !(platform.value === 'all' || tags.includes(platform.value));
      if (!card.hidden) count++;
    });
    if (curated && intent === 'all' && platform.value === 'all') deferredCards.forEach(card => { card.hidden = true; });
    $$('.product-group').forEach(group => {
      const matches = $$('.product-card', group).filter(card => !card.hidden).length;
      group.hidden = matches === 0;
      if ($('.group-count', group)) $('.group-count', group).textContent = `${matches} ${matches === 1 ? 'product' : 'products'}`;
    });
    $('.finder-count').textContent = `${count} ${count === 1 ? 'product' : 'products'}`;
    $('.finder-empty').hidden = count !== 0;
    $$('[data-intent]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.intent === intent)));
  }
  $$('[data-intent]').forEach(b => b.addEventListener('click', () => { intent = b.dataset.intent; uncurate(); filter(); }));
  platform.addEventListener('change', () => { uncurate(); filter(); });
  $('[data-filter-reset]').addEventListener('click', () => { intent = 'all'; platform.value = 'all'; curated = mobileCatalog.matches; syncToggle(); filter(); $('[data-intent="all"]').focus(); });
  if (catalogToggle) {
    catalogToggle.addEventListener('click', () => { curated = !curated; syncToggle(); filter(); });
    mobileCatalog.addEventListener('change', () => { curated = mobileCatalog.matches; syncToggle(); filter(); });
    syncToggle();
    filter();
  }
}
const archive = $('[data-demo="archive"]');
if (archive) {
  const clips = [
    { type: 'NOTE', title: 'The good coffee place', text: 'Juniper café — the little place on the corner.', pinned: true },
    { type: 'CODE', title: 'A fresh start', text: 'git switch -c next-good-idea', pinned: false },
    { type: 'IDEA', title: 'For the weekend', text: 'A long walk. A new recipe. Leave the laptop at home.', pinned: false },
    { type: 'TEXT', title: 'Words worth keeping', text: 'Make room for the things that make a difference.', pinned: false },
    { type: 'LIST', title: 'Before you leave', text: 'Keys, headphones, water bottle, light jacket.', pinned: false },
    { type: 'PATH', title: 'Where the project lives', text: 'Documents / Projects / something-good', pinned: false }
  ];
  let filter = 'all';
  function renderClips() {
    const query = $('#clip-search').value.trim().toLowerCase();
    const visible = clips.filter(c => (filter === 'all' || c.pinned) && `${c.type} ${c.title} ${c.text}`.toLowerCase().includes(query));
    const list = $('.sample-clips', archive);
    list.replaceChildren();
    visible.forEach(clip => {
      const item = document.createElement('article');
      const kind = document.createElement('span'); kind.className = 'clip-kind'; kind.textContent = clip.type;
      const title = document.createElement('h3'); title.textContent = clip.title;
      const body = document.createElement('p'); body.textContent = clip.text;
      const pin = document.createElement('button'); pin.type = 'button'; pin.textContent = clip.pinned ? 'Pinned' : 'Pin'; pin.setAttribute('aria-label', `Pin ${clip.title}`); pin.setAttribute('aria-pressed', String(clip.pinned));
      pin.addEventListener('click', () => {
        clip.pinned = !clip.pinned;
        if (filter === 'pinned') { renderClips(); $('[data-clip-filter="pinned"]', archive).focus(); }
        else { pin.textContent = clip.pinned ? 'Pinned' : 'Pin'; pin.setAttribute('aria-pressed', String(clip.pinned)); $('[data-pin-count]', archive).textContent = clips.filter(c => c.pinned).length; }
      });
      item.append(kind, title, body, pin); list.append(item);
    });
    if (!visible.length) { const empty = document.createElement('p'); empty.className = 'clip-empty'; empty.textContent = 'Nothing here yet. Try another search or pin a clip from All clips.'; list.append(empty); }
    $('.clip-status', archive).textContent = `${visible.length} sample ${visible.length === 1 ? 'clip' : 'clips'}`;
    $('[data-pin-count]', archive).textContent = clips.filter(c => c.pinned).length;
  }
  $('#clip-search').addEventListener('input', renderClips);
  $$('[data-clip-filter]', archive).forEach(b => b.addEventListener('click', () => { filter = b.dataset.clipFilter; $$('[data-clip-filter]', archive).forEach(x => x.setAttribute('aria-pressed', String(x === b))); renderClips(); }));
  renderClips();
}
const night = $('[data-demo="night"]');
if (night) {
  let duration = 20, remaining = 20000, running = false, end = 0, interval;
  const toggle = $('[data-timer-toggle]', night);
  function paint() {
    const seconds = Math.max(0, Math.ceil(remaining / 1000));
    $('.timer-value', night).textContent = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
    $('.timer-progress', night).style.strokeDashoffset = String(100 - remaining / (duration * 10));
    night.dataset.running = String(running);
  }
  function pause(message) {
    remaining = Math.max(0, end - performance.now()); running = false; clearInterval(interval); toggle.textContent = 'Resume countdown'; $('.timer-state', night).textContent = message; paint();
  }
  function reset(seconds = duration) {
    clearInterval(interval); duration = seconds; remaining = duration * 1000; running = false;
    toggle.textContent = 'Start countdown'; $('.timer-state', night).textContent = 'Ready when you are';
    $$('[data-duration]', night).forEach(b => b.setAttribute('aria-pressed', String(Number(b.dataset.duration) === duration))); paint();
  }
  toggle.addEventListener('click', () => {
    if (running) { pause('Paused. Take your time.'); return; }
    if (remaining <= 0) remaining = duration * 1000;
    end = performance.now() + remaining; running = true; toggle.textContent = 'Pause countdown'; $('.timer-state', night).textContent = 'Let the day wind down'; paint();
    interval = setInterval(() => {
      remaining = Math.max(0, end - performance.now());
      if (remaining === 0) { running = false; clearInterval(interval); toggle.textContent = 'Start again'; $('.timer-state', night).textContent = 'A little quieter. Good night.'; }
      paint();
    }, 100);
  });
  $('[data-timer-reset]', night).addEventListener('click', () => reset());
  $$('[data-duration]', night).forEach(b => b.addEventListener('click', () => reset(Number(b.dataset.duration))));
  document.addEventListener('visibilitychange', () => { if (document.hidden && running) pause('Paused while you were away.'); });
}
const cleanup = $('[data-demo="cleanup"]');
if (cleanup) {
  const checks = $$('input[name="cleanup-file"]', cleanup), sizes = [12.4, 2.1, .8];
  let archived = [];
  function renderCleanup() {
    const selected = checks.filter(c => c.checked), total = selected.reduce((n,c) => n + sizes[Number(c.value)], 0);
    $('[data-cleanup-total]', cleanup).innerHTML = `${total.toFixed(1)} <small>MB</small>`;
    $('[data-cleanup-description]', cleanup).textContent = `${selected.length} sample ${selected.length === 1 ? 'file' : 'files'} ${archived.length ? 'archived' : 'selected'}`;
    $('[data-archive-files]', cleanup).disabled = !selected.length || !!archived.length;
    $('[data-restore-files]', cleanup).disabled = !archived.length;
    checks.forEach(c => { c.disabled = !!archived.length; c.closest('label').classList.toggle('is-archived', archived.includes(c)); });
    cleanup.dataset.archived = String(!!archived.length);
  }
  checks.forEach(c => c.addEventListener('change', renderCleanup));
  $('[data-archive-files]', cleanup).addEventListener('click', () => {
    archived = checks.filter(c => c.checked); renderCleanup();
    $('.cleanup-status', cleanup).textContent = `${archived.length} sample files archived. Restore brings them right back.`;
    $('[data-restore-files]', cleanup).focus();
  });
  $('[data-restore-files]', cleanup).addEventListener('click', () => {
    const count = archived.length; archived = []; renderCleanup(); $('.cleanup-status', cleanup).textContent = `${count} sample files restored. Back where they started.`; $('[data-archive-files]', cleanup).focus();
  });
}
const staging = $('[data-demo="staging"]');
if (staging) {
  const names = ['reference-pack.zip', 'scratch-notes.txt', 'test-export.json'];
  let states = names.map(() => 'staged');
  function renderStaging() {
    const source = $('.staged-samples', staging), kept = $('.committed-samples', staging); source.replaceChildren(); kept.replaceChildren();
    names.forEach((name, i) => {
      if (states[i] === 'discarded') return;
      if (states[i] === 'committed') { const p = document.createElement('p'); p.className = 'committed-file'; p.textContent = name; kept.append(p); return; }
      const label = document.createElement('label'), check = document.createElement('input'), span = document.createElement('span');
      check.type = 'checkbox'; check.value = String(i); check.name = 'staged-file'; span.textContent = name;
      check.addEventListener('change', updateStagingActions); label.append(check,span); source.append(label);
    });
    if (!source.children.length) { const p = document.createElement('p'); p.className = 'stage-empty'; p.textContent = 'Staging is clear.'; source.append(p); }
    if (!kept.children.length) { const p = document.createElement('p'); p.className = 'stage-empty'; p.textContent = 'Nothing permanent. Until you make it so.'; kept.append(p); }
    updateStagingActions();
  }
  function updateStagingActions() { const none = !$$('input:checked', staging).length; $('[data-stage-commit]', staging).disabled = none; $('[data-stage-discard]', staging).disabled = none; }
  function move(destination) {
    const selected = $$('input:checked', staging); selected.forEach(c => states[Number(c.value)] = destination); renderStaging();
    $('.staging-status', staging).textContent = `${selected.length} sample ${selected.length === 1 ? 'file' : 'files'} ${destination}. ${states.filter(s => s === 'staged').length} still staged.`;
    ($('input', staging) || $('[data-stage-reset]', staging)).focus();
  }
  $('[data-stage-commit]', staging).addEventListener('click', () => move('committed'));
  $('[data-stage-discard]', staging).addEventListener('click', () => move('discarded'));
  $('[data-stage-reset]', staging).addEventListener('click', () => { states = names.map(() => 'staged'); renderStaging(); $('.staging-status', staging).textContent = '3 sample files staged. Select what happens next.'; });
  renderStaging();
}
const forecast = $('[data-demo="forecast"]');
if (forecast) {
  const hours = [
    {time:'06:00',period:'Early morning',temp:12,condition:'A cool, quiet start',heading:'Take the warmer layer.',detail:'Cool air before the day gets going. A jacket makes the early walk more comfortable.',rain:'5%',wind:'4 km/h'},
    {time:'09:00',period:'Morning',temp:16,condition:'Clouds giving way',heading:'Start with a light layer.',detail:'A cool start. Bring a layer you can take off as the day warms up.',rain:'10%',wind:'8 km/h'},
    {time:'12:00',period:'Midday',temp:21,condition:'A brighter window',heading:'Make time to get outside.',detail:'The warmest, driest part of this sample day. A useful window for that longer walk.',rain:'5%',wind:'10 km/h'},
    {time:'15:00',period:'Afternoon',temp:18,condition:'Showers moving through',heading:'Bring something for the rain.',detail:'Keep a rain layer or umbrella within reach. There may be a shower on the way home.',rain:'70%',wind:'16 km/h'},
    {time:'18:00',period:'Evening',temp:15,condition:'A softer evening',heading:'Put that layer back on.',detail:'Cooling down as the evening arrives. A light jacket should earn its place in your bag.',rain:'20%',wind:'7 km/h'}
  ];
  $('#forecast-hour').addEventListener('input', event => {
    const i = Number(event.target.value), h = hours[i]; forecast.dataset.hour = String(i);
    $('.forecast-temp', forecast).innerHTML = `${h.temp}<span>°</span>`;
    for (const [selector,key] of [['.forecast-condition','condition'],['.forecast-headline','heading'],['.forecast-detail','detail'],['.forecast-rain','rain'],['.forecast-wind','wind'],['.forecast-selected','time']]) $(selector,forecast).textContent = h[key];
    $('.forecast-time', forecast).textContent = `${h.time} · ${h.period}`;
    event.target.setAttribute('aria-valuetext', `${h.time}, ${h.temp} degrees, ${h.condition}`);
  });
}
// Enhancements are visible only after their behaviors have initialized.
$$('[data-enhance]').forEach(e => e.hidden = false);
// Short, one-shot arrival motion, with content visible even if JavaScript is absent.
if ('IntersectionObserver' in window) {
  const arrivals = new IntersectionObserver(entries => entries.forEach(entry => {
    if (entry.isIntersecting) {
      if (root.dataset.motion === 'on') entry.target.animate([{ transform:'translateY(20px)', opacity:.55 },{ transform:'translateY(0)', opacity:1 }], { duration:600, easing:'cubic-bezier(.2,.7,.3,1)' });
      arrivals.unobserve(entry.target);
    }
  }), { threshold: .12 });
  $$('.experience-section,.product-card,.studio-featured,.section-heading').forEach(e => arrivals.observe(e));
}
const finePointer = matchMedia('(hover: hover) and (pointer: fine)');
$$('[data-tilt]').forEach(stage => {
  let frame;
  stage.addEventListener('pointermove', event => {
    if (!finePointer.matches || root.dataset.motion !== 'on') return;
    cancelAnimationFrame(frame);
    const bounds = stage.getBoundingClientRect(), x = (event.clientX - bounds.left) / bounds.width - .5, y = (event.clientY - bounds.top) / bounds.height - .5;
    frame = requestAnimationFrame(() => stage.style.transform = `perspective(900px) rotateX(${-y*4}deg) rotateY(${x*5}deg)`);
  });
  stage.addEventListener('pointerleave', () => { cancelAnimationFrame(frame); stage.style.transform = ''; });
});
// Compare cards use the rendered, manifest-derived content as their source.
const compareChoices = $$('[data-compare]');
if (compareChoices.length && window.HTMLDialogElement) {
  const selected = new Set();
  const make = (tag, cls, text) => { const e=document.createElement(tag);if(cls)e.className=cls;if(text)e.textContent=text;return e; };
  const button = (text,cls) => { const b=make('button',cls,text);b.type='button';return b; };
  const tray=make('aside','compare-tray');tray.setAttribute('aria-label','Selected software');tray.hidden=true;
  const message=make('p','compare-message');message.setAttribute('role','status');
  const chips=make('div','compare-chips');
  const compare=button('Compare software','compare-open'),clear=button('Clear','compare-clear');tray.append(message,chips,compare,clear);document.body.append(tray);
  const dialog=make('dialog','compare-dialog');dialog.setAttribute('aria-labelledby','comparison-title');
  const heading=make('header','compare-header'),intro=make('div'),kicker=make('span','kicker','THE PROOF FOUNDRY / CHOOSE YOUR TOOLS'),h2=make('h2','','A closer look.');h2.id='comparison-title';intro.append(kicker,h2);
  const close=button('Close comparison','compare-close');heading.append(intro,close);
  const columns=make('div','compare-columns');dialog.append(heading,columns);document.body.append(dialog);
  function record(id) {
    const card=$(`#products [data-product="${id}"]`),featured=card.classList.contains('studio-featured');
    let releaseVer='', availStatus='';
    if(featured){
      const metaSpans=$$('.featured-meta > span:not(.meta-sep)',card);
      const parts=Array.from(metaSpans).map(s=>s.textContent.trim());
      releaseVer=parts[1]||'';
      availStatus=parts[2]||'';
    }else{
      releaseVer=$('.card-version',card)?.textContent.trim()||'';
      availStatus=$('.card-availability',card)?.textContent.trim()||$('.card-topline span:last-child',card)?.textContent.trim()||'';
    }
    return {id,name:products[id].name,category:products[id].category,route:products[id].route,
      value:featured?$('.featured-copy>p:not([class])',card).textContent:$('.card-value',card).textContent,
      platform:featured?'Windows':($('.card-platform',card)?.textContent||$('.card-topline span',card)?.textContent),
      releaseVer,availStatus,
      detail:$('.card-detail',card)?.textContent||'',image:$('img',card)};
  }
  function update() {
    tray.hidden=selected.size===0; document.body.classList.toggle('has-compare-tray',selected.size>0);
    message.textContent=selected.size===1?'Choose one more to compare.':`${selected.size} products selected`;
    compare.disabled=selected.size<2;chips.replaceChildren();
    selected.forEach(id=>{const b=button(`${products[id].name} ×`,'compare-chip');b.setAttribute('aria-label',`Remove ${products[id].name} from comparison`);b.addEventListener('click',()=>{
      const index=Array.prototype.indexOf.call(chips.children,b);
      selected.delete(id);update();
      if(selected.size) chips.children[Math.min(index,chips.children.length-1)].focus();
      else $(`[data-compare="${id}"] input`)?.focus();
    });chips.append(b);});
    compareChoices.forEach(label=>{const input=$('input',label);input.checked=selected.has(label.dataset.compare);label.classList.toggle('is-selected',input.checked);input.disabled=selected.size===3&&!input.checked;});
  }
  compareChoices.forEach(label=>$('input',label).addEventListener('change',event=>{const id=label.dataset.compare;if(event.target.checked&&selected.size<3)selected.add(id);else selected.delete(id);update();}));
  clear.addEventListener('click',()=>{const first=selected.values().next().value;selected.clear();update();if(first)$(`[data-compare="${first}"] input`).focus();});
  compare.addEventListener('click',()=>{
    columns.replaceChildren();columns.dataset.count=String(selected.size);
    selected.forEach(id=>{const p=record(id),card=make('article',`comparison-product comparison-${id}`),media=make('div','comparison-media'),photo=p.image.cloneNode();photo.removeAttribute('fetchpriority');photo.loading='eager';photo.sizes='(max-width:700px) 85vw, 380px';media.append(photo);
      const copy=make('div','comparison-copy'),name=make('h3','',p.name),category=make('p','comparison-category',p.category),value=make('p','comparison-value',p.value),dl=make('dl');
      dl.append(make('dt','','Platform'),make('dd','',p.platform));
      if(p.releaseVer)dl.append(make('dt','','Public release'),make('dd','',p.releaseVer.replace(/^Public release:\s*/i,'').replace(/^Public\s*/i,'')));
      if(p.availStatus)dl.append(make('dt','','Availability'),make('dd','',p.availStatus));
      if(p.detail)dl.append(make('dt','','Current note'),make('dd','',p.detail));
      const link=make('a','comparison-link',`Explore ${p.name} ↗`);link.href=p.route;
      copy.append(category,name,value,dl,link);card.append(media,copy);columns.append(card);
    });dialog.showModal();close.focus();
  });
  close.addEventListener('click',()=>dialog.close());
}
// Keep the page's own navigation and availability action close while exploring.
const hero = $('.product-hero');
if(hero && 'IntersectionObserver' in window) {
  const identity=$('.product-identity > span').textContent;
  const dock=document.createElement('nav');dock.className='product-dock';dock.setAttribute('aria-label',`${identity} page navigation`);dock.hidden=true;
  const name=document.createElement('span');name.className='dock-product';name.textContent=identity;dock.append(name);
  const acquisitionAvailable=document.body.dataset.acquisitionAvailable==='true';
  const availability=acquisitionAvailable?(document.body.classList.contains('product-proofshot')?'Status':document.body.classList.contains('product-cache-vault')?'Availability':document.body.classList.contains('product-lights-out')?'Releases':'Get the app'):'Release status';
  const entries=[['overview','Overview'],['try-it','Try it'],['download',availability],['proof','Proof']];
  entries.forEach(([id,label])=>{const link=document.createElement('a');link.href=`#${id}`;link.textContent=label;link.dataset.section=id;dock.append(link);});document.body.append(dock);
  let heroVisible=true,footerVisible=false;
  function toggleDock(){dock.hidden=heroVisible||footerVisible;}
  const regions=new IntersectionObserver(entries=>{entries.forEach(entry=>{if(entry.target===hero)heroVisible=entry.isIntersecting;else footerVisible=entry.isIntersecting;});toggleDock();},{threshold:0});
  regions.observe(hero);if($('.site-footer'))regions.observe($('.site-footer'));
  let scheduled=false;
  function indicate(){scheduled=false;const current=entries.filter(([id])=>document.getElementById(id)?.getBoundingClientRect().top<innerHeight*.45).at(-1)?.[0]||'overview';$$('a',dock).forEach(a=>{if(a.dataset.section===current)a.setAttribute('aria-current','location');else a.removeAttribute('aria-current');});}
  addEventListener('scroll',()=>{if(!scheduled){scheduled=true;requestAnimationFrame(indicate);}},{passive:true});indicate();
}
})();
