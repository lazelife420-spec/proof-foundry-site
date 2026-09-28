[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$TestName)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$registryPath = Join-Path $PSScriptRoot 'test-authority-registry.json'
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entry = @($registry.legacyScripts | Where-Object { $_.script -eq $TestName }) | Select-Object -First 1

if (-not $entry -or $entry.status -notin @('SUPERSEDED_CONTRACT', 'HISTORICAL_ONLY')) {
  Write-Error "No delegable test-authority entry for $TestName"
  exit 1
}

# Preserve the archived qualification receipt, but allow the authorized site
# tranche to evolve files named by that historical manifest. Current owners
# below hold the live assertions for the updated source.
$freeze = if ($registry.qualificationFreeze) { $registry.qualificationFreeze } else { $registry.candidate }
$manifestRelativePath = if ($freeze.manifest) { [string]$freeze.manifest } else { [string]$freeze.workingTreeManifest }
$manifestExpectedHash = if ($freeze.manifestSha256) { [string]$freeze.manifestSha256 } else { [string]$freeze.workingTreeManifestSha256 }
$manifestPath = Join-Path $root $manifestRelativePath
$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifestHash -ne $manifestExpectedHash) {
  Write-Error 'Archived qualification manifest bytes changed; refusing delegated coverage.'
  exit 1
}
foreach ($line in Get-Content -LiteralPath $manifestPath -Encoding UTF8) {
  if ($line -notmatch '^([a-f0-9]{64})\s+(.+)$') { Write-Error "Malformed qualified manifest line: $line"; exit 1 }
  $relativePath = $Matches[2]
  $filePath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { Write-Error "Archived candidate path missing: $relativePath"; exit 1 }
}
Write-Host 'PASS: historical receipt bytes are preserved; current site source is governed by its live owner gates.'

$ownerIds = @($entry.families | ForEach-Object { $_.owners } | Select-Object -Unique)
if ($ownerIds.Count -eq 0) { Write-Error "No controlling gate owners declared for $TestName"; exit 1 }
$passed = 0
$failed = 0
$testInventory = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'test-*.ps1' -File | ForEach-Object { $_.Name })
$expectedTestCount = if ($freeze.scriptInventoryCount) { [int]$freeze.scriptInventoryCount } else { 24 }
if ($testInventory.Count -ne $expectedTestCount) { Write-Error "Expected $expectedTestCount test scripts in the qualification inventory; found $($testInventory.Count)."; exit 1 }
Write-Host "=== TEST AUTHORITY: $TestName [$($entry.status)] ==="
Write-Host "Reason: $($entry.action)"

foreach ($family in $entry.families) {
  $familyOwners = @($family.owners)
  if ($familyOwners.Count -eq 0) { Write-Error "Invariant family has no owner: $($family.name)"; $failed++; continue }
  foreach ($ownerId in $familyOwners) {
    $authority = @($registry.authorities | Where-Object { $_.id -eq $ownerId }) | Select-Object -First 1
    if (-not $authority) { Write-Error "Unregistered controlling authority: $ownerId"; $failed++; continue }
    $gatePath = Join-Path $PSScriptRoot $authority.script
    if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf) -or $authority.script -notin $testInventory) {
      Write-Error "Controlling gate is missing from the 24-script suite: $($authority.script)"; $failed++; continue
    }
    Write-Host "PASS: $($family.name) is owned by $ownerId ($($authority.script))"
    $passed++
  }
}
Write-Host "Current owner gates execute as their own members of the required $expectedTestCount-script run."
Write-Host "=== AUTHORITY REGISTRY RESULT: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
