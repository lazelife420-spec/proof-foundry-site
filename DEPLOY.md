# Deploying theprooffoundry.com

The site is a **Cloudflare Pages direct-upload** deployment named `proof-foundry-site`
in account `ceomindset2019`. It is not GitHub Pages, and it is not using a Git
integration in Cloudflare.

## Current publish model

- Cloudflare project: `proof-foundry-site`
- Deploy surface: `wrangler pages deploy`
- Public domains:
  - `https://proof-foundry-site.pages.dev`
  - `https://theprooffoundry.com`
  - `https://www.theprooffoundry.com`
- Git connection in Cloudflare: none

## One-time setup

```powershell
npx wrangler login
```

Authorize the `ceomindset2019` Cloudflare account in the browser.

## Deploy

Use the repo script:

```powershell
./deploy.ps1
```

What it does:

- rebuilds `public/` from tracked source files
- copies site assets and brand files
- writes `_headers`
- copies `_redirects`
- deploys with:

```powershell
npx --yes wrangler pages deploy .\public --project-name proof-foundry-site --branch main
```

## Verify

The deploy script already runs:

```powershell
.\scripts\Verify-PublicSite.ps1 -Targets @(
  "https://proof-foundry-site.pages.dev",
  "https://theprooffoundry.com",
  "https://www.theprooffoundry.com"
)
```

Manual spot checks:

```powershell
foreach ($u in @(
  "https://proof-foundry-site.pages.dev/",
  "https://theprooffoundry.com/",
  "https://www.theprooffoundry.com/",
  "https://theprooffoundry.com/founders/",
  "https://theprooffoundry.com/forgecast/",
  "https://theprooffoundry.com/proof/"
)) { (Invoke-WebRequest $u -UseBasicParsing).StatusCode }
```

If the apex domain fails locally right after a DNS/domain change, run:

```powershell
ipconfig /flushdns
```

## Notes

- `public/` is build output and is regenerated on each deploy.
- `reports/deploy-receipts/` contains public verification receipts copied into `public/`.
- New verification events are written under ignored `receipts/deploy-verification/` with unique UTC event names. They include the full commit and tree SHA and never overwrite published historical receipts. `Verify-PublicSite.ps1 -ReceiptPath <path>` can select another new destination.
- Cloudflare dashboard fallback:
  - Workers & Pages -> `proof-foundry-site` -> create deployment
  - upload the contents of `public/`
- The source of truth for deployment behavior is `deploy.ps1`.
