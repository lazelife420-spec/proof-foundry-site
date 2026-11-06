# Shared current main-site contract; callers retain their own gate counters.
function Assert-DirectoryContract([string]$Root, [string]$PublicDir, [scriptblock]$Assert) {
  $editorial = Get-Content (Join-Path $Root 'site-editorial.json') -Raw | ConvertFrom-Json
  $entries = @($editorial.entries | Where-Object visible | Sort-Object order, id)
  $html = Get-Content (Join-Path $PublicDir 'software/index.html') -Raw
  $homePage = Get-Content (Join-Path $PublicDir 'index.html') -Raw
  $manifest = Get-AuthoredReleaseManifest
  $ids = @([regex]::Matches($html, 'data-directory-entry="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  & $Assert 'directory identities and exact order follow visible site-editorial.json entries, not the release registry' ($entries.Count -gt 0 -and ($ids -join ',') -ceq (($entries | ForEach-Object id) -join ','))
  & $Assert 'Home is an orientation, proof method, record entrance and support page, not a portfolio' ($homePage -match 'home-orientation' -and $homePage -match 'ledger-chain' -and $homePage -match 'home-records' -and $homePage -match 'home-contact' -and $homePage -notmatch 'data-directory-entry=|data-ledger-feature=|data-ledger-specimen=|studio-product-card|studio-portfolio')
  & $Assert 'Home exposes no static artifact digest or release version' ($homePage -notmatch '\b[0-9a-f]{64}\b|\bv\d+\.\d+\.\d+')
  & $Assert 'Home links to the directory, proof standard, human truth, release records and support' (@('/software/','/proof-standard/','/truth-files/','/proof/','/support/' | Where-Object { $homePage -notmatch ('href="' + [regex]::Escape($_) + '"') }).Count -eq 0)
  & $Assert 'directory controls are hidden progressive enhancements with a live count and explicit empty state' ($html -match '<form class="directory-finder"[^>]*data-directory-finder hidden' -and $html -match 'name="query"' -and $html -match 'name="group"' -and $html -match 'data-directory-count role="status"' -and $html -match 'data-directory-empty hidden')
  foreach ($entry in $entries) {
    $card = [regex]::Match($html, '(?s)<article\b[^>]*data-directory-entry="' + [regex]::Escape($entry.id) + '"[^>]*>.*?</article>').Value
    $decoded = [Net.WebUtility]::HtmlDecode($card)
    & $Assert "$($entry.id): directory purpose and group come from editorial presentation" ($decoded.Contains([string]$entry.shortDescription) -and $decoded.Contains('data-directory-group="' + $entry.group + '"'))
    & $Assert "$($entry.id): artwork is authentic, contextualized and named, or honestly absent" (($entry.artwork -and $card.Contains('src="' + $entry.artwork + '"') -and (Test-Path (Join-Path $PublicDir $entry.artwork.TrimStart('/'))) -and $card -match 'alt="[^"]+"' -and $card -notmatch '<figcaption>' -and ([regex]::Matches($html, '<p class="directory-art-note">Card images are existing captures or artwork\. Version context is retained in the product record\.</p>')).Count -eq 1) -or (-not $entry.artwork -and $card -notmatch '<img\b' -and $card -match 'directory-no-art" aria-hidden="true"' -and ([regex]::Matches($html, '<p class="directory-emblem-note">Each Foundry system\u2019s emblem is a drawing of what it does, not a screenshot\.</p>')).Count -eq 1))
    $targetOK = $false
    if ($entry.destination) {
      $route, $fragment = $entry.destination -split '#', 2
      $target = Join-Path $PublicDir ($route.TrimStart('/') + 'index.html')
      $targetOK = $card.Contains('href="' + $entry.destination + '"') -and (Test-Path $target)
      if ($targetOK -and $fragment) { $targetOK = (Get-Content $target -Raw).Contains('id="' + $fragment + '"') }
    } else { $targetOK = $card -notmatch '<a\b' -and $card -notmatch 'not yet available' -and ($card -match 'class="directory-availability directory-availability--none">No public installer<' -or
      $html -match ('data-directory-group-note="' + [regex]::Escape($entry.group) + '">None of these has a public installer\.<')) }
    & $Assert "$($entry.id): directory destination resolves to an actual local page or fragment, or declares no route" $targetOK
    & $Assert "$($entry.id): entry is visible without JavaScript and never offers an installer directly" ($card -and $card -notmatch '<article[^>]*\shidden\b|<a[^>]*href="https?://|>\s*Download\b')
    $product = @($manifest.products | Where-Object id -eq $entry.id)[0]
    if ($product -and $product.release.publicVersion) {
      & $Assert "$($entry.id): directory public version derives from shared release authority" ($card.Contains('v' + $product.release.publicVersion))
    }
  }
  foreach ($entry in @($editorial.entries | Where-Object { -not $_.visible })) {
    & $Assert "$($entry.id): editorial exclusion does not publish a directory card" ($entry.id -notin $ids)
  }
  foreach ($p in @($manifest.products | Where-Object visible)) {
    & $Assert "$($p.id): editorial inclusion does not control canonical product and truth preservation" ((Test-Path (Join-Path $PublicDir "$($p.id)/index.html")) -and (Test-Path (Join-Path $PublicDir "truth/products/$($p.id).json")))
  }
  & $Assert 'withdrawal remains explicit in the directory and on the preserved record, without a download CTA' ($html -match 'public v1\.1\.0 withdrawn' -and (Get-Content (Join-Path $PublicDir 'reality-gate/index.html') -Raw) -notmatch '<a[^>]+>\s*Download')
  & $Assert 'Home and directory markers fully resolve' (($homePage + $html) -notmatch '\{\{[^}]+\}\}|<!--\s*@(?:directory|studio)-')
}
