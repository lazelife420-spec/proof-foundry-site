# H6: rendered Cache Vault WCAG AA regression guard. Uses an independent
# headed Chrome profile, never the owner/desktop browser or port 9331.
[CmdletBinding()]
param(
  [string]$PublicDir = '',
  [switch]$NegativeControl
)
$ErrorActionPreference = 'Stop'
if (-not $PublicDir) { $PublicDir = Join-Path $PSScriptRoot '..\public' }
$arguments = @((Join-Path $PSScriptRoot 'test-h6-rendered-contrast.mjs'), (Resolve-Path $PublicDir).Path)
if ($NegativeControl) { $arguments += '--negative-control' }
$output = & node @arguments
if ($LASTEXITCODE -ne 0) { throw "Rendered contrast harness failed: $output" }
$results = ($output -join "`n") | ConvertFrom-Json
$passed = 0; $failed = 0
foreach ($result in $results) {
  if ($result.pass) { $passed++; Write-Host "PASS: $($result.label)" -ForegroundColor Green }
  else { $failed++; Write-Host "FAIL: $($result.label)" -ForegroundColor Red }
  Write-Host ($result | ConvertTo-Json -Depth 10 -Compress)
}
if ($results.Count -ne 6) { throw "Expected six rendered checks (two targets and live status at two viewport widths), got $($results.Count)" }
Write-Host "=== RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
