# H3 TRUST-TO-ACTION — bounded assertions (observation-driven, P0-P2 scope)
#
# Coverage contract:
#   P0  Reality Gate #origin readability correction is present and paired
#   P1  "What changed" path on all 7 products; onboarding blocks on released
#       products with uninstall + leftover-data answers; support next-step guidance
#   P2  Reality Gate SHA-256 dedupe; Cache Vault stale-reference correction;
#       Lights Out availability honesty; mobile CTA parity; directory discovery
#   H1/H2 preservation guards re-asserted where this tranche touches shared files
#
# Runs against built public/ output. No network.

[CmdletBinding()]
param([string]$PublicDir = '')

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $PublicDir) { $PublicDir = Join-Path $root 'public' }

$script:passed = 0
$script:failed = 0

function Assert-Condition([bool]$cond, [string]$label) {
  if ($cond) { $script:passed++; Write-Host "  PASS: $label" }
  else { $script:failed++; Write-Host "  FAIL: $label" -ForegroundColor Red }
}

function Read-Page([string]$route) {
  $p = if ($route -eq '') { Join-Path $publicDir 'index.html' } else { Join-Path $publicDir "$route\index.html" }
  return Get-Content $p -Raw -Encoding UTF8
}

Write-Host "=== H3 TRUST-TO-ACTION ASSERTIONS ==="

$rg  = Read-Page 'reality-gate'
$cv  = Read-Page 'cache-vault'
$lo  = Read-Page 'lights-out'
$cl  = Read-Page 'cleanroom'
$gl  = Read-Page 'ghostlayer'
$fc  = Read-Page 'forgecast'
$ps  = Read-Page 'proofshot'
$sup = Read-Page 'support'
$homeHtml = Read-Page ''
$catalogHtml = Read-Page 'software'

# ── P0: Reality Gate origin readability ─────────────────────────────────────
Assert-Condition ($rg -match '<section\b(?=[^>]*\bclass="[^"]*\bpp-origin\b)(?=[^>]*\bid="origin")[^>]*>') "P0: Reality Gate origin section remains semantically identified"
Assert-Condition ($rg -match 'href="/product-worlds\.css[?"]' -and (Get-Content (Join-Path $publicDir 'product-worlds.css') -Raw -Encoding UTF8) -match '\.product-reality-gate \.archive-origin-ledger\s*\{') "P0: loaded product-world stylesheet owns the origin section surface"
Assert-Condition ($rg -notmatch 'id="origin" style="background:\s*rgba\(255,255,255,0\.02\)') "P0: old translucent origin background pairing removed"
Assert-Condition ($rg -match '01.*Dependency Became Real') "P0: origin copy preserved (beat 01)"
Assert-Condition ($rg -match 'Case Study Evidence: Lights Out Repository Reconstruction') "P0: origin case-study copy preserved"

# ── P1: What-changed path on all 7 products ─────────────────────────────────
Assert-Condition ($rg -match 'href="#release-note"') "P1: Reality Gate what-changed link present"
Assert-Condition ($rg -match 'id="release-note"') "P1: Reality Gate release-note anchor present"
Assert-Condition ($cv -match 'href="#release-note"') "P1: Cache Vault what-changed link present"
Assert-Condition ($lo -match 'href="#release-note"') "P1: Lights Out what-changed link present"
Assert-Condition ($cl -match 'href="#release-note"') "P1: Cleanroom what-changed link present"
Assert-Condition ($gl -match 'RELEASE_NOTES_v0\.4\.0\.md[^"]*"[^>]*>\s*What changed in v0\.4\.0') "P1: GhostLayer what-changed link to RELEASE_NOTES present"
Assert-Condition ($fc -match 'github\.com/lazelife420-spec/ForgeCast/releases/tag/v0\.3\.5[^"]*"[^>]*>\s*What changed in v0\.3\.5') "P1: ForgeCast what-changed link to GitHub release present"
Assert-Condition ($ps -match 'href="/proof/#receipt-proofshot"' -and $ps -match 'Public release v2\.0\.0') "P1: ProofShot exposes release details through its canonical proof record"

