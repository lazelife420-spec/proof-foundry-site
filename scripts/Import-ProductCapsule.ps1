[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
  [string]$ProductsRoot,
  [string]$ManifestPath,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot
$capsuleRoot = (Resolve-Path -LiteralPath $Path).Path
$productsRoot = if ($ProductsRoot) { [IO.Path]::GetFullPath($ProductsRoot) } else { Join-Path $repoRoot 'products' }
$productsRoot = [IO.Path]::GetFullPath($productsRoot)
$manifestFile = if ($ManifestPath) { [IO.Path]::GetFullPath($ManifestPath) } else { Join-Path $repoRoot 'site-manifest.json' }
$productJsonPath = Join-Path $capsuleRoot 'product.json'
if (-not (Test-Path -LiteralPath $productJsonPath -PathType Leaf)) { throw 'Capsule root must contain product.json.' }
if (-not (Test-Path -LiteralPath $productsRoot -PathType Container)) { throw "ProductsRoot does not exist: $productsRoot" }
if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf)) { throw 'Canonical site-manifest.json was not found.' }

function Assert-HasProperties($object, [string[]]$required, [string[]]$allowed, [string]$where) {
  if ($object -isnot [System.Management.Automation.PSCustomObject]) { throw "$where must be an object." }
  $names = @($object.PSObject.Properties.Name)
  foreach ($key in $required) { if ($names -notcontains $key) { throw "$where is missing required property '$key'." } }
  foreach ($key in $names) { if ($allowed -notcontains $key) { throw "$where contains unsupported property '$key'." } }
}
function Assert-CleanText($node, [string]$where) {
  if ($node -is [string]) {
    if ($node -match '(?i)\bTODO\b|\bTBD\b|REPLACE[- ]ME') { throw "$where still contains a scaffold placeholder." }
  } elseif ($node -is [System.Management.Automation.PSCustomObject]) {
    foreach ($property in $node.PSObject.Properties) { Assert-CleanText $property.Value "$where.$($property.Name)" }
  } elseif ($node -is [array]) {
    for ($i=0; $i -lt $node.Count; $i++) { Assert-CleanText $node[$i] "$where[$i]" }
  }
}
function Resolve-CapsulePath([string]$relative, [string]$where) {
  if ([string]::IsNullOrWhiteSpace($relative) -or $relative.Contains('\') -or $relative -match '^(?:/|[A-Za-z]:)|(^|/)\.\.?(/|$)|//|[:?#]') {
    throw "$where must be a safe relative capsule path using forward slashes."
  }
  if ($relative -notmatch '^[A-Za-z0-9._/-]+$') { throw "$where contains unsupported path characters." }
  $full = [IO.Path]::GetFullPath((Join-Path $capsuleRoot ($relative.Replace('/',[IO.Path]::DirectorySeparatorChar))))
  $prefix = $capsuleRoot.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "$where escapes the capsule root." }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "$where points to a missing file: $relative" }
  $item = Get-Item -LiteralPath $full -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "$where must not use symbolic links or reparse points." }
  $parent = Split-Path -Parent $full
  while ($parent.StartsWith($capsuleRoot,[StringComparison]::OrdinalIgnoreCase)) {
    $parentItem = Get-Item -LiteralPath $parent -Force
    if (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "$where must not traverse a symbolic link or reparse point." }
    if ($parent -eq $capsuleRoot) { break }
    $parent = Split-Path -Parent $parent
  }
  return $full
}
function Assert-ImageFile([string]$full, [string]$relative) {
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
  if ($extension -notin @('.png','.jpg','.jpeg','.webp','.avif')) { throw "Unsupported image type: $relative" }
  $bytes = [IO.File]::ReadAllBytes($full)
  if ($bytes.Length -lt 16 -or $bytes.Length -gt 20971520) { throw "Image is empty or larger than 20 MiB: $relative" }
  $valid = switch ($extension) {
    '.png' { $bytes[0] -eq 137 -and $bytes[1] -eq 80 -and $bytes[2] -eq 78 -and $bytes[3] -eq 71 }
    { $_ -in @('.jpg','.jpeg') } { $bytes[0] -eq 255 -and $bytes[1] -eq 216 -and $bytes[2] -eq 255 }
    '.webp' { [Text.Encoding]::ASCII.GetString($bytes,0,4) -eq 'RIFF' -and [Text.Encoding]::ASCII.GetString($bytes,8,4) -eq 'WEBP' }
    '.avif' { [Text.Encoding]::ASCII.GetString($bytes,4,4) -eq 'ftyp' -and [Text.Encoding]::ASCII.GetString($bytes,8,4) -match '^(avif|avis|mif1)$' }
    default { $false }
  }
  if (-not $valid) { throw "File extension does not match a supported image signature: $relative" }
}
function Assert-PassiveSvg([string]$full, [string]$relative) {
  if ((Get-Item -LiteralPath $full).Length -gt 1048576) { throw "SVG exceeds 1 MiB: $relative" }
  $svgText = [IO.File]::ReadAllText($full)
  if ($svgText -match '(?i)\bTODO\b|\bTBD\b|<\s*(script|foreignObject|iframe|object|embed|animate|set|style)\b|\son[a-z]+\s*=|\sstyle\s*=|url\s*\(|(?:href|src)\s*=\s*["'']\s*(?:https?:|//|javascript:|data:)') {
    throw "SVG is active, externally linked, or still a placeholder: $relative"
  }
  $settings = [Xml.XmlReaderSettings]::new()
  $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
  $settings.XmlResolver = $null
  $reader = [Xml.XmlReader]::Create($full,$settings)
  try {
    $doc = [Xml.XmlDocument]::new(); $doc.XmlResolver = $null; $doc.Load($reader)
  } finally { $reader.Dispose() }
  if (-not $doc.DocumentElement -or $doc.DocumentElement.LocalName -ne 'svg') { throw "Brand asset is not an SVG document: $relative" }
  foreach ($element in $doc.SelectNodes('//*')) {
    if ($element.LocalName -match '^(?i:script|foreignObject|iframe|object|embed|animate|set|style)$') { throw "SVG contains a forbidden active element: $relative" }
    foreach ($attribute in $element.Attributes) {
      if ($attribute.Name -match '^(?i:on)' -or $attribute.Name -match '^(?i:href|src|style)$') { throw "SVG contains a forbidden attribute: $relative" }
    }
  }
}
function Map-CapsuleAsset([string]$relative, [string]$id) {
  if ($relative -match '^brand/mark\.svg$') { return "/assets/products/$id/brand/logo.svg" }
  if ($relative -match '^brand/logo\.svg$') { return "/assets/products/$id/brand/wordmark.svg" }
  if ($relative -match '^hero/') { return "/assets/products/$id/media/" + [IO.Path]::GetFileName($relative) }
  if ($relative -match '^screenshots/') { return "/assets/products/$id/media/screenshots/" + $relative.Substring('screenshots/'.Length) }
  if ($relative -eq 'social/og.png') { return "/assets/products/$id/media/social/og.png" }
  throw "Asset path is outside the capsule asset folders: $relative"
}

