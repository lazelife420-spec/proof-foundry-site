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
Copy-Item index.html, founders.html, forgecast.html, lights-out.html, styles.css, CNAME, robots.txt, sitemap.xml, 404.html, proof.html, site-manifest.json public\
Copy-Item brand, assets public\ -Recurse

# Place product pages and proof page at clean directory routes
New-Item -ItemType Directory public\forgecast | Out-Null
Copy-Item forgecast.html public\forgecast\index.html
New-Item -ItemType Directory public\lights-out | Out-Null
Copy-Item lights-out.html public\lights-out\index.html
New-Item -ItemType Directory public\founders | Out-Null
Copy-Item founders.html public\founders\index.html
New-Item -ItemType Directory public\proof | Out-Null
Copy-Item proof.html public\proof\index.html

# Expose deploy receipts publicly
if (Test-Path reports\deploy-receipts) {
    New-Item -ItemType Directory public\reports\deploy-receipts -Force | Out-Null
    Copy-Item reports\deploy-receipts\* public\reports\deploy-receipts\ -Force
}

# Generate _headers file
$headersContent = @"
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/*.html
  Cache-Control: no-cache, must-revalidate

/lights-out
  Cache-Control: no-cache, must-revalidate

/proof
  Cache-Control: no-cache, must-revalidate

/forgecast/
  Cache-Control: no-cache, must-revalidate

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/brand/*
  Cache-Control: public, max-age=31536000, immutable
"@
$headersContent | Out-File public\_headers -Encoding utf8

# Copy _redirects file from root
Copy-Item _redirects public\ -Force

Write-Host "==> Deploying proof-foundry-site to Cloudflare Pages"
npx --yes wrangler pages deploy .\public --project-name proof-foundry-site --branch main

Write-Host "==> Waiting 10 seconds for edge propagation..."
Start-Sleep -Seconds 10

Write-Host "==> Done. Running Verification..."
$ErrorActionPreference = 'Continue'
& "$PSScriptRoot\scripts\Verify-PublicSite.ps1" -Targets @("https://proof-foundry-site.pages.dev", "https://theprooffoundry.com", "https://www.theprooffoundry.com")
$verifyExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($verifyExit -ne 0) {
    Write-Host "==> VERIFICATION FAILED (exit $verifyExit). Check output above." -ForegroundColor Red
    exit $verifyExit
}
Write-Host "==> ALL GATES PASSED. Deploy complete." -ForegroundColor Green
