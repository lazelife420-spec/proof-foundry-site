# Isolated consumer/renderer test seam. Production build-site.ps1 retains its
# rejection of alternate authority inputs. Facts originate in release-truth.json
# through the shared reducer; tests may tamper with the disposable v1 transport
# to prove malformed/untrusted state is rejected, without authoring site facts.
[CmdletBinding()]
param([switch]$ValidateOnly, [string]$ManifestPath, [string]$OutDir,
  [string]$PreviewProductId, [string]$ProductsDir, [string]$TruthCommit,
  [string]$TruthTree, [string]$TruthCommittedAt, [string]$StateSourcePath)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/release-qualification.ps1"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$out = if ($OutDir) { [IO.Path]::GetFullPath($OutDir) } else { '' }
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
if (-not $out -or -not $out.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or $out.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Qualification fixture output must be isolated under the process temporary directory, outside the source tree.'
}
for ($ancestor = $out; $ancestor; $ancestor = Split-Path -Parent $ancestor) {
  if (Test-Path -LiteralPath $ancestor) {
    if (((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'Qualification fixture output cannot traverse a reparse point.'
    }
  }
  if ($ancestor.TrimEnd('\','/') -eq $tempRoot.TrimEnd('\','/')) { break }
}
$transport = if ($ManifestPath) { Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100 } else { Get-AuthoredReleaseManifest }
if ($transport.releaseFactsSource -and @($transport.products | Where-Object { -not $_.release }).Count -gt 0) {
  if ($ManifestPath -and [IO.Path]::GetFullPath($ManifestPath) -eq (Join-Path $repoRoot 'site-manifest.json')) {
    $transport = Get-AuthoredReleaseManifest
  } else { throw 'Presentation-only site-manifest.json cannot supply fixture release authority.' }
}
# Remove only the authored-loader directive from this already derived test
# transport. This exercises the unchanged v1 consumer validators, not a second
# release authority. It cannot pass the v2 sealed-production deployment gate.
$transport.PSObject.Properties.Remove('releaseFactsSource')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('pf-derived-transport-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
  $fixture = Join-Path $scratch 'derived-compatibility.json'
  [IO.File]::WriteAllText($fixture, ($transport | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
  $options = @{ ManifestPath = $fixture; OutDir = $out }
  foreach ($key in @('ProductsDir','PreviewProductId','StateSourcePath','TruthCommit','TruthTree','TruthCommittedAt')) {
    if ($PSBoundParameters.ContainsKey($key)) { $options[$key] = $PSBoundParameters[$key] }
  }
  if ($ValidateOnly) { $options.ValidateOnly = $true }
  & "$PSScriptRoot/build-site.ps1" @options
  $buildExit = $LASTEXITCODE
} finally {
  # Exact directory created above; never a user-provided cleanup target.
  if ([IO.Path]::GetFullPath($scratch).StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $scratch -Recurse -Force
  }
}
exit $buildExit
