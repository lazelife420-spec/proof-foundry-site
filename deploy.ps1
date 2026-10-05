# Publish only a committed, qualified artifact; never rebuild during deployment.
# Production requires exact served-byte qualification of the same preview artifact.
[CmdletBinding()]
param(
  [ValidateSet('stage','production')][string]$Mode,
  [string]$Artifact,
  [string]$QualificationReceipt,
  [string]$StageReceipt
)
$ErrorActionPreference = 'Stop'
if (-not $Mode -or -not $Artifact -or -not $QualificationReceipt) {
  throw 'Explicit mode, sealed artifact and qualified candidate receipt required. No build or authentication has occurred.'
}
if ($Mode -eq 'production' -and -not $StageReceipt) {
  throw 'Production requires the exact served-preview byte receipt. No authentication has occurred.'
}
& node (Join-Path $PSScriptRoot 'scripts/authority-deployment.cjs') $Mode $Artifact $QualificationReceipt $StageReceipt
exit $LASTEXITCODE