try { $capsule = Get-Content -LiteralPath $productJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { throw "product.json is invalid JSON: $($_.Exception.Message)" }
Assert-HasProperties $capsule @('schema','id','brand','theme','hero','card','taxonomy','placement','sections') @('schema','id','lifecycle','brand','theme','hero','card','taxonomy','placement','sections','social') 'product.json'
if ($capsule.schema -ne 'proof-foundry.product-capsule/v1') { throw 'Unsupported product capsule schema; expected proof-foundry.product-capsule/v1.' }
if ($capsule.id -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw 'Product id must be a lowercase kebab-case slug.' }
Assert-CleanText $capsule 'product.json'
Assert-HasProperties $capsule.brand @('name','shortName','mark') @('name','shortName','mark','logo') 'brand'
Assert-HasProperties $capsule.theme @('accent','accentSecondary','atmosphere') @('accent','accentSecondary','atmosphere') 'theme'
Assert-HasProperties $capsule.hero @('variant','kicker','headline','lede','media','mediaAlt','mediaCaption') @('variant','kicker','headline','emphasis','lede','media','mediaAlt','mediaCaption') 'hero'
Assert-HasProperties $capsule.card @('tagline','summary','media','mediaAlt') @('tagline','summary','media','mediaAlt') 'card'
Assert-HasProperties $capsule.taxonomy @('category','jobs','platforms') @('category','jobs','platforms') 'taxonomy'
Assert-HasProperties $capsule.placement @('catalog') @('catalog','homepageTier','homepageOrder','homepageVariant','homepageNote') 'placement'
if ($capsule.lifecycle -and $capsule.lifecycle -notin @('draft','preview','public-eligible')) { throw 'lifecycle must be draft, preview, or public-eligible.' }
if ($capsule.theme.accent -notmatch '^(#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?|rgba?\(\s*(\d{1,3}\s*,\s*){2}\d{1,3}(\s*,\s*(0|1|0?\.\d+))?\s*\))$' -or
    $capsule.theme.accentSecondary -notmatch '^(#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?|rgba?\(\s*(\d{1,3}\s*,\s*){2}\d{1,3}(\s*,\s*(0|1|0?\.\d+))?\s*\))$') { throw 'Theme colors must be hex, rgb(), or rgba() values.' }
$atmospheres = @('archive','night','control-room','weather','carbon','memory','clean','foundry','none')
if ($capsule.theme.atmosphere -notin $atmospheres) { throw 'Unsupported theme atmosphere.' }
$heroVariants = @('split','centered','cinematic','console','device','immersive')
if ($capsule.hero.variant -notin $heroVariants) { throw 'Unsupported hero variant.' }
if ($capsule.placement.homepageTier -and $capsule.placement.homepageTier -notin @('featured','major','secondary','hidden','none')) { throw 'Unsupported homepageTier.' }
if ($capsule.placement.homepageVariant -and $capsule.placement.homepageVariant -notin @('forge-scene','workstation','device','console','wide-screen','compact')) { throw 'Unsupported homepageVariant.' }
if ($capsule.placement.homepageOrder -and $capsule.placement.homepageOrder -isnot [ValueType]) { throw 'homepageOrder must be numeric.' }
if ($capsule.placement.catalog -isnot [bool]) { throw 'placement.catalog must be a boolean.' }
if ($capsule.social) { Assert-HasProperties $capsule.social @() @('ogImage') 'social' }
if ($capsule.sections -isnot [array]) { throw 'sections must be an array.' }
if ($capsule.sections.Count -gt 30) { throw 'A capsule may contain at most 30 sections.' }
$supportedTypes = @('outcomes','features','copy','gallery','faq','guided-tour','devices','integrations')
foreach ($section in $capsule.sections) {
  Assert-HasProperties $section @('type') @('type','id','kicker','title','lede','paragraphs','items') 'section'
  if ($section.type -notin $supportedTypes) { throw "Unsupported section type '$($section.type)'." }
  if ($section.id -and $section.id -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') { throw 'Section id must be a safe HTML identifier.' }
  if ($section.items -and $section.items.Count -gt 12) { throw "Section '$($section.type)' has more than 12 items." }
  foreach ($item in @($section.items)) {
    Assert-HasProperties $item @() @('title','body','note','src','alt','caption') "section $($section.type) item"
    if ($item.src) { $null = Resolve-CapsulePath ([string]$item.src) "section.$($section.type).item.src" }
  }
}

$assets = @{}
$assetPaths = @([string]$capsule.brand.mark,[string]$capsule.hero.media,[string]$capsule.card.media)
if ($capsule.brand.logo) { $assetPaths += [string]$capsule.brand.logo }
if ($capsule.social -and $capsule.social.ogImage) { $assetPaths += [string]$capsule.social.ogImage }
foreach ($section in $capsule.sections) { foreach ($item in @($section.items)) { if ($item.src) { $assetPaths += [string]$item.src } } }
foreach ($assetPath in @($assetPaths | Select-Object -Unique)) {
  $full = Resolve-CapsulePath $assetPath 'asset'
  if ($assetPath -match '^brand/') { if ([IO.Path]::GetExtension($assetPath).ToLowerInvariant() -ne '.svg') { throw 'Brand mark and logo must be SVG.' }; Assert-PassiveSvg $full $assetPath }
  else { Assert-ImageFile $full $assetPath }
  $assets[$assetPath] = $full
}
foreach ($file in Get-ChildItem -LiteralPath $capsuleRoot -Recurse -File -Force) {
  $rel = $file.FullName.Substring($capsuleRoot.TrimEnd('\').Length).TrimStart('\','/').Replace('\','/')
  if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Capsule contains a reparse-point file: $rel" }
  if ($rel -in @('product.json','README.md')) { continue }
  if ($rel -in @('brand/mark.svg','brand/logo.svg')) { Assert-PassiveSvg $file.FullName $rel; continue }
  if ($rel -eq 'social/og.png') { Assert-ImageFile $file.FullName $rel; continue }
  if ($rel -match '^(hero|screenshots)/.+\.(png|jpe?g|webp|avif)$') { Assert-ImageFile $file.FullName $rel; continue }
  throw "Unsupported capsule file: $rel"
}
$markFull = Resolve-CapsulePath ([string]$capsule.brand.mark) 'brand.mark'
if ([IO.Path]::GetExtension($capsule.brand.mark).ToLowerInvariant() -ne '.svg') { throw 'brand.mark must be an SVG file.' }
if ($capsule.brand.logo -and [IO.Path]::GetExtension($capsule.brand.logo).ToLowerInvariant() -ne '.svg') { throw 'brand.logo must be an SVG file.' }
if ($capsule.hero.media -notmatch '^hero/' -or $capsule.card.media -notmatch '^(hero/|screenshots/)') { throw 'Hero media must be under hero/ and card media under hero/ or screenshots/.' }
foreach ($sp in @('hero/mediaAlt','card/mediaAlt')) {
  $value = if ($sp -eq 'hero/mediaAlt') { $capsule.hero.mediaAlt } else { $capsule.card.mediaAlt }
  if ([string]::IsNullOrWhiteSpace([string]$value)) { throw "$sp is required." }
}
if ($capsule.social -and $capsule.social.ogImage -ne 'social/og.png') { throw 'Optional social image path must be social/og.png.' }

$id = [string]$capsule.id
$target = [IO.Path]::GetFullPath((Join-Path $productsRoot $id))
$rootPrefix = $productsRoot.TrimEnd('\') + [IO.Path]::DirectorySeparatorChar
if (-not $target.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Resolved product destination escapes ProductsRoot.' }
$existingTarget = Test-Path -LiteralPath $target
if ($existingTarget) {
  if (-not $Force) { throw "Product directory already exists; use -Force only to replace this same module: products/$id" }
  $oldModulePath = Join-Path $target 'module.json'
  if (-not (Test-Path -LiteralPath $oldModulePath -PathType Leaf)) { throw '-Force will replace only a directory containing a module.json for the same id.' }
  $oldModule = Get-Content -LiteralPath $oldModulePath -Raw | ConvertFrom-Json
  if ($oldModule.id -ne $id) { throw '-Force target module id does not match the capsule id.' }
  $targetItem = Get-Item -LiteralPath $target -Force
  if (($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw '-Force cannot replace a linked or reparse-point directory.' }
}
foreach ($dir in Get-ChildItem -LiteralPath $productsRoot -Directory -Force) {
  if ($dir.FullName -eq $target) { continue }
  $candidate = Join-Path $dir.FullName 'module.json'
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
  try { $other = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json } catch { continue }
  if ($other.id -eq $id -or ([string]$other.route).ToLowerInvariant() -eq "/$id/") { throw "Duplicate product id or route already exists in $($dir.Name)." }
}

$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$truth = @($manifest.products | Where-Object { $_.id -eq $id }) | Select-Object -First 1
$requestedLifecycle = if ($capsule.lifecycle) { [string]$capsule.lifecycle } else { 'preview' }
$gateReady = $truth -and $truth.route -eq "/$id/" -and $truth.visible -and $truth.release.releaseStatus -eq 'PUBLIC_RELEASE' -and $truth.verification.status -eq 'VERIFIED' -and -not [string]::IsNullOrWhiteSpace([string]$truth.release.publicVersion)
$lifecycle = $requestedLifecycle
if ($requestedLifecycle -eq 'public-eligible' -and -not $gateReady) { $lifecycle = 'preview' }
$visibility = if ($lifecycle -eq 'public-eligible') { 'visible' } else { 'hidden' }
$order = 100
foreach ($otherPath in Get-ChildItem -LiteralPath $productsRoot -Directory -Force) {
  $otherJson = Join-Path $otherPath.FullName 'module.json'
  if (Test-Path -LiteralPath $otherJson) { try { $otherDoc=Get-Content -LiteralPath $otherJson -Raw | ConvertFrom-Json; if ($otherDoc.order -is [ValueType]) { $order=[Math]::Max($order,[int]$otherDoc.order+10) } } catch {} }
}
$sectionObjects = @()
foreach ($section in $capsule.sections) {
  $copy = [ordered]@{ type=[string]$section.type }
  foreach ($key in @('id','kicker','title','lede')) { if ($section.$key) { $copy[$key]=[string]$section.$key } }
  if ($section.paragraphs) { $copy.paragraphs=@($section.paragraphs | ForEach-Object { [string]$_ }) }
  if ($section.items) {
    $copy.items = @($section.items | ForEach-Object {
      $item=[ordered]@{}
      foreach ($key in @('title','body','note','alt','caption')) { if ($_.PSObject.Properties[$key] -and $_.$key) { $item[$key]=[string]$_.$key } }
      if ($_.src) { $item.src=Map-CapsuleAsset ([string]$_.src) $id }
      $item
    })
  }
  $sectionObjects += $copy
}
$moduleSections = @('hero') + $sectionObjects
$module = [ordered]@{
  id=$id; route="/$id/"; order=$order; visibility=$visibility; lifecycle=$lifecycle
  schemaVersion=2
  brand=[ordered]@{ name=[string]$capsule.brand.name; shortName=[string]$capsule.brand.shortName; mark="/assets/products/$id/brand/logo.svg" }
  theme=[ordered]@{ accent=[string]$capsule.theme.accent; accentSecondary=[string]$capsule.theme.accentSecondary; atmosphere=[string]$capsule.theme.atmosphere }
  hero=[ordered]@{
    variant=[string]$capsule.hero.variant; kicker=[string]$capsule.hero.kicker; headline=[string]$capsule.hero.headline
    lede=[string]$capsule.hero.lede; media=[ordered]@{ src=(Map-CapsuleAsset ([string]$capsule.hero.media) $id); alt=[string]$capsule.hero.mediaAlt; caption=[string]$capsule.hero.mediaCaption }
  }
  card=[ordered]@{
    tagline=[string]$capsule.card.tagline; summary=[string]$capsule.card.summary
    media=(Map-CapsuleAsset ([string]$capsule.card.media) $id); mediaAlt=[string]$capsule.card.mediaAlt
  }
  taxonomy=[ordered]@{ category=[string]$capsule.taxonomy.category; jobs=@($capsule.taxonomy.jobs | ForEach-Object { [string]$_ }); platforms=@($capsule.taxonomy.platforms | ForEach-Object { [string]$_ }) }
  placement=[ordered]@{ catalog=[bool]$capsule.placement.catalog }
  sections=$moduleSections
  meta=[ordered]@{
    title=([string]$capsule.brand.name + ' — ' + [string]$capsule.hero.headline + ' | The Proof Foundry')
    description=[string]$capsule.hero.lede; robots='index, follow'; viewport='width=device-width, initial-scale=1'
    ogTitle=([string]$capsule.brand.name + ' — ' + [string]$capsule.hero.headline)
    ogDescription=[string]$capsule.hero.lede; ogType='product'
    ogImage=if ($capsule.social -and $capsule.social.ogImage) { Map-CapsuleAsset ([string]$capsule.social.ogImage) $id } else { 'https://theprooffoundry.com/brand/proof-foundry-social-card.png' }
  }
}
if ($capsule.brand.logo) { $module.brand.logo="/assets/products/$id/brand/wordmark.svg" }
$tier = if (-not $capsule.placement.homepageTier -or $capsule.placement.homepageTier -eq 'none') { 'hidden' } else { [string]$capsule.placement.homepageTier }
$variant = if ($capsule.placement.homepageVariant) { [string]$capsule.placement.homepageVariant } else { 'workstation' }
$homeOrder = if ($capsule.placement.homepageOrder) { [int]$capsule.placement.homepageOrder } else { $order }
$module.homepage=[ordered]@{
  tier=$tier; variant=$variant; order=$homeOrder
  headline=[string]$capsule.hero.headline; lede=[string]$capsule.hero.lede
  media=(Map-CapsuleAsset ([string]$capsule.hero.media) $id); mediaAlt=[string]$capsule.hero.mediaAlt
  mediaCaption=[string]$capsule.hero.mediaCaption; note=[string]$capsule.placement.homepageNote
}

$stage = Join-Path $productsRoot ('.' + $id + '.import-stage-' + [Guid]::NewGuid().ToString('N'))
$backup = Join-Path $productsRoot ('.' + $id + '.import-backup-' + [Guid]::NewGuid().ToString('N'))
$destinationText = "products/$id/ ($lifecycle)"
Write-Host "Capsule validated. Planned module: $destinationText"
if ($requestedLifecycle -eq 'public-eligible' -and -not $gateReady) {
  Write-Host 'Publication gate did not match canonical manifest truth; lifecycle will remain preview.'
}
Write-Host 'Before public eligibility: a matching verified PUBLIC_RELEASE manifest record, explicit public-eligible lifecycle, visible presentation, and a successful site build are required.'
if ($PSCmdlet.ShouldProcess($destinationText, 'Import normalized presentation module')) {
  New-Item -ItemType Directory -Path $stage | Out-Null
  try {
    Copy-Item $markFull (Join-Path $stage 'logo.svg')
    if ($capsule.brand.logo) {
      $logoFull=Resolve-CapsulePath ([string]$capsule.brand.logo) 'brand.logo'
      Assert-PassiveSvg $logoFull ([string]$capsule.brand.logo)
      Copy-Item $logoFull (Join-Path $stage 'wordmark.svg')
    }
    foreach ($relative in @($assetPaths | Select-Object -Unique)) {
      if ($relative -match '^brand/') { continue }
      $full=$assets[$relative]
      $destinationRelative = if ($relative -match '^hero/') { 'media/' + [IO.Path]::GetFileName($relative) }
        elseif ($relative -match '^screenshots/') { 'media/screenshots/' + $relative.Substring('screenshots/'.Length) }
        else { 'media/social/og.png' }
      $fileOut=Join-Path $stage $destinationRelative.Replace('/',[IO.Path]::DirectorySeparatorChar)
      New-Item -ItemType Directory -Path (Split-Path -Parent $fileOut) -Force | Out-Null
      Copy-Item -LiteralPath $full -Destination $fileOut -Force
    }
    foreach ($file in Get-ChildItem -LiteralPath $capsuleRoot -Recurse -File -Force | Where-Object { $_.FullName -match '[\\/]screenshots[\\/]' }) {
      $relative=$file.FullName.Substring($capsuleRoot.TrimEnd('\').Length).TrimStart('\','/').Replace('\','/')
      $destinationRelative='media/screenshots/' + $relative.Substring('screenshots/'.Length)
      $fileOut=Join-Path $stage $destinationRelative.Replace('/',[IO.Path]::DirectorySeparatorChar)
      New-Item -ItemType Directory -Path (Split-Path -Parent $fileOut) -Force | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $fileOut -Force
    }
    [IO.File]::WriteAllText((Join-Path $stage 'module.json'), ($module | ConvertTo-Json -Depth 30) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    if ($existingTarget) { Move-Item -LiteralPath $target -Destination $backup }
    try { Move-Item -LiteralPath $stage -Destination $target }
    catch {
      if ($existingTarget -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $target }
      throw
    }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    Write-Host "Imported presentation module to products/$id/."
    Write-Host "Lifecycle: $lifecycle; visibility: $visibility. No release truth was created or changed."
  } finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
  }
}
