# H2 — PAGE MATERIAL RHYTHM bounded regression checks.
# Runs against the built output in public/ (run scripts/build-site.ps1 first).
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$homePath = Join-Path $public 'index.html'
$cssPath = Join-Path $public 'signature.css'

if (-not (Test-Path $homePath)) { throw "Generated homepage missing: $homePath" }
if (-not (Test-Path $cssPath)) { throw "Generated signature stylesheet missing: $cssPath" }

$homeHtml = Get-Content $homePath -Raw -Encoding UTF8
$catalogHtml = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
$css = Get-Content $cssPath -Raw -Encoding UTF8
$pass = 0
$fail = 0

function Assert-H2([string]$name, [bool]$condition) {
  if ($condition) {
    $script:pass++
    Write-Host "PASS: $name" -ForegroundColor Green
  } else {
    $script:fail++
    Write-Host "FAIL: $name" -ForegroundColor Red
  }
}

# --- Material-zone tokens / rules present ---
Assert-H2 'iron/slate catalog floor tokens exist' ($css -match '--pf-iron-floor')
Assert-H2 'warmer forged-field tokens exist' ($css -match '--pf-forge-edge')
Assert-H2 'catalog carries the iron/slate field' ($css -match '(?s)\.signature-home \.studio-catalog \{[^}]*--pf-iron-floor')
Assert-H2 'founders signpost carries the warm forged field' ($css -match '(?s)\.signature-home \.founders-signpost \{[^}]*--pf-forge-edge')
Assert-H2 'card family shares the forged-iron surface' ($css -match '(?s)\.signature-home \.product-card \{[^}]*linear-gradient')
Assert-H2 'Cleanroom pale outlier treatment is gone' ($css -notmatch '#c7d5d1')

# H9 replaces the numbered H2 seams with explicit editorial sections. Protect
# that navigation/section contract instead of resurrecting obsolete PF indices.
# CP-0189 replaces the H9 seams with the approved ledger sections and the
# directory catalog. Protect that contract.
Assert-H2 'collection links to the functional software catalog' ($homeHtml -match 'href="/software/"' -and $catalogHtml -match 'id="directory-title"')
Assert-H2 'records section has a labelled heading' ($homeHtml -match 'aria-labelledby="home-records-title"' -and $homeHtml -match 'id="home-records-title"')
Assert-H2 'studio identity uses the machined PF emblem' ($homeHtml -match 'PF_MARK_G_TI_HEADER\.webp' -and $homeHtml -match 'pf-emblem')
Assert-H2 'frozen founders route remains discoverable' ($homeHtml -match 'href="/founders/"')
Assert-H2 'record-chain section remains labelled' ($homeHtml -match 'class="ledger-chain container" aria-labelledby="chain-title"')

# --- Released-product media states not empty ---
$cardImgs = [regex]::Matches($catalogHtml, 'class="directory-art"[^>]*>\s*<img src="(?<src>/assets/[^"]+)" alt="(?<alt>[^"]+)"')
Assert-H2 'all five everyday directory entries carry real imagery slots' ($cardImgs.Count -eq 5)
$releasedIds = @('lights-out', 'cleanroom', 'ghostlayer')
foreach ($rid in $releasedIds) {
  $cardBlock = [regex]::Match($catalogHtml, "(?s)data-directory-entry=`"$rid`".*?</article>").Value
  $hasImg = $cardBlock -match 'class="directory-art"[^>]*>\s*<img src="/assets/[^"]+"'
  $imgEmpty = $cardBlock -match '<img src=""'
  Assert-H2 "$rid directory frame carries real imagery" ($hasImg -and -not $imgEmpty)
}
Assert-H2 'ProofShot history route pairs brand identity with public release truth' ($catalogHtml -match 'href="/proofshot/"' -and $catalogHtml -notmatch 'data-directory-entry="proofshot"')

# --- Naming consistency (homepage-facing only) ---
Assert-H2 'homepage uses no short-name product labels' ($homeHtml -notmatch 'Lights Out PC' -and $homeHtml -notmatch 'ForgeCast Weather')
Assert-H2 'catalog uses the short product labels' ($catalogHtml -match 'Lights Out' -and $catalogHtml -match 'ForgeCast' -and $catalogHtml -notmatch 'Lights Out PC')
$lightsOutPage = Get-Content (Join-Path $public 'lights-out/index.html') -Raw -Encoding UTF8
$forgecastPage = Get-Content (Join-Path $public 'forgecast/index.html') -Raw -Encoding UTF8
Assert-H2 'canonical Lights Out PC naming preserved on its product page' ($lightsOutPage -match 'Lights Out PC')
Assert-H2 'canonical ForgeCast Weather naming preserved on its product page' ($forgecastPage -match 'ForgeCast Weather')

# H9 supersedes H1 homepage composition; its real media and seven-product
# discovery are now protected in the editorial home and functional catalog.
Assert-H2 'forged field retains the machined emblem' ($homeHtml -match 'ledger-hero' -and $homeHtml -match 'PF_MARK_G_TI_460\.webp' -and $homeHtml -notmatch 'forged_pf_emblem_in_smoky_ruins')
Assert-H2 'approved hero copy preserved' ($homeHtml -match 'Real software' -and $homeHtml -match 'leaves a record\.')
Assert-H2 'catalog exposes the five everyday public downloads' (([regex]::Matches($catalogHtml, 'data-availability="download"')).Count -eq 5)
Assert-H2 'D1 tablet containment override still served' ($css -match '@media \(max-width: 940px\) and \(min-width: 701px\)')
Assert-H2 'H1 hero composition rules intact' ($css -match '(?s)\.signature-home \.studio-home-hero \{[^}]*min-height: 680px')

if ($fail -gt 0) {
  Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
