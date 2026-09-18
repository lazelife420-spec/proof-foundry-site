// H9 catalog only. Release text and platform availability come from built cards.
// Shared comparison remains in experience.js; no product state is synthesized here.
const finder = document.querySelector('.h9-product-finder');

if (finder) {
  const search = finder.querySelector('#product-search');
  const clearSearch = finder.querySelector('#product-search-clear');
  const platform = finder.querySelector('#platform-filter');
  const choices = [...finder.querySelectorAll('[data-intent]')];
  const count = finder.querySelector('.finder-count');
  const empty = document.querySelector('.finder-empty');
  const resetButtons = [...document.querySelectorAll('[data-filter-reset]')];
  const cards = [...document.querySelectorAll('#software-results [data-product]')];
  // Editorial job taxonomy only; versions, platform names and release notes
  // remain manifest-rendered content. No mobile subset hides matching products.
  const jobs = {
    'cache-vault': 'memory', cleanroom: 'memory', ghostlayer: 'memory',
    'lights-out': 'everyday', forgecast: 'everyday',
    'reality-gate': 'build', proofshot: 'build'
  };
  const normalize = value => value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9.]+/g, ' ').trim();
  let intent = 'all';

  // Bring exact existing platform/version nodes into view. Moving, rather than
  // copying, preserves the selectors read by the shared comparison controller.
  const entries = cards.map(card => {
    const metadata = document.createElement('div');
    metadata.className = 'h9-card-meta';
    const fields = [...card.querySelectorAll('.card-platform, .card-version')];
    metadata.append(...fields);
    card.querySelector('.card-value').after(metadata);
    const details = card.querySelector('.card-more');
    if (details && !details.querySelector('.card-detail')) details.remove();
    const text = [...card.querySelectorAll('.card-name, .card-value, .card-platform, .card-version, .card-detail, .card-availability')].map(node => node.textContent).join(' ');
    return {
      card,
      job: jobs[card.dataset.product],
      platforms: normalize(card.querySelector('.card-platform')?.textContent || '').split(' '),
      text: normalize(text)
    };
  });

  function filter() {
    const terms = normalize(search.value).split(' ').filter(Boolean);
    let matches = 0;
    for (const entry of entries) {
      const visible = (intent === 'all' || entry.job === intent)
        && (platform.value === 'all' || entry.platforms.includes(platform.value))
        && terms.every(term => entry.text.includes(term));
      entry.card.hidden = !visible;
      if (visible) matches++;
    }
    count.textContent = `${matches} ${matches === 1 ? 'product' : 'products'}`;
    empty.hidden = matches > 0;
    clearSearch.hidden = search.value.length === 0;
    const active = search.value.length > 0 || intent !== 'all' || platform.value !== 'all';
    resetButtons.forEach(button => { button.disabled = !active; });
    choices.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.intent === intent)));
  }

  search.addEventListener('input', filter);
  search.addEventListener('search', filter);
  clearSearch.addEventListener('click', () => { search.value = ''; filter(); search.focus(); });
  choices.forEach(button => button.addEventListener('click', () => { intent = button.dataset.intent; filter(); }));
  platform.addEventListener('change', filter);
  resetButtons.forEach(button => button.addEventListener('click', () => {
    intent = 'all'; platform.value = 'all'; search.value = ''; filter(); search.focus();
  }));
  // A comparison selection may outlive its current filter. The shared clear
  // action cannot focus a card that is hidden; keep the next keyboard step visible.
  const tray = document.querySelector('.compare-tray');
  tray?.addEventListener('click', () => {
    if (tray.hidden && !document.activeElement?.closest('.product-card:not([hidden])')) search.focus();
  });
  filter();
  finder.hidden = false;
}
