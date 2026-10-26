# Homepage receipt inspector — Public Truth v1 binding.
# Validates every built /truth/ record against /truth/schema-v1.json with two
# independent validators (PowerShell Test-Json and the browser's own
# pf-truth-receipt.js), checks the inspector's receipts against the records and
# the /proof/ page, and checks that the homepage copies no release values.
# Build public/ first: pwsh -NoProfile -File scripts/build-site.ps1
# Not named test-*.ps1: the qualified test inventory is frozen at 25 scripts
# (test-authority-registry.json). It runs as part of the H9_BINDING gate,
# scripts/test-h9-binding.ps1 (owner ruling, 2026-10-13), and can run alone.
[CmdletBinding()]
param([string]$PublicDir = '')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/..").Path
if (-not $PublicDir) { $PublicDir = Join-Path $root 'public' }
$pass = 0; $fail = 0
function Assert-Receipt([string]$name, [bool]$condition) { if ($condition) { $script:pass++; Write-Host "PASS: $name" } else { $script:fail++; Write-Host "FAIL: $name" -ForegroundColor Red } }
function Read-Text([string]$path) { [IO.File]::ReadAllText($path) }
Write-Host '=== HOMEPAGE RECEIPT TRUTH BINDING ==='

# The one inherited v1 exception recorded in SHARED_RELEASE_TRUTH_AUTHORITY.md:
# a null URL the shipped v1 schema rejects. It must keep failing only there.
$expectedInvalid = [ordered]@{ 'reality-gate' = '/artifacts/0/downloadUrl' }
$authorityDoc = Read-Text (Join-Path $root 'SHARED_RELEASE_TRUTH_AUTHORITY.md')
Assert-Receipt 'expected schema failure is the inherited exception the authority document records' ($authorityDoc -match 'v1 schema rejects one unchanged null URL' -and $authorityDoc -match "Reality Gate's\s+withdrawn artifact URL" -and $authorityDoc -notmatch 'two unchanged null URLs')

