# test-brand-invariants.ps1 — invariant tests for the brand token authority.
#
# Every test runs the real validator against FIXTURE copies of
# brand/proof-foundry.theme.json and styles.css written to a temp directory. The
# canonical files are never written to, so a failed or interrupted run cannot
# damage brand authority data.
#
# This suite is separate from test-receipts-invariants.ps1 on purpose: that suite
# is scoped to the manifest/registry pipeline and its harness mutates a JSON
# object graph, while brand fixtures are two plain text surfaces. The enforcement
# itself lives in scripts/build-site.ps1, which every build and deploy already
# runs, so the guard cannot be skipped by forgetting to run this file — this file
# only proves the guard fires.
#
# Proves:
#   1. baseline         - canonical brand data passes with no [brand] error
#   2. theme regression - copper cannot reoccupy theme proof_teal
#   3. css regression   - copper cannot reoccupy styles.css --teal
#   4. product accent   - a product accent cannot occupy the shared house teal
#   5. intra-file       - palette and css_variables cannot silently disagree
#   6. pinned values    - each canonical house token fails independently
#   7. namespace freedom- product-specific tokens are not policed
#   8. immutability     - canonical brand files byte-identical after all tests
#   9. malformed input  - unparseable theme fails as [brand], not as a crash
#  10. missing input    - each missing brand input fails as [brand], not a crash
$ErrorActionPreference = 'Stop'

$root       = (Resolve-Path "$PSScriptRoot/..").Path
$buildPs1   = Join-Path $root 'scripts\build-site.ps1'
$canonTheme = Join-Path $root 'brand\proof-foundry.theme.json'
$canonCss   = Join-Path $root 'styles.css'
$work       = Join-Path ([IO.Path]::GetTempPath()) ("pf-brand-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null

$themeShaBefore = (Get-FileHash $canonTheme -Algorithm SHA256).Hash.ToLower()
$cssShaBefore   = (Get-FileHash $canonCss   -Algorithm SHA256).Hash.ToLower()

$pass = 0; $fail = 0
function Assert($name, [bool]$ok, $detail = '') {
  if ($ok) { $script:pass++; Write-Host "PASS: $name" -ForegroundColor Green }
  else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red; if ($detail) { Write-Host "      $detail" -ForegroundColor Red } }
}

# Build against fixture brand data. $mutateTheme receives the parsed theme object
# and returns it; $mutateCss receives the stylesheet text and returns it. Passing
# $null for either leaves that surface canonical. $ThemeOverride/$CssOverride
# force a literal path (used to exercise missing/malformed inputs).
function Invoke-BrandBuild {
  param(
    [string]$Name,
    [scriptblock]$MutateTheme,
    [scriptblock]$MutateCss,
    [string]$RawTheme,
    [string]$ThemeOverride,
    [string]$CssOverride
  )
  $fixDir = Join-Path $work $Name
  New-Item -ItemType Directory -Force -Path $fixDir | Out-Null

  $themeArg = $ThemeOverride
  if (-not $themeArg) {
    $fixTheme = Join-Path $fixDir 'proof-foundry.theme.json'
    if ($PSBoundParameters.ContainsKey('RawTheme')) {
      [IO.File]::WriteAllText($fixTheme, $RawTheme, (New-Object System.Text.UTF8Encoding $false))
    } else {
      $obj = Get-Content $canonTheme -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($MutateTheme) { $obj = & $MutateTheme $obj }
      [IO.File]::WriteAllText($fixTheme, ($obj | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding $false))
    }
    $themeArg = $fixTheme
  }

  $cssArg = $CssOverride
  if (-not $cssArg) {
    $fixCss = Join-Path $fixDir 'styles.css'
    $text = [IO.File]::ReadAllText($canonCss)
    if ($MutateCss) { $text = & $MutateCss $text }
    [IO.File]::WriteAllText($fixCss, $text, (New-Object System.Text.UTF8Encoding $false))
    $cssArg = $fixCss
  }

  $psExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Process -Id $PID).Path }
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName  = $psExe
  $pinfo.Arguments = "-NoProfile -File `"$buildPs1`" -ValidateOnly -ThemePath `"$themeArg`" -StylesPath `"$cssArg`""
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError  = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow  = $true
  $p = [System.Diagnostics.Process]::Start($pinfo)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  return @{ Exit = $p.ExitCode; Output = ($stdout + "`n" + $stderr).Trim() }
}

Write-Host "=== fixture workspace: $work ===" -ForegroundColor Cyan
Write-Host ""

