import { defineConfig } from 'vite';

// Preview only. PowerShell remains the authoritative production build.
export default defineConfig({
  root: 'public',
  publicDir: false,
  plugins: [{
    name: 'local-viewport-review',
    configureServer(server) {
      // Local review harness only; this middleware is never production output.
      server.middlewares.use('/__review', (req, res) => {
        const params = new URL(req.url, 'http://preview').searchParams;
        const width = params.get('width') === '390' ? 390 : 1440;
        const route = params.get('page') || '/';
        const section = ['try-it', 'products', 'proof'].includes(params.get('section')) ? '#' + params.get('section') : '';
        if (!/^\/(?:[a-z-]+\/)?$/.test(route)) { res.statusCode = 400; res.end(); return; }
        res.setHeader('Content-Type', 'text/html');
        res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Local viewport review</title><style>*{box-sizing:border-box}body{margin:0;background:#080b0e;display:flex;justify-content:center}iframe{display:block;border:0;width:${width}px;height:${width === 390 ? 844 : 900}px;flex:none;transform-origin:top center} @media(max-width:1450px){iframe.desktop{transform:scale(.88);margin-top:0}}</style></head><body><iframe title="Website at ${width} CSS pixels" class="${width === 390 ? 'mobile' : 'desktop'}" src="${route}${section}"></iframe></body></html>`);
      });
    }
  }],
  // The static generator replaces public/ atomically enough to invalidate
  // inode-based watches. Polling keeps repeated build reviews on fresh files.
  server: { host: '0.0.0.0', allowedHosts: ['terminal.local'], watch: { usePolling: true, interval: 200 } }
});
