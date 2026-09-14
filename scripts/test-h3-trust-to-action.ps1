# H3 TRUST-TO-ACTION — bounded assertions (observation-driven, P0-P2 scope)
#
# Coverage contract:
#   P0  Reality Gate #origin readability correction is present and paired
#   P1  "What changed" path on all 7 products; onboarding blocks on released
#       products with uninstall + leftover-data answers; support next-step guidance
#   P2  Reality Gate SHA-256 dedupe; Cache Vault stale-reference correction;
#       Lights Out no-download-honesty; mobile CTA parity; compare hint visible
#   H1/H2 preservation guards re-asserted where this tranche touches shared files
#
# Runs against built public/ output. No network.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$publicDir = Join-Path $root 'public'

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

# ── P0: Reality Gate origin readability ─────────────────────────────────────
Assert-Condition ($rg -match '\.product-reality-gate #origin') "P0: Reality Gate carries the origin readability correction"
Assert-Condition ($rg -match 'background:\s*#101418') "P0: origin section is given a dark paired surface"
Assert-Condition ($rg -notmatch 'id="origin" style="background:\s*rgba\(255,255,255,0\.02\)') "P0: old translucent origin background pairing removed"
Assert-Condition ($rg -match '01 · Dependency Became Real') "P0: origin copy preserved (beat 01)"
Assert-Condition ($rg -match 'Case Study Evidence: Lights Out Repository Reconstruction') "P0: origin case-study copy preserved"

# ── P1: What-changed path on all 7 products ─────────────────────────────────
Assert-Condition ($rg -match 'href="#release-note"') "P1: Reality Gate what-changed link present"
Assert-Condition ($rg -match 'id="release-note"') "P1: Reality Gate release-note anchor present"
Assert-Condition ($cv -match 'href="#release-note"') "P1: Cache Vault what-changed link present"
Assert-Condition ($lo -match 'href="#release-note"') "P1: Lights Out what-changed link present"
Assert-Condition ($cl -match 'href="#release-note"') "P1: Cleanroom what-changed link present"
Assert-Condition ($gl -match 'RELEASE_NOTES_v0\.4\.0\.md[^"]*"[^>]*>\s*What changed in v0\.4\.0') "P1: GhostLayer what-changed link to RELEASE_NOTES present"
Assert-Condition ($fc -match 'github\.com/lazelife420-spec/ForgeCast/releases/tag/v0\.3\.5[^"]*"[^>]*>\s*What changed in v0\.3\.5') "P1: ForgeCast what-changed link to GitHub release present"
Assert-Condition ($ps -match 'no changelog yet') "P1: ProofShot explicitly states no changelog (no release)"

# ── P1: onboarding blocks (released products get full 5-field block) ────────
$released = @{ 'reality-gate' = $rg; 'cleanroom' = $cl; 'ghostlayer' = $gl; 'forgecast' = $fc }
foreach ($k in $released.Keys) {
  $h = $released[$k]
  Assert-Condition ($h -match 'Install, update, uninstall &amp; leftover data') "P1: $k onboarding block present"
  Assert-Condition ($h -match '<dt>Uninstall</dt>') "P1: $k uninstall answer present"
  Assert-Condition ($h -match '<dt>Leftover data</dt>') "P1: $k leftover-data answer present"
}
# Onboarding facts must be source-truth anchored (data paths from privacy sections)
Assert-Condition ($rg -match 'onboarding-list[\s\S]*%APPDATA%\\RealityGate\\') "P1: Reality Gate leftovers cite %APPDATA%\RealityGate\"
Assert-Condition ($cl -match 'onboarding-list[\s\S]*%APPDATA%\\Cleanroom\\Archive\\') "P1: Cleanroom leftovers cite %APPDATA%\Cleanroom\Archive\"
Assert-Condition ($gl -match 'onboarding-list[\s\S]*%TEMP%\\GhostLayer\\') "P1: GhostLayer leftovers cite %TEMP%\GhostLayer\"
Assert-Condition ($fc -match 'onboarding-list[\s\S]*com\.prooffoundry\.forgecast') "P1: ForgeCast leftovers cite app-private storage"
# Onboarding stays availability-honest per product: Lights Out is held (no
# download promised); Cache Vault now ships a final public release, so its
# onboarding must match the live v0.2.3 download instead of the RC-era
# "unavailable" wording. The Android companion hold copy is preserved exactly.
Assert-Condition ($lo -match 'Install, update, uninstall') "P1: Lights Out onboarding block present (held-state honest)"
Assert-Condition ($cv -match 'Install, update, uninstall') "P1: Cache Vault onboarding block present (final-release honest)"
Assert-Condition ($lo -match 'not publicly downloadable') "P1: Lights Out onboarding does not promise a download"
Assert-Condition ($cv -match 'Download v0\.2\.3 \(Windows\)') "P1: Cache Vault onboarding matches the live final v0.2.3 download CTA"
Assert-Condition ($cv -match 'The public Windows v0\.2\.3 release is available from Proof Foundry downloads') "P1: Cache Vault install guidance names the live v0.2.3 release"
Assert-Condition ($cv -match 'Android: public companion v0\.2\.0; v0\.2\.1 remains on hold') "P1: Cache Vault keeps the Android hold truth intact"

