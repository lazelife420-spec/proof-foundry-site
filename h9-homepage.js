const forgeHero = document.querySelector('.studio-hero');
if (forgeHero) {
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  let frame = 0;

  function updateForge() {
    frame = 0;
    if (reducedMotion.matches) {
      forgeHero.style.removeProperty('--forge-depth-y');
      forgeHero.style.removeProperty('--forge-hearth-y');
      forgeHero.style.removeProperty('--forge-light-y');
      forgeHero.style.removeProperty('--forge-light-opacity');
      document.body.style.removeProperty('--forge-ambient-x');
      document.body.style.removeProperty('--forge-ambient-y');
      document.body.style.removeProperty('--forge-ambient-opacity');
      document.body.style.removeProperty('--forge-outside-y');
      return;
    }
    const bounds = forgeHero.getBoundingClientRect();
    const progress = Math.max(0, Math.min(1, -bounds.top / Math.max(bounds.height, 1)));
    const depthRange = innerWidth <= 760 ? 10 : 36;
    forgeHero.style.setProperty('--forge-depth-y', `${Math.round((progress - 0.5) * depthRange)}px`);
    forgeHero.style.setProperty('--forge-hearth-y', `${Math.round((progress - 0.5) * 28)}px`);
    forgeHero.style.setProperty('--forge-light-y', `${Math.round(15 - progress * 30)}px`);
    forgeHero.style.setProperty('--forge-light-opacity', (0.24 + progress * 0.12).toFixed(3));
    const pageRange = Math.max(1, document.documentElement.scrollHeight - innerHeight);
    const ambientProgress = Math.max(0, Math.min(1, scrollY / pageRange));
    const ambientTravel = innerWidth <= 760 ? 14 : 24;
    document.body.style.setProperty('--forge-ambient-x', `${Math.round((ambientProgress - 0.5) * (innerWidth <= 760 ? 36 : 72))}px`);
    document.body.style.setProperty('--forge-ambient-y', `${Math.round(-ambientProgress * ambientTravel)}px`);
    document.body.style.setProperty('--forge-ambient-opacity', (0.22 + ambientProgress * 0.14).toFixed(3));
    document.body.style.setProperty('--forge-outside-y', `${Math.round((ambientProgress - 0.5) * (innerWidth <= 760 ? 24 : 44))}px`);
  }

  function scheduleForge() {
    if (!reducedMotion.matches && !frame) frame = requestAnimationFrame(updateForge);
  }

  addEventListener('scroll', scheduleForge, { passive: true });
  addEventListener('resize', scheduleForge);
  reducedMotion.addEventListener('change', () => {
    if (frame) cancelAnimationFrame(frame);
    updateForge();
  });
  updateForge();
}
