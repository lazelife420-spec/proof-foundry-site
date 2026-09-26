[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$Id,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Name,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutDir
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot
$destination = if ([IO.Path]::IsPathRooted($OutDir)) { [IO.Path]::GetFullPath($OutDir) } else { [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutDir)) }
if ($destination -eq [IO.Path]::GetPathRoot($destination)) { throw 'OutDir cannot be a filesystem root.' }
if (Test-Path -LiteralPath $destination) { throw "OutDir already exists; choose a new path: $destination" }
if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match '[<>\r\n]') { throw 'Name must be plain one-line product text.' }
$shortName = if ($Name.Length -gt 32) { $Name.Substring(0,32).Trim() } else { $Name }
$starter = [ordered]@{
  schema = 'proof-foundry.product-capsule/v1'
  id = $Id
  lifecycle = 'draft'
  brand = [ordered]@{ name = $Name; shortName = $shortName; mark = 'brand/mark.svg' }
  theme = [ordered]@{ accent = '#6FA8A2'; accentSecondary = '#D7B77D'; atmosphere = 'foundry' }
  hero = [ordered]@{
    variant = 'split'; kicker = 'TODO: product category'; headline = "TODO: $Name headline"
    lede = 'TODO: explain the product in one clear sentence.'
    media = 'hero/hero.webp'; mediaAlt = 'TODO: describe the product interface'; mediaCaption = 'TODO: identify this capture'
  }
  card = [ordered]@{
    tagline = 'TODO: short product promise'; summary = 'TODO: describe who this product helps and how.'
    media = 'hero/hero.webp'; mediaAlt = 'TODO: describe the catalog image'
  }
  taxonomy = [ordered]@{ category = 'TODO'; jobs = @(); platforms = @() }
  placement = [ordered]@{ catalog = $true; homepageTier = 'hidden'; homepageOrder = 100; homepageVariant = 'workstation' }
  sections = @()
}
$readme = @"
# $Name Product Capsule

This is a presentation-only starter. It contains no release version, artifact,
checksum, download URL, or verification claim.

1. Replace every TODO value in product.json.
2. Replace brand/mark.svg with the real product mark.
3. Replace hero/hero.webp with a real PNG, JPEG, WebP, or AVIF image.
4. Add screenshots under screenshots/ and reference them from a gallery
   section if needed.
5. Import and preview:

   ~~~powershell
   ./scripts/Import-ProductCapsule.ps1 -Path "$destination"
   ./scripts/Preview-Product.ps1 -Id $Id
   ~~~

The importer intentionally rejects these placeholders until they are replaced.
Set placement.homepageTier to featured, major, or secondary to request
local homepage placement; hidden keeps the product route/catalog/truth while
omitting it from the homepage. The legacy value none is normalized to hidden.
"@

if ($PSCmdlet.ShouldProcess($destination, "Create Product Capsule '$Id'")) {
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  foreach ($subdir in @('brand','hero','screenshots')) {
    New-Item -ItemType Directory -Path (Join-Path $destination $subdir) -Force | Out-Null
  }
  $utf8 = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText((Join-Path $destination 'product.json'), ($starter | ConvertTo-Json -Depth 20) + [Environment]::NewLine, $utf8)
  [IO.File]::WriteAllText((Join-Path $destination 'README.md'), $readme, $utf8)
  $placeholderMark = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><title>TODO: replace with the approved product mark</title><rect width="128" height="128" rx="24" fill="#6FA8A2"/><text x="64" y="72" text-anchor="middle" font-size="16">TODO</text></svg>'
  [IO.File]::WriteAllText((Join-Path $destination 'brand/mark.svg'), $placeholderMark, $utf8)
  [IO.File]::WriteAllText((Join-Path $destination 'hero/hero.webp'), 'TODO: replace with a real WebP image file.', $utf8)
  Write-Host "Created draft capsule: $destination"
  Write-Host 'Next: replace all TODO values/assets, import it, and run Preview-Product.ps1.'
}
