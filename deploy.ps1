# deploy.ps1 — Build public/ from tracked source and deploy to Cloudflare Pages.
#
# Prerequisite (one-time): npx wrangler login   (authorize account ceomindset2019)
# Usage:                    ./deploy.ps1
#
# This rebuilds the public/ asset dir from the tracked site files, then deploys
# to the Cloudflare Pages project "proof-foundry-site". Custom domains
# (theprooffoundry.com / www.theprooffoundry.com) are attached via the Pages dashboard.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Rebuilding public/ from tracked source"
if (Test-Path public) { Remove-Item public -Recurse -Force }
New-Item -ItemType Directory public | Out-Null
Copy-Item index.html, founders.html, forgecast.html, lights-out.html, styles.css, CNAME, robots.txt, sitemap.xml public\
Copy-Item brand, assets public\ -Recurse

# Place product pages at clean directory routes
New-Item -ItemType Directory public\forgecast | Out-Null
Copy-Item forgecast.html public\forgecast\index.html
New-Item -ItemType Directory public\lights-out | Out-Null
Copy-Item lights-out.html public\lights-out\index.html
New-Item -ItemType Directory public\founders | Out-Null
Copy-Item founders.html public\founders\index.html

# Optional: explicit path rewrites
"`n/forgecast/ /forgecast.html 200`n/lights-out/ /lights-out.html 200`n/founders/ /founders.html 200`n" | Out-File public\_redirects -Encoding utf8NoBOM

Write-Host "==> Deploying proof-foundry-site to Cloudflare Pages"
npx --yes wrangler pages deploy .\public --project-name proof-foundry-site --branch main

Write-Host "==> Done. Verify: https://proof-foundry-site.pages.dev/  and  https://theprooffoundry.com/ (after DNS cutover)"
