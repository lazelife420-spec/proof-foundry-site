# Deploying theprooffoundry.com

The site is a **Cloudflare Worker static-assets** deployment named `proof-foundry-site`
(account `ceomindset2019`). It is **not** GitHub Pages.

## One-time setup

```powershell
npx wrangler login   # authorize the ceomindset2019 Cloudflare account in the browser
```

## Deploy

```powershell
./deploy.ps1
```

This rebuilds `public/` from the tracked source files (`index.html`, `founders.html`,
`styles.css`, `CNAME`, `brand/`) and runs `wrangler deploy`.

`wrangler.toml` declares both triggers, so they survive every deploy:

- `theprooffoundry.com` (custom domain)
- `proof-foundry-site.ceomindset2019.workers.dev` (`workers_dev = true`)

> Note: if `workers_dev = true` is ever removed while `routes` are present, Wrangler
> auto-disables the workers.dev URL. Keep it set.

## Verify

```powershell
foreach ($u in @(
  "https://theprooffoundry.com/",
  "https://theprooffoundry.com/founders.html",
  "https://theprooffoundry.com/styles.css",
  "https://www.theprooffoundry.com/"
)) { (Invoke-WebRequest $u -UseBasicParsing).StatusCode }
```

If the apex (`theprooffoundry.com`) fails to resolve locally right after a domain
change, run `ipconfig /flushdns` — it is a local resolver cache, not the deploy.

## Notes

- `public/` and `receipts/*.zip` are git-ignored (build output / Direct-Upload fallback).
- Direct-Upload fallback: zip the contents of `public/` and upload via the Cloudflare
  dashboard (Workers & Pages → proof-foundry-site → new version).
