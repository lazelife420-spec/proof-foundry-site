# deploy.ps1 — Build public/ from source and deploy to Cloudflare Pages.
#
# Prerequisite (one-time): npx wrangler login   (authorize account ceomindset2019)
# Usage:                    ./deploy.ps1
#
# The build is performed by scripts/build-site.ps1, which validates
# site-manifest.json and generates public/ from templates + partials + manifest.
# public/ is a generated artifact — never hand-edit it.

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Building public/ (manifest-driven)"
& "$PSScriptRoot\scripts\build-site.ps1"
$buildExit = $LASTEXITCODE
if ($null -eq $buildExit) { $buildExit = 0 }
if ($buildExit -ne 0) {
  Write-Host "==> BUILD FAILED (exit $buildExit). Site not deployed." -ForegroundColor Red
  exit $buildExit
}

Write-Host "==> Deploying proof-foundry-site to Cloudflare Pages"
npx --yes wrangler pages deploy .\public --project-name proof-foundry-site --branch main

Write-Host "==> Waiting 10 seconds for edge propagation..."
Start-Sleep -Seconds 10

Write-Host "==> Running Verification..."
$ErrorActionPreference = 'Continue'
& "$PSScriptRoot\scripts\Verify-PublicSite.ps1" -Targets @("https://proof-foundry-site.pages.dev", "https://theprooffoundry.com", "https://www.theprooffoundry.com")
$verifyExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($verifyExit -ne 0) {
  Write-Host "==> VERIFICATION FAILED (exit $verifyExit). Check output above." -ForegroundColor Red
  exit $verifyExit
}
Write-Host "==> ALL GATES PASSED. Deploy complete." -ForegroundColor Green
