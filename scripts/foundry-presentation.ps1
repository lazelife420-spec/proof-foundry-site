# Authored V3 presentation. Release facts remain in the existing projection.
function Get-FoundryHeroDimensions([string]$Src) {
  if ($Src -cnotmatch '^/assets/[A-Za-z0-9_./-]+\.png$' -or $Src -match '/\.{1,2}(?:/|$)') { return '' }
  $path = Join-Path $root $Src.TrimStart('/')
  if (-not [IO.File]::Exists($path)) { return '' }
  $bytes = [IO.File]::ReadAllBytes($path)
  if ($bytes.Length -lt 24 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) { return '' }
  $w = [int]$bytes[16]*16777216 + [int]$bytes[17]*65536 + [int]$bytes[18]*256 + [int]$bytes[19]
  $h = [int]$bytes[20]*16777216 + [int]$bytes[21]*65536 + [int]$bytes[22]*256 + [int]$bytes[23]
  return ' width="' + $w + '" height="' + $h + '"'
}
function Get-FoundryHeroWebp([string]$Src) {
  if ($Src -cnotmatch '^/assets/[A-Za-z0-9_./-]+\.png$' -or $Src -match '/\.{1,2}(?:/|$)') { return '' }
  $stem = [IO.Path]::GetFileNameWithoutExtension($Src)
  $items = @(Get-ChildItem -LiteralPath (Join-Path $root 'assets/studio') -File -Filter ($stem + '-*.webp') | Where-Object { $_.Name -match ('^' + [regex]::Escape($stem) + '-[0-9]+\.webp$') } | Sort-Object { [int]([regex]::Match($_.Name, '-([0-9]+)\.webp$').Groups[1].Value) })
  if (-not $items.Count) { return (Build-PreviewWebpSource $Src) }
  $sources = @($items | ForEach-Object { '/assets/studio/' + $_.Name + ' ' + [regex]::Match($_.Name, '-([0-9]+)\.webp$').Groups[1].Value + 'w' }) -join ', '
  return '<source type="image/webp" srcset="' + (Html-Attr $sources) + '" sizes="(max-width:700px) calc(100vw - 36px), (max-width:1100px) 60vw, 760px"/>'
}
function Get-FoundryJoint([string]$Id, [string]$Instance) {
  $path = Join-Path $root "brand/connections/$Id.svg"
  if (-not (Test-Path $path)) { return '' }
  $svg = Read-File $path
  $prefix = 'j-' + ($Instance -replace '[^a-zA-Z0-9-]', '-') + '-'
  foreach ($m in [regex]::Matches($svg, '\bid="([^"]+)"')) {
    $old = $m.Groups[1].Value
    $svg = $svg.Replace('id="' + $old + '"', 'id="' + $prefix + $old + '"').Replace('url(#' + $old + ')', 'url(#' + $prefix + $old + ')')
  }
  return $svg
}
function Build-FoundryDoors {
  $out = ''
  foreach ($m in ($productRegistry | Where-Object {$_.visibility -eq 'visible'} | Sort-Object { if ($_.homepage.order) { [int]$_.homepage.order } else { [int]$_.order } })) {
    $joint = Get-FoundryJoint $m.id ('home-' + $m.id)
    $out += '<a class="foundry-door foundry-connection door-' + $m.id + '" href="' + (Html-Attr $m.route) + '" data-world-link="' + (Html-Attr $m.id) + '"><span class="door-mechanism" data-joint="' + $m.id + '">' + $joint + '</span><span class="door-name">' + (Html-Text $m.brand.name) + '</span><span class="door-purpose">' + (Html-Text $m.card.tagline) + '</span><span class="door-arrow" aria-hidden="true">↗</span></a>'
  }
  return $out
}
function Complete-FoundryPresentation([string]$Html, [string]$Name, [string]$Page, [string]$Product) {
  # Select one owner for each scope; legacy paint sheets are not loaded beneath overrides.
  $html = [regex]::Replace($Html, '<link\b[^>]*href="/(?:styles|studio|experience|signature|product-page|truth-files|h9-homepage|h9-software|pf-home-ledger|pf-site-ledger|pf-foundry-system|foundry-world)\.css(?:\?[^"]*)?"[^>]*>', '')
  $css = @('styles.css','pf-foundry-system.css','foundry-connections.css','foundry-world.css')
  if ($Name -eq 'index.html') { $css += 'pf-home-ledger.css' }
  elseif ($Page -eq 'software') { $css += @('h9-software.css','experience.css') }
  elseif ($html -match '\btf-page\b' -or $Page -in @('truth','truth-files','proof')) { $css += 'truth-files.css' }
  elseif ($Product) { $css += @('product-page.css','experience.css','product-worlds.css') }
  if (-not $Product -and $Name -ne 'index.html' -and $Page -ne 'software') { $css += 'foundry-rooms.css' }
  $links = ''
  foreach ($asset in $css) {
    $assetPath = Join-Path $root $asset
    if (Test-Path $assetPath) {
      $v = (Get-FileHash $assetPath -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
      $links += '<link rel="stylesheet" href="/' + $asset + '?v=' + $v + '"/>' + "`n"
    }
  }
  $nv = (Get-FileHash (Join-Path $root 'foundry-navigation.js') -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
  $html = $html.Replace('</head>', $links + '<script src="/foundry-navigation.js?v=' + $nv + '"></script>' + "`n</head>")
  $html = $html.Replace('<!-- @foundry-doors -->', (Build-FoundryDoors))
  if ($Page -eq 'software') {
    foreach ($m in ($productRegistry | Where-Object {$_.visibility -eq 'visible'})) {
      $joint = Get-FoundryJoint $m.id ('catalog-' + $m.id)
      $jointLink = '<a class="catalog-joint foundry-connection" href="' + $m.route + '" data-world-link="' + $m.id + '" aria-label="Enter ' + (Html-Attr $m.brand.name) + '"><span data-joint="' + $m.id + '">' + $joint + '</span></a>'
      $pattern = '(?s)(<article class="product-card[^>]*data-product="' + [regex]::Escape($m.id) + '".*?<div class="card-body">)'
      $html = [regex]::Replace($html, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{param($match) $match.Value + $jointLink})
    }
  }
  $world = if ($Product) { $Product } elseif ($html -match '\btf-page\b[^>]*\bproduct-([a-z-]+)') { $Matches[1] } else { $Page }
  if (-not $world) { $world = 'home' }
  $html = [regex]::Replace($html, '<body\b', '<body data-foundry-world="' + (Html-Attr $world) + '" data-foundry-page="' + (Html-Attr $Page) + '"')
  # Existing semantic body classes stay stable; data attributes identify the V3 presentation.
  if ($html -match '\btf-page\b' -and $world -ne 'home') {
    $joint = Get-FoundryJoint $world ('record-' + $world)
    $reverse = '<a class="record-return foundry-connection" href="/' + $world + '/" data-world-link="' + $world + '"><span class="record-joint" data-joint="' + $world + '">' + $joint + '</span><span>Reverse face / return to product <span aria-hidden="true">↗</span></span></a>'
    $html = $html.Replace('<p class="tf-hero-kicker">Product record</p>', '<p class="tf-hero-kicker">The Truth Files / Product record</p>')
    $summaryMatch = [regex]::Match($html, '(?s)<p class="tf-product-summary">.*?</p>')
    if ($summaryMatch.Success) {
      $html = $html.Replace($summaryMatch.Value, $reverse)
      $html = $html.Replace('<!-- @record-summary -->', '')
      $html = $html.Replace('<h2>Current truth</h2>', '<h2>Current truth</h2>')
      $html = $html.Replace('</main>', '<section class="tf-section container"><h2>Product scope</h2>' + $summaryMatch.Value + '</section></main>')
    }
    if ($world -eq 'proofshot') {
      $html = $html.Replace('<span class="tf-state">', '<span class="tf-state">')
      $html = [regex]::Replace($html, '(?s)(<section class="tf-hero".*?)(</section>)', '$1<p class="record-qualification">Open licensing-authority finding. Scope and impact remain unpublished; historical qualification does not resolve it.</p>$2')
    }
    $html = $html.Replace('<!-- @record-next -->', '')
    $nextJoint = Get-FoundryJoint 'lights-out' ('continue-' + $world)
    $html = $html.Replace('</main>', '<nav class="record-next container" aria-label="Continue exploring"><span>Leave the records. Enter a quieter world.</span><a class="text-link foundry-connection" href="/lights-out/" data-world-link="lights-out"><span data-joint="lights-out">' + $nextJoint + '</span><span>Enter Lights Out ↗</span></a><a class="text-link" href="/">The Foundry ↗</a></nav></main>')
  }
  # Project selected state into static shared navigation, including the no-JS route.
  $currentRoute = if ($Name -eq 'index.html') { '/' } elseif ($Product) { '/' + $Product + '/' } elseif ($Page) { '/' + $Page + '/' } else { '' }
  # A page inside a section lights its section's key as the current location (aria-current="true"),
  # never as the current page: product pages sit under Products, release records under Proof, the
  # Truth File records under Truth Files, and the Founders Circle and Roadmap under About (the
  # footer's Company group).
  $sectionRoute = if ($Product) { '/software/' } elseif ($Page -in @('proof','receipts')) { '/proof-standard/' } elseif ($Page -eq 'truth' -or $Page -like 'truth-files-*') { '/truth-files/' } elseif ($Page -in @('founders','roadmap')) { '/about/' } else { '' }
  $html = [regex]::Replace($html, '(?s)<nav class="pf-route-chain\b.*?</nav>', [System.Text.RegularExpressions.MatchEvaluator]{param($nav)
    [regex]::Replace($nav.Value, '<a href="([^"]+)"', [System.Text.RegularExpressions.MatchEvaluator]{param($link)
      if ($link.Groups[1].Value -eq $currentRoute) { $link.Value + ' aria-current="page"' }
      elseif ($sectionRoute -and $link.Groups[1].Value -eq $sectionRoute) { $link.Value + ' aria-current="true"' }
      else { $link.Value }
    })
  })
  if ($Page -eq 'support') {
    $html = [regex]::Replace($html, '<a\b(?=[^>]*class="[^"]*\bnav-cta\b)(?![^>]*aria-current)[^>]*', '$0 aria-current="page"')
  }
  return $html
}

function Get-FoundryChrome([string]$Header, [string]$Footer) {
  # V5 (owner ruling, 2026-10-13; studio-wide 2026-10-25): every route's header carries
  # the PF Mark G header render so the studio has one brand mark. Since 2026-11-04 (owner
  # decision) that render is the Blender titanium mark (ti_emblem.py --mode mark). Forced
  # colours keep the shared vector micro mark.
  $sharedMark = '<img class="brand-mark" src="/brand/PF_HEADER_MARK.svg" alt="" width="42" height="42" />'
  if (-not $header.Contains($sharedMark)) { throw 'Header: the shared header no longer carries the expected micro mark.' }
  $header = $header.Replace($sharedMark, '<picture class="brand-mark-picture"><source media="(forced-colors: active)" srcset="/brand/PF_HEADER_MARK.svg"/><img class="brand-mark" src="/brand/emblem/PF_MARK_G_TI_HEADER.webp" alt="" width="50" height="51"/></picture>')
  # Forced colours (V5 refinement F5, studio-wide): every route's header and footer also carry an inline,
  # same-document copy of the canonical micro mark, shown only in forced colours and drawn in system colours
  # by pf-home-ledger.css on Home and pf-site-ledger.css on every other route. An SVG loaded through <img>
  # evaluates its own forced-colours rules in a separate image document, which was observed to keep its
  # normal colours on warm-cache and switched loads.
  $microSvg = Read-File (Join-Path $root 'brand/PF_HEADER_MARK.svg')
  $microStart = $microSvg.IndexOf('</style>') + '</style>'.Length
  $microBody = ($microSvg.Substring($microStart, $microSvg.LastIndexOf('</svg>') - $microStart).Trim() -replace '>\s+<', '><')
  if ($microStart -lt 8 -or $microBody -match '\sid="|<style|<title|<desc|<script') { throw 'Forced-colours mark: PF_HEADER_MARK.svg no longer has the expected shape.' }
  $fcMark = @{}
  foreach ($kind in @('header', 'footer')) { $fcMark[$kind] = "<span class=`"pf-mark-fc pf-mark-fc--$kind`" hidden><svg viewBox=`"0 0 256 256`" aria-hidden=`"true`" focusable=`"false`">$microBody</svg></span>" }
  if (([regex]::Matches($header, '</picture>')).Count -ne 1) { throw 'Header: expected exactly one picture element.' }
  $header = $header.Replace('</picture>', '</picture>' + $fcMark['header'])


  # The footer's logo is the Blender badge (ti_emblem.py --mode badge, owner decision 2026-11-04); the inline vector
  # micro mark after it is shown only in forced colours.
  $footerLogo = '<img class="footer-logo" src="/brand/emblem/PF_MARK_G_TI_BADGE.webp" alt="" width="34" height="34"/>'
  if (([regex]::Matches($footer, [regex]::Escape($footerLogo))).Count -ne 1) { throw 'Footer: the shared footer no longer carries the expected logo.' }
  $footer = $footer.Replace($footerLogo, $footerLogo + $fcMark['footer'])
  return @{ Header=$header; Footer=$footer }
}
