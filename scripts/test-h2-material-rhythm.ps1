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
Assert-H2 'H9 collection links to the functional software catalog' ($homeHtml -match 'href="/software/"' -and $catalogHtml -match 'id="catalog-title"')
Assert-H2 'H9 proof section has a labelled heading' ($homeHtml -match 'aria-labelledby="proof-title"' -and $homeHtml -match 'id="proof-title"')
Assert-H2 'H9 studio identity uses the selected G monogram' ($homeHtml -match 'h9-studio-chip' -and $homeHtml -match 'PF_MARK_G_MASTER\.svg')
Assert-H2 'frozen founders route remains discoverable' ($homeHtml -match 'href="/founders/"')
Assert-H2 'H9 principles remain labelled' ($homeHtml -match 'class="h9-principles" aria-label="Studio principles"')

# --- Released-product media states not empty ---
$cardImgs = [regex]::Matches($catalogHtml, 'catalog-image-link"[^>]*>\s*<img src="(?<src>/assets/[^"]+)" alt="(?<alt>[^"]+)"')
Assert-H2 'all seven software catalog cards carry real imagery slots' ($cardImgs.Count -eq 7)
$releasedIds = @('lights-out', 'cleanroom', 'ghostlayer')
foreach ($rid in $releasedIds) {
  $cardBlock = [regex]::Match($catalogHtml, "(?s)product-card card-$rid.*?</article>").Value
  $hasImg = $cardBlock -match 'catalog-image-link" href="[^"]+"[^>]*>\s*<img src="/assets/studio/[^"]+"'
  $imgEmpty = $cardBlock -match '<img src=""' -or $cardBlock -match 'catalog-image-link[^>]*>\s*</a>'
  Assert-H2 "$rid media frame carries real imagery" ($hasImg -and -not $imgEmpty)
}
$proofshotBlock = [regex]::Match($catalogHtml, '(?s)product-card card-proofshot.*?</article>').Value
Assert-H2 'ProofShot catalog frame pairs legacy workbench imagery with public release truth' ($proofshotBlock -match 'workbench-home' -and $proofshotBlock -match 'data-availability="public-release"' -and $proofshotBlock -match 'Public v2\.0\.0')

# --- Naming consistency (homepage-facing only) ---
Assert-H2 'homepage card/footer labels use Lights Out (not Lights Out PC)' ($homeHtml -notmatch 'Lights Out PC' -and $homeHtml -match 'Lights Out')
Assert-H2 'homepage card/footer labels use ForgeCast (not ForgeCast Weather)' ($homeHtml -notmatch 'ForgeCast Weather' -and $homeHtml -match 'ForgeCast')
$lightsOutPage = Get-Content (Join-Path $public 'lights-out/index.html') -Raw -Encoding UTF8
$forgecastPage = Get-Content (Join-Path $public 'forgecast/index.html') -Raw -Encoding UTF8
Assert-H2 'canonical Lights Out PC naming preserved on its product page' ($lightsOutPage -match 'Lights Out PC')
Assert-H2 'canonical ForgeCast Weather naming preserved on its product page' ($forgecastPage -match 'ForgeCast Weather')

# H9 supersedes H1 homepage composition; its real media and seven-product
# discovery are now protected in the editorial home and functional catalog.
Assert-H2 'H9 forged field retains real hero artwork' ($homeHtml -match 'h9-hero-forge' -and $homeHtml -match 'forged_pf_emblem_in_smoky_ruins')
Assert-H2 'H9 editorial hero copy preserved' ($homeHtml -match 'Useful software\.' -and $homeHtml -match 'On your terms\.')
Assert-H2 'H9 catalog exposes seven comparison choices' (([regex]::Matches($catalogHtml, 'data-compare=')).Count -eq 7)
Assert-H2 'D1 tablet containment override still served' ($css -match '@media \(max-width: 940px\) and \(min-width: 701px\)')
Assert-H2 'H1 hero composition rules intact' ($css -match '(?s)\.signature-home \.studio-home-hero \{[^}]*min-height: 680px')

if ($fail -gt 0) {
  Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Red
  exit 1
}

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor Green
