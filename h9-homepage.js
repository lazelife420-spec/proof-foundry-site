// Content is visible by default, including when JavaScript is unavailable.
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const animations = new Set();
let observer;
function stopMotion() {
  observer?.disconnect();
  for (const animation of animations) animation.cancel();
  animations.clear();
}
if (!reduced.matches && 'IntersectionObserver' in window && Element.prototype.animate) {
  observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      observer.unobserve(entry.target);
      if (reduced.matches) continue;
      const animation = entry.target.animate(
        [{opacity: .55, transform: 'translateY(12px)'}, {opacity: 1, transform: 'none'}],
        {duration: 300, easing: 'cubic-bezier(.2,.65,.25,1)'}
      );
      animations.add(animation);
      animation.finished.catch(() => {}).finally(() => animations.delete(animation));
    }
  }, {threshold: .08});
  document.querySelectorAll('.h9-reveal').forEach(node => observer.observe(node));
}
reduced.addEventListener('change', event => { if (event.matches) stopMotion(); });
window.addEventListener('pagehide', stopMotion, {once: true});
// Begin the small-screen viewport at the real run, keeping the full capture
// scrollable with touch, trackpad, or keyboard. This does not alter the pixels.
const compact = matchMedia('(max-width: 760px)');
const runroom = document.querySelector('.h9-screen-scroll');
function composeRunroom() { if (runroom) runroom.scrollLeft = compact.matches ? 290 : 210; }
composeRunroom();
compact.addEventListener('change', composeRunroom);