# ── P1: support next-step guidance ──────────────────────────────────────────
Assert-Condition ($sup -match 'What to do with it') "P1: support template carries next-step guidance"
Assert-Condition ($sup -match 'href="/roadmap/"') "P1: support guidance points to the roadmap for channel announcement"
Assert-Condition ($sup -match 'Privacy Warning') "P1: support privacy warning preserved"

# ── P2: Reality Gate SHA-256 dedupe (one canonical verify block) ────────────
$rgShaCount = ([regex]::Matches($rg, '58cc27d2')).Count
Assert-Condition ($rgShaCount -le 2) "P2: Reality Gate hash rendered at most twice (was three) — found $rgShaCount"
$rgDlCount = ([regex]::Matches($rg, 'Download v1\.1\.0 Developer Pilot')).Count
Assert-Condition ($rgDlCount -eq 1) "P2: Reality Gate download button appears exactly once — found $rgDlCount"
Assert-Condition ($rg -match 'href="#evidence-download"') "P2: Reality Gate defers to the canonical download block"

# ── P2: final-public availability honesty ──────────────────────────────────
Assert-Condition (
  $cv -match 'v0\.2\.3 is the current public Windows release' -and
  $cv -match 'points to Proof Foundry downloads for the v0\.2\.3 Windows ZIP' -and
  $cv -match '28262e491ad1f7b3f6f4c9f28eabfe2899a61af7c7a26c17c4915d604e00371d' -and
  $cv -notmatch 'v0\.2\.3-rc1|v0\.2\.3-rc2' -and
  $cv -notmatch 'intentionally not linked'
) "P2: Cache Vault availability copy correctly asserts final public v0.2.3 (live URL + published digest) and omits RC-era candidate/404 copy"
Assert-Condition ($lo -notmatch 'download again') "P2: Lights Out no longer instructs a download retry while no download exists"
Assert-Condition ($lo -match '<a href="/support/#report">contact the project</a>') "P2: Lights Out support anchor preserved (P2-1 contract)"

# ── P2: discovery affordances ────────────────────────────────────────────────
Assert-Condition ($homeHtml -match 'class="finder-hint"') "P2: compare/finder hint present in homepage markup"
Assert-Condition ($homeHtml -match 'Compare two or three') "P2: compare hint copy present"
# Mobile CTA parity: studio.css no longer hides the nav CTA
$studioCss = Get-Content (Join-Path $root 'studio.css') -Raw -Encoding UTF8
Assert-Condition ($studioCss -notmatch '\.studio \.nav-cta\{display:none\}') "P2: mobile nav CTA no longer hidden at <=900px"
Assert-Condition ((Get-Content (Join-Path $root 'styles.css') -Raw -Encoding UTF8) -match '\.nav-cta \{\s*margin-top: 0\.9rem') "P2: styles.css mobile nav-cta panel rule intact"

# ── Shared-component presence ────────────────────────────────────────────────
$stylesCss = Get-Content (Join-Path $root 'styles.css') -Raw -Encoding UTF8
Assert-Condition ($stylesCss -match '\.onboarding-list dt') "shared onboarding-list styles present"

# ── H1/H2 preservation guards (this tranche touches shared files) ───────────
Assert-Condition ($homeHtml -match 'zone-index') "H2 preserved: zone index markers still present on homepage"
Assert-Condition ($homeHtml -match 'PF / 01') "H2 preserved: PF/01 rhythm marker present"
Assert-Condition ($homeHtml -match 'Good software\.') "H1 preserved: hero headline untouched"
Assert-Condition ($homeHtml -notmatch 'Lights Out PC <span aria-hidden="true">') "H2 preserved: homepage short naming intact"
Assert-Condition ($rg -match 'Your projects\.<br><em>Your execution\. Your way back\.</em>') "H1/H2 preserved: Reality Gate hero headline untouched"
Assert-Condition ($gl -match 'Public v0\.4\.0') "truth preserved: GhostLayer version claim intact"
Assert-Condition ($ps -match 'There is no public ProofShot release or installer') "truth preserved: ProofShot no-release claim intact"

Write-Host ""
Write-Host "=== H3 RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }

