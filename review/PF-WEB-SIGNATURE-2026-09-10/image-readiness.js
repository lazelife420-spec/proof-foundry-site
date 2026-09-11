// Force lazy images to resolve, then report readiness of every raster image.
(function () {
  const imgs = Array.from(document.images);
  for (const img of imgs) {
    if (img.loading === 'lazy') img.loading = 'eager';
    if (img.hasAttribute('decoding')) img.decoding = 'sync';
  }
  const notReady = imgs
    .filter(function (i) { return !i.complete || i.naturalWidth === 0; })
    .map(function (i) { return { src: (i.currentSrc || i.src || '').split('/').slice(-1)[0], complete: i.complete, nw: i.naturalWidth }; });

  return JSON.stringify({
    totalImages: imgs.length,
    readyImages: imgs.length - notReady.length,
    notReadyCount: notReady.length,
    notReady: notReady.slice(0, 20)
  }, null, 2);
})();
