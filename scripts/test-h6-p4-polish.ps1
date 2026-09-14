# H6 P4 bounded-polish regression guard.
# Covers the two mechanically proven Cache Vault WCAG 2.1 AA contrast fixes.
# Runs against source and generated output. No network.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourceCssPath = Join-Path $root 'experience.css'
$publicCssPath = Join-Path $root 'public\experience.css'

$script:passed = 0
$script:failed = 0

function Assert-Condition([bool]$condition, [string]$label) {
  if ($condition) {
    $script:passed++
    Write-Host "PASS: $label" -ForegroundColor Green
  } else {
    $script:failed++
    Write-Host "FAIL: $label" -ForegroundColor Red
  }
}

function Get-RelativeLuminance([string]$hex) {
  $channels = @(0, 2, 4 | ForEach-Object {
    [Convert]::ToInt32($hex.Substring($_ + 1, 2), 16) / 255.0
  } | ForEach-Object {
    if ($_ -le 0.04045) { $_ / 12.92 } else { [Math]::Pow(($_ + 0.055) / 1.055, 2.4) }
  })
  return (0.2126 * $channels[0]) + (0.7152 * $channels[1]) + (0.0722 * $channels[2])
}

function Get-ContrastRatio([string]$foreground, [string]$background) {
  $a = Get-RelativeLuminance $foreground
  $b = Get-RelativeLuminance $background
  return ([Math]::Max($a, $b) + 0.05) / ([Math]::Min($a, $b) + 0.05)
}

if (-not (Test-Path $sourceCssPath)) { throw "Source stylesheet missing: $sourceCssPath" }
if (-not (Test-Path $publicCssPath)) { throw "Generated stylesheet missing: $publicCssPath" }

$sourceCss = Get-Content $sourceCssPath -Raw -Encoding UTF8
$publicCss = Get-Content $publicCssPath -Raw -Encoding UTF8

$archiveKicker = '#526248'
$archiveBackground = '#d9dfcd'
$clipStatus = '#5a6a50'
$clipBackground = '#eef0e7'
$kickerRatio = Get-ContrastRatio $archiveKicker $archiveBackground
$statusRatio = Get-ContrastRatio $clipStatus $clipBackground

Assert-Condition ($sourceCss -match '\.archive-demo \.kicker\{color:#526248\}') 'source: archive-demo kicker uses the corrected contrast color'
Assert-Condition ($sourceCss -match '\.clip-status\{[^}]*color:#5a6a50') 'source: clip-status uses the corrected contrast color'
Assert-Condition ($publicCss -match '\.archive-demo \.kicker\{color:#526248\}') 'output: archive-demo kicker preserves the corrected contrast color'
Assert-Condition ($publicCss -match '\.clip-status\{[^}]*color:#5a6a50') 'output: clip-status preserves the corrected contrast color'
Assert-Condition ($kickerRatio -ge 4.5) ("WCAG AA: archive-demo kicker contrast is {0:N2}:1 (>= 4.50:1)" -f $kickerRatio)
Assert-Condition ($statusRatio -ge 4.5) ("WCAG AA: clip-status contrast is {0:N2}:1 (>= 4.50:1)" -f $statusRatio)
Assert-Condition ($sourceCss -notmatch '#586a4f|#6b7b60') 'source: pre-H6 failing colors are absent'
Assert-Condition ($publicCss -notmatch '#586a4f|#6b7b60') 'output: pre-H6 failing colors are absent'

Write-Host "=== RESULT: $($script:passed) passed, $($script:failed) failed ==="
if ($script:failed -gt 0) { exit 1 }
exit 0