# ── P1: onboarding blocks (released products get full 5-field block) ────────
$released = @{ 'cleanroom' = $cl; 'ghostlayer' = $gl; 'forgecast' = $fc }
foreach ($k in $released.Keys) {
  $h = $released[$k]
  Assert-Condition ($h -match 'Install, update, uninstall &amp; leftover data') "P1: $k onboarding block present"
  Assert-Condition ($h -match '<dt>Uninstall</dt>') "P1: $k uninstall answer present"
  Assert-Condition ($h -match '<dt>Leftover data</dt>') "P1: $k leftover-data answer present"
}
# Onboarding facts must be source-truth anchored (data paths from privacy sections)
Assert-Condition ($rg -match 'Withdrawn:</strong> v1\.1\.0 is not available for download' -and $rg -notmatch 'onboarding-list') "P1: Reality Gate withdrawal does not invent current installation or leftover-data guidance"
Assert-Condition ($cl -match 'onboarding-list[\s\S]*%APPDATA%\\Cleanroom\\Archive\\') "P1: Cleanroom leftovers cite %APPDATA%\Cleanroom\Archive\"
Assert-Condition ($gl -match 'onboarding-list[\s\S]*%TEMP%\\GhostLayer\\') "P1: GhostLayer leftovers cite %TEMP%\GhostLayer\"
Assert-Condition ($fc -match 'onboarding-list[\s\S]*com\.prooffoundry\.skyfoundry') "P1: ForgeCast leftovers cite app-private storage"
# Onboarding stays availability-honest per product: Lights Out v11.2.0 is now a
# public release, so its onboarding names the real download; Cache Vault ships a
# final public release and its onboarding must match the live v0.3.1 download
# instead of the RC-era "unavailable" wording.
Assert-Condition ($lo -match 'Install, update, uninstall') "P1: Lights Out onboarding block present (public-release honest)"
Assert-Condition ($cv -match 'Install, update, uninstall') "P1: Cache Vault onboarding block present (final-release honest)"
Assert-Condition ($lo -match 'Download Lights Out v11\.3\.4' -and $lo -notmatch 'not publicly downloadable|currently unavailable') "P1: Lights Out onboarding names the public v11.3.4 download"
Assert-Condition ($cv -match 'Download v0\.3\.1 \(Windows\)') "P1: Cache Vault onboarding matches the live v0.3.1 download CTA"
Assert-Condition ($cv -match 'The public Windows v0\.3\.1 release is available from Proof Foundry downloads') "P1: Cache Vault install guidance names the live v0.3.1 release"
Assert-Condition ($cv -match 'public, release-signed v0\.3\.1 companion APK') "P1: Cache Vault Android public APK is accurately labeled"

# ── P1: support next-step guidance ──────────────────────────────────────────
Assert-Condition ($sup -match 'What to do with it') "P1: support template carries next-step guidance"
Assert-Condition ($sup -match 'href="/roadmap/"') "P1: support guidance points to the roadmap for channel announcement"
Assert-Condition ($sup -match 'Privacy Warning') "P1: support privacy warning preserved"
# K12: closing support links name the self-service guide; no channel is published
foreach ($pp in @(
    @{ n = 'reality-gate'; h = $rg }, @{ n = 'cache-vault'; h = $cv }, @{ n = 'lights-out'; h = $lo },
    @{ n = 'cleanroom'; h = $cl }, @{ n = 'ghostlayer'; h = $gl }, @{ n = 'forgecast'; h = $fc }, @{ n = 'proofshot'; h = $ps })) {
  $finalCta = [regex]::Match($pp.h, '(?s)<section class="pp-final-cta">.*?</section>').Value
  $supportLabels = @([regex]::Matches($finalCta, '(?s)<a\b[^>]*href="/support/[^"]*"[^>]*>(.*?)</a>') | ForEach-Object { $_.Groups[1].Value })
  Assert-Condition ((-not [string]::IsNullOrWhiteSpace($finalCta)) -and $finalCta -notmatch 'Talk to support' -and $supportLabels.Count -ge 1 -and @($supportLabels | Where-Object { $_ -notmatch '^Support &amp; troubleshooting guide\b' }).Count -eq 0) "P1: $($pp.n) closing CTA names the support guide, not a conversation"
}

