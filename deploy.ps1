# deploy.ps1 — Build public/ from source and deploy to Cloudflare Pages.
#
# Prerequisite (one-time): npx wrangler login   (authorize account ceomindset2019)
# Usage:                    ./deploy.ps1
#                           ./deploy.ps1 -AllowDirtyDeploy   (NOT RECOMMENDED — see guard below)
#
# The build is performed by scripts/build-site.ps1, which validates
# site-manifest.json and generates public/ from templates + partials + manifest.
# public/ is a generated artifact — never hand-edit it.
#
# Deploy-safety guard: build-site.ps1 builds public/ from whatever is on disk,
# not from git HEAD. A file left dirty for unrelated reasons would otherwise
# ship silently alongside whatever change this deploy is actually meant for.
# This script refuses to build or deploy while `git status --porcelain=v1` is
# non-empty. Use -AllowDirtyDeploy only after explicitly reviewing and
# accepting every dirty file it lists.

[CmdletBinding()]
param(
  [switch]$AllowDirtyDeploy
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "==> Checking working tree is clean before build/deploy"
$dirty = git status --porcelain=v1
if ($LASTEXITCODE -ne 0) {
  Write-Host "==> DEPLOY BLOCKED: 'git status' failed (exit $LASTEXITCODE). Is $PSScriptRoot a git repository?" -ForegroundColor Red
  exit 1
}
if ($dirty -and -not $AllowDirtyDeploy) {
  Write-Host "==> DEPLOY BLOCKED: working tree is not clean." -ForegroundColor Red
  Write-Host "    build-site.ps1 builds public/ from whatever is on disk right now, not from" -ForegroundColor Red
  Write-Host "    git HEAD -- every file below would be included in this deploy, reviewed or not:" -ForegroundColor Red
  $dirty | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
  Write-Host "    Run 'git status' for full details. Commit, stash, or revert these changes first." -ForegroundColor Red
  Write-Host "    Only if you have explicitly reviewed and accept shipping every file listed" -ForegroundColor Red
  Write-Host "    above, re-run with -AllowDirtyDeploy." -ForegroundColor Red
  exit 1
}
if ($dirty -and $AllowDirtyDeploy) {
  Write-Host "==> WARNING: -AllowDirtyDeploy set. Deploying with a dirty working tree:" -ForegroundColor Yellow
  $dirty | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
}

Write-Host "==> Building public/ (manifest-driven)"
& "$PSScriptRoot\scripts\build-site.ps1"
$buildExit = $LASTEXITCODE
if ($null -eq $buildExit) { $buildExit = 0 }
if ($buildExit -ne 0) {
  Write-Host "==> BUILD FAILED (exit $buildExit). Site not deployed." -ForegroundColor Red
  exit $buildExit
}

Write-Host "==> Deploying proof-foundry-site to Cloudflare Pages"
$deployDirectory = Join-Path $PSScriptRoot 'public'
$deployOutput = npx --yes wrangler pages deploy $deployDirectory --project-name proof-foundry-site --branch main 2>&1
$deployExit = $LASTEXITCODE
$deployOutput | ForEach-Object { Write-Host $_ }

# Parse the deployment URL from wrangler output so we can report it even if
# post-deploy verification fails.  This prevents an agent from mistaking
# "upload succeeded but verification failed" for "nothing was deployed."
$deployUrl = $null
# -match populates $Matches only when the left side is a scalar; wrangler output
# arrives as an array of lines under PowerShell 7, where array -match filters
# instead and $Matches keeps a stale value. Reduce to one string first.
$deployText = ($deployOutput | Out-String)
if ($deployText -match 'https://([a-f0-9]+)\.proof-foundry-site\.pages\.dev') {
  $deployUrl = $Matches[0]
}

if ($deployExit -ne 0) {
  Write-Host "==> DEPLOYMENT FAILED (wrangler exit $deployExit). Cloudflare did not publish." -ForegroundColor Red
  exit $deployExit
}

if ($deployUrl) {
  Write-Host "==> DEPLOYMENT SUCCEEDED: $deployUrl" -ForegroundColor Green
} else {
  Write-Host "==> DEPLOYMENT SUCCEEDED (deployment URL not parsed from output)" -ForegroundColor Green
}

Write-Host "==> Waiting 10 seconds for edge propagation..."
Start-Sleep -Seconds 10

Write-Host "==> Running Verification..."
$ErrorActionPreference = 'Continue'
& "$PSScriptRoot\scripts\Verify-PublicSite.ps1" -Targets "https://proof-foundry-site.pages.dev,https://theprooffoundry.com,https://www.theprooffoundry.com"
$verifyExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($verifyExit -ne 0) {
  Write-Host "" -ForegroundColor Red
  Write-Host "==> POST-DEPLOY VERIFICATION FAILED (exit $verifyExit)." -ForegroundColor Red
  Write-Host "    IMPORTANT: The Cloudflare upload already succeeded." -ForegroundColor Yellow
  if ($deployUrl) {
    Write-Host "    Deployment URL: $deployUrl" -ForegroundColor Yellow
  }
  Write-Host "    Production may already be serving the new deployment." -ForegroundColor Yellow
  Write-Host "    Do NOT retry the deploy command — that creates an unnecessary duplicate deployment." -ForegroundColor Yellow
  Write-Host "    Investigate the verification failures above and fix the verifier or the site." -ForegroundColor Yellow
  exit $verifyExit
}
Write-Host "==> ALL GATES PASSED. Deploy complete." -ForegroundColor Green
