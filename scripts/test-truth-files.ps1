. "$PSScriptRoot/release-qualification.ps1"
# PF-TF1 — Truth Files qualification: human layer must agree byte-for-byte with
# the manifest facts that also generate /truth/*.json, and must never leak
# internal data.
$ErrorActionPreference = 'Stop'

$root   = (Resolve-Path "$PSScriptRoot/..").Path
$public = Join-Path $root 'public'
$manifest = Get-AuthoredReleaseManifest

$indexPath = Join-Path $public 'truth-files/index.html'
if (-not (Test-Path $indexPath)) { throw "Generated Truth Files index missing: $indexPath" }
$indexHtml = Get-Content $indexPath -Raw -Encoding UTF8

$pass = 0; $fail = 0
function Assert-TF([string]$name, [bool]$condition) {
  if ($condition) { $script:pass++ ; Write-Host "PASS: $name" -ForegroundColor Green }
  else { $script:fail++ ; Write-Host "FAIL: $name" -ForegroundColor Red }
}

$stateLabels = $manifest.stateLabels
$statusTax   = $manifest.statusTaxonomy

Assert-TF 'index declares its doctrine' ($indexHtml -match 'The Truth Files' -and $indexHtml -match 'Mutable truth\. Immutable proof\.')
Assert-TF 'index links the machine surface' ($indexHtml -match 'href="/truth/"')
Assert-TF 'index links doctrine and ledger' ($indexHtml -match 'href="/proof-standard/"' -and $indexHtml -match 'href="/proof/"')

$productIds = @($manifest.products | Where-Object { $_.visible } | ForEach-Object { $_.id })
Assert-TF 'index renders one card per visible product' (([regex]::Matches($indexHtml, 'class="tf-card"').Count) -eq $productIds.Count)
Assert-TF 'catalog card preserves withdrawn version instead of saying unreleased' ($indexHtml -match '(?s)Reality Gate.*?Withdrawn v1\.1\.0.*?Withdrawn · no public download')

foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $pagePath = Join-Path $public "truth-files/$($p.id)/index.html"
  Assert-TF "$($p.id): truth-file page emitted" (Test-Path $pagePath)
  if (-not (Test-Path $pagePath)) { continue }
  $h = Get-Content $pagePath -Raw -Encoding UTF8

  Assert-TF "$($p.id): canonical + machine alternate bound" (($h -match "href=`"https://theprooffoundry\.com/truth-files/$($p.id)/`" rel=`"canonical`"") -and ($h -match "href=`"/truth/products/$($p.id)\.json`" rel=`"alternate`" title=`"Machine record`" type=`"application/json`""))
  Assert-TF "$($p.id): breadcrumb returns to index" ($h -match 'href="/truth-files/"')
  Assert-TF "$($p.id): product identity renders" ($h -match [regex]::Escape(">$($p.name)<") -and $h -match 'card-mark')

  $ver = if ($p.release -and $p.release.publicVersion) { "v$($p.release.publicVersion)" } elseif ($p.release -and $p.release.withdrawnVersion) { "Withdrawn v$($p.release.withdrawnVersion)" } else { 'Unreleased' }
  Assert-TF "$($p.id): current version matches manifest" ($h -match [regex]::Escape(">$ver<"))

  $plats = if ($p.platforms) { ($p.platforms -join ', ') } else { $p.platform }
  Assert-TF "$($p.id): platform matches manifest" ($h -match [regex]::Escape($plats))

  $relStatus = if ($p.release -and $p.release.releaseStatus) { $p.release.releaseStatus } else { 'UNRELEASED' }
  $relLabel = if ($statusTax.PSObject.Properties[$relStatus]) { $statusTax.($relStatus) } else { $relStatus }
  Assert-TF "$($p.id): release state matches manifest" ($h -match [regex]::Escape($relLabel))

  if ($p.release -and $p.release.releaseStatus -eq 'WITHDRAWN') {
    $j = Get-Content (Join-Path $public "truth/products/$($p.id).json") -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-TF "$($p.id): human and machine truth agree on withdrawn version/state" ($j.release.withdrawnVersion -eq $p.release.withdrawnVersion -and $j.release.releaseStatus -eq $relStatus -and $j.version -eq $null -and $h -match [regex]::Escape("Withdrawn v$($p.release.withdrawnVersion)"))
    Assert-TF "$($p.id): withdrawn truth has no available download" ($j.download.available -eq $false -and $h -match 'Not publicly downloadable')
  }

  Assert-TF "$($p.id): artifact availability stated honestly" (($h -match 'Artifact available for download' -eq [bool]$p.downloadUrl))

  if (@($p.artifacts).Count -gt 0) {
    Assert-TF "$($p.id): artifact filename rendered" ($h -match [regex]::Escape($p.artifacts[0].filename))
    Assert-TF "$($p.id): artifact sha256 prefix rendered" ($h -match $p.artifacts[0].sha256.Substring(0,16))
  }
  if ($p.verification -and $p.verification.status) {
    $words = $manifest.labels
    $isWithdrawn = $p.release -and $p.release.releaseStatus -eq 'WITHDRAWN'
    $chipText = if ($isWithdrawn) { $words.releaseReportWithdrawn } elseif ($p.verification.status -ceq 'VERIFIED') { $words.releaseReportPassing } else { $p.verification.status }
    $chip = '<span class="tf-v-label">' + [regex]::Escape($words.releaseReportChip) + '</span><span class="tf-v-val"><span class="tf-chip [a-z-]+" data-report-status="' + [regex]::Escape($p.verification.status) + '">' + [regex]::Escape($chipText) + '</span>'
    Assert-TF "$($p.id): release-report state renders the record status, in words" ($h -cmatch $chip)
    Assert-TF "$($p.id): no 'Qualification state' or 'Last verified' wording" ($h -cnotmatch 'Qualification state|Last verified')
    if ($p.verification.verifiedAt) {
      Assert-TF "$($p.id): release report date shown, not a verified date" ($h -cmatch [regex]::Escape("$($words.releaseReportStamp) $($p.verification.verifiedAt)") -and $h -cmatch ([regex]::Escape($words.releaseReportDate) + '</span><span>' + [regex]::Escape($p.verification.verifiedAt)) -and $h -cnotmatch ('Verified ' + [regex]::Escape($p.verification.verifiedAt)))
    }
    if ($isWithdrawn) { Assert-TF "$($p.id): a withdrawn record never reads as passing" ($h -cnotmatch [regex]::Escape($words.releaseReportPassing)) }
  }
  if ($p.release -and $p.release.sourceCommit) {
    Assert-TF "$($p.id): source commit prefix rendered" ($h -match $p.release.sourceCommit.Substring(0,12))
  }
  if (@($p.limits).Count -gt 0) {
    # Limits render through the same Html-Attr escaping the build uses.
    $escaped = @($p.limits | ForEach-Object { $_ -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;' })
    Assert-TF "$($p.id): every known limit renders verbatim" ((@($escaped) | Where-Object { $h -notmatch [regex]::Escape($_) }).Count -eq 0)
  } else {
    Assert-TF "$($p.id): empty limits disclosed" ($h -match 'No product-specific limits are recorded')
  }
  Assert-TF "$($p.id): machine record links to product truth JSON" ($h -match "href=`"/truth/products/$($p.id)\.json`"")
  Assert-TF "$($p.id): machine record also links the canonical v2 record" (($h -match "href=`"/truth/v2/products/$([regex]::Escape($p.id))\.json`"") -and (Test-Path -LiteralPath (Join-Path $public "truth/v2/products/$($p.id).json") -PathType Leaf))
  Assert-TF "$($p.id): ledger + product page linked" ($h -match 'href="/proof/"' -and $h -match "href=`"$([regex]::Escape($p.route))`"")
  Assert-TF "$($p.id): freshness line binds source commit" ($h -match 'Generated from source commit')
}

# ── TF1-HOLD-1: artifact semantics — "public" only when the release is public ──
foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $pagePath = Join-Path $public "truth-files/$($p.id)/index.html"
  if (-not (Test-Path $pagePath)) { continue }
  $h = Get-Content $pagePath -Raw -Encoding UTF8
  $isPub = $p.release -and ($p.release.releaseStatus -in @('PUBLIC_RELEASE','FROZEN'))
  $n = @($p.artifacts).Count
  if ($n -gt 0) {
    $good = if ($isPub) { "$n public artifact" } else { "$n recorded artifact" }
    $bad  = if ($isPub) { "$n recorded artifact" } else { "$n public artifact" }
    Assert-TF "HOLD-1 $($p.id): artifact scope label is '$good'" ($h -match [regex]::Escape($good) -and $h -notmatch [regex]::Escape($bad))
  }
}

# ── TF1-HOLD-1b: a recorded file the site withholds is never counted or linked as offered ──
foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $pagePath = Join-Path $public "truth-files/$($p.id)/index.html"
  if (-not (Test-Path $pagePath)) { continue }
  $h = Get-Content $pagePath -Raw -Encoding UTF8
  $uoProp = if ($p.presentation) { $p.presentation.PSObject.Properties['unofferedArtifacts'] } else { $null }
  $uo = @(if ($uoProp) { $uoProp.Value | ForEach-Object { [int]$_ } })
  if ($uo.Count -eq 0) {
    Assert-TF "HOLD-1b $($p.id): no offered-file markers without a withheld file" ($h -notmatch 'Offered here:' -and $h -notmatch 'offered here ·')
    continue
  }
  $n = @($p.artifacts).Count
  $offered = @(0..($n - 1) | Where-Object { $uo -notcontains $_ -and $p.artifacts[$_].downloadUrl }).Count
  $more = $n - $offered
  $line = "$offered file$(if ($offered -ne 1) { 's' }) offered here · $more more recorded in the release record"
  Assert-TF "HOLD-1b $($p.id): Truth File counts $offered offered and $more recorded-only file(s)" ($h.Contains($line))
  Assert-TF "HOLD-1b $($p.id): one Offered-here marker per artifact" (([regex]::Matches($h, 'Offered here: yes')).Count -eq $offered -and ([regex]::Matches($h, 'Offered here: no')).Count -eq $more)
  foreach ($i in $uo) { Assert-TF "HOLD-1b $($p.id): withheld artifact $i is not linked" (-not $p.artifacts[$i].downloadUrl -or -not $h.Contains('href="' + [string]$p.artifacts[$i].downloadUrl + '"')) }
}

# ── TF1-HOLD-2: companion parity — machine record and human page agree ────────
foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $jPath = Join-Path $public "truth/products/$($p.id).json"
  $pagePath = Join-Path $public "truth-files/$($p.id)/index.html"
  if (-not ((Test-Path $jPath) -and (Test-Path $pagePath))) { continue }
  $j = Get-Content $jPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $h = Get-Content $pagePath -Raw -Encoding UTF8
  $expectedComp = if ($p.release -and $p.release.companionPublicVersion) { $p.release.companionPublicVersion } else { $null }
  Assert-TF "HOLD-2 $($p.id): machine companionPublicVersion matches manifest" ($j.release.companionPublicVersion -eq $expectedComp)
  if ($expectedComp) {
    Assert-TF "HOLD-2 $($p.id): page renders public companion v$expectedComp" ($h -match "Companion v$([regex]::Escape($expectedComp))")
  }
}

# ── TF1-HOLD-3: source-identity contract — never promise unproven data ─────────
Assert-TF 'HOLD-3 index does not promise universal source identity' ($indexHtml -notmatch 'the source identity it was verified against' -and $indexHtml -match 'where the release evidence records it')
foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $pagePath = Join-Path $public "truth-files/$($p.id)/index.html"
  $jPath = Join-Path $public "truth/products/$($p.id).json"
  if (-not ((Test-Path $pagePath) -and (Test-Path $jPath))) { continue }
  $h = Get-Content $pagePath -Raw -Encoding UTF8
  $j = Get-Content $jPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $hasCommit = [bool]($p.release -and $p.release.sourceCommit)
  Assert-TF "HOLD-3 $($p.id): source-identity row present iff manifest proves it" (($h -match 'Source identity') -eq $hasCommit)
  # human page and machine record must agree on release source identity
  Assert-TF "HOLD-3 $($p.id): machine release.sourceCommit matches manifest" ($j.release.sourceCommit -eq $p.release.sourceCommit)
  # parity: version/state/status rendered == machine record
  Assert-TF "HOLD-3 $($p.id): human/machine version parity" ($j.version -eq $p.release.publicVersion)
  Assert-TF "HOLD-3 $($p.id): human/machine download parity" (($h -match 'Artifact available for download') -eq [bool]$j.download.available)
}

# ── A-13: dated website notes beside custody-pinned limits ───────────────────
# A note is website presentation (site-manifest.json limitNotes). It renders in
# the annotated limit's own list item, after the verbatim custody text, on the
# Truth File and the /proof/ receipt card, and never enters a release record.
function ConvertTo-TfEscaped([string]$s) { $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;' }
$lnNotes = @(@($manifest.limitNotes) | Where-Object { $_ })
$lnHeadDate = (& git -C $root log -1 --format=%cs).Trim()
Assert-TF 'A13: limitNotes annotate exactly the four reviewed custody limits' ((@($lnNotes | ForEach-Object { "$($_.productId)#$($_.limitIndex)" } | Sort-Object) -join ',') -ceq 'forgecast#4,ghostlayer#0,ghostlayer#1,reality-gate#1')
$lnProofHtml = Get-Content (Join-Path $public 'proof/index.html') -Raw -Encoding UTF8
function Get-TfReceiptCard([string]$id) { [regex]::Match($lnProofHtml, '(?s)<article\b[^>]*\bid="receipt-' + [regex]::Escape($id) + '"[^>]*>.*?</article>').Value }
foreach ($lnNote in $lnNotes) {
  $lnTag = "A13 $($lnNote.productId)#$($lnNote.limitIndex)"
  $lnProduct = @($manifest.products | Where-Object { $_.id -ceq [string]$lnNote.productId })[0]
  $lnLimit = [string]@($lnProduct.limits)[[int]$lnNote.limitIndex]
  Assert-TF "${lnTag}: anchor still names the annotated custody limit" (-not [string]::IsNullOrWhiteSpace([string]$lnNote.anchor) -and $lnLimit.Contains([string]$lnNote.anchor))
  Assert-TF "${lnTag}: note is dated and not later than its commit" ([string]$lnNote.asOf -match '^\d{4}-\d{2}-\d{2}$' -and [string]::CompareOrdinal([string]$lnNote.asOf, $lnHeadDate) -le 0)
  $lnBare = '<li>' + (ConvertTo-TfEscaped $lnLimit) + '</li>'
  $lnLi = '<li>' + (ConvertTo-TfEscaped $lnLimit) + '<br><span class="limit-note"><strong>Website note (as of ' + (ConvertTo-TfEscaped ([string]$lnNote.asOf)) + ').</strong> ' + (ConvertTo-TfEscaped ([string]$lnNote.note)) + '</span></li>'
  $lnTf = Get-Content (Join-Path $public "truth-files/$($lnNote.productId)/index.html") -Raw -Encoding UTF8
  Assert-TF "${lnTag}: Truth File shows the dated note directly under its verbatim limit" ($lnTf.Contains($lnLi) -and -not $lnTf.Contains($lnBare))
  $lnCard = Get-TfReceiptCard ([string]$lnNote.productId)
  Assert-TF "${lnTag}: /proof/ receipt card shows the dated note directly under its verbatim limit" ($lnCard.Contains($lnLi) -and -not $lnCard.Contains($lnBare))
}
foreach ($p in ($manifest.products | Where-Object { $_.visible })) {
  $lnOwn = @($lnNotes | Where-Object { [string]$_.productId -ceq $p.id }).Count
  $lnTf = Get-Content (Join-Path $public "truth-files/$($p.id)/index.html") -Raw -Encoding UTF8
  Assert-TF "A13 $($p.id): Truth File carries only its own website notes" ([regex]::Matches($lnTf, 'class="limit-note"').Count -eq $lnOwn)
  Assert-TF "A13 $($p.id): /proof/ receipt card carries only its own website notes" ([regex]::Matches((Get-TfReceiptCard $p.id), 'class="limit-note"').Count -eq $lnOwn)
}
# Notes never enter release limits in the data files.
$lnRegistry = Get-Content (Join-Path $public 'proof/index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lnDerived = Get-Content (Join-Path $public 'site-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lnDrift = @(foreach ($p in $manifest.products) {
  $want = ConvertTo-Json -Compress -InputObject @($p.limits)
  $r = @($lnRegistry.products | Where-Object { $_.id -ceq $p.id })[0]
  $d = @($lnDerived.products | Where-Object { $_.id -ceq $p.id })[0]
  if (-not $r -or -not $d -or (ConvertTo-Json -Compress -InputObject @($r.limits)) -cne $want -or (ConvertTo-Json -Compress -InputObject @($d.limits)) -cne $want) { $p.id }
})
Assert-TF "A13: website notes never enter release limits in /proof/index.json or /site-manifest.json (drift: $($lnDrift -join ', '))" ($lnDrift.Count -eq 0)

# Safety: no internal/private patterns in emitted truth-files HTML.
$unsafe = 'C:\\|file://|localhost|127\.0\.0\.1|api[_-]?key|secret|bearer\s+[A-Za-z0-9]|password|javascript:|data:|vbscript:'
$allTf = Get-ChildItem (Join-Path $public 'truth-files') -Recurse -Filter *.html
foreach ($f in $allTf) {
  $t = Get-Content $f.FullName -Raw -Encoding UTF8
  Assert-TF "$($f.Directory.Name): no internal/private patterns" ($t -notmatch $unsafe)
}

# Discovery: footer + sitemap + _headers.
$foot = Get-Content (Join-Path $public 'software/index.html') -Raw -Encoding UTF8
Assert-TF 'footer discovers Truth Files' ($foot -match 'href="/truth-files/"')
$sitemap = Get-Content (Join-Path $public 'sitemap.xml') -Raw -Encoding UTF8
Assert-TF 'sitemap carries all truth-file routes' ((@('/truth-files/') + ($productIds | ForEach-Object { "/truth-files/$_/" }) | Where-Object { $sitemap -notmatch [regex]::Escape("https://theprooffoundry.com$_") }).Count -eq 0)
$headers = Get-Content (Join-Path $public '_headers') -Raw -Encoding UTF8
Assert-TF '_headers revalidates truth-files routes' ($headers -match '/truth-files/\*')
$mainOf = { param($rel) [regex]::Match((Get-Content (Join-Path $public $rel) -Raw -Encoding UTF8), '(?s)<main\b.*?</main>').Value }
Assert-TF '/proof/ and /proof-standard/ link Truth Files from the page body' (((& $mainOf 'proof/index.html') -match 'href="/truth-files/"') -and ((& $mainOf 'proof-standard/index.html') -match 'href="/truth-files/"'))

$allGeneratedHtml = Get-ChildItem $public -Recurse -File -Filter *.html
$emptyHrefPattern = 'href\s*=\s*(?:"\s*"|''\s*'')'
$emptyHrefCount = @($allGeneratedHtml | Where-Object { [IO.File]::ReadAllText($_.FullName) -match $emptyHrefPattern }).Count
Assert-TF 'all generated public HTML omits empty href attributes' ($emptyHrefCount -eq 0)
# The machine records still exist alongside (TF1 adds, never replaces).
Assert-TF 'machine truth surface intact' ((Test-Path (Join-Path $public 'truth/index.json')) -and (Test-Path (Join-Path $public 'truth/products/cache-vault.json')))

Write-Host ""
Write-Host "=== TRUTH FILES RESULT: $pass passed, $fail failed ===" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
exit $(if ($fail -eq 0) { 0 } else { 1 })
