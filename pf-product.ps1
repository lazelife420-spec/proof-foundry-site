$ErrorActionPreference = 'Stop'
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Error 'Node.js is required for the local pf-product CLI.'
  exit 2
}
& $node.Source (Join-Path $PSScriptRoot 'scripts/pf-product.mjs') @args
exit $LASTEXITCODE