# ── TEST 1: canonical baseline ───────────────────────────────────────────────
Write-Host "--- TEST 1: canonical brand data passes validation ---"
$t1 = Invoke-BrandBuild -Name 'baseline'
Assert 'canonical brand data validates'        ($t1.Exit -eq 0) $t1.Output
Assert 'no [brand] error on canonical data'    ($t1.Output -notmatch '\[brand\]') $t1.Output
Write-Host ""

# ── TEST 2: theme Proof Teal historical regression ──────────────────────────
# The exact defect corrected in 3af93a2, reintroduced on the theme side only.
Write-Host "--- TEST 2: copper cannot reoccupy theme proof_teal ---"
$t2 = Invoke-BrandBuild -Name 'theme-copper' -MutateTheme {
  param($o) $o.palette.proof_teal = '#B9823F'; $o
}
Assert 'copper in theme proof_teal fails'      ($t2.Exit -ne 0) "exit=$($t2.Exit)"
Assert 'error names proof_teal'                ($t2.Output -match 'palette\.proof_teal') $t2.Output
Assert 'error names canonical #00D1B2'         ($t2.Output -match '#00D1B2')
Assert 'error names the superseded copper'     ($t2.Output -match 'superseded copper #B9823F')
Write-Host ""

# ── TEST 3: CSS Proof Teal historical regression ─────────────────────────────
# Theme stays canonical, stylesheet drifts. This is the asymmetric case that a
# pinned-value check alone would miss and equality alone would also miss if both
# surfaces moved together.
Write-Host "--- TEST 3: copper cannot reoccupy styles.css --teal ---"
$t3 = Invoke-BrandBuild -Name 'css-copper' -MutateCss {
  param($t) $t.Replace('--teal: #00D1B2;', '--teal: #B9823F;')
}
Assert 'copper in styles.css --teal fails'     ($t3.Exit -ne 0) "exit=$($t3.Exit)"
Assert 'error reports cross-file disagreement' ($t3.Output -match "styles\.css --teal is '#B9823F'") $t3.Output
Assert 'error names the superseded copper'     ($t3.Output -match 'superseded copper #B9823F')
Write-Host ""

# ── TEST 4: product accent occupying the house teal ─────────────────────────
Write-Host "--- TEST 4: a product accent cannot occupy shared --teal ---"
$t4 = Invoke-BrandBuild -Name 'css-product-accent' -MutateCss {
  param($t) $t.Replace('--teal: #00D1B2;', '--teal: #1A9E8C;')
}
Assert 'Cache Vault accent in --teal fails'    ($t4.Exit -ne 0) "exit=$($t4.Exit)"
Assert 'error names the offending value'       ($t4.Output -match "styles\.css --teal is '#1A9E8C'") $t4.Output
Write-Host ""

# ── TEST 5: theme intra-file disagreement ───────────────────────────────────
Write-Host "--- TEST 5: theme cannot disagree with itself ---"
$t5 = Invoke-BrandBuild -Name 'theme-intra' -MutateTheme {
  param($o) $o.css_variables.'--pf-teal' = '#00CC33'; $o
}
Assert 'palette/css_variables mismatch fails'  ($t5.Exit -ne 0) "exit=$($t5.Exit)"
Assert 'error names both sides'                ($t5.Output -match 'theme disagrees with itself.*proof_teal.*--pf-teal') $t5.Output
Write-Host ""

# ── TEST 6: every pinned canonical token fails independently ────────────────
Write-Host "--- TEST 6: each canonical house token is independently pinned ---"
$pinned = [ordered]@{
  'stamp_gold'    = '#D6A84F'
  'foundry_black' = '#0B0F14'
  'iron_gray'     = '#1C232B'
  'receipt_white' = '#F4F7F8'
  'warning_red'   = '#E5484D'
}
foreach ($token in $pinned.Keys) {
  $tk = $token
  $r = Invoke-BrandBuild -Name "pinned-$tk" -MutateTheme {
    param($o) $o.palette.$tk = '#123456'; $o
  }.GetNewClosure()
  Assert "mutating $tk fails the build"        ($r.Exit -ne 0) "exit=$($r.Exit)"
  Assert "error identifies $tk"                ($r.Output -match "palette\.$tk is '#123456'") $r.Output
  Assert "error states expected $($pinned[$tk])" ($r.Output -match [regex]::Escape($pinned[$tk])) $r.Output
}
Write-Host ""

