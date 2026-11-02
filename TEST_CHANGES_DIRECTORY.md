# Directory qualification test changes

No source/product/release authority files changed. No shared public build performed.

## `scripts/test-home-v5-browser.mjs`
Reason: Main-site Home no longer contains featured cards or a specimen; read explicit dialog product configuration and primary entrance, fail closed on missing setup, preserve every receipt scenario.

Old:
```
const receiptIds = [...new Set([...home.matchAll(/data-receipt-open="([a-z0-9-]+)"/g)].map((m) => m[1]))];
  const featureIds = [...home.matchAll(/data-ledger-feature="([a-z0-9-]+)"/g)].map((m) => m[1]);
  const specimenId = (home.match(/data-ledger-specimen="([a-z0-9-]+)"/) || [])[1];
```
Replacement:
```
const triggerIds = [...new Set([...home.matchAll(/data-receipt-open="([a-z0-9-]+)"/g)].map((m) => m[1]))];
  const receiptIds = (home.match(/data-receipt-products="([^"]+)"/) || [])[1]?.split(/\s+/) || [];
  const specimenId = triggerIds[0]; // primary record entrance, not a static specimen
  const featureIds = receiptIds.filter((id) => id !== specimenId);
  if (!specimenId || receiptIds.length < 3 || !receiptIds.includes(specimenId)) throw new Error('Missing primary receipt entrance or configured receipt products.');
  const receiptTrigger = `[data-receipt-open="${specimenId}"]`;
  const openReceipt = async (id) => {
    await evaluate(`document.querySelector(${JSON.stringify(receiptTrigger)}).click()`);
    await waitFor(panelSettled);
    if (id !== specimenId) {
      await evaluate(`document.getElementById('pf-receipt-tab-${id}').click()`);
      await waitFor(panelSettled);
    }
  };
```

## `scripts/test-home-v5-browser.mjs`
Reason: Replace featured-card count with current entrance/tab topology.

Old:
```
  check('the homepage offers receipts for its specimen and featured products', specimenId && featureIds.length === 3 && receiptIds.includes(specimenId) && featureIds.every((id) => receiptIds.includes(id)), { specimenId, featureIds, receiptIds });
```
Replacement:
```
  check('Home offers one record entrance and at least three explicitly configured receipt tabs, without a portfolio', triggerIds.length === 1 && receiptIds.length >= 3 && new Set(receiptIds).size === receiptIds.length && featureIds.length >= 2 && !/data-ledger-feature=|data-ledger-specimen=/.test(home), { triggerIds, receiptIds });
```

## `scripts/test-home-v5-browser.mjs`
Reason: Static digest specimen intentionally removed; dynamic parity checks remain.

Old:
```
check('the page shows one product digest, the specimen\'s, until a receipt is opened', page.digests.length === 1 && specimenDigests.includes(page.digests[0]), page.digests);
```
Replacement:
```
check('Home exposes no artifact digest until a validated receipt is opened', page.digests.length === 0, page.digests);
```

## `scripts/test-home-v5-browser.mjs`
Reason: No-JS fallback is the records entrance.

Old:
```
      const spec = document.querySelector('[data-ledger-specimen]');
```
Replacement:
```
      const spec = document.querySelector('.home-records');
```

## `scripts/test-home-v5-browser.mjs`
Reason: Check current hash-scope caveat rather than nonexistent specimen.

Old:
```
hash: hash && visible(hash) ? hash.textContent : null,
```
Replacement:
```
hash: hash && visible(hash) ? hash.textContent : null,
        scope: spec?.textContent.includes('does not establish custody or safety'),
```

## `scripts/test-home-v5-browser.mjs`
Reason: Full SHA is now deliberately fetched only at open time; fallback remains usable through human records.

Old:
```
    check(`${width}px without JavaScript: the specimen keeps its full SHA-256, limitations and record links`, specimenDigests.includes(nojs.hash) && nojs.limitations && nojs.specimenLinks.includes(`/proof/#receipt-${specimenId}`) && nojs.specimenLinks.includes(`/truth-files/${specimenId}/`), nojs);
```
Replacement:
```
    check(`${width}px without JavaScript: human truth and published records stay reachable with honest hash scope`, nojs.hash === null && nojs.scope && nojs.specimenLinks.includes('/proof/') && nojs.specimenLinks.includes('/truth-files/'), nojs);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Enforce removal rather than demand a portfolio.

Old:
```
    check(`${width}px without JavaScript: every featured product keeps its Truth File link and caption, with no overflow`, nojs.featureLinks === 3 && nojs.captions.length === 3 && nojs.captions.every((n) => n > 0) && !nojs.overflow, nojs);
```
Replacement:
```
    check(`${width}px without JavaScript: Home has no featured cards and no overflow`, nojs.featureLinks === 0 && nojs.captions.length === 0 && !nojs.overflow, nojs);
```

## `scripts/test-home-v5-browser.mjs`
Reason: All primary keyboard/refresh selectors now use the real records entrance.

Old:
```
[data-ledger-specimen] [data-receipt-open]
```
Replacement:
```
[data-receipt-open]
```