# Lights Out's receipt references have no public URL. Every generated evidence
# list must hold links only, and the references must stay public as text.
$loReceipts = @('342c11bc-d2d6-4918-8920-a495211ff69b', '6323d762-859a-4385-91d7-923cd1bc1610', 'adff2359-3350-4d6d-9e04-74c295003c58')
$nullLinks = @()
foreach ($file in @(Get-ChildItem (Join-Path $PublicDir 'truth/products') -Filter '*.json') + @(Get-ChildItem (Join-Path $PublicDir 'truth/v2/products') -Filter '*.json')) {
  $rec = (Read-Text $file.FullName) | ConvertFrom-Json
  foreach ($e in @($rec.evidence)) { if ($null -ne $e -and $e -isnot [string] -and [string]::IsNullOrWhiteSpace([string]$e.url)) { $nullLinks += $file.FullName } }
}
$derived = (Read-Text (Join-Path $PublicDir 'site-manifest.json')) | ConvertFrom-Json
foreach ($p in @($derived.products)) { foreach ($e in @($p.evidence)) { if ($null -ne $e -and $e -isnot [string] -and [string]::IsNullOrWhiteSpace([string]$e.url)) { $nullLinks += "site-manifest.json:$($p.id)" } } }
Assert-Receipt 'every generated evidence list (v1, v2, derived manifest) holds links only' ($nullLinks.Count -eq 0)
$loDerived = @($derived.products | Where-Object id -eq 'lights-out')[0]
$loV2 = (Read-Text (Join-Path $PublicDir 'truth/v2/products/lights-out.json')) | ConvertFrom-Json
$loV2Labels = (@($loV2.verificationEvidence.evidence) | Where-Object { $_ -isnot [string] -and $null -eq $_.url } | ForEach-Object { $_.label }) -join "`n"
$loTruthFile = Read-Text (Join-Path $PublicDir 'truth-files/lights-out/index.html')
$loUnlinked = @($loDerived.unlinkedEvidence) -join "`n"
# The authored label, read from release-truth.json itself, rendered word for word
# as a text row; no link anywhere on the site carries one of these receipt IDs.
$loAuthored = @((Read-Text (Join-Path $root 'release-truth.json') | ConvertFrom-Json).products | Where-Object id -eq 'lights-out')[0]
$loLabels = @($loAuthored.verification.evidence | Where-Object { $_ -isnot [string] -and $null -eq $_.url } | ForEach-Object { [string]$_.label })
# Escaped exactly as build-site.ps1's Html-Attr escapes the Truth File text.
$loRows = @($loLabels | ForEach-Object { '<li><span class="tf-rec-label">Evidence</span><span>' + ($_ -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;') + '</span></li>' })
# Any recognisable part of a receipt ID: its first eight hex digits.
$receiptAlternation = '(' + (($loReceipts | ForEach-Object { $_.Substring(0, 8) }) -join '|') + ')'
$linkedReceipts = @(Get-ChildItem -LiteralPath $PublicDir -Recurse -Filter '*.html' | Where-Object { $_.FullName -notmatch '[\\/]__h14[\\/]' } | Where-Object { (Read-Text $_.FullName) -match ('(?s)<a\b[^>]*>(?:(?!</a>).)*?' + $receiptAlternation) -or (Read-Text $_.FullName) -match ('<a\b[^>]*href="[^"]*' + $receiptAlternation) } | ForEach-Object Name)
$guardProbe = & node -e "const {compile,FACT_FIELDS}=require(process.argv[1]);const fs=require('fs'),path=require('path');const root=path.resolve(path.dirname(process.argv[1]),'..');const model=JSON.parse(fs.readFileSync(path.join(root,'release-truth.json'),'utf8')),p=JSON.parse(fs.readFileSync(path.join(root,'site-manifest.json'),'utf8'));p.products[0].unlinkedEvidence=['forged'];try{compile(model,p);console.log('accepted')}catch(e){console.log(FACT_FIELDS.includes('unlinkedEvidence')&&/Dual-authored release fact in presentation/.test(e.message)?'refused':'other: '+e.message)}" (Join-Path $root 'scripts/shared-release-truth.cjs') 2>&1
Assert-Receipt 'presentation cannot author unlinked evidence: the projection refuses it as a release fact' ("$guardProbe".Trim() -ceq 'refused')
Assert-Receipt 'Lights Out receipt references stay public as unlinked evidence, word for word, never as links' ($loLabels.Count -eq 1 -and @($loReceipts | Where-Object { $loUnlinked.Contains($_) -and $loV2Labels.Contains($_) -and $loTruthFile.Contains($_) }).Count -eq 3 -and @($loRows | Where-Object { $loTruthFile.Contains($_) }).Count -eq $loRows.Count -and ($loDerived.unlinkedEvidence -join "`n") -ceq ($loLabels -join "`n") -and $linkedReceipts.Count -eq 0 -and @($derived.products | Where-Object { $_.id -ne 'lights-out' -and $_.PSObject.Properties.Name -contains 'unlinkedEvidence' }).Count -eq 0)

# ── 1. Independent validator: PowerShell Test-Json (JsonSchema.Net) ──────────
$schemaPath = Join-Path $PublicDir 'truth/schema-v1.json'
$schemaText = Read-Text $schemaPath
Assert-Receipt 'published schema is the source schema' ($schemaText -ceq (Read-Text (Join-Path $root 'schemas/public-truth-v1.schema.json')))
$verdicts = [ordered]@{}
$indexOk = Test-Json -Json (Read-Text (Join-Path $PublicDir 'truth/index.json')) -Schema $schemaText -ErrorAction SilentlyContinue
Assert-Receipt 'Test-Json: /truth/index.json conforms to schema-v1' ($indexOk -eq $true)
foreach ($file in Get-ChildItem (Join-Path $PublicDir 'truth/products') -Filter '*.json' | Sort-Object Name) {
  $id = $file.BaseName
  $errors = $null
  $ok = Test-Json -Json (Read-Text $file.FullName) -Schema $schemaText -ErrorAction SilentlyContinue -ErrorVariable errors
  $verdicts[$id] = [bool]$ok
  if ($expectedInvalid.Contains($id)) {
    # The location is proven by structure, not by Test-Json's message text (PowerShell 7.6.7 reports only the root
    # oneOf failure at ''): the published value at the pointer is null; replacing only that value with a schema-valid
    # placeholder URL (in memory only) makes the record valid; and with an unrelated required field removed it is still
    # invalid, so no other violation can hide behind the exception.
    $pointer = $expectedInvalid[$id]
    $node = [System.Text.Json.Nodes.JsonNode]::Parse((Read-Text $file.FullName))
    $segments = $pointer.TrimStart('/').Split('/')
    $parent = $node
    # Explicit assignments: an if-statement's output would unroll a one-element JsonArray.
    foreach ($segment in $segments[0..($segments.Count - 2)]) { if ($null -eq $parent) { break }; if ($segment -match '^\d+$') { $parent = $parent[[int]$segment] } else { $parent = $parent[$segment] } }
    $leaf = $segments[-1]
    $isNullThere = ($null -ne $parent) -and ($parent -is [System.Text.Json.Nodes.JsonObject]) -and $parent.ContainsKey($leaf) -and ($null -eq $parent[$leaf])
    $repairedOk = $false; $controlOk = $true
    if ($isNullThere) {
      $parent[$leaf] = [System.Text.Json.Nodes.JsonValue]::Create('https://withdrawn.invalid/')
      $repairedOk = Test-Json -Json $node.ToJsonString() -Schema $schemaText -ErrorAction SilentlyContinue
      $null = $node.AsObject().Remove('id')
      $controlOk = Test-Json -Json $node.ToJsonString() -Schema $schemaText -ErrorAction SilentlyContinue
    }
    Assert-Receipt "Test-Json: $id is the documented exception at $pointer" ((-not $ok) -and $isNullThere -and $repairedOk -eq $true -and $controlOk -eq $false)
  } else {
    Assert-Receipt "Test-Json: $id conforms to schema-v1" ($ok -eq $true)
  }
}

# ── 2. The browser's validator and receipt model, run under Node ─────────────
$expectedJson = ($expectedInvalid | ConvertTo-Json -Compress)
$nodeOutput = & node (Join-Path $PSScriptRoot 'home-receipt-truth.check.mjs') $PublicDir $expectedJson 2>&1
$nodeExit = $LASTEXITCODE
$nodePass = 0; $nodeResults = @(); $agreed = @()
foreach ($line in $nodeOutput) {
  $text = "$line"
  if ($text -match '^PASS: (.*)$') { $nodePass++; Assert-Receipt "browser validator: $($Matches[1])" $true }
  elseif ($text -match '^FAIL: (.*)$') { Assert-Receipt "browser validator: $($Matches[1])" $false }
  elseif ($text -match '^RESULT ([a-z0-9-]+) (valid|invalid)') {
    $id = $Matches[1]; $jsValid = $Matches[2] -eq 'valid'; $agreed += $id
    Assert-Receipt "both validators agree on $id ($($Matches[2]))" ($verdicts.Contains($id) -and $verdicts[$id] -eq $jsValid)
  }
  elseif ($text -match '^NODE RESULT: (.*)$') { $nodeResults += $Matches[1] }
  else { Write-Host $text }
}
# The Node half must finish and must have judged every record Test-Json judged.
# Its minimum may only be lowered in the change that removes its checks.
Assert-Receipt "browser validator suite ran to completion: exit $nodeExit, one ok footer, PASS=$nodePass (minimum 97), every record compared" ($nodeExit -eq 0 -and $nodeResults.Count -eq 1 -and $nodeResults[0] -ceq 'ok' -and $nodePass -ge 97 -and $verdicts.Count -gt 0 -and @($verdicts.Keys | Where-Object { $_ -notin $agreed }).Count -eq 0 -and $agreed.Count -eq $verdicts.Count)

# ── 3. The homepage copies no release values for the inspector ───────────────
$homeHtml = Read-Text (Join-Path $PublicDir 'index.html')
$homeJs = Read-Text (Join-Path $root 'pf-home.js')
$receiptJs = Read-Text (Join-Path $root 'pf-truth-receipt.js')
$manifest = (Read-Text (Join-Path $PublicDir 'site-manifest.json')) | ConvertFrom-Json
$specimenId = [regex]::Match($homeHtml, 'data-ledger-specimen="([a-z0-9-]+)"').Groups[1].Value
$specimen = @($manifest.products | Where-Object id -eq $specimenId)[0]
$digests = @([regex]::Matches($homeHtml, '(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])') | ForEach-Object Value | Sort-Object -Unique)
Assert-Receipt 'homepage HTML carries no digest except the specimen artifact' ($specimen -and $digests.Count -eq 1 -and $digests[0] -ceq [string]$specimen.sha256)
Assert-Receipt 'receipt panel ships empty; content comes from /truth/ at open time' ($homeHtml -match '<div class="pf-rc-doc" id="pf-receipt-panel" data-receipt-panel></div>' -and $homeHtml -match '<dialog class="pf-dialog pf-receipt-dialog" id="pf-receipt-dialog" aria-labelledby="pf-receipt-title">')
$triggers = @([regex]::Matches($homeHtml, '<button type="button" class="ledger-receipt-button"[^>]*>'))
Assert-Receipt 'receipt triggers carry only a product ID and stay hidden without the script' ($triggers.Count -eq 4 -and @($triggers | Where-Object { $_.Value -notmatch '^<button type="button" class="ledger-receipt-button" data-receipt-open="[a-z0-9-]+" aria-haspopup="dialog" aria-controls="pf-receipt-dialog" hidden>$' }).Count -eq 0)
Assert-Receipt 'homepage has no static tab widget' ($homeHtml -notmatch 'role="tablist"|role="tabpanel"')
$names = @($manifest.products | ForEach-Object { [string]$_.id; [string]$_.name; [string]$_.displayName } | Where-Object { $_ } | Sort-Object -Unique)
# The verification vocabulary names the Reality Gate check; it is bound to the
# site's own labels by the Node half, so it is not a product leak.
$receiptCode = [regex]::Replace($receiptJs, '(?s)export const VERIFICATION_LABELS = \{.*?\};', '')
$leaks = @($names | Where-Object { $homeJs.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $receiptCode.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
Assert-Receipt 'inspector scripts name no product' ($leaks.Count -eq 0)
$literal = '[0-9a-f]{40}|\bv?\d+\.\d+\.\d+\b|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|downloads\.theprooffoundry|github\.com'
Assert-Receipt 'inspector scripts hold no digests, versions, receipt IDs or download hosts' ($homeJs -notmatch $literal -and $receiptJs -notmatch $literal)
Assert-Receipt 'inspector reads only the same-origin truth records, schema and proof registry' ($receiptJs -match "TRUTH_SCHEMA_URL = '/truth/schema-v1.json'" -and $receiptJs -match "TRUTH_INDEX_URL = '/truth/index.json'" -and $receiptJs -match "PROOF_REGISTRY_URL = '/proof/index.json'" -and $receiptJs -match '`/truth/products/\$\{id\}\.json`' -and ([regex]::Matches($homeJs, '\bfetch\(')).Count -eq 1 -and ($homeJs + $receiptJs) -notmatch 'site-manifest|https?://(?!www\.w3\.org/2000/svg)')
foreach ($asset in @('pf-home.js', 'pf-truth-receipt.js')) {
  Assert-Receipt "$asset ships byte-identical to source" ((Get-FileHash (Join-Path $PublicDir $asset)).Hash -eq (Get-FileHash (Join-Path $root $asset)).Hash)
}
Assert-Receipt 'homepage loads the inspector as a versioned module' ($homeHtml -match '<script type="module" src="/pf-home\.js\?v=[0-9a-f]{12}"></script>')

# ── 4. The records the inspector reads state the authored release truth ──────
# release-truth.json, read through the qualification adapter, must equal what
# /truth/ and /proof/index.json state for every product with a receipt here.
. (Join-Path $PSScriptRoot 'release-qualification.ps1')
$authored = Get-AuthoredReleaseManifest
$registry = (Read-Text (Join-Path $PublicDir 'proof/index.json')) | ConvertFrom-Json -Depth 100
Assert-Receipt 'authored release truth is release-truth.json, and the proof registry was projected from it' ($authored.releaseFactsSource.authoredFile -eq 'release-truth.json' -and $registry.releaseFactsSource.authoredFile -eq 'release-truth.json')
function Release-Facts($release, $artifacts) {
  ConvertTo-Json -Compress -Depth 10 -InputObject ([ordered]@{
    status = $release.releaseStatus; version = $release.publicVersion; published = $release.publishedAt; withdrawn = $release.withdrawnVersion
    artifacts = @($artifacts | ForEach-Object { [ordered]@{ file = $_.filename; sha256 = $_.sha256; size = $_.sizeBytes } })
  })
}
function Pairs($items, [string]$a, [string]$b) { ConvertTo-Json -Compress -Depth 5 -InputObject @($items | ForEach-Object { [ordered]@{ $a = $_.$a; $b = $_.$b } }) }
# Authored evidence may be bare URLs; the build labels those by file name
# (Build-PublicTruthProduct in build-site.ps1), so compare under the same rule.
function Evidence($items) { ConvertTo-Json -Compress -Depth 5 -InputObject @($items | ForEach-Object { if ($_ -is [string]) { [ordered]@{ label = ($_ -split '/')[-1]; url = $_ } } else { [ordered]@{ label = $_.label; url = $_.url } } }) }
$receiptIds = @([regex]::Matches($homeHtml, 'data-receipt-open="([a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
Assert-Receipt 'every homepage receipt product is in the authored release truth' ($receiptIds.Count -ge 3 -and @($receiptIds | Where-Object { $id = $_; -not @($authored.products | Where-Object id -eq $id).Count }).Count -eq 0)
foreach ($id in $receiptIds) {
  $a = @($authored.products | Where-Object id -eq $id)[0]
  $r = (Read-Text (Join-Path $PublicDir "truth/products/$id.json")) | ConvertFrom-Json -Depth 100
  $e = @($registry.products | Where-Object id -eq $id)[0]
  $want = Release-Facts $a.release $a.artifacts
  Assert-Receipt "$id`: /truth/ record states the authored release, artifacts, digests and sizes" ($want -ceq (Release-Facts $r.release $r.artifacts))
  Assert-Receipt "$id`: /proof/index.json states the authored release, artifacts, digests and sizes" ($e -and $want -ceq (Release-Facts $e.release $e.artifacts))
  Assert-Receipt "$id`: product source commit and receipt ID are the authored ones" ([string]$r.release.sourceCommit -ceq [string]$a.release.sourceCommit -and [string]$r.verification.receiptId -ceq [string]$a.verification.receiptId -and [string]$e.verification.receiptId -ceq [string]$a.verification.receiptId)
  Assert-Receipt "$id`: limitations, tests and evidence are the authored ones" ((ConvertTo-Json -Compress -InputObject @($a.limits)) -ceq (ConvertTo-Json -Compress -InputObject @($e.limits)) -and (Pairs $a.tests 'label' 'result') -ceq (Pairs $r.tests 'label' 'result') -and (Evidence $a.evidence) -ceq (Evidence $r.evidence))
  $presented = @($derived.products | Where-Object id -eq $id)[0].presentation
  $wantWithheld = if ($presented -and $presented.PSObject.Properties['unofferedArtifacts']) { @($presented.unofferedArtifacts) -join ',' } else { '' }
  $gotWithheld = if ($e.PSObject.Properties['unofferedArtifacts']) { @($e.unofferedArtifacts) -join ',' } else { '' }
  Assert-Receipt "$id`: /proof/index.json names exactly the files the presentation withholds from this site" ($wantWithheld -ceq $gotWithheld)
}

# ── 5. Published capture captions, alt text and disclosures stay verbatim ────
$decoded = [System.Net.WebUtility]::HtmlDecode($homeHtml)
$featured = @(((Read-Text (Join-Path $root 'homepage-ledger.json')) | ConvertFrom-Json).featured)
foreach ($id in $featured) {
  $module = (Read-Text (Join-Path $root "products/$id/module.json")) | ConvertFrom-Json
  $article = [System.Net.WebUtility]::HtmlDecode([regex]::Match($homeHtml, '(?s)<article class="ledger-instrument" data-ledger-feature="' + [regex]::Escape($id) + '".*?</article>').Value)
  Assert-Receipt "$id`: capture keeps its published alt text and caption" ($article -and $article.Contains('alt="' + [string]$module.card.mediaAlt + '"') -and $article.Contains('<figcaption>' + [string]$module.homepage.mediaDisclosure + '</figcaption>'))
}
$apostrophe = [string][char]0x2019
foreach ($disclosure in @('Captures may show earlier builds or previous product names. Each preview states its context; the public record establishes current availability.', "Actual app previews or brand artwork. Some show earlier builds or previous product names. See each product$($apostrophe)s current release record.")) {
  Assert-Receipt "published disclosure kept verbatim: $($disclosure.Substring(0, 36))" ($decoded.Contains($disclosure))
}

# ── 6. Canonical geometry and recorded emblem assets ─────────────────────────
$master = Read-Text (Join-Path $root 'brand/PF_MARK_G_MASTER.svg')
$masterPaths = @([regex]::Matches($master, '<path d="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$canon = [regex]::Match($homeJs, "(?s)const CANON = \{\s*P: '([^']+)',\s*F: '([^']+)',\s*B: '([^']+)',")
Assert-Receipt 'Inspect the Mark outlines are PF_MARK_G_MASTER.svg paths, verbatim' ($masterPaths.Count -eq 3 -and $canon.Success -and $canon.Groups[1].Value -ceq $masterPaths[0] -and $canon.Groups[2].Value -ceq $masterPaths[1] -and $canon.Groups[3].Value -ceq $masterPaths[2])
$renderer = Read-Text (Join-Path $root 'scripts/pf-emblem/render-lib.js')
Assert-Receipt 'emblem renderer draws the same master paths' ($renderer.Contains("const P_PATH = '$($masterPaths[0])'") -and $renderer.Contains("const F_PATH = '$($masterPaths[1])'") -and $renderer.Contains("const B_PATH = '$($masterPaths[2])'"))
$provenance = Read-Text (Join-Path $root 'PF_MARK_G_EMBLEM_PROVENANCE.md')
$rows = @([regex]::Matches($provenance, '\|\s*`((?:brand|assets|scripts)/[^`]+)`\s*\|[^\n]*?\|\s*`([0-9a-f]{64})`\s*\|'))
Assert-Receipt 'provenance records every shipped emblem, light mask and font file' ($rows.Count -ge 14)
foreach ($row in $rows) {
  $file = Join-Path $root $row.Groups[1].Value
  Assert-Receipt "provenance hash matches $($row.Groups[1].Value)" ((Test-Path $file) -and (Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $row.Groups[2].Value)
}
$css = Read-Text (Join-Path $root 'pf-home-ledger.css')
$refs = @([regex]::Matches($css + $homeHtml, '/(?:brand/emblem|assets/fonts)/[A-Za-z0-9_.-]+') | ForEach-Object Value | Sort-Object -Unique)
# Active emblem assets are bound byte for byte: every /brand/emblem reference in the BUILT page (HTML, CSS, JS) must
# be a provenance-recorded file, and its source bytes, built bytes and recorded SHA-256 must all be equal.
$recordedSha = @{}
foreach ($row in $rows) { $recordedSha['/' + $row.Groups[1].Value] = $row.Groups[2].Value }
$builtHomeCss = Read-Text (Join-Path $PublicDir 'pf-home-ledger.css')
$builtHomeJs = Read-Text (Join-Path $PublicDir 'pf-home.js')
$activeEmblem = @([regex]::Matches($homeHtml + $builtHomeCss + $builtHomeJs, '/brand/emblem/[A-Za-z0-9_.-]+') | ForEach-Object Value | Sort-Object -Unique)
Assert-Receipt 'every active emblem, header, light-mask and loupe reference in the built page is a provenance-recorded file' ($activeEmblem.Count -ge 10 -and @($activeEmblem | Where-Object { -not $recordedSha.ContainsKey($_) }).Count -eq 0)
foreach ($ref in $activeEmblem) {
  $sourceFile = Join-Path $root $ref.TrimStart('/')
  $builtFile = Join-Path $PublicDir $ref.TrimStart('/')
  $sourceSha = if (Test-Path -LiteralPath $sourceFile -PathType Leaf) { (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant() } else { 'missing' }
  $builtSha = if (Test-Path -LiteralPath $builtFile -PathType Leaf) { (Get-FileHash -LiteralPath $builtFile -Algorithm SHA256).Hash.ToLowerInvariant() } else { 'missing' }
  Assert-Receipt "active asset bytes, source = built = recorded: $ref" ($recordedSha.ContainsKey($ref) -and $sourceSha -ceq $recordedSha[$ref] -and $builtSha -ceq $recordedSha[$ref])
}
Assert-Receipt 'every emblem and font reference resolves in the build' ($refs.Count -ge 14 -and @($refs | Where-Object { -not (Test-Path (Join-Path $PublicDir $_.TrimStart('/'))) }).Count -eq 0)
Assert-Receipt 'fonts ship with their licences' ((Test-Path (Join-Path $PublicDir 'assets/fonts/OFL-Archivo.txt')) -and (Test-Path (Join-Path $PublicDir 'assets/fonts/OFL-IBM-Plex-Mono.txt')))

Write-Host "=== HOMEPAGE RECEIPT TRUTH RESULT: $pass passed, $fail failed ==="
if ($fail -gt 0) { exit 1 }
exit 0