# ── P2: Reality Gate SHA-256 dedupe (one canonical verify block) ────────────
$rgShaCount = ([regex]::Matches($rg, '58cc27d2')).Count
Assert-Condition ($rgShaCount -le 2) "P2: Reality Gate hash rendered at most twice (was three) — found $rgShaCount"
$rgDlCount = ([regex]::Matches($rg, 'Download v1\.1\.0 Developer Pilot')).Count
Assert-Condition ($rgDlCount -eq 0 -and $rg -match 'No download is offered\.' -and $rg -notmatch 'aria-disabled="true"' -and $rg -notmatch 'href="https://downloads\.theprooffoundry\.com/reality-gate/') "P2: withdrawn Reality Gate has no download button and says so in plain text - found $rgDlCount"
Assert-Condition ($rg -match 'href="#evidence-download"') "P2: Reality Gate defers to the canonical download block"

# ── P2: final-public availability honesty ──────────────────────────────────
Assert-Condition (
  $cv -match 'v0\.3\.1 is the current public Windows release' -and
  $cv -match 'points to Proof Foundry downloads for the v0\.3\.1 Windows ZIP' -and
  $cv -match 'd0c59c440b1d5787c9319e1bdf8829f117ccaa2d64d3424dd6955a84fb975d45' -and
  $cv -notmatch 'v0\.2\.3-rc1|v0\.2\.3-rc2' -and
  $cv -notmatch 'intentionally not linked'
) "P2: Cache Vault availability copy asserts public v0.3.1 (live URL + published digest) and omits RC-era candidate/404 copy"
Assert-Condition ($lo -notmatch 'download again') "P2: Lights Out no longer instructs a download retry while no download exists"
Assert-Condition ($lo -match '<a href="/support/#report">see the support guide</a>' -and $lo -notmatch 'contact the project') "P2: Lights Out support anchor preserved (P2-1 contract) and named as the support guide"

# ── P2: discovery affordances ────────────────────────────────────────────────
Assert-Condition ($catalogHtml -match '<form\b[^>]*data-directory-finder[^>]*role="search"' -and $catalogHtml -match 'type="search" name="query"' -and $catalogHtml -match '<select name="group"' -and $catalogHtml -match 'data-directory-count role="status" aria-live="polite"') "P2: directory search, group filtering and accessible result count live on /software/"
Assert-Condition ($catalogHtml -match 'data-directory-empty[^>]*>No matching products\.' -and $catalogHtml -match 'type="reset">Clear</button>' -and $catalogHtml -notmatch 'data-compare=|Choose up to three tools to compare') "P2: directory offers empty-result recovery without obsolete comparison promises"
# Mobile CTA parity: studio.css no longer hides the nav CTA
$studioCss = Get-Content (Join-Path $root 'studio.css') -Raw -Encoding UTF8
Assert-Condition ($studioCss -notmatch '\.studio \.nav-cta\{display:none\}') "P2: mobile nav CTA no longer hidden at <=900px"
$primaryNav = [regex]::Match($homeHtml, '(?s)<nav class="pf-route-chain[^>]*aria-label="Primary navigation".*?</nav>').Value
Assert-Condition (([regex]::Matches($homeHtml, '<nav[^>]*aria-label="Primary navigation"')).Count -eq 1 -and ([regex]::Matches($primaryNav, '<a ')).Count -eq 6 -and $primaryNav -match 'href="/support/"' -and $homeHtml -notmatch 'class="top-nav"|class="nav-panel"|class="nav-toggle"') "P2: one physical-key primary navigation exposes six routes including Support without duplicate menus"

# ── Shared-component presence ────────────────────────────────────────────────
$stylesCss = Get-Content (Join-Path $root 'styles.css') -Raw -Encoding UTF8
Assert-Condition ($stylesCss -match '\.onboarding-list dt') "shared onboarding-list styles present"