# ── TEST 7: product namespaces are not policed ──────────────────────────────
# Product tokens are injected directly into :root alongside the house tokens, and
# the shipped product card literals are altered. House tokens stay canonical, so
# the guard must stay silent — it protects house-token authority, not palette
# diversity. Cleanroom's --cln-gold deliberately equals the house gold, which a
# diversity rule would have rejected.
Write-Host "--- TEST 7: product-specific tokens are not policed ---"
$t7 = Invoke-BrandBuild -Name 'product-freedom' -MutateCss {
  param($t)
  $t = $t.Replace('  --teal: #00D1B2;', "  --teal: #00D1B2;`n  --cv-accent: #7733AA;`n  --gl-volatile: #FF00FF;`n  --cln-mint: #D6A84F;`n  --ps-focus: #010203;")
  $t = $t.Replace('rgba(26, 158, 140, 0.28)', 'rgba(119, 51, 170, 0.28)')
  $t = $t.Replace('rgba(0, 204, 51, 0.28)',   'rgba(255, 0, 255, 0.28)')
  $t
}
Assert 'product token changes do not fail'     ($t7.Exit -eq 0) $t7.Output
Assert 'no [brand] error for product tokens'   ($t7.Output -notmatch '\[brand\]') $t7.Output
Write-Host ""

# ── TEST 9: malformed theme JSON ────────────────────────────────────────────
# Ordered before the immutability check so TEST 8 closes the suite.
Write-Host "--- TEST 9: malformed theme JSON fails as [brand], not as a crash ---"
$t9 = Invoke-BrandBuild -Name 'theme-malformed' -RawTheme '{ "palette": { "proof_teal": '
Assert 'malformed theme fails the build'       ($t9.Exit -ne 0) "exit=$($t9.Exit)"
Assert 'failure is a named [brand] error'      ($t9.Output -match '\[brand\].*not valid JSON') $t9.Output
Assert 'no uncontrolled PowerShell exception'  ($t9.Output -notmatch 'ScriptStackTrace|Exception:\s*$|At line:') $t9.Output

$t9b = Invoke-BrandBuild -Name 'theme-shape' -RawTheme '{ "brand": "no palette here" }'
Assert 'theme missing palette fails'           ($t9b.Exit -ne 0) "exit=$($t9b.Exit)"
Assert 'error names the missing objects'       ($t9b.Output -match "missing the required 'palette'") $t9b.Output
Write-Host ""

# ── TEST 10: missing required brand inputs ──────────────────────────────────
# Theme and stylesheet use separate resolution and separate Test-Path branches,
# so both are exercised.
Write-Host "--- TEST 10: missing brand inputs fail as [brand], not as a crash ---"
$absent = Join-Path $work 'does-not-exist-on-purpose'
$t10a = Invoke-BrandBuild -Name 'theme-missing' -ThemeOverride (Join-Path $absent 'theme.json')
Assert 'missing theme fails the build'         ($t10a.Exit -ne 0) "exit=$($t10a.Exit)"
Assert 'error names the missing theme'         ($t10a.Output -match '\[brand\] theme file not found') $t10a.Output
Assert 'no Resolve-Path exception escaped'     ($t10a.Output -notmatch 'ScriptStackTrace|Cannot find path') $t10a.Output

$t10b = Invoke-BrandBuild -Name 'css-missing' -CssOverride (Join-Path $absent 'styles.css')
Assert 'missing stylesheet fails the build'    ($t10b.Exit -ne 0) "exit=$($t10b.Exit)"
Assert 'error names the missing stylesheet'    ($t10b.Output -match '\[brand\] shared stylesheet not found') $t10b.Output
Assert 'no Resolve-Path exception escaped'     ($t10b.Output -notmatch 'ScriptStackTrace|Cannot find path') $t10b.Output

$t10c = Invoke-BrandBuild -Name 'css-no-root' -MutateCss { param($t) $t -replace ':root\s*\{[^}]*\}', '' }
Assert 'stylesheet without :root fails'        ($t10c.Exit -ne 0) "exit=$($t10c.Exit)"
Assert 'error explains :root is unresolvable'  ($t10c.Output -match 'declares no :root block') $t10c.Output
Write-Host ""

# ── TEST 8: canonical brand files untouched ─────────────────────────────────
Write-Host "--- TEST 8: canonical brand files are byte-identical ---"
$themeShaAfter = (Get-FileHash $canonTheme -Algorithm SHA256).Hash.ToLower()
$cssShaAfter   = (Get-FileHash $canonCss   -Algorithm SHA256).Hash.ToLower()
Assert 'brand/proof-foundry.theme.json unchanged' ($themeShaAfter -eq $themeShaBefore) "before=$themeShaBefore after=$themeShaAfter"
Assert 'styles.css unchanged'                     ($cssShaAfter -eq $cssShaBefore)     "before=$cssShaBefore after=$cssShaAfter"
Write-Host ""

Write-Host "=== RESULT: $pass passed, $fail failed ===" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { exit 1 }
exit 0
