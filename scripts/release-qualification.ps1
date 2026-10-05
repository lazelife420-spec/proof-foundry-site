# Qualification reads authored release facts through the shared reducer. This
# object is a disposable compatibility transport, never an authored input.
function Get-AuthoredReleaseManifest {
  $adapter = Join-Path $PSScriptRoot 'release-inputs.cjs'
  $consoleEncoding = [Console]::OutputEncoding
  $pipelineEncoding = $OutputEncoding
  try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $bytes = & node -e 'process.stdout.write(JSON.stringify(require(process.argv[1]).readReleaseManifest()))' $adapter
    if ($LASTEXITCODE -ne 0) { throw 'Authored release authority failed validation.' }
  } finally {
    [Console]::OutputEncoding = $consoleEncoding
    $OutputEncoding = $pipelineEncoding
  }
  return ($bytes | ConvertFrom-Json -Depth 100)
}

# Historical authored source comparisons must compile the model at that same
# revision; never compare a presentation-only record against public release data.
function Get-AuthoredReleaseManifestAt([string]$Revision) {
  $scriptPath = Join-Path $PSScriptRoot 'qualification-authority.cjs'
  $bytes = & node $scriptPath $Revision
  if ($LASTEXITCODE -ne 0) { throw 'Historical authored release projection failed.' }
  return ($bytes | ConvertFrom-Json -Depth 100)
}