# ── H1/H2 preservation guards (this tranche touches shared files) ───────────
# H9 keeps the forge-to-outside Home journey concise; product browsing is on Software.
# CP-0185 (owner directive, 2026-11-07): Unify welded navigation across all 6 pages.
# The canonical six-key bank sits under the header ahead of the main-site journey: hero, five-stage
# instrument, orientation, principle, records and support.
$journey = @('ledger-hero', 'ledger-chain', 'home-orientation', 'ledger-doctrine', 'home-records', 'home-contact')
$positions = @($journey | ForEach-Object { [regex]::Match($homeHtml, '<section\b[^>]*class="[^"]*\b' + $_ + '\b[^"]*"').Index })
$ordered = @($positions | Where-Object { $_ -le 0 }).Count -eq 0
for ($i = 1; $i -lt $positions.Count; $i++) { if ($positions[$i] -le $positions[$i - 1]) { $ordered = $false } }
$keyBankAt = $homeHtml.IndexOf('id="primary-nav"')
if (-not ($keyBankAt -gt $homeHtml.IndexOf('</header>') -and $keyBankAt -lt $positions[0])) { $ordered = $false }
Assert-Condition ($ordered -and ([regex]::Matches($homeHtml, 'class="pfa-num"')).Count -eq 5 -and ([regex]::Matches($homeHtml, 'class="stage-btn"')).Count -eq 5 -and $homeHtml -match 'id="chain-title"' -and $homeHtml -notmatch 'class="studio-portfolio"|studio-evidence') "Proof Ledger: unified key bank, hero, five-stage proof chain, orientation, principle, records and support form the main-site journey"
$heroHtml = [regex]::Match($homeHtml, '(?s)<section class="ledger-hero"[^>]*>.*?</section>').Value
$directoryIds = @([regex]::Matches($catalogHtml, '<article\b[^>]*data-directory-entry="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
$expectedIds = @('cache-vault','lights-out','cleanroom','ghostlayer','forgecast','hardline-zero','crosspoint','reality-gate','proof-foundry-app') | Sort-Object
Assert-Condition ($heroHtml -cmatch '<a class="button button-primary" href="/software/">Browse Products ' -and ($directoryIds -join ',') -ceq ($expectedIds -join ',') -and $catalogHtml -match '<a class="text-link" href="/proofshot/">Read ProofShot.s history</a>' -and $catalogHtml -notmatch 'data-directory-entry="proofshot"') "Proof Ledger: hero reaches the nine-entry Products directory with ProofShot's history linked, not featured (owner decision 2026-11-05: the review-inventory history section is withheld)"
# Main-site hero is scoped to its opening section; release facts stay in records.
$heroText = { param($h) (([regex]::Replace([regex]::Replace($h, '(?i)<br\s*/?>', ' '), '<[^>]+>', ' ')) -replace '\s+', ' ').Trim() }
Assert-Condition ((& $heroText ([regex]::Match($heroHtml, '(?s)<h1\b[^>]*>(.*?)</h1>').Groups[1].Value)) -ceq 'Real software leaves a record.' -and (& $heroText ([regex]::Match($heroHtml, '(?s)<p class="home-intro">(.*?)</p>').Groups[1].Value)) -ceq 'Useful tools. Deliberately made. Public releases you can inspect.' -and $heroHtml -match 'href="/proof-standard/"' -and $heroHtml -notmatch '\b[0-9a-f]{64}\b') "Proof Ledger: current brand-first headline, useful-software introduction and proof path lead the hero without a release digest"
Assert-Condition ($homeHtml -notmatch 'Lights Out PC <span aria-hidden="true">') "H2 preserved: homepage short naming intact"
Assert-Condition ($rg -match 'Your projects\.' -and $rg -match 'Your execution\.' -and $rg -match 'Your way back\.') "H1/H2 preserved: Reality Gate module hero copy remains intact"
Assert-Condition ($gl -match '<strong>Status</strong> Public release' -and $gl -match '<strong>Version</strong> v0\.4\.0') "truth preserved: GhostLayer public release version remains intact"
Assert-Condition ($ps -match 'Download ProofShot v2\.0\.0' -and $ps -match 'href="/proof/#receipt-proofshot"') "truth preserved: ProofShot public release links to its release record"

Write-Host ""
Write-Host "=== H3 RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
