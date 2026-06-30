# deploy.ps1 — Build public/ from tracked source and deploy to the Cloudflare Worker.
#
# Prerequisite (one-time): npx wrangler login   (authorize account ceomindset2019)
# Usage:                    ./deploy.ps1
#
# This rebuilds the public/ asset dir from the tracked site files, then deploys
# the Worker "proof-foundry-site". Custom domain (theprooffoundry.com) + workers.dev
# triggers are declared in wrangler.toml, so they are preserved on every deploy.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Rebuilding public/ from tracked source"
if (Test-Path public) { Remove-Item public -Recurse -Force }
New-Item -ItemType Directory public | Out-Null
Copy-Item index.html, founders.html, forgecast.html, lights-out.html, styles.css, CNAME, robots.txt, sitemap.xml public\
Copy-Item brand public\ -Recurse

# Place ForgeCast landing page at /forgecast/
New-Item -ItemType Directory public\forgecast | Out-Null
Copy-Item forgecast.html public\forgecast\index.html

Write-Host "==> Deploying proof-foundry-site"
npx --yes wrangler deploy --assets .\public --name proof-foundry-site --compatibility-date 2026-06-28

Write-Host "==> Done. Verify: https://theprooffoundry.com/  and  https://www.theprooffoundry.com/"
