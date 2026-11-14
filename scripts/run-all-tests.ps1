# run-all-tests.ps1 — run every scripts/test-*.ps1 in an isolated pwsh process
# and report pass/fail per file.
#
# Exit-code contract: each test is launched as `pwsh -NoProfile -File <test>` so
# the child's own `exit` statement is the verdict — never a $LASTEXITCODE left
# over by an earlier command in this process. A RESULT line inside the output is
# parsed as a cross-check: a process exit that disagrees with the test's own
# printed result is itself reported as a failure (reliability signal, not a test
# bug).
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot/..").Path

# ── Exit-code mechanism controls ────────────────────────────────────────────
$ctlDir = Join-Path ([IO.Path]::GetTempPath()) ('pf-runner-ctl-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $ctlDir | Out-Null
Set-Content -LiteralPath (Join-Path $ctlDir 'ctl-pass.ps1') -Value 'exit 0' -NoNewline
Set-Content -LiteralPath (Join-Path $ctlDir 'ctl-fail.ps1') -Value 'exit 1' -NoNewline
& pwsh -NoProfile -File (Join-Path $ctlDir 'ctl-pass.ps1') *> $null
$ctlPass = $LASTEXITCODE
& pwsh -NoProfile -File (Join-Path $ctlDir 'ctl-fail.ps1') *> $null
$ctlFail = $LASTEXITCODE
Remove-Item -LiteralPath $ctlDir -Recurse -Force
if ($ctlPass -ne 0 -or $ctlFail -ne 1) {
  Write-Output "RUNNER UNRELIABLE: controls returned pass=$ctlPass fail=$ctlFail (expected 0/1). Aborting."
  exit 2
}
Write-Output "Exit-code controls verified: pass=0, fail=1"
Write-Output ""

# ── Suite ───────────────────────────────────────────────────────────────────
$results = @()
Get-ChildItem (Join-Path $root 'scripts\test-*.ps1') | Sort-Object Name | ForEach-Object {
  $name = $_.Name
  Write-Output "=== RUN $name ==="
  $out = & pwsh -NoProfile -File $_.FullName 2>&1
  $code = $LASTEXITCODE
  $out | Select-Object -Last 3 | ForEach-Object { Write-Output "  $_" }
  # Cross-check: the test's printed RESULT line must agree with its process exit.
  $mismatch = $false
  $resultLine = @($out | Select-String 'RESULT:\s*(\d+)\s*passed,\s*(\d+)\s*failed' | Select-Object -Last 1)
  if ($resultLine) {
    $printedFailed = [int]$resultLine[0].Matches[0].Groups[2].Value
    if (($printedFailed -eq 0) -ne ($code -eq 0)) { $mismatch = $true }
  }
  if ($mismatch) {
    Write-Output "  !! exit-code/result mismatch: exit=$code but RESULT says $($resultLine[0].Matches[0].Value)"
  }
  $results += [pscustomobject]@{ Test = $name; Exit = $(if ($mismatch) { -1 } else { $code }) }
  Write-Output ("--- EXIT {0} {1}" -f $(if ($mismatch) { -1 } else { $code }), $name)
}
Write-Output ""
Write-Output "===== SUMMARY ====="
$results | ForEach-Object { Write-Output ("{0,-45} exit={1}" -f $_.Test, $_.Exit) }
$bad = @($results | Where-Object { $_.Exit -ne 0 })
if ($bad.Count -eq 0) { Write-Output "ALL GREEN"; exit 0 } else { Write-Output "$($bad.Count) FAILING"; exit 1 }