## `scripts/test-home-v5-browser.mjs`
Reason: Secondary records are tabs, not featured cards; Space still opens the real entrance.

Old:
```
await focus(`[data-ledger-feature="${featureIds[0]}"] [data-receipt-open]`);
```
Replacement:
```
await focus(receiptTrigger);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Retain keyboard activation for actual trigger.

Old:
```
  check('Space on a featured product opens its receipt', s.open && s.tabs.find((t) => t.selected === 'true')?.id === `pf-receipt-tab-${featureIds[0]}`, s.tabs);
```
Replacement:
```
  check('Space on the record entrance opens its receipt', s.open && s.tabs.find((t) => t.selected === 'true')?.id === `pf-receipt-tab-${specimenId}`, s.tabs);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Failure injections exercise a nonprimary configured tab through real UI.

Old:
```
await evaluate(`document.querySelector('[data-ledger-feature="${featured}"] [data-receipt-open]').click()`);
```
Replacement:
```
await openReceipt(featured);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Touch opens the real entrance; tab switching still tests other records.

Old:
```
await tap(`[data-ledger-feature="${featureIds[0]}"] [data-receipt-open]`);
```
Replacement:
```
await tap(receiptTrigger);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Touch tab must differ from primary.

Old:
```
const other = receiptIds.find((id) => id !== featureIds[0]);
```
Replacement:
```
const other = receiptIds.find((id) => id !== specimenId);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Focus restoration goes to actual trigger.

Old:
```
after.receipt === featureIds[0]
```
Replacement:
```
after.receipt === specimenId
```

## `scripts/test-home-v5-browser.mjs`
Reason: Current hero description selector; retain rendered font-family check.

Old:
```
document.querySelector('.ledger-hero-description')
```
Replacement:
```
document.querySelector('.home-intro')
```

## `scripts/test-home-v5-browser.mjs`
Reason: Doctrine watermark removed; absence remains correct, no null dereference.

Old:
```
watermark: vis('.ledger-receipt-watermark')
```
Replacement:
```
watermark: document.querySelector('.ledger-receipt-watermark') ? vis('.ledger-receipt-watermark') : false
```

## `scripts/check-home-receipt-truth.ps1`
Reason: Static specimen removed.

Old:
```
Assert-Receipt 'homepage HTML carries no digest except the specimen artifact' ($specimen -and $digests.Count -eq 1 -and $digests[0] -ceq [string]$specimen.sha256)
```
Replacement:
```
Assert-Receipt 'homepage HTML carries no static release digest or specimen' ($digests.Count -eq 0 -and $homeHtml -notmatch 'data-ledger-specimen=')
```

## `scripts/check-home-receipt-truth.ps1`
Reason: Current dialog explicitly configures tab IDs; empty panel still required.

Old:
```
aria-labelledby="pf-receipt-title">
```
Replacement:
```
aria-labelledby="pf-receipt-title" data-receipt-products="cache-vault proofshot lights-out">
```

## `scripts/check-home-receipt-truth.ps1`
Reason: One records entrance replaces four card/specimen triggers.

Old:
```
$triggers.Count -eq 4
```
Replacement:
```
$triggers.Count -eq 1
```

## `scripts/check-home-receipt-truth.ps1`
Reason: Every configured tab, not just entrance, must bind shared release truth.

Old:
```
$receiptIds = @([regex]::Matches($homeHtml, 'data-receipt-open="([a-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
```
Replacement:
```
$receiptIds = @([regex]::Match($homeHtml, 'data-receipt-products="([^"]+)"').Groups[1].Value -split '\s+' | Where-Object { $_ })
```

## `scripts/check-home-receipt-truth.ps1`
Reason: Featured capture disclosures moved to editorial directory; validate every current entry artwork, caption, alt, route, version, no-JS visibility and exclusions, not deleted Home cards.

Old:
```
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


```
Replacement:
```
# ── 5. Editorial captures keep context and authentic source artwork ────────
. "$PSScriptRoot/check-directory-contract.ps1"
Assert-DirectoryContract $root $PublicDir { param($name,$ok) Assert-Receipt $name $ok }


```

## `scripts/home-receipt-truth.check.mjs`
Reason: Validate every configured receipt tab even though only one Home trigger remains.

Old:
```
const receiptIds = [...new Set([...home.matchAll(/data-receipt-open="([a-z0-9-]+)"/g)].map((m) => m[1]))];
```
Replacement:
```
const receiptIds = (home.match(/data-receipt-products="([^"]+)"/) || [])[1]?.split(/\s+/) || [];
```

## `scripts/home-receipt-truth.check.mjs`
Reason: Keep full original three-product receipt coverage.

Old:
```
assert('homepage offers receipts for the three featured releases', receiptIds.length === 3, receiptIds);
```
Replacement:
```
assert('homepage explicitly configures three distinct receipt products', receiptIds.length === 3 && new Set(receiptIds).size === 3, receiptIds);
```

## `scripts/test-h9-homepage.ps1`
Reason: Approved main-site-first topology replaces frozen eight-section Ledger.

Old:
```
Assert-H9 'home preserves the exact shipped Proof Ledger section order' (($sections -join ',') -ceq 'ledger-hero,ledger-featured,ledger-chain,ledger-paper ledger-doctrine,ledger-specimen,ledger-paper ledger-index,ledger-position,ledger-close' -and $homeHtml -notmatch 'studio-threshold|studio-portfolio|data-home-products')
```
Replacement:
```
Assert-H9 'Home preserves the current six-section main-site order without a portfolio' (($sections -join ',') -ceq 'ledger-hero,home-orientation container,ledger-chain container,ledger-paper ledger-doctrine,home-records container,home-contact container' -and $homeHtml -notmatch 'studio-threshold|studio-portfolio|data-home-products')
```

## `scripts/test-h9-homepage.ps1`
Reason: Scope claims to actual current hero, not missing featured section.

Old:
```
$hero = [regex]::Match($homeHtml, '(?s)<section class="ledger-hero"[^>]*>.*?(?=<section class="ledger-featured")').Value
```
Replacement:
```
$hero = [regex]::Match($homeHtml, '(?s)<section class="ledger-hero"[^>]*>.*?(?=<section class="home-orientation)').Value
```

## `scripts/test-h9-homepage.ps1`
Reason: Current h1 has no ID; accessible page heading is still required.

Old:
```
$heroH1 = [regex]::Match($hero, '(?s)<h1 id="([^"]+)"[^>]*>(.*?)</h1>')
```
Replacement:
```
$heroH1 = [regex]::Match($hero, '(?s)<h1(?: id="([^"]+)")?[^>]*>(.*?)</h1>')
```

## `scripts/test-h9-homepage.ps1`
Reason: Check semantic text, not br serialization or obsolete section labelling.

Old:
```
Assert-H9 'hero headline is the approved V5 headline, the only h1, and names the hero section' ($heroH1.Success -and $heroH1.Groups[2].Value -ceq 'Real software<br/>leaves a record.' -and (Get-VisibleText $heroH1.Groups[2].Value) -ceq 'Real software leaves a record.' -and $hero -match ('^<section class="ledger-hero" aria-labelledby="' + [regex]::Escape($heroH1.Groups[1].Value) + '"') -and ([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1)
```
Replacement:
```
Assert-H9 'hero has the approved headline and the only h1' ($heroH1.Success -and (Get-VisibleText $heroH1.Groups[2].Value) -ceq 'Real software leaves a record.' -and ([regex]::Matches($homeHtml, '<h1\b')).Count -eq 1)
```

## `scripts/test-h9-homepage.ps1`
Reason: Owner-approved main-site copy replaces old subtitle/description; overclaim guard preserved.

Old:
```
Assert-H9 'hero subtitle and description are the approved V5 copy, in order, with no certification, security, digest or version claim in its text or labels' ($heroSubtitle.Success -and $heroDescription.Success -and (Get-VisibleText $heroSubtitle.Groups[1].Value) -ceq 'Receipts over hype.' -and (Get-VisibleText $heroDescription.Groups[1].Value) -ceq 'Independent software. Public records. Clear limits.' -and $hero.IndexOf($heroH1.Value) -lt $hero.IndexOf($heroSubtitle.Value) -and $hero.IndexOf($heroSubtitle.Value) -lt $hero.IndexOf($heroDescription.Value) -and $heroClaims -notmatch $overclaim -and $hero -notmatch '\b[0-9a-f]{64}\b' -and $heroClaims -notmatch '\bv\d+\.\d+')
```
Replacement:
```
Assert-H9 'hero has useful-tools copy and no certification, security, digest or version claim' ($hero -match '<p class="home-intro">Useful tools\. Deliberately made\.<br>Public releases you can inspect\.</p>' -and $heroClaims -notmatch $overclaim -and $hero -notmatch '\b[0-9a-f]{64}\b' -and $heroClaims -notmatch '\bv\d+\.\d+')
```

## `scripts/test-h9-homepage.ps1`
Reason: Keep metadata exact; doctrine heading intentionally changed.

Old:
```
Assert-H9 'Home search and social descriptions are the approved V5 copy, and the philosophy heading does not repeat the hero' ($homeHead -cmatch ('<meta name="description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHead -cmatch ('<meta property="og:description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHtml -cmatch '<h2 id="doctrine-title">Show the work\.</h2>' -and ([regex]::Matches($homeHtml, 'Receipts over hype\.')).Count -eq 1)
```
Replacement:
```
Assert-H9 'Home search and social descriptions retain the approved record-first copy and philosophy remains useful-first' ($homeHead -cmatch ('<meta name="description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHead -cmatch ('<meta property="og:description" content="' + [regex]::Escape($approvedDescription) + '"/>') -and $homeHtml -match '<h2>Useful first\.<br>Accountable always\.</h2>')
```

## `scripts/test-h9-homepage.ps1`
Reason: Hero now uses described maker seal plus inline vector, not decorative picture source.

Old:
```
Assert-H9 'hero emblem is decorative with a forced-colours vector seal, and its inspect control opens the mark dialog' ($hero -match '<div class="ledger-plate-scene" aria-hidden="true">' -and $hero -match '<source media="\(forced-colors: active\)" srcset="/brand/PF_MAKER_SEAL\.svg"/><img class="pf-emblem-image" src="/brand/emblem/PF_MARK_G_EMBLEM_R3\.webp" alt=""' -and $hero -match 'Source / Artifact / Record' -and $hero -match 'class="pf-inspect"[^>]*aria-haspopup="dialog"[^>]*aria-controls="pf-mark-dialog"' -and $homeHtml -match '<dialog [^>]*id="pf-mark-dialog"')
```
Replacement:
```
Assert-H9 'hero emblem has meaningful alt text, an inert forced-colours vector seal, and a named mark-dialog control' ($hero -match '<img class="pf-emblem-image"[^>]*alt="[^"]+"' -and $hero -match 'class="pf-seal-fc" hidden' -and $hero -match 'class="pf-seal-inline" focusable="false"' -and $hero -match 'class="pf-inspect"[^>]*aria-haspopup="dialog"[^>]*aria-controls="pf-mark-dialog"' -and $homeHtml -match '<dialog [^>]*id="pf-mark-dialog"')
```

## `scripts/test-h9-homepage.ps1`
Reason: Updated CTA classes and copy retain dedicated destinations.

Old:
```
Assert-H9 'hero sends visitors to dedicated Software and Proof Standard pages' ($heroActions -cmatch '^<a class="ledger-button" href="/software/">Browse software <svg' -and $hero -cmatch '<a class="ledger-link ledger-link-mono" href="/proof-standard/">Read the Proof Standard <svg' -and $homeHtml -match 'href="/software/"' -and $homeHtml -match 'href="/proof-standard/"')
```
Replacement:
```
Assert-H9 'hero sends visitors to Products and Proof Standard' ($hero -match '<a class="button button-primary" href="/software/">Browse Products' -and $hero -match 'href="/proof-standard/">Our proof standard')
```

## `scripts/test-h9-homepage.ps1`
Reason: Product IDs are valid receipt configuration outside the brand hero; prohibit actual embedded portfolio.

Old:
```
Assert-H9 'hero is brand-owned and contains no fixed product identity' ($sourceHome -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=' -and $homeHtml -notmatch 'class="studio-hero-product"')
```
Replacement:
```
Assert-H9 'hero is brand-owned and contains no product card or fixed portfolio' ($hero -notmatch '(?i)cache vault|reality gate|ghostlayer|forgecast|proofshot|lights out|cleanroom|data-module=' -and $homeHtml -notmatch 'class="studio-hero-product"|data-ledger-feature=|data-ledger-specimen=')
```

## `scripts/test-h9-homepage.ps1`
Reason: Public directory deliberately differs from module card registry; validate actual generated targets fail-closed.

Old:
```
Assert-H9 'Software cards retain registry routes, authentic images and public versions' ($catalogFailures.Count -eq 0)
```
Replacement:
```
Assert-H9 'directory projection is independently validated against current editorial and release inputs' ((& node (Join-Path $PSScriptRoot 'portfolio-review.cjs') --verify-generated $public 2>&1 | Out-String) -match 'Editorial generated targets verified:' -and $LASTEXITCODE -eq 0)
```

## `scripts/test-h9-homepage.ps1`
Reason: Current directory has contextual media and preserves unfeatured history, not ProofShot catalog brand card.

Old:
```
Assert-H9 'Software explains that app previews may show earlier builds, names no HyperSnatch-era preview, and shows ProofShot by its brand card' ($software -match 'App previews may show earlier builds\.' -and $software -notmatch 'HyperSnatch' -and $proofshotSoftwareCard -match '<img src="/assets/proofshot/og-image\.png"')
```
Replacement:
```
Assert-H9 'directory imagery states its context, and hidden ProofShot has no directory card while its history remains reachable' ($software -match 'Existing capture or artwork\. Version context is retained in the product record\.' -and $software -notmatch 'data-directory-entry="proofshot"' -and $software -match 'href="/proofshot/"')
```

## `scripts/test-h9-homepage.ps1`
Reason: Current stylesheet disables living-metal motion and uses inline CanvasText vectors; browser still measures pixels.

Old:
```
Assert-H9 'active ledger preserves motion limits and actual SVG forced-color support' ($homeCss -match 'prefers-reduced-motion:reduce' -and $homeCss -match 'animation:none!important' -and $homeCss -match 'forced-colors:active' -and $homeCss -match 'background:Canvas' -and $headerMark -match 'forced-colors:active' -and $headerMark -match 'fill:CanvasText' -and $makerSeal -match 'fill:CanvasText' -and $makerSeal -match 'stroke:CanvasText')
```
Replacement:
```
Assert-H9 'active main-site preserves reduced motion and actual SVG forced-color support' ($homeCss -match 'prefers-reduced-motion:reduce' -and $homeCss -match '\.pf-lm\{display:none\}' -and $homeCss -match 'forced-colors:active' -and $homeCss -match 'CanvasText' -and $headerMark -match 'fill:CanvasText' -and $makerSeal -match 'fill:CanvasText' -and $makerSeal -match 'stroke:CanvasText')
```

## `scripts/test-h9-homepage.ps1`
Reason: Updated wording preserves same limitation.

Old:
```
Assert-H9 'Home proof link scopes hash identity and custody honestly' ($homeHtml -match 'A verified hash establishes artifact identity' -and $homeHtml -match 'does not by itself establish custody or safety' -and $homeHtml -notmatch 'HASH VERIFIED' -and $proof -match 'Artifact custody')
```
Replacement:
```
Assert-H9 'Home scopes hash identity and custody honestly' ($homeHtml -match 'A SHA-256 match identifies exact files' -and $homeHtml -match 'does not establish custody or safety' -and $homeHtml -notmatch 'HASH VERIFIED' -and $proof -match 'Artifact custody')
```

## `scripts/test-h9-homepage.ps1`
Reason: Directory search/group replaces legacy purpose/platform/comparison UI.

Old:
```
Assert-H9 'search and comparison stay on the full catalogue page' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"' -and $software -match 'product-finder|finder-intents' -and $software -match 'compare-choice|data-compare')
```
Replacement:
```
Assert-H9 'search lives on Products and no comparison controls compete with Home orientation' ($homeHtml -notmatch 'product-finder|data-compare=|id="product-search"|data-directory-finder' -and $software -match 'data-directory-finder' -and $software -match 'name="query"' -and $software -match 'name="group"')
```

## `scripts/test-h9-homepage.ps1`
Reason: Replace module-card taxonomy count with stronger full per-entry editorial, route, artwork, release and preservation checks.

Old:
```
Assert-H9 'catalog trims secondary taxonomy while retaining finder data and release facts' ($catalogCards.Count -eq @($manifest.products | Where-Object visible).Count -and @($catalogCards | Where-Object { $_ -match 'class="card-taxonomy"' -or $_ -notmatch 'data-category="[^\"]+"' -or $_ -notmatch 'data-jobs="[^\"]+"' -or $_ -notmatch 'class="h9-card-meta"' -or $_ -notmatch 'class="card-availability"' -or $_ -notmatch 'class="card-commerce"' }).Count -eq 0)
```
Replacement:
```
. "$PSScriptRoot/check-directory-contract.ps1"
Assert-DirectoryContract $root $public { param($name,$ok) Assert-H9 $name $ok }
```

## `scripts/test-h9-homepage.ps1`
Reason: Current responsive breakpoint is 700px; browser still checks six widths.

Old:
```
@media\s*\(max-width:640px\)
```
Replacement:
```
@media\s*\(max-width:700px\)
```

## `scripts/test-h9-homepage.ps1`
Reason: Watermark removed and arrows intentionally use text glyphs; preserve canonical mark binding and vector fallback, measured by browser.

Old:
```
Assert-H9 'shared PF micro mark stays in the footer and unified seal derivatives appear without glyph arrows' (([regex]::Matches($homeFooter, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and $homeHtml -match 'PF_MAKER_SEAL\.svg' -and $homeHtml -match 'PF_RECEIPT_WATERMARK\.svg' -and $homeHtml -notmatch 'pf-stamp-top|PF_MARK_G_MONO_LIGHT\.svg' -and $homeHtml -match 'class="site-footer"' -and $homeHtml -notmatch '↗|→|←' -and $homeHtml -match 'class="ledger-arrow"')
```
Replacement:
```
Assert-H9 'shared micro marks stay in footer and the maker seal has a forced-colours vector, without legacy mono glyph branding' (([regex]::Matches($homeFooter, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and ([regex]::Matches($homeHtml, '<img[^>]*PF_HEADER_MARK\.svg')).Count -eq 1 -and $homeHtml -match 'pf-seal-inline' -and $homeHtml -notmatch 'pf-stamp-top|PF_MARK_G_MONO_LIGHT\.svg' -and $homeHtml -match 'class="site-footer"')
```

## `scripts/test-h9-binding.ps1`
Reason: Main-site-first structure replaces old eight-section release index.

Old:
```
Assert-Binding 'Home preserves all eight Proof Ledger sections and excludes the obsolete portfolio renderer' (($homeSections -join ',') -ceq 'ledger-hero,ledger-featured,ledger-chain,ledger-paper ledger-doctrine,ledger-specimen,ledger-paper ledger-index,ledger-position,ledger-close' -and $renderedPortfolio.Count -eq 0 -and $homeHtml -notmatch 'studio-portfolio|studio-evidence|studio-product-tab|data-home-products')
```
Replacement:
```
Assert-Binding 'Home has current orientation, method and record entrances without an embedded portfolio' ($homeHtml -match 'home-orientation' -and $homeHtml -match 'ledger-chain' -and $homeHtml -match 'home-records' -and $renderedPortfolio.Count -eq 0 -and $homeHtml -notmatch 'studio-portfolio|studio-evidence|studio-product-tab|data-home-products')
```

## `scripts/test-h9-binding.ps1`
Reason: Home no longer carries release index.

Old:
```
Assert-Binding 'withdrawal appears only as an unavailable record in the release index' ($expectedWithdrawn.Count -eq 1 -and $renderedWithdrawn.Count -eq 0 -and $homeHtml -match 'data-release-status="WITHDRAWN"' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work')
```
Replacement:
```
Assert-Binding 'withdrawal stays off Home but remains explicit in directory release context' ($expectedWithdrawn.Count -eq 1 -and $renderedWithdrawn.Count -eq 0 -and $software -match 'public v1\.1\.0 withdrawn' -and $homeHtml -notmatch 'studio-withdrawn|Withdrawn work|data-release-status=')
```

## `scripts/test-h9-binding.ps1`
Reason: Unified plate and watermark removed; canonical emblem remains.

Old:
```
Assert-Binding 'Proof Ledger uses its unified plate and micro PF derivative without a featured-product renderer' ($homeHtml -match 'ledger-plate-scene' -and $homeHtml -match 'PF_HEADER_MARK\.svg' -and $homeHtml -match 'PF_MAKER_SEAL\.svg' -and $homeHtml -match 'PF_RECEIPT_WATERMARK\.svg' -and $homeHtml -notmatch 'PF_MARK_G_MONO_LIGHT\.svg|pf-stamp-top' -and $homeHtml -match '/pf-home-ledger\.css' -and $homeHtml -notmatch 'studio-hero-product|@studio-hero-product|studio-hero-emblem')
```
Replacement:
```
Assert-Binding 'Home keeps canonical emblem and forced-colours vector without featured-product renderer' ($homeHtml -match 'home-maker' -and $homeHtml -match 'PF_MARK_G_EMBLEM_R3\.webp' -and $homeHtml -match 'PF_HEADER_MARK\.svg' -and $homeHtml -match 'pf-seal-inline' -and $homeHtml -match '/pf-home-ledger\.css' -and $homeHtml -notmatch 'studio-hero-product|@studio-hero-product|studio-hero-emblem')
```

## `scripts/test-h9-binding.ps1`
Reason: Receipt configuration necessarily lists IDs, not a homepage portfolio.

Old:
```
Assert-Binding 'root source contains no fixed product list, product identity or product-specific card markup' ((Read-Source 'index.html') -notmatch '(?i)cache vault|reality gate|forgecast|ghostlayer|lights out|cleanroom|proofshot|data-module=')
```
Replacement:
```
Assert-Binding 'root source has no product-specific card markup or portfolio renderer' ((Read-Source 'index.html') -notmatch 'data-module=|data-ledger-feature=|data-ledger-specimen=|@studio-')
```

## `scripts/test-h9-binding.ps1`
Reason: Shared main-site stylesheet contains product route accents; only Home identity branches are forbidden.

Old:
```
Assert-Binding 'active root CSS uses generic presentation semantics' ((Read-Source 'pf-home-ledger.css') -notmatch '(?i)cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot|data-module="')
```
Replacement:
```
Assert-Binding 'active Home selectors do not introduce product-specific identity branches' ((Read-Source 'pf-home-ledger.css') -notmatch '(?i)\.(?:home|ledger)-(?:cache-vault|reality-gate|forgecast|ghostlayer|lights-out|cleanroom|proofshot)\b|data-module="')
```

## `scripts/test-h9-binding.ps1`
Reason: Validate editorial directory per entry rather than obsolete module card media/accent.

Old:
```
Assert-Binding 'Software cards bind route, authentic media, accent and public version to module truth' ($bindingFailures.Count -eq 0)
```
Replacement:
```
. "$PSScriptRoot/check-directory-contract.ps1"
Assert-DirectoryContract $Root $PublicDir { param($name,$ok) Assert-Binding $name $ok }
```

## `scripts/test-h9-binding.ps1`
Reason: Editorial exclusions preserve product routes/history without card requirement.

Old:
```
Assert-Binding 'all product routes, catalog cards and Truth outputs remain reachable off Home' (@($publicModules | Where-Object { $id=$_.id; $homeHtml -match ('data-module="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "$id/index.html")) -or $software -notmatch ('data-product="' + [regex]::Escape([string]$id) + '"') -or -not (Test-Path (Join-Path $PublicDir "truth/products/$id.json")) }).Count -eq 0)
```
Replacement:
```
Assert-Binding 'all canonical product and Truth outputs remain reachable from directory history or records off Home' (@($publicModules | Where-Object { $id=$_.id; -not (Test-Path (Join-Path $PublicDir "$id/index.html")) -or $software -notmatch ('href="/' + [regex]::Escape([string]$id) + '/"') -or -not (Test-Path (Join-Path $PublicDir "truth/products/$id.json")) }).Count -eq 0)
```

## `scripts/test-h9-binding.ps1`
Reason: Presentation authority is site-editorial.json, not manifest catalog flags.

Old:
```
Assert-Binding 'software catalog enumerates the manifest catalog projection' (([regex]::Matches($software, '<article\b[^>]*data-product="').Count) -eq @($manifest.products | Where-Object { $_.visible -and (-not $_.placement -or $_.placement.catalog -ne $false) }).Count)
```
Replacement:
```
Assert-Binding 'directory includes exactly the visible editorial identities' (([regex]::Matches($software, 'data-directory-entry="').Count) -eq @(((Read-Source 'site-editorial.json') | ConvertFrom-Json).entries | Where-Object visible).Count)
```

## `scripts/test-h9-binding.ps1`
Reason: Static specimen removed; inspector continues binding every configured tab to shared release authority.

Old:
```
Assert-Binding 'Static homepage release specimen binds its digest and version to the authored ProofShot record, and the page carries no primary digest of any other product' ($homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'Checksums identify exact files' -and (Read-Built 'proof/index.html') -match 'Artifact custody' -and $homeHtml -match 'data-ledger-specimen="proofshot"' -and $homeHtml.Contains([string]$specimen.sha256) -and $homeHtml.Contains('v' + [string]$specimen.release.publicVersion) -and @($manifest.products | Where-Object { $_.sha256 -and $homeHtml.Contains([string]$_.sha256) }).Count -eq 1)
```
Replacement:
```
Assert-Binding 'Home exposes no static digest and sends visitors to human proof and Truth records' ($homeHtml -match 'href="/proof/"' -and $homeHtml -match 'href="/truth-files/"' -and $homeHtml -match 'A SHA-256 match identifies exact files' -and (Read-Built 'proof/index.html') -match 'Artifact custody' -and $homeHtml -notmatch 'data-ledger-specimen=|\b[0-9a-f]{64}\b')
```

## `scripts/test-h9-binding.ps1`
Reason: Cache Vault versions retained in current directory-state presentation.

Old:
```
$software -match 'data-product="cache-vault"' -and $software -match 'class="card-version">v0\.3\.1'
```
Replacement:
```
$software -match 'data-directory-entry="cache-vault"' -and $software -match 'Windows · v0\.3\.1 / Android · v0\.3\.1'
```

## `scripts/test-h9-binding.ps1`
Reason: Current responsive breakpoint; browser layout checks remain.

Old:
```
@media\s*\(max-width:640px\)
```
Replacement:
```
@media\s*\(max-width:700px\)
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Current directory replaces legacy h9 finder.

Old:
```
Assert-Condition ($sourceCatalog -match 'class="h9-product-finder" data-h9-enhance hidden') 'source: software filters are progressive enhancement'
```
Replacement:
```
Assert-Condition ($sourceCatalog -match '<form class="directory-finder" data-directory-finder hidden role="search">') 'source: directory filters are hidden progressive enhancement'
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Search/group are current inputs.

Old:
```
Assert-Condition ($outputCatalog -match 'class="h9-product-finder" data-h9-enhance hidden' -and $outputCatalog -match 'class="finder-intents"') 'output: software filter controls survive build'
```
Replacement:
```
Assert-Condition ($outputCatalog -match 'data-directory-finder hidden role="search"' -and $outputCatalog -match 'name="query"' -and $outputCatalog -match 'name="group"') 'output: directory search and group controls survive build'
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Configurable directory count replaces seven module cards.

Old:
```
Assert-Condition ($sourceCatalog -notmatch 'data-catalog-toggle' -and ([regex]::Matches($outputCatalog, '<article class="product-card')).Count -eq 7) 'source/output: software ships the complete seven-tool catalog without a curation toggle'
```
Replacement:
```
$editorial = Get-Content (Join-Path $root 'site-editorial.json') -Raw | ConvertFrom-Json
Assert-Condition ($sourceCatalog -notmatch 'data-catalog-toggle' -and ([regex]::Matches($outputCatalog, 'data-directory-entry="')).Count -eq @($editorial.entries | Where-Object visible).Count) 'source/output: directory ships the complete visible editorial projection without curation'
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Approved heading changed.

Old:
```
Assert-Condition ($sourceCatalog -match '<h1>Find your tool\.</h1>') 'source: catalog has a clear product-first heading'
```
Replacement:
```
Assert-Condition ($sourceCatalog -match '<h1>Tools for the work\.<br>Worlds of their own\.</h1>') 'source: directory has the current product-first heading'
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Current five-stage method wording, same scope.

Old:
```
Assert-Condition ($sourceHome -match 'id="chain-title"' -and $sourceHome -match 'Recorded build evidence, where applicable\.' -and $sourceHome -match 'Known limitations stay on the record\.' -and $sourceHome -notmatch '@studio-evidence') 'source: Proof Ledger chain scopes build evidence and limitations honestly'
```
Replacement:
```
Assert-Condition ($sourceHome -match 'id="chain-title"' -and $sourceHome -match 'Record how it was made\.' -and $sourceHome -match 'Keep the qualifications visible\.' -and $sourceHome -notmatch '@studio-evidence') 'source: proof method scopes build evidence and limitations honestly'
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Semantic line break and CTA changed.

Old:
```
Assert-Condition ($outputHome -match 'Real software<br/>leaves a record\.' -and $outputHome -match 'Browse Software' -and $outputHome -match 'href="/software/"' -and $outputHome -notmatch 'studio-portfolio|studio-evidence') 'output: shipped Proof Ledger headline and catalog CTA survive build'
```
Replacement:
```
Assert-Condition ($outputHome -match 'Real software<br>leaves a record\.' -and $outputHome -match 'Browse Products' -and $outputHome -match 'href="/software/"' -and $outputHome -notmatch 'studio-portfolio|studio-evidence') 'output: main-site headline and directory CTA survive build'
```

## `scripts/check-directory-contract.ps1`
Reason: PowerShell variables are case-insensitive; `$home` collided with read-only `$HOME` and aborted test-h9-binding.ps1 mid-run. Renamed to `$homePage`; assertions unchanged.

## `scripts/test-home-v5-browser.mjs`
Reason: Probe showed site.js/pf-home.js initialization racing the fixed 250 ms delay right after JavaScript is re-enabled (motion unset, 0 mark pins); after 1.5 s the page had motion=on and 10 pins. Wait for observable init. Not a page defect.

Old:
```
    await loaded;
    await evaluate('document.fonts.ready.then(() => true)');
```
Replacement:
```
    await loaded;
    await evaluate('document.fonts.ready.then(() => true)');
    // Module scripts may finish after load; wait for their observable init instead of a fixed delay.
    if (scriptsEnabled) await waitFor(`!!document.documentElement.dataset.motion && [...document.querySelectorAll('[data-mark-open]')].every((b) => !b.hidden)`, 10000);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Track script state for the readiness wait.

Old:
```
  async function go(route = '/') {
```
Replacement:
```
  let scriptsEnabled = true;
  async function go(route = '/') {
```

## `scripts/test-home-v5-browser.mjs`
Reason: Readiness wait applies only with JavaScript.

Old:
```
await send('Emulation.setScriptExecutionDisabled', { value: true });
```
Replacement:
```
await send('Emulation.setScriptExecutionDisabled', { value: true }); scriptsEnabled = false;
```

## `scripts/test-home-v5-browser.mjs`
Reason: Readiness wait applies only with JavaScript.

Old:
```
await send('Emulation.setScriptExecutionDisabled', { value: false });
```
Replacement:
```
await send('Emulation.setScriptExecutionDisabled', { value: false }); scriptsEnabled = true;
```

## `scripts/test-home-v5-browser.mjs`
Reason: An invalid index legitimately builds no tabs; do not crash, let the scenario assertion judge the refusal.

Old:
```
    if (id !== specimenId) {
      await evaluate(`document.getElementById('pf-receipt-tab-${id}').click()`);
```
Replacement:
```
    if (id !== specimenId && await evaluate(`!!document.getElementById('pf-receipt-tab-${id}')`)) {
      await evaluate(`document.getElementById('pf-receipt-tab-${id}').click()`);
```

## `scripts/test-home-v5-browser.mjs`
Reason: Faults target the product the real entrance opens directly (as the old card click did), so every failure scenario, including the invalid-index refusal, stays reachable.

Old:
```
const featured = featureIds.find((id) => id !== specimenId && expected[id].ok && records[id].artifacts.some((a) => a.sha256));
```
Replacement:
```
const featured = [specimenId, ...featureIds].find((id) => expected[id].ok && records[id].artifacts.some((a) => a.sha256));
```

## `scripts/test-h7a-design-pilot.ps1`
Reason: Rule moved to product-worlds.css (product styling, not edited here); assert the active rule in source and output and measure it against both actual pane backgrounds, stronger than the obsolete single pair.

Old:
```
Assert-Condition ($experience -match '\.layer-number\{font:9px Consolas,monospace;color:#969eb5;letter-spacing:\.14em\}') 'source: GhostLayer contrast color is corrected'
Assert-Condition ($outputExperience -match '\.layer-number\{font:9px Consolas,monospace;color:#969eb5;letter-spacing:\.14em\}') 'output: GhostLayer contrast color survives build'
Assert-Condition ($layerRatio -ge 4.5) ("WCAG AA: GhostLayer layer number contrast is {0:N2}:1 (>= 4.50:1)" -f $layerRatio)
```
Replacement:
```
# The GhostLayer layer-number rule moved from experience.css to product-worlds.css with new pane colours.
$layerRule = '.product-ghostlayer .layer-number,.product-ghostlayer .layer-state{font:10px var(--pf-mono);color:#bac9cc}'
$worlds = Get-Content (Join-Path $root 'product-worlds.css') -Raw -Encoding UTF8
$outputWorlds = Get-Content (Join-Path $public 'product-worlds.css') -Raw -Encoding UTF8
Assert-Condition ($worlds.Contains($layerRule) -and $experience -notmatch '\.layer-number\{') 'source: GhostLayer layer number has one active colour rule'
Assert-Condition ($outputWorlds.Contains($layerRule)) 'output: GhostLayer layer number colour survives build'
# Panes are #2c3944c9 over a darker page and #34423b; the opaque base is the lower contrast bound.
foreach ($pane in '#2c3944', '#34423b') {
  $ratio = Get-ContrastRatio '#bac9cc' $pane
  Assert-Condition ($ratio -ge 4.5) ("WCAG AA: GhostLayer layer number contrast on {0} is {1:N2}:1 (>= 4.50:1)" -f $pane, $ratio)
}
```

## `scripts/test-h9-homepage.ps1` (navigation parity)
Reason: Home's catalog CTA moved from `ledger-button` to the shared `button button-primary` class; header parity, Support CTA and all nav destinations are still asserted exactly.

Old:
```
$homeHtml -match 'class="ledger-button" href="/software/"' -and $manifest.navCta
```
Replacement:
```
$homeHtml -match 'class="button button-primary" href="/software/"' -and $manifest.navCta
```
