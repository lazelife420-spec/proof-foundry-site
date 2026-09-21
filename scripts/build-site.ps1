# scripts/build-site.ps1 — Manifest-driven static site generator for The Proof Foundry.
#
# Source of truth: site-manifest.json (product identity / status / release facts)
# Shared chrome:    partials/*.html
# Page content:     root *.html files (templates with markers + tokens)
# Output:           public/  (GENERATED — never hand-edit)
#
# Usage:  ./scripts/build-site.ps1
#         ./scripts/build-site.ps1 -ValidateOnly
#
# Markers understood in templates:
#   <!-- @page <id> -->            declares page identity (sets nav active state)
#   <!-- @product <slug> -->       binds this product page to a manifest entry
#   <!-- @include header -->       injects partials/header.html (nav resolved)
#   <!-- @include footer -->       injects partials/footer.html (products resolved)
#   <!-- @products -->             emits one product-card per visible product
#   {{product.<field>}}            bound product fields + computed blocks
#   {{brand}} {{tagline}} {{positioning}}
#
# Computed product tokens:
#   {{product.statusLabel}}   display label from stateLabels[state]
#   {{product.versionLabel}}  "vX.Y.Z" or ""
#   {{product.meta}}          "vX.Y.Z · Platform" or "Platform"
#   {{product.proofStrip}}    full release-status/proof strip (cannot drift from cards)
#   {{product.downloadBlock}} primary CTA (download button or muted "coming soon")
#   {{product.hashBlock}}     SHA-256 code block, or empty
#   {{product.releaseNoteBlock}}  note paragraph, or empty

[CmdletBinding()]
param(
  [switch]$ValidateOnly,
  # Build/validate against an alternate manifest and/or output directory. Lets the
  # invariant tests exercise fixture data without ever writing to the canonical
  # site-manifest.json or the real public/ tree.
  [string]$ManifestPath,
  [string]$OutDir,
  # Alternate products/ module directory (fixtures exercise registry controls
  # — extra/hidden/colliding modules — without touching the canonical tree).
  [string]$ProductsDir,
  # Deterministic source-identity overrides for the public truth outputs. When
  # unset, identity is derived from Git (HEAD commit/tree/commit timestamp +
  # worktree-dirty flag). Tests pass explicit values so fixture builds are
  # byte-reproducible regardless of the surrounding repository state.
  [string]$TruthCommit,
  [string]$TruthTree,
  [string]$TruthCommittedAt,
  # Alternate public-state transport: a JSON document shaped like the future
  # public API response ({ products: [...] }). When set, product state flows
  # through New-FixtureApiProductStateSource instead of the manifest — the
  # adapter seam tests exercise, and the shape a real API source will take.
  [string]$StateSourcePath
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$root = (Resolve-Path "$PSScriptRoot/..").Path
# H13: module registry directory — overridable so fixtures can exercise
# registry controls without mutating the canonical products/ tree.
$script:productsDir = if ($ProductsDir) { (Resolve-Path $ProductsDir).Path } else { Join-Path $root 'products' }
Set-Location $root

$manifestPath = if ($ManifestPath) { (Resolve-Path $ManifestPath).Path } else { Join-Path $root 'site-manifest.json' }
$partialsDir  = Join-Path $root 'partials'
$publicDir    = if ($OutDir) { $OutDir } else { Join-Path $root 'public' }

if (-not (Test-Path $manifestPath)) { throw "site-manifest.json not found at $manifestPath" }
# -Encoding UTF8 is mandatory: site-manifest.json is UTF-8 and contains non-ASCII
# punctuation (middle dot U+00B7, em dash U+2014). Without it, Get-Content falls
# back to the platform default (Windows-1252 on Windows PowerShell), which
# decodes those bytes as mojibake (Â·, â€") into every generated page.
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────
$allowedStates = @('pilot','available','frozen','testing','proof','coming')
$statesRequiringDownload = @('pilot','available','frozen')
$allowedProductStatuses = @('PUBLIC_RELEASE','RELEASE_CANDIDATE','ACTIVE_PROOF','HOLD','FROZEN','RESEARCH','ROADMAP_DIRECTION','UNRELEASED')
$allowedReleaseStatuses = @('PUBLIC_RELEASE','RELEASE_CANDIDATE','ACTIVE_PROOF','HOLD','FROZEN','RESEARCH','ROADMAP_DIRECTION','UNRELEASED')
$allowedVerificationStatuses = @('VERIFIED','PENDING','NOT_PUBLISHED','NOT_VERIFIED')
$allowedVerificationTypes = @('ARTIFACT_HASH_PUBLISHED','ARTIFACT_HASH_VERIFIED','ARTIFACT_CUSTODY','RUNTIME_VALIDATION','REALITY_GATE','PUBLIC_DOWNLOAD','CODE_SIGNING','RELEASE_AUTHORIZATION','PUBLICATION_STATUS')
$allowedSigningStatuses = @('UNSIGNED','DEBUG_SIGNED','PRODUCTION_SIGNED','NOT_APPLICABLE')
$errors = @()

function StateLabel($state) {
  return $manifest.stateLabels.$state
}

$seenIds = @{}
$seenRoutes = @{}
foreach ($p in $manifest.products) {
  $tag = "[$($p.id)]"
  if ([string]::IsNullOrWhiteSpace($p.id)) { $errors += "$tag missing id"; continue }
  if ($seenIds.ContainsKey($p.id)) { $errors += "duplicate product id: $($p.id)" }
  $seenIds[$p.id] = $true

  if ([string]::IsNullOrWhiteSpace($p.name)) { $errors += "$tag missing name" }
  if ([string]::IsNullOrWhiteSpace($p.route)) { $errors += "$tag missing route" }
  else {
    if ($seenRoutes.ContainsKey($p.route)) { $errors += "duplicate route: $($p.route) (id $($p.id))" }
    $seenRoutes[$p.route] = $true
  }

  if (-not ($allowedStates -contains $p.state)) {
    $errors += "$tag unknown state '$($p.state)'. Allowed: $($allowedStates -join ', ')"
  }

  if ($p.visible) {
    if ([string]::IsNullOrWhiteSpace($p.summary)) { $errors += "$tag visible product missing summary" }
    if ([string]::IsNullOrWhiteSpace($p.cta))     { $errors += "$tag visible product missing cta" }
  }

  # Presentation block. These fields drive the homepage card, which is the first
  # and often only thing a visitor reads about a product, so they are validated
  # with the same seriousness as release data rather than treated as decoration.
  if ($p.visible) {
    if (-not $p.presentation) {
      $errors += "$tag visible product missing presentation block (valueLine, cardImage, cardImageAlt, cardCta)"
    } else {
      $pr = $p.presentation
      if ([string]::IsNullOrWhiteSpace($pr.valueLine)) {
        $errors += "$tag presentation.valueLine is empty; the card would render without a value proposition"
      } elseif ($pr.valueLine.Length -gt 150) {
        $errors += "$tag presentation.valueLine is $($pr.valueLine.Length) chars; keep it under 150 so the card stays a card"
      }
      if ([string]::IsNullOrWhiteSpace($pr.cardCta)) {
        $errors += "$tag presentation.cardCta is empty"
      }
      # A card image is a claim that this software exists and looks like this. A
      # broken path would publish an empty frame, so the file must be present.
      if ([string]::IsNullOrWhiteSpace($pr.cardImage)) {
        $errors += "$tag presentation.cardImage is empty; every visible product card shows real product imagery"
      } else {
        if ($pr.cardImage -notlike '/assets/*') {
          $errors += "$tag presentation.cardImage must be a site-absolute /assets/ path: $($pr.cardImage)"
        }
        $imgRel  = $pr.cardImage.TrimStart('/')
        $imgFile = Join-Path $root ($imgRel -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path $imgFile)) {
          $errors += "$tag presentation.cardImage does not exist in the repository: $($pr.cardImage)"
        }
        if ([string]::IsNullOrWhiteSpace($pr.cardImageAlt)) {
          $errors += "$tag presentation.cardImage is set but cardImageAlt is empty; a product screenshot carries meaning and needs a description"
        }
      }
      # A card CTA that says Download/Get must be backed by an actual artifact.
      # This is the card-level equivalent of the existing cta/downloadUrl rule and
      # exists because the card is where a visitor decides whether to trust us.
      if (($pr.cardCta -like 'Download*' -or $pr.cardCta -like 'Get *') -and [string]::IsNullOrWhiteSpace($p.downloadUrl)) {
        $errors += "$tag presentation.cardCta '$($pr.cardCta)' promises a download but downloadUrl is empty"
      }
      if ($pr.cardCta -match '(?i)release candidate' -and $p.release.releaseStatus -ne 'RELEASE_CANDIDATE') {
        $errors += "$tag presentation.cardCta '$($pr.cardCta)' offers a release candidate but releaseStatus is $($p.release.releaseStatus)"
      }
    }
  }

  # Internal route (starts with /) must have a product module products/{id}/module.json
  # (H13: generic renderer + module replaced per-product {id}.html templates)
  if ($p.route -like '/*') {
    $src = Join-Path $script:productsDir "$($p.id)\module.json"
    if (-not (Test-Path $src)) { $errors += "$tag internal route $($p.route) but no module products/$($p.id)/module.json" }
  }

  # Released states must have a download URL
  if ($statesRequiringDownload -contains $p.state) {
    if ([string]::IsNullOrWhiteSpace($p.downloadUrl)) {
      $errors += "$tag state '$($p.state)' requires downloadUrl"
    }
  }

  # Version format if present
  if (-not [string]::IsNullOrWhiteSpace($p.version)) {
    if ($p.version -notmatch '^\d+\.\d+\.\d+$') {
      $errors += "$tag malformed version '$($p.version)' (expected X.Y.Z)"
    }
  }

  # Canonical release schema invariants
  if ($p.release) {
    if (-not $allowedProductStatuses -contains $p.productStatus) {
      $errors += "$tag unknown productStatus '$($p.productStatus)'. Allowed: $($allowedProductStatuses -join ', ')"
    }
    if (-not $allowedReleaseStatuses -contains $p.release.releaseStatus) {
      $errors += "$tag unknown release.releaseStatus '$($p.release.releaseStatus)'. Allowed: $($allowedReleaseStatuses -join ', ')"
    }
    if ($p.release.publicVersion -and $p.release.publicVersion -notmatch '^\d+\.\d+\.\d+$') {
      $errors += "$tag malformed release.publicVersion '$($p.release.publicVersion)'"
    }
    if ($p.release.candidateVersion -and $p.release.candidateVersion -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9._]+)?$') {
      $errors += "$tag malformed release.candidateVersion '$($p.release.candidateVersion)'"
    }
    if ($p.release.companionPublicVersion -and $p.release.companionPublicVersion -notmatch '^\d+\.\d+\.\d+$') {
      $errors += "$tag malformed release.companionPublicVersion '$($p.release.companionPublicVersion)'"
    }
    if ($p.release.publishedAt -and $p.release.publishedAt -notmatch '^\d{4}-\d{2}-\d{2}$') {
      $errors += "$tag malformed release.publishedAt '$($p.release.publishedAt)' (expected YYYY-MM-DD)"
    }
    if ($p.release.companionCandidateVersion -and $p.release.companionCandidateVersion -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9._]+)?$') {
      $errors += "$tag malformed release.companionCandidateVersion '$($p.release.companionCandidateVersion)'"
    }
    if ($p.release.sourceCommit -and $p.release.sourceCommit -notmatch '^[0-9a-f]{40}$') {
      $errors += "$tag malformed release.sourceCommit '$($p.release.sourceCommit)' (expected 40 lowercase hex chars)"
    }
    if ($p.packageId -and $p.packageId -notmatch '^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$') {
      $errors += "$tag malformed packageId '$($p.packageId)' (expected reverse-domain id like com.example.app)"
    }

    # PUBLIC_RELEASE must have public version and at least one downloadable artifact
    if ($p.release.releaseStatus -eq 'PUBLIC_RELEASE') {
      if ([string]::IsNullOrWhiteSpace($p.release.publicVersion)) {
        $errors += "$tag releaseStatus PUBLIC_RELEASE but release.publicVersion is empty"
      }
      if (-not $p.artifacts -or $p.artifacts.Count -eq 0) {
        if ($p.state -ne 'pilot') { $errors += "$tag releaseStatus PUBLIC_RELEASE but no artifacts listed" }
      }
    }

    # Candidate must not silently replace public version
    if ($p.release.candidateVersion -and $p.release.publicVersion -and $p.release.candidateVersion -eq $p.release.publicVersion) {
      $errors += "$tag candidateVersion equals publicVersion ($($p.release.publicVersion)); must not silently replace public version"
    }
  }

  # Legacy display-node digest. This field is rendered on product pages via
  # {{product.sha256}} and is the hashBlock fallback, so it is canonical rendered
  # truth and obeys the same representation rule as artifact digests.
  if ($p.sha256) {
    if ($p.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
      $errors += "$tag sha256 must be exactly 64 hex chars: '$($p.sha256)'"
    } elseif ($p.sha256 -cnotmatch '^[0-9a-f]{64}$') {
      $errors += "$tag sha256 must be lowercase hex (canonical representation): '$($p.sha256)'"
    }
  }

  # Artifact invariants
  if ($p.artifacts) {
    $aIndex = 0
    foreach ($a in $p.artifacts) {
      $aTag = "$tag artifact[$aIndex]"
      if ($a.sha256) {
        # Lowercase is the canonical representation. Hex is case-insensitive as a
        # value, so uppercase would still be the same digest — but it defeats
        # string comparison against sha256sum/Get-FileHash output and against the
        # JSON registry, so it is rejected rather than silently accepted.
        if ($a.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
          $errors += "$aTag sha256 must be exactly 64 hex chars: '$($a.sha256)'"
        } elseif ($a.sha256 -cnotmatch '^[0-9a-f]{64}$') {
          $errors += "$aTag sha256 must be lowercase hex (canonical representation): '$($a.sha256)'"
        }
      }
      if ($a.downloadUrl) {
        if ($a.downloadUrl -match '^(file|localhost|127\.0\.0\.1|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
          $errors += "$aTag downloadUrl is not a public first-party URL: $($a.downloadUrl)"
        }
      }
      if ($a.signingStatus -and -not ($allowedSigningStatuses -contains $a.signingStatus)) {
        $errors += "$aTag unknown signingStatus '$($a.signingStatus)'"
      }
      $aIndex++
    }
  }

  # Version-literal drift: artifact filenames and URLs embed the version as a
  # literal (…/v1.1.0/Reality-Gate-1.1.0-….zip), independently of
  # release.publicVersion. Without this check, bumping publicVersion while leaving
  # the artifact URLs on the previous build would render a new version number next
  # to a download link and checksum for the old one, and nothing would fail.
  if ($p.artifacts) {
    $declaredVersions = @(
      $p.release.publicVersion, $p.release.candidateVersion,
      $p.release.companionPublicVersion,
      $p.companionVersion, $p.currentLocalVersion, $p.version
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    # A pre-release candidateVersion like "0.2.3-rc1" also declares its base
    # semver "0.2.3", which appears in artifact filenames and URLs.
    $baseSemvers = @($declaredVersions | ForEach-Object {
      if ($_ -match '^(\d+\.\d+\.\d+)-') { $Matches[1] }
    }) | Where-Object { $_ }
    $declaredVersions = @($declaredVersions + $baseSemvers) | Select-Object -Unique
    # Versions a PUBLIC_RELEASE artifact is allowed to advertise. A candidate-only
    # version must never appear on something the public can download.
    $publicVersions = @($p.release.publicVersion, $p.release.companionPublicVersion, $p.companionVersion) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $aIndex = 0
    foreach ($a in $p.artifacts) {
      $aTag = "$tag artifact[$aIndex]"
      $blob = "$($a.filename) $($a.downloadUrl) $($a.sha256Url)"
      $embedded = @([regex]::Matches($blob, '(?<![\d.])(\d+\.\d+\.\d+)(?![\d.])') |
                    ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      foreach ($v in $embedded) {
        if ($declaredVersions -notcontains $v) {
          $errors += "$aTag embeds version $v which $($p.id) does not declare (declared: $($declaredVersions -join ', '))"
        }
      }
      if ($a.downloadUrl -and $p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE' -and $embedded.Count -gt 0) {
        $nonPublic = @($embedded | Where-Object { $publicVersions -notcontains $_ })
        if ($nonPublic.Count -gt 0) {
          $errors += "$aTag is publicly downloadable under PUBLIC_RELEASE but advertises non-public version(s) $($nonPublic -join ', ') (public: $($publicVersions -join ', '))"
        }
      }
      $aIndex++
    }
  }

  # Verification invariants
  if ($p.verification) {
    if (-not ($allowedVerificationStatuses -contains $p.verification.status)) {
      $errors += "$tag unknown verification.status '$($p.verification.status)'"
    }
    if ($p.verification.verifiedAt -and $p.verification.verifiedAt -notmatch '^\d{4}-\d{2}-\d{2}$') {
      $errors += "$tag malformed verification.verifiedAt '$($p.verification.verifiedAt)'"
    }
    if ($p.verification.verificationType) {
      foreach ($vt in $p.verification.verificationType) {
        if (-not ($allowedVerificationTypes -contains $vt)) {
          $errors += "$tag unknown verificationType '$vt'"
        }
      }
    }
    if ($p.verification.status -eq 'VERIFIED' -and -not $p.verification.verifiedAt) {
      $errors += "$tag verification.status VERIFIED but verifiedAt missing"
    }
  }

  # Privacy / leak checks on canonical and legacy fields
  $leakTargets = @($p.downloadUrl, $p.sha256Url, $p.releaseNote, $p.build)
  if ($p.artifacts) { foreach ($a in $p.artifacts) { $leakTargets += @($a.downloadUrl, $a.sha256Url, $a.filename) } }
  if ($p.evidence) { foreach ($e in $p.evidence) { $leakTargets += $e.url } }
  foreach ($lt in $leakTargets) {
    if ($lt -and ($lt -match 'C:\\Users\\' -or $lt -match '\\\\[^\\]+\\' -or $lt -match 'bearer\s+' -or $lt -match 'token=|api[_-]?key' -or $lt -match '^file://' -or $lt -match '^http://localhost' -or $lt -match '127\.0\.0\.1' -or $lt -match '\.r2\.dev')) {
      # r2.dev is allowed only if explicitly documented as a staging/diagnostic path; canonical public metadata should prefer downloads.theprooffoundry.com
      if ($lt -match '\.r2\.dev') {
        $errors += "$tag canonical public URL still uses raw .r2.dev provider: $lt"
      } elseif ($lt -match 'C:\\Users\\|\\\\[^\\]+\\|bearer\s+|token=|api[_-]?key|^file://|^http://localhost|127\.0\.0\.1') {
        $errors += "$tag potential private path/secret in public data: $lt"
      }
    }
  }

  # CTA must not promise a download when no artifact exists
  if ($p.cta -like 'Download*' -and [string]::IsNullOrWhiteSpace($p.downloadUrl)) {
    $errors += "$tag cta says Download but downloadUrl is empty"
  }

  # A download label must name the version of the artifact it downloads. For a
  # release candidate, that is the candidate version rather than the last public
  # release shown in the state line.
  $canonicalDownloadVersion = if ($p.release -and $p.release.releaseStatus -eq 'RELEASE_CANDIDATE' -and $p.release.candidateVersion) {
    $p.release.candidateVersion
  } elseif ($p.release -and $p.release.publicVersion) {
    $p.release.publicVersion
  } else {
    $p.version
  }
  if ($p.downloadLabel -like 'Download*' -and -not [string]::IsNullOrWhiteSpace($canonicalDownloadVersion)) {
    if ($p.downloadLabel -notlike "*$canonicalDownloadVersion*") {
      $errors += "$tag downloadLabel '$($p.downloadLabel)' omits canonical download version $canonicalDownloadVersion"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($p.downloadLabel) -and [string]::IsNullOrWhiteSpace($p.downloadUrl)) {
    $errors += "$tag downloadLabel set but downloadUrl is empty"
  }
}

# Visitor-facing presentation guards. The availability taxonomy must label every
# derived availability, and every visible product must land in exactly one
# homepage group. Without this a new release state could silently drop a product
# off the homepage, show it twice, or blank its badge — and still report success.
# Availability is derived inline here (the shared helpers are defined later in
# the file) and must stay in sync with VisitorAvailability(): a product is
# AVAILABLE when a public release exists, regardless of its newest build lane.
$visibleProducts = @($manifest.products | Where-Object { $_.visible })
foreach ($p in $visibleProducts) {
  $rs = if ($p.release -and $p.release.releaseStatus) { $p.release.releaseStatus } else { '' }
  if ([string]::IsNullOrWhiteSpace($rs)) {
    $errors += "[$($p.id)] visible product has no release.releaseStatus, so no card state layer can be derived"
    continue
  }
  $pubVersion = if ($p.release -and $p.release.publicVersion) { "$($p.release.publicVersion)" } else { '' }
  $avail = if (-not [string]::IsNullOrWhiteSpace($pubVersion)) { 'AVAILABLE' } else { 'NO_PUBLIC_RELEASE' }
  if (-not $manifest.availabilityTaxonomy -or -not $manifest.availabilityTaxonomy.labels.$avail) {
    $errors += "[$($p.id)] derived availability '$avail' has no availabilityTaxonomy label; the card badge would render blank"
  }
  $matchingGroups = @($manifest.productGroups | Where-Object { $_.availability -contains $avail })
  if ($matchingGroups.Count -eq 0) {
    $errors += "[$($p.id)] availability '$avail' matches no productGroups entry; the product would vanish from the homepage"
  } elseif ($matchingGroups.Count -gt 1) {
    $errors += "[$($p.id)] availability '$avail' matches $($matchingGroups.Count) productGroups ($($matchingGroups.id -join ', ')); it would be listed more than once"
  }

  # A card CTA that names a version must name a version the manifest actually
  # authorizes for this product — never an invented or stale number.
  $ctaText = if ($p.presentation -and $p.presentation.cardCta) { $p.presentation.cardCta } else { '' }
  if ($ctaText -match 'v(\d[\w.\-]*)') {
    $ctaVersion = $Matches[1]
    $authorized = @()
    if ($p.release -and $p.release.publicVersion)   { $authorized += $p.release.publicVersion }
    if ($p.release -and $p.release.candidateVersion) { $authorized += $p.release.candidateVersion }
    if ($authorized -notcontains $ctaVersion) {
      $errors += "[$($p.id)] cardCta names version v$ctaVersion but the manifest authorizes only: $($authorized -join ', ')"
    }
  }

  # The card CTA deep-links into a section of the product page. A missing anchor
  # would land the visitor at the top of the page with no explanation, so the
  # target section must actually exist in that product's template.
  $anchor = if (-not [string]::IsNullOrWhiteSpace($p.downloadUrl)) { 'download' } else { 'release-status' }
  $tplPath = Join-Path $root ("$($p.id).html")
  if (Test-Path $tplPath) {
    $tplBody = [System.IO.File]::ReadAllText($tplPath)
    if ($tplBody -notmatch ('id\s*=\s*"' + [regex]::Escape($anchor) + '"')) {
      $errors += "[$($p.id)] card CTA targets #$anchor but $($p.id).html has no element with id=`"$anchor`""
    }
  }
}
if (-not $manifest.trustStrip -or @($manifest.trustStrip).Count -eq 0) {
  $errors += "[trustStrip] missing or empty; the homepage trust strip would render as an empty row"
} else {
  $tsIndex = 0
  foreach ($ts in @($manifest.trustStrip)) {
    if ([string]::IsNullOrWhiteSpace($ts.label)) { $errors += "[trustStrip[$tsIndex]] missing label" }
    if ([string]::IsNullOrWhiteSpace($ts.note))  { $errors += "[trustStrip[$tsIndex]] missing note" }
    $tsIndex++
  }
}

# Site verification receipt must exist and be self-consistent. The receipt is
# linked from /proof/ as public evidence, so a missing file would publish a dead
# evidence link — and the file it points at must be present in a fresh checkout,
# not merely on the machine that happens to have built the site.
if ($manifest.siteVerification) {
  $sv = $manifest.siteVerification
  if ([string]::IsNullOrWhiteSpace($sv.receiptPath)) {
    $errors += "[siteVerification] receiptPath is empty"
  } else {
    if ($sv.receiptPath -notlike '/*') {
      $errors += "[siteVerification] receiptPath must be a site-absolute path: $($sv.receiptPath)"
    }
    $receiptRel  = $sv.receiptPath.TrimStart('/')
    $receiptFile = Join-Path $root ($receiptRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $receiptFile)) {
      $errors += "[siteVerification] receiptPath does not exist in the repository: $($sv.receiptPath)"
    } else {
      # Existing on the machine that happens to be building is not sufficient.
      # /proof/ links this file as public evidence, so it must survive a fresh
      # clone; only git can answer that. Repo location is discovered, never
      # hardcoded, so this works in any checkout or CI workspace.
      $gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $gitCmd) {
        $errors += "[siteVerification] cannot prove receipt '$($sv.receiptPath)' is tracked: git executable not found on PATH. Public evidence must be provably committed, so this is treated as a failure rather than assumed valid."
      } else {
        $null = & $gitCmd.Source -C $root rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -ne 0) {
          $errors += "[siteVerification] cannot prove receipt '$($sv.receiptPath)' is tracked: '$root' is not inside a git work tree. Public evidence must be provably committed, so this is treated as a failure rather than assumed valid."
        } else {
          $null = & $gitCmd.Source -C $root ls-files --error-unmatch -- $receiptRel 2>$null
          if ($LASTEXITCODE -ne 0) {
            $errors += "[siteVerification] receipt '$($sv.receiptPath)' exists locally but is NOT tracked by git; a fresh clone would publish a dead evidence link. Fix with: git add $receiptRel"
          }
        }
      }
    }
  }
  if ([string]::IsNullOrWhiteSpace($sv.receiptDate)) {
    $errors += "[siteVerification] receiptDate is empty"
  } elseif ($sv.receiptDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    $errors += "[siteVerification] malformed receiptDate '$($sv.receiptDate)' (expected YYYY-MM-DD)"
  } elseif ($sv.receiptPath -and $sv.receiptPath -notlike "*$($sv.receiptDate)*") {
    $errors += "[siteVerification] receiptDate $($sv.receiptDate) does not match receiptPath $($sv.receiptPath)"
  }
}

# Live templates must not carry canonical artifact digests as literals. A digest
# duplicated into HTML is a second source of truth: bumping the manifest would
# leave the page advertising the previous build's checksum, and nothing would
# fail. Only literals that *equal a canonical digest* are rejected — an
# illustrative hash in a documentation code sample is not canonical truth and is
# therefore untouched by this rule, with no filename or hash exemption list to
# maintain.
$canonicalDigests = @{}
foreach ($p in $manifest.products) {
  if ($p.sha256) { $canonicalDigests[$p.sha256.ToLowerInvariant()] = "$($p.id) display node" }
  if ($p.artifacts) {
    $ai = 0
    foreach ($a in @($p.artifacts)) {
      if ($a.sha256) {
        $label = "$($p.id) artifact[$ai]"
        if ($a.filename) { $label += " ($($a.filename))" }
        $canonicalDigests[$a.sha256.ToLowerInvariant()] = $label
        # Record the token that should be used instead.
        $canonicalDigests["token:$($a.sha256.ToLowerInvariant())"] = "{{product.artifacts.$ai.sha256}}"
      }
      $ai++
    }
  }
}
# H13: templates now live as root *.html plus products/<id>/content.html slots.
$templateFiles = @(Get-ChildItem -Path $root -Filter '*.html' -File | ForEach-Object { @{ File = $_; Label = $_.Name } })
$templateFiles += @(Get-ChildItem -Path $script:productsDir -Filter 'content.html' -Recurse -File | ForEach-Object { @{ File = $_; Label = "products/$($_.Directory.Name)/content.html" } })
foreach ($tpl in $templateFiles) {
  $tplText = [System.IO.File]::ReadAllText($tpl.File.FullName)
  foreach ($m in [regex]::Matches($tplText, '(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])')) {
    $key = $m.Value.ToLowerInvariant()
    if ($canonicalDigests.ContainsKey($key)) {
      $useToken = if ($canonicalDigests.ContainsKey("token:$key")) { $canonicalDigests["token:$key"] } else { '{{product.artifactSha256}}' }
      $errors += "[template] $($tpl.Label) hardcodes the canonical SHA-256 of $($canonicalDigests[$key]); replace the literal with $useToken so the digest cannot drift from the manifest"
    }
  }
}

# Canonical literal guard (H10): URLs, artifact filenames and receipt ids that are
# manifest-owned must not be retyped in templates — a stale copy is exactly the
# failure mode H10 exists to prevent. Report the token that should be used.
$canonicalLiterals = @{}
foreach ($p in $manifest.products) {
  $litTag = "$($p.id)"
  if ($p.downloadUrl) { $canonicalLiterals[$p.downloadUrl] = "$litTag product downloadUrl" }
  if ($p.sha256Url)   { $canonicalLiterals[$p.sha256Url]   = "$litTag product sha256Url" }
  if ($p.verification -and $p.verification.receiptId) { $canonicalLiterals[$p.verification.receiptId] = "$litTag verification.receiptId" }
  if ($p.release -and $p.release.sourceCommit) { $canonicalLiterals[$p.release.sourceCommit] = "$litTag release.sourceCommit" }
  if ($p.packageId) { $canonicalLiterals[$p.packageId] = "$litTag packageId" }
  $ai = 0
  foreach ($a in @($p.artifacts)) {
    if ($a.filename)    { $canonicalLiterals[$a.filename]    = "$litTag artifact[$ai] filename" }
    if ($a.downloadUrl) { $canonicalLiterals[$a.downloadUrl] = "$litTag artifact[$ai] downloadUrl" }
    if ($a.sha256Url)   { $canonicalLiterals[$a.sha256Url]   = "$litTag artifact[$ai] sha256Url" }
    $ai++
  }
  $pi = 0
  foreach ($u in @($p.proofLinks)) { if ($u) { $canonicalLiterals[$u] = "$litTag proofLinks[$pi]" }; $pi++ }
  if ($p.evidence -is [array]) { $ei = 0; foreach ($e in $p.evidence) { if ($e.url) { $canonicalLiterals[$e.url] = "$litTag evidence[$ei].url" }; $ei++ } }
}
foreach ($tpl in $templateFiles) {
  $tplText = [System.IO.File]::ReadAllText($tpl.File.FullName)
  foreach ($lit in $canonicalLiterals.Keys) {
    if ($tplText.Contains($lit)) {
      $errors += "[template] $($tpl.Label) hardcodes canonical literal '$lit' ($($canonicalLiterals[$lit])); render it through the matching product token instead so it cannot drift from the manifest"
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "==> MANIFEST VALIDATION FAILED" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "==> Manifest validated: $($manifest.products.Count) products, $($errors.Count) errors" -ForegroundColor Green

if ($ValidateOnly) { exit 0 }

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Read-File($path) { return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }

function VersionLabel($p) {
  # Prefer canonical release.publicVersion, then legacy publicVersion, then version.
  $v = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion }
       elseif (-not [string]::IsNullOrWhiteSpace($p.publicVersion)) { $p.publicVersion }
       elseif (-not [string]::IsNullOrWhiteSpace($p.version))      { $p.version }
       else { return '' }
  return "v$v"
}

function CandidateVersionLabel($p) {
  if ($p.release -and $p.release.candidateVersion) { return "v$($p.release.candidateVersion)" }
  if (-not [string]::IsNullOrWhiteSpace($p.currentLocalVersion)) { return "v$($p.currentLocalVersion)" }
  return ''
}

function CurrentVersionLabel($p) {
  if ([string]::IsNullOrWhiteSpace($p.currentLocalVersion)) { return '' }
  return "Local v$($p.currentLocalVersion)"
}

function CompanionLabel($p) {
  if ([string]::IsNullOrWhiteSpace($p.companionVersion)) { return '' }
  return "Companion v$($p.companionVersion)"
}

function CompanionPublicVersionLabel($p) {
  if ($p.release -and $p.release.companionPublicVersion) { return "v$($p.release.companionPublicVersion)" }
  return ''
}

function PlatformLabel($p) {
  # Prefer the platforms array; fall back to the legacy string field.
  if ($p.platforms -is [array] -and $p.platforms.Count -gt 0) {
    return ($p.platforms -join ' + ')
  }
  if (-not [string]::IsNullOrWhiteSpace($p.platform)) {
    return $p.platform
  }
  return ''
}

function TestStatusLabel($p) {
  # testStatus is the canonical field; fall back to testCount for backward compat.
  if (-not [string]::IsNullOrWhiteSpace($p.testStatus)) { return $p.testStatus }
  if (-not [string]::IsNullOrWhiteSpace($p.testCount))  { return $p.testCount }
  return ''
}

function MetaLine($p) {
  $parts = @()
  $vl = VersionLabel $p
  if ($vl) { $parts += $vl }
  $pl = PlatformLabel $p
  if ($pl) { $parts += $pl }
  $dot = [char]0x00B7
  return ($parts -join " $dot ")
}

function StatusLine($p) {
  $parts = @()
  $status = if ($p.productStatus -and $manifest.statusTaxonomy.$($p.productStatus)) {
    $manifest.statusTaxonomy.$($p.productStatus)
  } else {
    StateLabel $p.state
  }
  if ($status) { $parts += $status }

  $public = VersionLabel $p
  $candidate = CandidateVersionLabel $p
  if (-not $public -and $candidate -and $p.release -and $p.release.releaseStatus -eq 'UNRELEASED') {
    $parts += "no public release"
    $parts += "engine $candidate"
  } elseif ($public -and $candidate -and $public -ne $candidate) {
    $parts += "public $public"
    if ($p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE') {
      $parts += "next $candidate"
    } else {
      $parts += "candidate $candidate"
    }
  } elseif ($public) {
    $parts += $public
  } elseif ($candidate) {
    $parts += $candidate
  }

  $platform = PlatformLabel $p
  if ($platform) { $parts += $platform }
  $dot = [char]0x00B7
  return ($parts -join " $dot ")
}

# Attribute-safe escaping (& < > " ') — also correct for text nodes: entities
# decode to the literal characters in every HTML context.
function Html-Attr($s) { return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;' -replace "'",'&#39;') }

# Public-state URL policy: the only URL shapes allowed to cross into public
# surfaces are site-relative paths and https:// absolute URLs on public hosts.
# Everything else (javascript:, data:, file:, vbscript:, about:, blob:,
# filesystem:, loopback/RFC1918 hosts) is rejected as invalid public state
# BEFORE it can reach an href/src, truth JSON, or metadata surface.
function Test-PublicUrlSafe($url, $what) {
  if ([string]::IsNullOrWhiteSpace($url)) { return }
  if ($url -match '^/') { return }
  if ($url -match '^https://') {
    $h = ([uri]$url).Host
    if ($h -match '^(localhost|127\.|0\.0\.0\.0|\[?::1\]?$|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -or $h -match '^(::1|0:0:0:0:0:0:0:1)$') {
      throw "$what`: unsafe host in public URL state: $url"
    }
    return
  }
  throw "$what`: unsafe scheme in public URL state: $url"
}

# Applies the URL policy to every URL-bearing field of adapter-produced
# product state — the boundary is the adapter output, so any future
# non-manifest source is held to the same contract.
function Assert-PublicStateUrls($products) {
  foreach ($p in @($products)) {
    $tag = "product '$($p.id)'"
    foreach ($u in @($p.downloadUrl, $p.sha256Url)) { Test-PublicUrlSafe $u $tag }
    foreach ($a in @($p.artifacts)) { if ($a) { foreach ($u in @($a.url, $a.downloadUrl, $a.sha256Url)) { Test-PublicUrlSafe $u "$tag artifact" } } }
    foreach ($e in @($p.evidence)) { if ($e) { Test-PublicUrlSafe $e.url "$tag evidence" } }
    foreach ($l in @($p.proofLinks)) { Test-PublicUrlSafe $l "$tag proofLinks" }
    if ($p.verification) { Test-PublicUrlSafe $p.verification.receiptUrl "$tag verification" }
    if ($p.presentation) { Test-PublicUrlSafe $p.presentation.cardImage "$tag cardImage" }
  }
}

# ── Visitor-facing presentation ──────────────────────────────────────────────
# Two distinct concepts live here and must never be conflated:
#
#   Availability — does a public release of the PRODUCT exist? Derived from
#   release.publicVersion, not from the newest build lane. Lights Out has a
#   public v11.1.2, so it is Available even though its v11.1.3 candidate is on
#   hold; calling it "in the foundry" would erase a real release.
#
#   Development lane — what releaseStatus says the newest build is doing. That
#   is engineering truth and stays on the card as a second state layer, not as
#   a mutually exclusive homepage bucket.

function VisitorAvailability($p) {
  $pub = if ($p.release) { $p.release.publicVersion } else { $null }
  if (-not [string]::IsNullOrWhiteSpace("$pub")) { return 'AVAILABLE' }
  return 'NO_PUBLIC_RELEASE'
}

function VisitorAvailabilityLabel($p) {
  $a = VisitorAvailability $p
  if ($manifest.availabilityTaxonomy -and $manifest.availabilityTaxonomy.labels.$a) { return $manifest.availabilityTaxonomy.labels.$a }
  return $a
}

function VisitorAvailabilitySlug($p) {
  $label = VisitorAvailabilityLabel $p
  return ($label.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-')
}

function ProductGroupId($p) {
  $a = VisitorAvailability $p
  foreach ($g in @($manifest.productGroups)) {
    if ($g.availability -contains $a) { return $g.id }
  }
  return ''
}

# Cards lead with the public version. Candidate state is a separate detail.
# Distribution observations never change canonical release classifications.
function CardVersionLabel($p) {
  if ($p.id -eq 'lights-out') { return "$(VersionLabel $p) (Windows)" }
  return (VersionLabel $p)
}

# The card's second state layer: what the newest build lane is doing, stated
# without erasing the public release named above it. The separator is spelled as
# a char literal, not a raw middle dot: this script must survive being read as
# Windows-1252 by Windows PowerShell 5.1, and a literal UTF-8 dot in source
# would otherwise emit mojibake into the page.
function CardDetailLine($p) {
  $rs   = if ($p.release -and $p.release.releaseStatus) { $p.release.releaseStatus } else { '' }
  $pub  = if ($p.release -and $p.release.publicVersion) { "v$($p.release.publicVersion)" } else { '' }
  $cand = if ($p.release -and $p.release.candidateVersion) { "v$($p.release.candidateVersion)" } else { '' }
  $dot  = [char]0x00B7

  switch ($rs) {
    'RELEASE_CANDIDATE' {
      if ($pub) {
        if ($p.presentation.downloadUnavailable) { return "Candidate $cand $dot downloads currently unavailable" }
        return "Candidate $cand available $dot public release remains $pub"
      }
      if ($cand) { return "Release candidate $cand" }
      return ''
    }
    'HOLD' {
      if ($p.id -eq 'lights-out' -and $p.release.companionPublicVersion) {
        return "Android companion public v$($p.release.companionPublicVersion) $dot Windows and Android $cand candidates on hold $dot public downloads currently unavailable"
      }
      if ($cand) { return "Candidate $cand on hold $dot public download currently unavailable" }
      return ''
    }
    'ACTIVE_PROOF' {
      if ($cand) { return "$cand candidate in proof" }
      return ''
    }
    'PUBLIC_RELEASE' {
      if ($cand -and (!$pub -or "v$cand" -ne $pub)) { return "Next build $cand in progress" }
      return ''
    }
    'FROZEN' {
      if ($cand -and (!$pub -or "v$cand" -ne $pub)) { return "Next build $cand in progress" }
      return ''
    }
    'UNRELEASED' {
      if ($cand) { return "Engine $cand $dot not yet packaged under this name" }
      return 'No public release yet'
    }
    default { return '' }
  }
}

function CardCtaHref($p) {
  $anchor = if (-not [string]::IsNullOrWhiteSpace($p.downloadUrl)) { 'download' } else { 'release-status' }
  return "$($p.route)#$anchor"
}

# The card's secondary action points into the receipts page rather than a
# per-product proof section, because the receipt anchor is generated for every
# visible product by Build-ReceiptCards and therefore cannot dead-end. Product
# pages use different local section names for their proof content.
function CardProofHref($p) {
  return "$($manifest.proofRegistryPath -replace 'index\.json$','')#receipt-$($p.id)"
}

function IsExternalUrl($url) {
  return $url -like 'http://*' -or $url -like 'https://*'
}

# ISO date (YYYY-MM-DD) to the site's long display form ("17 September 2026").
function IsoDateLabel([string]$iso) {
  if ([string]::IsNullOrWhiteSpace($iso)) { return '' }
  return [datetime]::ParseExact($iso, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
}
function IsFileDownload($url) {
  return $url -like '*.zip' -or $url -like '*.exe' -or $url -like '*.apk'
}

# Resolve computed blocks for a product from canonical data (release/artifacts/verification)
function ProductTokens($p) {
  $tokens = @{}
  $tokens['id']                  = $p.id
  $tokens['name']                = $p.name
  $tokens['displayName']         = $p.displayName
  # Homepage-facing short label (H2 naming consistency); canonical name stays authoritative elsewhere.
  $tokens['homeName']            = if ($p.homeName) { $p.homeName } else { $p.name }
  $tokens['route']               = $p.route
  $tokens['state']               = $p.state
  $tokens['statusLabel']         = StateLabel $p.state
  $tokens['productStatus']       = if ($p.productStatus) { $p.productStatus } else { '' }
  $tokens['productStatusLabel']  = if ($p.productStatus -and $manifest.statusTaxonomy.$($p.productStatus)) { $manifest.statusTaxonomy.$($p.productStatus) } else { $tokens['statusLabel'] }
  $tokens['versionLabel']        = VersionLabel $p
  $tokens['candidateVersionLabel'] = CandidateVersionLabel $p
  $tokens['currentVersionLabel'] = CurrentVersionLabel $p
  $tokens['companionLabel']      = CompanionLabel $p
  $tokens['companionPublicVersionLabel'] = CompanionPublicVersionLabel $p
  # H10 public-truth tokens — narrow fields and derivations for current-state facts.
  $tokens['companionVersion']    = if ($p.companionVersion) { $p.companionVersion } else { '' }
  $tokens['companionCandidateVersion'] = if ($p.release -and $p.release.companionCandidateVersion) { $p.release.companionCandidateVersion } else { '' }
  $tokens['companionCandidateVersionLabel'] = if ($tokens['companionCandidateVersion']) { "v$($tokens['companionCandidateVersion'])" } else { '' }
  $tokens['sourceCommit']        = if ($p.release -and $p.release.sourceCommit) { $p.release.sourceCommit } else { '' }
  $tokens['receiptId']           = if ($p.verification -and $p.verification.receiptId) { $p.verification.receiptId } else { '' }
  $tokens['packageId']           = if ($p.packageId) { $p.packageId } else { '' }
  $tokens['publishedAtLabel']    = IsoDateLabel $p.release.publishedAt
  $tokens['checkedAtLabel']      = if ($p.verification -and $p.verification.checkedAt) { IsoDateLabel $p.verification.checkedAt } else { '' }
  $tokens['version']             = $p.version
  $tokens['meta']                = MetaLine $p
  $tokens['statusLine']          = StatusLine $p
  $tokens['visitorStatusLabel']  = VisitorAvailabilityLabel $p
  $tokens['visitorStatusSlug']   = VisitorAvailabilitySlug $p
  $tokens['groupId']             = ProductGroupId $p
  $tokens['cardVersionLabel']    = CardVersionLabel $p
  $tokens['cardDetailLine']      = CardDetailLine $p
  $tokens['cardCtaHref']         = CardCtaHref $p
  $tokens['cardProofHref']       = CardProofHref $p
  $tokens['valueLine']           = if ($p.presentation -and $p.presentation.valueLine) { $p.presentation.valueLine } else { $p.cardSummary }
  $tokens['cardImage']           = if ($p.presentation) { $p.presentation.cardImage } else { '' }
  $tokens['cardImageWidth']      = if ($p.presentation) { $p.presentation.cardImageWidth } else { '' }
  $tokens['cardImageHeight']     = if ($p.presentation) { $p.presentation.cardImageHeight } else { '' }
  $tokens['cardImageAlt']        = if ($p.presentation) { $p.presentation.cardImageAlt } else { '' }
  $tokens['cardCta']             = if ($p.presentation -and $p.presentation.cardCta) { $p.presentation.cardCta } else { $p.cta }
  $tokens['platform']            = PlatformLabel $p
  $tokens['summary']             = $p.summary
  $tokens['cardSummary']         = if (-not [string]::IsNullOrWhiteSpace($p.cardSummary)) { $p.cardSummary } else { $p.summary }
  $tokens['markSvg']             = if (-not [string]::IsNullOrWhiteSpace($p.markSvg)) { $p.markSvg } else { '' }
  $tokens['cta']                 = $p.cta
  $tokens['distType']            = $p.distType
  $tokens['build']               = $p.build
  $tokens['testStatus']          = TestStatusLabel $p
  $tokens['testCount']           = $p.testCount
  $tokens['proofStatus']         = $p.proofStatus
  $tokens['lastVerified']        = if ($p.verification -and $p.verification.verifiedAt) { $p.verification.verifiedAt } else { $p.lastVerified }
  $tokens['downloadUrl']         = $p.downloadUrl
  $tokens['downloadLabel']       = $p.downloadLabel
  $tokens['sha256']              = $p.sha256
  $tokens['sha256Url']           = $p.sha256Url
  $tokens['releaseNote']         = $p.releaseNote

  # Canonical release / artifact / verification derived tokens
  $pubVer = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { if ($p.version) { $p.version } else { '' } }
  $canVer = if ($p.release -and $p.release.candidateVersion) { $p.release.candidateVersion } else { if ($p.currentLocalVersion) { $p.currentLocalVersion } else { '' } }
  $tokens['publicVersion']       = $pubVer
  $tokens['candidateVersion']    = $canVer
  $tokens['releaseStatus']       = if ($p.release -and $p.release.releaseStatus) { $p.release.releaseStatus } else { '' }
  $tokens['publishedAt']         = if ($p.release -and $p.release.publishedAt) { $p.release.publishedAt } else { '' }
  $tokens['verificationStatus']  = if ($p.verification -and $p.verification.status) { $p.verification.status } else { 'PENDING' }

  # Primary artifact for product-page display (first downloadable artifact, or first artifact)
  $primaryArtifact = $null
  if ($p.artifacts) {
    foreach ($a in $p.artifacts) { if (-not [string]::IsNullOrWhiteSpace($a.downloadUrl) -or $a.sha256) { $primaryArtifact = $a; break } }
  }
  $tokens['artifactFilename']    = if ($primaryArtifact) { $primaryArtifact.filename } else { '' }
  $tokens['artifactSha256']      = if ($primaryArtifact) { $primaryArtifact.sha256 } else { if ($p.sha256) { $p.sha256 } else { '' } }
  $tokens['artifactDownloadUrl'] = if ($primaryArtifact) { $primaryArtifact.downloadUrl } else { if ($p.downloadUrl) { $p.downloadUrl } else { '' } }
  $tokens['artifactSha256Url']   = if ($primaryArtifact) { $primaryArtifact.sha256Url } else { if ($p.sha256Url) { $p.sha256Url } else { '' } }
  $tokens['artifactSigningStatus'] = if ($primaryArtifact -and $primaryArtifact.signingStatus) { $primaryArtifact.signingStatus } else { 'UNSIGNED' }

  # Artifact-indexed tokens: {{product.artifacts.N.sha256}} and friends.
  # The unqualified artifact* tokens above resolve to the *primary* artifact, so a
  # page that means "the proof bundle" or "the Android companion" cannot express
  # that with them — it would silently bind the desktop build's digest instead.
  # Indexes match the manifest array positions exactly (0-based), so a template
  # reference can be checked against canonical data by eye.
  if ($p.artifacts) {
    for ($ai = 0; $ai -lt @($p.artifacts).Count; $ai++) {
      $art = @($p.artifacts)[$ai]
      $tokens["artifacts.$ai.sha256"]        = if ($art.sha256)        { $art.sha256 }        else { '' }
      $tokens["artifacts.$ai.filename"]      = if ($art.filename)      { $art.filename }      else { '' }
      $tokens["artifacts.$ai.downloadUrl"]   = if ($art.downloadUrl)   { $art.downloadUrl }   else { '' }
      $tokens["artifacts.$ai.sha256Url"]     = if ($art.sha256Url)     { $art.sha256Url }     else { '' }
      $tokens["artifacts.$ai.signingStatus"] = if ($art.signingStatus) { $art.signingStatus } else { 'UNSIGNED' }
      $tokens["artifacts.$ai.platform"]      = if ($art.platform)      { $art.platform }      else { '' }
    }
  }

  # proofLinks-indexed tokens: {{product.proofLinks.N}} → canonical release-record URL.
  if ($p.proofLinks) {
    for ($li = 0; $li -lt @($p.proofLinks).Count; $li++) {
      $tokens["proofLinks.$li"] = $p.proofLinks[$li]
    }
  }

  # tests-indexed tokens: {{product.tests.N.label}} / {{product.tests.N.result}}.
  if ($p.tests -is [array]) {
    for ($ti = 0; $ti -lt @($p.tests).Count; $ti++) {
      $tEntry = @($p.tests)[$ti]
      $tokens["tests.$ti.label"]  = if ($tEntry.label)  { $tEntry.label }  else { '' }
      $tokens["tests.$ti.result"] = if ($tEntry.result) { $tEntry.result } else { '' }
    }
  }

  # evidence-indexed tokens: {{product.evidence.N.label}} / {{product.evidence.N.url}}.
  if ($p.evidence -is [array]) {
    for ($ei = 0; $ei -lt @($p.evidence).Count; $ei++) {
      $eEntry = @($p.evidence)[$ei]
      $tokens["evidence.$ei.label"] = if ($eEntry.label) { $eEntry.label } else { '' }
      $tokens["evidence.$ei.url"]   = if ($eEntry.url)   { $eEntry.url }   else { '' }
    }
  }

  # proofStrip — typed status + version + platform + tests + verification dimension summary
  $pills = @()
  $pills += "<span class=`"proof-pill`"><strong>Status</strong> $(Html-Attr $tokens['statusLabel'])</span>"
  $ver = if ($tokens['versionLabel']) { Html-Attr $tokens['versionLabel'] } else { '&mdash;' }
  $pills += "<span class=`"proof-pill`"><strong>Version</strong> $ver</span>"
  if ($canVer -and $canVer -ne $pubVer) {
    $candidateLabel = if ($p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE') { 'Next' } else { 'Candidate' }
    $pills += "<span class=`"proof-pill`"><strong>$candidateLabel</strong> v$(Html-Attr $canVer)</span>"
  }
  $pills += "<span class=`"proof-pill`"><strong>Platform</strong> $(Html-Attr $tokens['platform'])</span>"
  if ($tokens['testStatus']) {
    $pills += "<span class=`"proof-pill`"><strong>Tests</strong> $(Html-Attr $tokens['testStatus'])</span>"
  }
  $pills += "<span class=`"proof-pill`"><strong>Proof</strong> $(Html-Attr $tokens['proofStatus'])</span>"
  if ($tokens['lastVerified']) {
    $pills += "<span class=`"proof-pill`"><strong>Verified</strong> $(Html-Attr $tokens['lastVerified'])</span>"
  }
  $tokens['proofStrip'] = "<div class=`"proof-strip`">" + ($pills -join "`n          ") + "</div>"

  # downloadBlock — derive from canonical artifact if available, else legacy fields
  $dlUrl = if ($tokens['artifactDownloadUrl']) { $tokens['artifactDownloadUrl'] } else { $p.downloadUrl }
  if ($p.presentation.downloadUnavailable -or [string]::IsNullOrWhiteSpace($dlUrl)) {
    $mutedLabel = if ($p.presentation.downloadUnavailable) { 'Downloads currently unavailable' }
                  elseif (-not [string]::IsNullOrWhiteSpace($p.disabledDownloadLabel)) { $p.disabledDownloadLabel }
                  elseif ($p.state -eq 'proof') { 'No public build yet' }
                  else { 'Coming soon' }
    $tokens['downloadBlock'] = "<span class=`"button button-muted`" aria-disabled=`"true`">$(Html-Attr $mutedLabel)</span>"
  } else {
    $url = Html-Attr $dlUrl
    $label = if ($p.downloadLabel) { $p.downloadLabel } else { 'Download' }
    $extAttr = ''
    $dlAttr = ''
    if (IsExternalUrl $url) { $extAttr = ' target="_blank" rel="noopener"' }
    if (IsFileDownload $url) { $dlAttr = ' download' }
    $tokens['downloadBlock'] = "<a class=`"button button-primary`" href=`"$url`"$extAttr$dlAttr>$(Html-Attr $label)</a>"
    $sha256Link = if ($tokens['artifactSha256Url']) { $tokens['artifactSha256Url'] } else { $p.sha256Url }
    if (-not [string]::IsNullOrWhiteSpace($sha256Link)) {
      $tokens['downloadBlock'] += " <a class=`"button button-secondary`" href=`"$(Html-Attr $sha256Link)`" target=`"_blank`" rel=`"noopener`">SHA-256</a>"
    }
  }

  # hashBlock — full primary artifact SHA-256 with copy control wrapper
  $primarySha = if ($tokens['artifactSha256']) { $tokens['artifactSha256'] } else { $p.sha256 }
  if (-not [string]::IsNullOrWhiteSpace($primarySha)) {
    $platform = PlatformLabel $p
    $verificationNote = if ($platform -like '*Android*') {
      "<p class=`"note`">Desktop verification: <code class=`"inline`">Get-FileHash `".\$(Html-Attr $tokens['artifactFilename'])`" -Algorithm SHA256</code> (Phone-native verification guidance is being prepared on the <a href=`"/support/#android`" class=`"text-link`">support hub</a>)</p>"
    } else {
      "<p class=`"note`">Windows verification: <code class=`"inline`">Get-FileHash `".\$(Html-Attr $tokens['artifactFilename'])`" -Algorithm SHA256</code></p>"
    }
    $shaEsc = Html-Attr $primarySha
    $tokens['hashBlock'] = @"
<div class="code-block sha256-block" data-sha256="$shaEsc">
  <code class="sha256-value">$shaEsc</code>
  <button type="button" class="sha256-copy" aria-label="Copy SHA-256" title="Copy SHA-256">Copy</button>
</div>
$verificationNote
"@
  } else {
    $tokens['hashBlock'] = ''
  }

  # releaseNoteBlock
  if (-not [string]::IsNullOrWhiteSpace($p.releaseNote)) {
    $tokens['releaseNoteBlock'] = "<p class=`"note`">$(Html-Attr $p.releaseNote)</p>"
  } else {
    $tokens['releaseNoteBlock'] = ''
  }

  # limits as HTML (for optional product-page token)
  if ($p.limits -and $p.limits.Count -gt 0) {
    $limItems = $p.limits | ForEach-Object { "<li>$(Html-Attr $_)</li>" }
    $tokens['limitsBlock'] = "<ul class=`"limits-list`">" + ($limItems -join '') + "</ul>"
  } else {
    $tokens['limitsBlock'] = ''
  }

  return $tokens
}

# Tokens whose values are generated markup — they are built by this script and
# already escape their dynamic leaves. Every other token value is untrusted
# dynamic state and is HTML-escaped at interpolation (attribute-safe set).
$script:MarkupProductTokens = @('proofStrip','downloadBlock','hashBlock','releaseNoteBlock','limitsBlock','markSvg')

# Apply {{product.X}} substitution to a string given a tokens hashtable
function Replace-ProductTokens($text, $tokens, [switch]$Strict) {
  foreach ($key in $tokens.Keys) {
    $v = [string]$tokens[$key]
    if ($script:MarkupProductTokens -notcontains $key) { $v = Html-Attr $v }
    $text = $text -replace [regex]::Escape("{{product.$key}}"), $v
  }
  # On a page bound to a product, an unresolved token is a defect, not a blank.
  # Silently stripping it would delete published evidence — a mistyped
  # {{product.artifacts.1.sha256}} would render an empty checksum block and the
  # build would still report success.
  if ($Strict) {
    $leftover = @([regex]::Matches($text, '\{\{product\.[^}]+\}\}') |
                  ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($leftover.Count -gt 0) {
      throw "Unresolved product token(s) on a bound product page: $($leftover -join ', '). Known tokens: $((($tokens.Keys | Sort-Object) -join ', '))"
    }
  }
  # Strip any leftover product tokens (e.g. on non-product pages)
  $text = $text -replace '\{\{product\.[^}]+\}\}', ''
  return $text
}

# ─────────────────────────────────────────────────────────────────────────────
# Build nav links + footer products
# ─────────────────────────────────────────────────────────────────────────────
function Build-NavLinks($activeId) {
  if ($activeId -eq 'software') { $activeId = 'products' }
  # Product pages map to the "products" nav item
  $productIds = @()
  foreach ($p in $allProductState) { $productIds += $p.id }
  if ($productIds -contains $activeId) { $activeId = 'products' }

  $links = @()
  foreach ($item in $manifest.nav) {
    $cur = ''
    if ($item.id -eq $activeId) { $cur = ' aria-current="page"' }
    $links += "<a href=`"$(Html-Attr $item.href)`"$cur>$(Html-Attr $item.label)</a>"
  }
  return ($links -join "`n        ")
}

function Build-FooterProducts {
  $items = @()
  foreach ($p in $allProductState) {
    $footerName = if ($p.homeName) { $p.homeName } else { $p.name }
    $items += "<li><a href=`"$(Html-Attr $p.route)`">$(Html-Attr $footerName)</a></li>"
  }
  return ($items -join "`n          ")
}

function Render-ProductCard($p, $cardTemplate) {
  $t = ProductTokens $p
  $card = $cardTemplate
  # cardVersionLabel is substituted before versionLabel would be, and the token
  # names are distinct, so ordering here is incidental rather than load-bearing.
  foreach ($key in @(
    'homeName','name','route','state','statusLabel','summary','cardSummary','statusLine','markSvg','id','meta','cta',
    'visitorStatusLabel','visitorStatusSlug','groupId','cardVersionLabel','cardDetailLine','cardCtaHref',
    'cardProofHref','valueLine','cardImage','cardImageAlt','cardImageWidth','cardImageHeight','cardCta','platform'
  )) {
    $v = [string]$t[$key]
    if ($script:MarkupProductTokens -notcontains $key) { $v = Html-Attr $v }
    $card = $card -replace [regex]::Escape("{{$key}}"), $v
  }
  # Optional card regions collapse rather than rendering an empty element, so a
  # product without a detail line does not leave a blank row in the card.
  if ([string]::IsNullOrWhiteSpace($t['cardDetailLine'])) {
    $card = $card -replace '(?s)<!--\s*@if-detail\s*-->.*?<!--\s*@end-detail\s*-->', ''
  } else {
    $card = $card -replace '<!--\s*@if-detail\s*-->', '' -replace '<!--\s*@end-detail\s*-->', ''
  }
  if ([string]::IsNullOrWhiteSpace($t['cardVersionLabel'])) {
    $card = $card -replace '(?s)<!--\s*@if-version\s*-->.*?<!--\s*@end-version\s*-->', ''
  } else {
    $card = $card -replace '<!--\s*@if-version\s*-->', '' -replace '<!--\s*@end-version\s*-->', ''
  }
  return $card
}

# Emits the cards for one homepage group. Membership is derived from product
# availability (a public release exists) via manifest productGroups, so a product
# can never be hand-placed into a group that contradicts its release facts, and a
# product with a public release is never presented as unreleased just because its
# newest candidate is not out yet.
function Build-ProductCards($groupId, [bool]$includeFeatured = $false) {
  $cardTemplate = Read-File (Join-Path $partialsDir 'product-card.html')
  $cards = @()
  foreach ($p in $allProductState) {
    # The featured product gets its own full-width composition above the groups
    # rather than a card, so it is not also emitted into the grid.
    if ($p.featured -and -not $includeFeatured) { continue }
    if ($groupId -and (ProductGroupId $p) -ne $groupId) { continue }
    $cards += (Render-ProductCard $p $cardTemplate)
  }
  return ($cards -join "`n`n          ")
}

# One group section: heading, note, and grid. Emitted only when the group has
# members, so an empty category cannot publish a heading with nothing under it.
function Build-ProductGroupSections {
  $sections = @()
  foreach ($g in @($manifest.productGroups)) {
    $members = @($allProductState | Where-Object { -not $_.featured -and (ProductGroupId $_) -eq $g.id })
    if ($members.Count -eq 0) { continue }
    $cards = Build-ProductCards $g.id
    $count = $members.Count
    $countWord = if ($count -eq 1) { '1 product' } else { "$count products" }
    $sections += @"
<section class="product-group product-group-$(Html-Attr $g.id)" aria-labelledby="group-$(Html-Attr $g.id)-title">
        <div class="group-head">
          <h3 id="group-$(Html-Attr $g.id)-title" class="group-title">$(Html-Attr $g.label)</h3>
          <p class="group-note">$(Html-Attr $g.note)</p>
          <p class="group-count">$countWord</p>
        </div>
        <div class="products-grid">
          $cards
        </div>
      </section>
"@
  }
  return ($sections -join "`n`n      ")
}

# A concrete, derived statement of how much real software exists. Two separate
# facts, each counted from its own source of truth:
#   - downloads ready today = a served artifact exists (downloadUrl non-empty)
#   - products with a public release = release.publicVersion non-empty
# These differ on purpose: Lights Out has a public v11.1.2 whose artifact is
# currently blocked, so it counts as released but not as downloadable. Counting
# both from the same predicate is what let the old line erase that release.
function Build-CatalogSummary {
  $visible     = $allProductState
  $downloadable = @($visible | Where-Object { -not $_.presentation.downloadUnavailable -and -not [string]::IsNullOrWhiteSpace($_.downloadUrl) })
  $released     = @($visible | Where-Object { $_.release -and -not [string]::IsNullOrWhiteSpace("$($_.release.publicVersion)") })
  $total        = $visible.Count
  $dot = [char]0x00B7
  $parts = @()
  if ($downloadable.Count -gt 0) {
    $noun = if ($downloadable.Count -eq 1) { 'download' } else { 'downloads' }
    $parts += "<strong>$($downloadable.Count)</strong> $noun ready today"
  }
  if ($released.Count -gt 0) {
    $parts += "<strong>$($released.Count)</strong> of $total products have a public release"
  }
  return ($parts -join " $dot ")
}

function Build-TrustStrip {
  $items = @()
  foreach ($ts in @($manifest.trustStrip)) {
    $items += @"
<li class="trust-item">
            <span class="trust-label">$(Html-Attr $ts.label)</span>
            <span class="trust-note">$(Html-Attr $ts.note)</span>
          </li>
"@
  }
  return ($items -join "`n          ")
}

function Build-ProofRegistry {
  # Emit a canonical, machine-readable proof registry as a PowerShell object.
  $entries = @()
  foreach ($p in $allProductState) {
    $pubVer = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { $p.version }
    $canVer = if ($p.release -and $p.release.candidateVersion) { $p.release.candidateVersion } else { $null }
    $primaryArtifact = $null
    if ($p.artifacts) {
      foreach ($a in $p.artifacts) { if (-not [string]::IsNullOrWhiteSpace($a.sha256) -or $a.downloadUrl) { $primaryArtifact = $a; break } }
    }
    if (-not $primaryArtifact -and ($p.sha256 -or $p.downloadUrl)) {
      $primaryArtifact = @{ filename = $null; sha256 = $p.sha256; downloadUrl = $p.downloadUrl; sha256Url = $p.sha256Url; signingStatus = 'UNSIGNED'; platform = $p.platform; distType = $p.distType }
    }

    # [ordered] throughout: a plain @{} is an unordered hashtable, and ConvertTo-Json
    # emits its keys in enumeration order, which PowerShell varies between processes.
    # That made two consecutive builds of the same manifest produce byte-different
    # JSON (455 of 476 lines moved), defeating diffing, content hashing and any
    # consumer that caches the registry by digest.
    $artifactEntries = @()
    if ($p.artifacts) {
      foreach ($a in $p.artifacts) {
        $artifactEntries += [ordered]@{
          filename      = $a.filename
          sizeBytes     = $a.sizeBytes
          sha256        = $a.sha256
          downloadUrl   = $a.downloadUrl
          sha256Url     = $a.sha256Url
          signingStatus = $a.signingStatus
          platform      = $a.platform
          distType      = $a.distType
        }
      }
    } elseif ($p.sha256 -or $p.downloadUrl) {
      $artifactEntries += [ordered]@{
        filename      = $primaryArtifact.filename
        sizeBytes     = $null
        sha256        = $p.sha256
        downloadUrl   = $p.downloadUrl
        sha256Url     = $p.sha256Url
        signingStatus = 'UNSIGNED'
        platform      = $p.platform
        distType      = $p.distType
      }
    }

    $evidenceEntries = @()
    if ($p.evidence) {
      foreach ($e in $p.evidence) {
        if ($e.url) { $evidenceEntries += [ordered]@{ label = $e.label; url = $e.url } }
      }
    }
    if ($p.proofLinks -and $p.proofLinks.Count -gt 0) {
      foreach ($link in $p.proofLinks) {
        if ($link) {
          $base = $link -split '/' | Select-Object -Last 1
          $evidenceEntries += [ordered]@{ label = $base; url = $link }
        }
      }
    }

    $verificationEntry = if ($p.verification) {
      [ordered]@{
        status           = $p.verification.status
        verifiedAt       = $p.verification.verifiedAt
        verificationType = if ($p.verification.verificationType) { @($p.verification.verificationType) } else { @() }
        receiptId        = $p.verification.receiptId
        receiptUrl       = $p.verification.receiptUrl
      }
    } else {
      [ordered]@{ status = 'PENDING'; verifiedAt = $null; verificationType = @(); receiptId = $null; receiptUrl = $null }
    }

    $entry = [ordered]@{
      id            = $p.id
      name          = $p.name
      displayName   = $p.displayName
      productStatus = $p.productStatus
      release       = [ordered]@{
        publicVersion    = $pubVer
        candidateVersion = $canVer
        releaseStatus    = if ($p.release -and $p.release.releaseStatus) { $p.release.releaseStatus } else { 'UNRELEASED' }
        publishedAt      = if ($p.release -and $p.release.publishedAt) { $p.release.publishedAt } else { $null }
      }
      platform      = if ($p.platforms -and $p.platforms.Count -gt 0) { @($p.platforms) } else { @($p.platform) }
      route         = $p.route
      artifacts     = $artifactEntries
      verification  = $verificationEntry
      tests         = if ($p.tests) { @($p.tests) } else { @() }
      evidence      = $evidenceEntries
      limits        = if ($p.limits) { @($p.limits) } else { @() }
      summary       = $p.summary
    }
    $entries += $entry
  }

  return [ordered]@{
    schemaVersion   = '1.0.0'
    generatedAt     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    canonicalUrl    = $manifest.canonicalUrl
    registryPath    = $manifest.proofRegistryPath
    productCount    = $entries.Count
    products        = $entries
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# H11 public truth surface
#
# /truth/* is the site's versioned, sanitized, deterministic machine-readable
# contract. It is constructed field-by-field from an explicit allowlist — the
# manifest is never serialized wholesale, so future internal fields cannot leak.
# Truth bytes carry no wall-clock data: identity binds to the Git commit/tree,
# and committedAt is the commit timestamp, so the same tree yields the same
# bytes on every build.
# ─────────────────────────────────────────────────────────────────────────────
function Get-SourceIdentity {
  if ($TruthCommit -or $TruthTree -or $TruthCommittedAt) {
    foreach ($pair in @(@('TruthCommit',$TruthCommit), @('TruthTree',$TruthTree), @('TruthCommittedAt',$TruthCommittedAt))) {
      if (-not $pair[1]) { throw "Truth identity override incomplete: -$($pair[0]) missing (all of -TruthCommit, -TruthTree, -TruthCommittedAt are required together)" }
    }
    return [ordered]@{
      commit        = $TruthCommit
      tree          = $TruthTree
      committedAt   = $TruthCommittedAt
    }
  }
  $commit = (& git -C $root rev-parse HEAD 2>$null)
  $tree   = (& git -C $root rev-parse 'HEAD^{tree}' 2>$null)
  $at     = (& git -C $root show -s '--format=%cI' HEAD 2>$null)
  if (-not $commit -or -not $tree -or -not $at -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Public truth source identity requires a Git repository (or explicit -TruthCommit/-TruthTree/-TruthCommittedAt overrides). Refusing to publish truth without provable provenance."
  }
  # Local worktree state is deliberately NOT part of the public contract:
  # published truth claims only the committed source identity. Whether a build
  # may deploy from a tracked-dirty tree is enforced at deploy.ps1 preflight,
  # not in public JSON. See schemas/PUBLIC_TRUTH_VERSIONING.md.
  return [ordered]@{
    commit        = $commit
    tree          = $tree
    committedAt   = $at
  }
}

# Fields allowed to leave the manifest into public truth. Anything not listed
# here is internal/presentation and must never reach /truth/*.
$script:PublicTruthSafePattern = 'C:\\|file://|localhost|127\.0\.0\.1|0\.0\.0\.0|::1|api[_-]?key|secret|bearer\s+[A-Za-z0-9]|password|(?i)javascript:|data:|vbscript:'
function Test-PublicTruthSafe([string]$json, [string]$what) {
  if ($json -match $script:PublicTruthSafePattern) {
    throw "Public truth output '$what' contains a private/unsafe pattern (local path, loopback, or credential-like token). Refusing to emit it."
  }
}

function Build-PublicTruthProduct($p, $source) {
  $pubVer  = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { $null }
  $canVer  = if ($p.release -and $p.release.candidateVersion) { $p.release.candidateVersion } else { $null }
  $rel = if ($p.release) {
    [ordered]@{
      releaseStatus              = $p.release.releaseStatus
      publicVersion              = $pubVer
      candidateVersion           = $canVer
      companionCandidateVersion  = if ($p.release.companionCandidateVersion) { $p.release.companionCandidateVersion } else { $null }
      companionPublicVersion     = if ($p.release.companionPublicVersion) { $p.release.companionPublicVersion } else { $null }
      publishedAt                = if ($p.release.publishedAt) { $p.release.publishedAt } else { $null }
      sourceCommit               = if ($p.release.sourceCommit) { $p.release.sourceCommit } else { $null }
    }
  } else { $null }

  $artifactEntries = @()
  foreach ($a in @($p.artifacts)) {
    $artifactEntries += [ordered]@{
      filename      = $a.filename
      sizeBytes     = $a.sizeBytes
      sha256        = $a.sha256
      downloadUrl   = $a.downloadUrl
      sha256Url     = $a.sha256Url
      signingStatus = $a.signingStatus
      platform      = $a.platform
      distType      = $a.distType
    }
  }

  $verification = if ($p.verification) {
    [ordered]@{
      status               = $p.verification.status
      verifiedAt           = $p.verification.verifiedAt
      checkedAt            = if ($p.verification.checkedAt) { $p.verification.checkedAt } else { $null }
      verificationType     = if ($p.verification.verificationType) { @($p.verification.verificationType) } else { $null }
      downloadAvailability = if ($p.verification.downloadAvailability) { $p.verification.downloadAvailability } else { $null }
      receiptId            = $p.verification.receiptId
      receiptUrl           = $p.verification.receiptUrl
    }
  } else { $null }

  # Array fields must be bound from variables, not if/else expressions: an
  # if-branch emitting nothing assigns $null and serializes as null, not [].
  $platformsArr = @(); if ($p.platforms) { $platformsArr = @($p.platforms) }
  $testsArr = @(); if ($p.tests) { $testsArr = @($p.tests | ForEach-Object { [ordered]@{ label = $_.label; result = $_.result } }) }
  $evidenceArr = @(); if ($p.evidence) { $evidenceArr = @($p.evidence | ForEach-Object { if ($_ -is [string]) { [ordered]@{ label = ($_ -split '/')[-1]; url = $_ } } else { [ordered]@{ label = $_.label; url = $_.url } } }) }
  $proofLinksArr = @(); if ($p.proofLinks) { $proofLinksArr = @($p.proofLinks) }

  return [ordered]@{
    schemaVersion = 1
    id            = $p.id
    name          = $p.name
    state         = $p.state
    status        = $p.productStatus
    version       = $pubVer
    platforms     = $platformsArr
    packageId     = if ($p.packageId) { $p.packageId } else { $null }
    pageUrl       = "/$($p.id)/"
    truthUrl      = "/truth/products/$($p.id).json"
    release       = $rel
    download      = [ordered]@{
      available = -not [string]::IsNullOrWhiteSpace($p.downloadUrl)
      url       = if ($p.downloadUrl) { $p.downloadUrl } else { $null }
      sha256    = if ($p.sha256) { $p.sha256 } else { $null }
      sha256Url = if ($p.sha256Url) { $p.sha256Url } else { $null }
      label     = if ($p.downloadLabel) { $p.downloadLabel } else { $null }
    }
    artifacts     = $artifactEntries
    verification  = $verification
    tests         = $testsArr
    evidence      = $evidenceArr
    proofLinks    = $proofLinksArr
    source        = $source
  }
}

function Build-PublicTruth($source) {
  $indexEntries = @()
  $productDocs  = @()
  foreach ($p in $allProductState) {
    $pubVer = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { $null }
    $indexEntries += [ordered]@{
      id       = $p.id
      name     = $p.name
      state    = $p.state
      status   = $p.productStatus
      version  = $pubVer
      pageUrl  = "/$($p.id)/"
      truthUrl = "/truth/products/$($p.id).json"
    }
    $productDocs += Build-PublicTruthProduct $p $source
  }
  $index = [ordered]@{
    schemaVersion = 1
    generatedFrom = 'site-manifest.json'
    schemaUrl     = '/truth/schema-v1.json'
    canonicalUrl  = $manifest.canonicalUrl
    source        = $source
    productCount  = $indexEntries.Count
    products      = $indexEntries
  }
  return [ordered]@{ index = $index; products = $productDocs }
}

# Human index cards for /truth/ — rendered from the same manifest model as the
# JSON so the page cannot disagree with the machine-readable surface.
function Build-TruthIndexCards {
  $cards = ''
  foreach ($p in $allProductState) {
    $statusLabel = if ($manifest.statusTaxonomy -and $manifest.statusTaxonomy.PSObject.Properties[$p.productStatus]) { $manifest.statusTaxonomy.($p.productStatus) } else { $p.productStatus }
    $ver = if ($p.release -and $p.release.publicVersion) { "v$($p.release.publicVersion)" } else { 'Unreleased' }
    $artCount = @($p.artifacts).Count
    $artWord = if ($artCount -eq 1) { 'artifact' } else { 'artifacts' }
    $cards += @"
        <article class="detail-card">
          <h3>$(Html-Attr $p.name)</h3>
          <p>$(Html-Attr $statusLabel) · $(Html-Attr $ver) · $artCount public $artWord</p>
          <p><a class="text-link" href="/truth/products/$(Html-Attr $p.id).json">View JSON ↗</a> · <a class="text-link" href="/$(Html-Attr $p.id)/">Product page ↗</a></p>
        </article>
"@
  }
  return $cards
}

function Build-LatestVerification {
  # Return a generated "latest site verification" summary based on the most recent
  # verification.verifiedAt or release.publishedAt across all visible products.
  # Returns null properties when no evidence exists so the template cannot
  # fabricate a "Latest" claim.
  $latestDate = $null
  $latestProduct = $null
  $latestEvent = $null
  foreach ($p in $allProductState) {
    $candidates = @()
    if ($p.verification -and $p.verification.verifiedAt) { $candidates += @{ Date = $p.verification.verifiedAt; Product = $p; Event = 'artifact verified' } }
    if ($p.release -and $p.release.publishedAt) { $candidates += @{ Date = $p.release.publishedAt; Product = $p; Event = 'public release' } }
    if ($p.lastVerified -and (-not $p.verification -or -not $p.verification.verifiedAt)) { $candidates += @{ Date = $p.lastVerified; Product = $p; Event = 'last verified' } }
    foreach ($c in $candidates) {
      if (-not $latestDate -or $c.Date -gt $latestDate) {
        $latestDate = $c.Date
        $latestProduct = $c.Product
        $latestEvent = $c.Event
      }
    }
  }
  return @{
    date    = $latestDate
    product = if ($latestProduct) { $latestProduct.displayName } else { $null }
    event   = $latestEvent
  }
}

function Get-VerificationStatus($dimension, $p) {
  # Returns (label, value, cssClass) for a verification dimension
  $label = if ($manifest.verificationLabels.$dimension) { $manifest.verificationLabels.$dimension } else { $dimension }
  $hasType = $p.verification -and $p.verification.verificationType -and ($p.verification.verificationType -contains $dimension)

  $value = ''
  $cssClass = ''

  switch ($dimension) {
    'ARTIFACT_HASH_PUBLISHED' {
      $hasHash = ($p.artifacts -and ($p.artifacts | Where-Object { $_.sha256 }).Count -gt 0) -or $p.sha256
      $value = if ($hasHash) { 'PUBLISHED' } else { 'NOT_PUBLISHED' }
      $cssClass = if ($hasHash) { 'published' } else { 'not-published' }
    }
    'ARTIFACT_HASH_VERIFIED' {
      $hasHash = ($p.artifacts -and ($p.artifacts | Where-Object { $_.sha256 }).Count -gt 0) -or $p.sha256
      $verified = $hasHash -and ($p.verification.status -eq 'VERIFIED')
      $value = if ($verified) { 'VERIFIED' } else { 'PENDING' }
      $cssClass = if ($verified) { 'verified' } else { 'pending' }
    }
    'ARTIFACT_CUSTODY' {
      $value = if ($hasType) { 'VERIFIED' } else { 'PENDING' }
      $cssClass = if ($hasType) { 'verified' } else { 'pending' }
    }
    'RUNTIME_VALIDATION' {
      $value = if ($hasType) { 'VERIFIED' } else { 'PENDING' }
      $cssClass = if ($hasType) { 'verified' } else { 'pending' }
    }
    'REALITY_GATE' {
      $value = if ($hasType) { 'VERIFIED' } else { 'PENDING' }
      $cssClass = if ($hasType) { 'verified' } else { 'pending' }
    }
    'PUBLIC_DOWNLOAD' {
      if ($p.presentation -and $p.presentation.downloadUnavailable) {
        $value = 'UNAVAILABLE'
        $cssClass = 'not-published'
      } else {
        $hasDownload = ($p.artifacts -and ($p.artifacts | Where-Object { $_.downloadUrl }).Count -gt 0) -or $p.downloadUrl
        $value = if ($hasDownload) { 'VERIFIED' } else { 'NOT_PUBLISHED' }
        $cssClass = if ($hasDownload) { 'verified' } else { 'not-published' }
      }
    }
    'CODE_SIGNING' {
      $signing = if ($p.artifacts -and $p.artifacts.Count -gt 0) { $p.artifacts[0].signingStatus } else { 'UNSIGNED' }
      if (-not $signing) { $signing = 'UNSIGNED' }
      $statusMap = @{ 'PRODUCTION_SIGNED' = 'SIGNED'; 'DEBUG_SIGNED' = 'DEBUG SIGNED'; 'UNSIGNED' = 'UNSIGNED' }
      $value = $statusMap[$signing]
      $cssClass = if ($signing -eq 'PRODUCTION_SIGNED') { 'verified' } elseif ($signing -eq 'DEBUG_SIGNED') { 'pending' } else { 'not-published' }
    }
    'RELEASE_AUTHORIZATION' {
      if ($p.release -and $p.release.releaseStatus -eq 'HOLD') { $value = 'HOLD'; $cssClass = 'pending' }
      elseif ($p.release -and ($p.release.releaseStatus -in @('PUBLIC_RELEASE','FROZEN'))) { $value = 'AUTHORIZED'; $cssClass = 'verified' }
      else { $value = 'PENDING'; $cssClass = 'pending' }
    }
    'PUBLICATION_STATUS' {
      $value = $p.release.releaseStatus
      $cssClass = if ($p.release.releaseStatus -in @('PUBLIC_RELEASE','FROZEN')) { 'verified' } elseif ($p.release.releaseStatus -eq 'HOLD') { 'pending' } else { 'not-published' }
    }
    default { $value = 'PENDING'; $cssClass = 'pending' }
  }

  return @($label, $value, $cssClass)
}

function Build-ReceiptCards {
  $cards = @()
  foreach ($p in $allProductState) {
    $t = ProductTokens $p

    # status text and CSS class from canonical productStatus
    $ps = if ($p.productStatus) { $manifest.statusTaxonomy.$($p.productStatus) } else { if ($p.proofStatus) { $p.proofStatus } else { 'verification pending' } }
    $statusClass = if ($p.productStatus) { $p.productStatus.ToLower() } else { ($p.state -replace ' ', '-') }

    # route link
    if ($p.route -like 'http*') {
      $routeLink = "<a href=`"$(Html-Attr $p.route)`" target=`"_blank`" rel=`"noopener`">External link</a>"
    } elseif ($p.route -like '/*') {
      $routeLink = "<a href=`"$(Html-Attr $p.route)`">$(Html-Attr $p.route)</a>"
    } else {
      $routeLink = '<span style="color:var(--muted);">N/A</span>'
    }

    # public version / candidate version
    $publicVer = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { $p.version }
    $candidateVer = if ($p.release -and $p.release.candidateVersion) { $p.release.candidateVersion } else { '' }
    if ($publicVer) {
      $verHtml = "<dd>v$(Html-Attr $publicVer)</dd>"
      if ($candidateVer -and $candidateVer -ne $publicVer) {
        $candidateLabel = if ($p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE') { 'Next' } else { 'Candidate' }
        $verHtml += "<dd class='candidate-version'>$candidateLabel v$(Html-Attr $candidateVer)</dd>"
      }
    } else {
      $verHtml = '<dd style="color:var(--muted);">Unreleased</dd>'
    }

    # primary artifact + full SHA-256
    $primaryArtifact = $null
    if ($p.artifacts) { foreach ($a in $p.artifacts) { if (-not [string]::IsNullOrWhiteSpace($a.sha256)) { $primaryArtifact = $a; break } } }
    if (-not $primaryArtifact -and $p.sha256) { $primaryArtifact = @{ filename = if ($t['artifactFilename']) { $t['artifactFilename'] } else { '' }; sha256 = $p.sha256; downloadUrl = $p.downloadUrl; sha256Url = $p.sha256Url } }

    if ($primaryArtifact -and $primaryArtifact.sha256) {
      $fn = if ($primaryArtifact.filename) { Html-Attr $primaryArtifact.filename } else { 'Artifact' }
      # Name the build this checksum covers. The card's "Public version" row sits a
      # few lines above, so an unattributed hash reads as the public release's
      # checksum. For a product on HOLD (Lights Out: public v11.1.2, artifacts
      # v11.1.3) that would be a false public claim, so say which build it is.
      $artifactVersions = @([regex]::Matches("$($primaryArtifact.filename) $($primaryArtifact.downloadUrl)", '(?<![\d.])(\d+\.\d+\.\d+(?:-[a-zA-Z0-9._]+)?)(?![\d.])') |
                            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      $scopeNote = ''
      if ($publicVer -and $artifactVersions.Count -gt 0 -and ($artifactVersions -notcontains $publicVer)) {
        $scopeLabel = if ($candidateVer -and ($artifactVersions -contains $candidateVer)) { "candidate v$candidateVer" } else { "v$($artifactVersions[0])" }
        $scopeNote = " <span class=`"sha256-scope`">$(Html-Attr $scopeLabel) &mdash; not the public v$(Html-Attr $publicVer)</span>"
      }
      $shaEsc = Html-Attr $primaryArtifact.sha256
      $shaBlock = @"
        <p class="sha256-file">Checksum covers <span class="sha256-filename">$fn</span>$scopeNote</p>
        <div class="sha256-block" data-sha256="$shaEsc">
          <code class="sha256-value">$shaEsc</code>
          <button type="button" class="sha256-copy" aria-label="Copy SHA-256 for $fn" title="Copy SHA-256">Copy</button>
        </div>
        <p class="sha256-prefix-note">SHA-256 prefix: <span class="code" title="$shaEsc">$(Html-Attr $primaryArtifact.sha256.Substring(0,16))&hellip;</span></p>
"@
    } else {
      $shaBlock = '<p style="color:var(--muted);">No public artifact hash.</p>'
    }

    # typed verification matrix
    $matrixDims = @('ARTIFACT_HASH_PUBLISHED','ARTIFACT_HASH_VERIFIED','ARTIFACT_CUSTODY','RUNTIME_VALIDATION','REALITY_GATE','PUBLIC_DOWNLOAD','CODE_SIGNING','RELEASE_AUTHORIZATION','PUBLICATION_STATUS')
    $matrixRows = @()
    foreach ($dim in $matrixDims) {
      $r = Get-VerificationStatus $dim $p
      $matrixRows += "<div><dt>$(Html-Attr $r[0])</dt><dd class=`"status-$($r[2])`">$(Html-Attr $r[1])</dd></div>"
    }
    $matrix = "<dl class='receipt-fields verification-matrix'>" + ($matrixRows -join '') + "</dl>"

    # evidence links from canonical evidence and legacy proofLinks
    $evidenceLinks = @()
    $seenEvidence = @{}
    if ($p.evidence) {
      foreach ($e in $p.evidence) {
        if ($e.url -and -not $seenEvidence.ContainsKey($e.url)) {
          $evidenceLinks += "<a href=`"$(Html-Attr $e.url)`" target=`"_blank`" rel=`"noopener`">$(Html-Attr $e.label)</a>"
          $seenEvidence[$e.url] = $true
        }
      }
    }
    if ($p.proofLinks -and $p.proofLinks.Count -gt 0) {
      foreach ($link in $p.proofLinks) {
        if ($link -and -not $seenEvidence.ContainsKey($link)) {
          $base = $link -split '/' | Select-Object -Last 1
          $evidenceLinks += "<a href=`"$(Html-Attr $link)`" target=`"_blank`" rel=`"noopener`">$(Html-Attr $base)</a>"
          $seenEvidence[$link] = $true
        }
      }
    }
    $evidenceHtml = if ($evidenceLinks.Count -gt 0) { "<dd>$($evidenceLinks -join ', ')</dd>" } else { '<dd style="color:var(--muted);">Not listed yet</dd>' }

    # typed verification timestamps
    $timestamps = @()
    $em = [char]0x2014
    if ($p.verification -and $p.verification.verifiedAt) {
      if ($p.verification.verificationType -contains 'REALITY_GATE') { $timestamps += 'Reality Gate verified' }
      else { $timestamps += 'Artifact verified' }
      $timestamps[-1] += " $em $(Html-Attr $p.verification.verifiedAt)"
    }
    if ($p.release -and $p.release.publishedAt) { $timestamps += "Published $em $(Html-Attr $p.release.publishedAt)" }
    if ($p.lastVerified -and (-not $p.verification -or -not $p.verification.verifiedAt)) { $timestamps += "Last verified $em $(Html-Attr $p.lastVerified)" }
    $timestampHtml = if ($timestamps.Count -gt 0) { "<dd>$($timestamps -join '<br>')</dd>" } else { '<dd style="color:var(--muted);">N/A</dd>' }

    # limits
    $limitsHtml = ''
    if ($p.limits -and $p.limits.Count -gt 0) {
      $limItems = $p.limits | ForEach-Object { "<li>$(Html-Attr $_)</li>" }
      $limitsHtml = "<ul class='limits-list'>" + ($limItems -join '') + "</ul>"
    }

    # download action
    $dlUrl = if ($primaryArtifact -and $primaryArtifact.downloadUrl) { $primaryArtifact.downloadUrl } else { $p.downloadUrl }
    if ($p.presentation.downloadUnavailable -or [string]::IsNullOrWhiteSpace($dlUrl)) {
      $label = if ($p.presentation.downloadUnavailable) { 'Downloads currently unavailable' } elseif ($p.state -eq 'proof') { 'No public download yet' } else { 'Download coming soon' }
      $action = "<span class=`"button button-muted`" style=`"display:block; text-align:center;`" aria-disabled=`"true`">$(Html-Attr $label)</span>"
    } else {
      $ext = if (IsExternalUrl $dlUrl) { ' target="_blank" rel="noopener"' } else { '' }
      $dl = if (IsFileDownload $dlUrl) { ' download' } else { '' }
      $action = "<a class=`"button button-primary`" style=`"display:block; text-align:center;`" href=`"$(Html-Attr $dlUrl)`"$ext$dl>$(Html-Attr $t['downloadLabel'])</a>"
    }

    $build = if ($p.build) { Html-Attr $p.build } else { 'Release details coming soon.' }
    if ($p.presentation.downloadUnavailable) {
      $build = '<strong>' + (Html-Attr $p.presentation.downloadNotice) + '</strong> Historical release record: ' + $build
    }

    $cards += @"
        <article class="receipt-card" id="receipt-$(Html-Attr $p.id)" data-status="$(Html-Attr $p.productStatus)" data-platform="$(Html-Attr $t['platform'])">
          <div class="receipt-card-head">
            <div>
              <h3>$(Html-Attr $t['name'])</h3>
              <span class="platform-badge">$(Html-Attr $t['platform'])</span>
            </div>
            <span class="status-indicator $(Html-Attr $statusClass)">$(Html-Attr $ps)</span>
          </div>
          <p class="build-desc">$build</p>

          <div class="receipt-section">
            <h4 class="receipt-section-title">Release</h4>
            <dl class="receipt-fields">
              <div><dt>Route</dt><dd>$routeLink</dd></div>
              <div><dt>Public version</dt>$verHtml</div>
              <div><dt>Release state</dt><dd>$(Html-Attr $t['releaseStatus'])</dd></div>
            </dl>
          </div>

          <div class="receipt-section">
            <h4 class="receipt-section-title">Verification</h4>
            $matrix
          </div>

          <div class="receipt-section">
            <h4 class="receipt-section-title">Artifact</h4>
            $shaBlock
          </div>

          <div class="receipt-section">
            <h4 class="receipt-section-title">Evidence</h4>
            <dl class="receipt-fields"><div><dt>Links</dt>$evidenceHtml</div><div><dt>Dates</dt>$timestampHtml</div></dl>
          </div>

          $limitsHtml

          <div class="receipt-card-action">$action</div>
        </article>
"@
  }
  return ($cards -join "`n`n          ")
}

# ─────────────────────────────────────────────────────────────────────────────
# Prepare public/ output dir
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "==> Rebuilding public/ from templates + partials + manifest"
if (Test-Path $publicDir) {
  try { Remove-Item $publicDir -Recurse -Force -ErrorAction Stop }
  catch {
    # Directory handle locked — clear contents and reuse
    Get-ChildItem $publicDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
}
if (-not (Test-Path $publicDir)) { New-Item -ItemType Directory $publicDir | Out-Null }

# ─────────────────────────────────────────────────────────────────────────────
# Process every template
# ─────────────────────────────────────────────────────────────────────────────
# H13-WEB — modular product registry + public-state adapter + generic renderer.
# Product enumeration comes from products/<id>/module.json (stable structural
# identity). Public product FACTS come through a ProductStateSource adapter —
# today backed by site-manifest.json; later swappable for a sanitized public
# API (ApiProductStateSource) without touching the renderer. Renderer, catalog,
# truth surface, and H12 discovery all enumerate the registry — never a
# hardcoded product-id list.

$KnownProductSections = @('hero','film','outcomes','how','story','get','onboard','faq','identity','evidence','privacy','related','final-cta')
$ReservedRoutes = @('/','/software/','/truth/','/proof/','/proof-standard/','/support/','/roadmap/','/api/','/assets/','/brand/','/reports/','/about/','/founders/','/404','/sitemap.xml','/robots.txt','/_redirects','/_headers')

function Get-ProductRegistry {
  # Discovers products/*/module.json; returns ordered, validated module list.
  $modulesDir = $script:productsDir
  $modules = @()
  $regErrors = @()
  if (Test-Path $modulesDir) {
    foreach ($dir in Get-ChildItem $modulesDir -Directory | Sort-Object Name) {
      $modPath = Join-Path $dir.FullName 'module.json'
      if (-not (Test-Path $modPath)) { $regErrors += "products/$($dir.Name)/: missing module.json"; continue }
      try { $m = Get-Content $modPath -Raw -Encoding UTF8 | ConvertFrom-Json }
      catch { $regErrors += "products/$($dir.Name)/module.json: invalid JSON — $($_.Exception.Message)"; continue }
      $modules += $m
    }
  }
  $seenIds = @{}; $seenRoutes = @{}
  foreach ($m in $modules) {
    $tag = "module '$($m.id)'"
    if ([string]::IsNullOrWhiteSpace($m.id)) { $regErrors += "module missing id"; continue }
    if ($m.id -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $regErrors += "${tag}: unsafe slug '$($m.id)'" }
    if ($seenIds.ContainsKey($m.id)) { $regErrors += "${tag}: duplicate product id" }
    $seenIds[$m.id] = $true
    if ($m.route -ne "/$($m.id)/") { $regErrors += "${tag}: route '$($m.route)' must be /<id>/" }
    $routeKey = $m.route.ToLowerInvariant()
    if ($ReservedRoutes -contains $routeKey) { $regErrors += "${tag}: route collides with reserved route $($m.route)" }
    if ($seenRoutes.ContainsKey($routeKey)) { $regErrors += "${tag}: duplicate/case-colliding route $($m.route)" }
    $seenRoutes[$routeKey] = $true
    if ($m.visibility -notin @('visible','hidden')) { $regErrors += "${tag}: visibility must be visible|hidden (got '$($m.visibility)')" }
    if (-not ($m.order -is [int] -or $m.order -is [long] -or $m.order -is [double])) { $regErrors += "${tag}: numeric order required" }
    foreach ($s in @($m.sections)) { if ($s -notin $KnownProductSections) { $regErrors += "${tag}: unknown section '$s'" } }
    if ($m.contentSource -ne 'content.html') { $regErrors += "${tag}: contentSource must be content.html (no traversal/alt paths)" }
    if (-not (Test-Path (Join-Path $modulesDir "$($m.id)\content.html"))) { $regErrors += "${tag}: missing content.html" }
    if (-not $m.meta -or [string]::IsNullOrWhiteSpace($m.meta.title) -or [string]::IsNullOrWhiteSpace($m.meta.description)) { $regErrors += "${tag}: meta.title + meta.description required" }
    if (-not @($manifest.products | Where-Object { $_.id -eq $m.id }).Count) { $regErrors += "${tag}: no manifest product with id '$($m.id)'" }
  }
  foreach ($p in $manifest.products) {
    if ($p.visible -and -not $seenIds.ContainsKey($p.id)) { $regErrors += "manifest product '$($p.id)' has no module — registry is the enumeration source" }
  }
  if ($regErrors.Count) { throw "PRODUCT REGISTRY INVALID:`n" + ($regErrors | ForEach-Object { "  - $_" } | Out-String) }
  return @($modules | Sort-Object { [int]$_.order })
}

function New-ManifestProductStateSource($manifestData, $registry) {
  # The adapter boundary. Everything downstream consumes GetAll()/Get($id)
  # product-state objects — never $manifest.products directly. A future
  # ApiProductStateSource returns the same public-state contract over HTTP.
  $src = [PSCustomObject]@{ Kind = 'manifest'; Manifest = $manifestData; Registry = $registry }
  $src | Add-Member -MemberType ScriptMethod -Name GetAll -Value {
    # Every module-paired product — including hidden (hidden state may still be
    # referenced by name tokens on non-product pages).
    $byId = @{}; foreach ($p in $this.Manifest.products) { $byId[$p.id] = $p }
    return @($this.Registry | ForEach-Object { $byId[$_.id] })
  }
  $src | Add-Member -MemberType ScriptMethod -Name GetVisible -Value {
    # Visible modules only — the enumeration source for public surfaces.
    $byId = @{}; foreach ($p in $this.Manifest.products) { $byId[$p.id] = $p }
    return @($this.Registry | Where-Object { $_.visibility -eq 'visible' } | ForEach-Object { $byId[$_.id] })
  }
  $src | Add-Member -MemberType ScriptMethod -Name Get -Value { param($id)
    return @($this.Manifest.products | Where-Object { $_.id -eq $id }) | Select-Object -First 1
  }
  return $src
}

# A state source whose data arrives from a foreign transport (JSON document
# shaped like the future public API response). Same GetAll/GetVisible/Get
# contract; the manifest is not consulted for product state on this path —
# it exists so the seam is exercised end-to-end, not merely asserted.
function New-FixtureApiProductStateSource($data, $registry) {
  $src = [PSCustomObject]@{ Kind = 'fixture-api'; Data = $data; Registry = $registry }
  $src | Add-Member -MemberType ScriptMethod -Name GetAll -Value {
    $byId = @{}; foreach ($p in $this.Data) { $byId[$p.id] = $p }
    return @($this.Registry | ForEach-Object { $byId[$_.id] })
  }
  $src | Add-Member -MemberType ScriptMethod -Name GetVisible -Value {
    $byId = @{}; foreach ($p in $this.Data) { $byId[$p.id] = $p }
    return @($this.Registry | Where-Object { $_.visibility -eq 'visible' } | ForEach-Object { $byId[$_.id] })
  }
  $src | Add-Member -MemberType ScriptMethod -Name Get -Value { param($id)
    return @($this.Data | Where-Object { $_.id -eq $id }) | Select-Object -First 1
  }
  return $src
}

$productRegistry    = Get-ProductRegistry
if ($StateSourcePath) {
  # Fixture/alternate transport: a JSON document shaped like the public-state
  # response ({ products: [...] }) — the adapter seam, not the manifest.
  $stateDoc = Get-Content $StateSourcePath -Raw | ConvertFrom-Json
  $productStateSource = New-FixtureApiProductStateSource (@($stateDoc.products)) $productRegistry
} else {
  $productStateSource = New-ManifestProductStateSource $manifest $productRegistry
}
$allProductState    = @($productStateSource.GetVisible())
$allModuleState     = @($productStateSource.GetAll())
# The URL/contract policy runs on adapter output so every source — manifest or
# foreign — is held to the same public-state rules before emission.
Assert-PublicStateUrls $allModuleState

function Render-ProductShell($module) {
  # Generic product renderer: assembles the full page shell from module
  # metadata. Narrative markup lives in products/<id>/content.html (injected at
  # the content marker and still flows through the normal token pipeline).
  # Reusable shells (breadcrumb, related-products nav) are generated here —
  # never hand-maintained per product.
  $p = $productStateSource.Get($module.id)
  $name = Html-Attr $p.name
  $crumb = "<nav class=`"product-breadcrumb`" aria-label=`"Breadcrumb`"><a href=`"/#products`">All software</a><span aria-hidden=`"true`">/</span><span>$name</span></nav>"
  $related = "<nav class=`"studio-related`" aria-label=`"More software`"><span>More from the foundry</span>" +
    (($productRegistry | Where-Object { $_.visibility -eq 'visible' -and $_.id -ne $module.id } | ForEach-Object {
      $rp = $productStateSource.Get($_.id); "<a href=`"$($_.route)`">$(Html-Attr $rp.name)</a>" }) -join '') + "</nav>"
  # Module meta fields are authored markup (already HTML-encoded in module.json,
  # same trust level as template literals) — emitted verbatim; escaping is the
  # module author's responsibility, validated by the registry.
  $metaTitle = $module.meta.title
  $metaDesc  = $module.meta.description
  $ogTitle   = if ($module.meta.ogTitle) { $module.meta.ogTitle } else { $module.meta.title }
  $viewport  = if ($module.meta.viewport) { $module.meta.viewport } else { 'width=device-width, initial-scale=1' }
  $robots    = if ($module.meta.robots) { $module.meta.robots } else { 'index, follow' }
  $themeTag  = if ($module.meta.themeColor) { "`n<meta content=`"$($module.meta.themeColor)`" name=`"theme-color`"/>" } else { '' }
  $ogType    = if ($module.meta.ogType) { $module.meta.ogType } else { 'product' }
  $ogImage   = if ($module.meta.ogImage) { $module.meta.ogImage } else { 'https://theprooffoundry.com/brand/proof-foundry-social-card.png' }
  $ogDesc    = if ($module.meta.ogDescription) { $module.meta.ogDescription } else { $metaDesc }
  $twCard    = if ($module.meta.twitterCard) { $module.meta.twitterCard } else { 'summary_large_image' }
  $twImage   = if ($module.meta.twitterImage) { $module.meta.twitterImage } else { $ogImage }
  $twExtra   = ''
  if ($module.meta.twitterTitle) { $twExtra += "`n<meta content=`"$($module.meta.twitterTitle)`" name=`"twitter:title`"/>" }
  if ($module.meta.twitterDescription) { $twExtra += "`n<meta content=`"$($module.meta.twitterDescription)`" name=`"twitter:description`"/>" }
  $jsonLdTag = ''
  if ($module.jsonLd) {
    $jsonLdTag = "`n<!-- Structured data carries identity only. No offers/availability claims. -->`n<script type=`"application/ld+json`">`n" + ($module.jsonLd | ConvertTo-Json -Depth 20) + "`n</script>"
  }
  $inlineCssTag = if ($module.inlineCss) { "`n<style>" + $module.inlineCss + "</style>" } else { '' }
  $shell = @"
<!doctype html>
<!-- @page $($module.id) -->
<!-- @product $($module.id) -->
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta content="$viewport" name="viewport"/>
<title>$metaTitle</title>
<meta content="$metaDesc" name="description"/>
<meta content="$robots" name="robots"/>$themeTag
<link href="https://theprooffoundry.com$($module.route)" rel="canonical"/>
<meta content="$ogTitle" property="og:title"/>
<meta content="$ogDesc" property="og:description"/>
<meta content="$ogType" property="og:type"/>
<meta content="https://theprooffoundry.com$($module.route)" property="og:url"/>
<meta content="The Proof Foundry" property="og:site_name"/>
<meta content="$ogImage" property="og:image"/>
<meta content="$twCard" name="twitter:card"/>$twExtra
<meta content="$twImage" name="twitter:image"/>
<link href="/styles.css" rel="stylesheet"/>
<link rel="stylesheet" href="/studio.css">
<link rel="stylesheet" href="/experience.css">
<link rel="stylesheet" href="/product-page.css">
<link href="/brand/proof-foundry-mark.svg" rel="icon" type="image/svg+xml"/>$jsonLdTag$inlineCssTag
</head>
<body class="studio product-page product-$($module.id) pp-system">
<!-- @include header -->
<!-- @product-content -->
</body></html>
"@
  # Inject the module's narrative content + generated shells at their markers.
  $content = Read-File (Join-Path $script:productsDir "$($module.id)\content.html")
  $content = $content -replace '<!--\s*@product-breadcrumb\s*-->', $crumb
  $content = $content -replace '<!--\s*@product-related\s*-->',    $related
  $shell = $shell -replace '<!--\s*@product-content\s*-->', $content
  return $shell
}

# Map: source file  ->  output path under public/
# Product routes come from the registry; non-product routes stay literal.
$dirRoutes = @('founders','proof','roadmap','support','about','proof-standard','software','truth')
$rootFiles = @('index.html','404.html')

# Pre-compute latest site verification so templates can inject it
$latestVerification = Build-LatestVerification

$headerPartial = Read-File (Join-Path $partialsDir 'header.html')
$footerPartial = Read-File (Join-Path $partialsDir 'footer.html')

function Process-Template($srcPath, $srcName, [string]$OverrideHtml) {
  # H13: when -OverrideHtml is supplied, render that generated markup instead of
  # reading $srcPath — lets Render-ProductShell feed module-built pages through
  # the identical pipeline (tokens, includes, asset versioning, H12 alternate
  # injection, icon, generated-file warning).
  $html = if ($PSBoundParameters.ContainsKey('OverrideHtml') -and $null -ne $OverrideHtml) { $OverrideHtml } else { Read-File $srcPath }

  # Give shared presentation assets content-derived URLs. A cached stylesheet
  # or script must not leave visitors on a previous design after publication.
  foreach ($assetName in @('styles.css', 'studio.css', 'experience.css', 'signature.css', 'product-page.css', 'site.js', 'experience.js', 'h9-homepage.css', 'h9-software.css', 'h9-homepage.js', 'h9-software.js')) {
    $assetPath = Join-Path $root $assetName
    $assetVersion = (Get-FileHash $assetPath -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
    $html = $html.Replace('"/' + $assetName + '"', '"/' + $assetName + '?v=' + $assetVersion + '"')
  }

  # Extract @page id
  $pageId = ''
  if ($html -match '<!--\s*@page\s+(\S+)\s*-->') { $pageId = $Matches[1] }
  $html = $html -replace '<!--\s*@page\s+\S+\s*-->\s*\r?\n?', ''

  # Extract @product slug (binds product tokens)
  $productSlug = ''
  if ($html -match '<!--\s*@product\s+(\S+)\s*-->') { $productSlug = $Matches[1] }
  $html = $html -replace '<!--\s*@product\s+\S+\s*-->\s*\r?\n?', ''

  # H12 reciprocal discovery: a page advertises rel="alternate" only when the
  # target is a true alternate representation of THIS document's meaning —
  # never as generic "related JSON". Binding keys on @page identity == manifest
  # route (never @product — that pragma is token-binding only; index.html binds
  # reality-gate for tokens but IS NOT its page). The only aggregate pair that
  # qualifies is /truth/ ↔ /truth/index.json (direct representation) and
  # /software/ ↔ /truth/index.json (same public catalog, reformulated).
  $truthAlternate = $null
  $pageModule = @($productRegistry | Where-Object { $_.visibility -eq 'visible' -and $_.route -eq "/$pageId/" }) | Select-Object -First 1
  if ($pageModule) {
    $truthAlternate = "/truth/products/$($pageModule.id).json"
  } elseif ($pageId -in @('truth', 'software') -and $html -match 'rel="canonical"') {
    # Canonical-gated: noindex pages (404 reuses @page home for nav state) never
    # advertise machine alternates.
    $truthAlternate = '/truth/index.json'
  }
  if ($truthAlternate) {
    $altTag = "  <link href=`"$truthAlternate`" rel=`"alternate`" title=`"Public Truth`" type=`"application/json`"/>"
    $html = $html -replace '</head>', "$altTag`n</head>"
  }

  # Resolve nav + cta
  $navLinks = Build-NavLinks $pageId
  $navCta = "<a class=`"button button-primary nav-cta`" href=`"$(Html-Attr $manifest.navCta.href)`">$(Html-Attr $manifest.navCta.label)</a>"
  $header = $headerPartial
  $header = $header -replace [regex]::Escape('{{nav-links}}'), $navLinks
  $header = $header -replace [regex]::Escape('{{nav-cta}}'),   $navCta

  $footer = $footerPartial -replace [regex]::Escape('{{footer-products}}'), (Build-FooterProducts)

  # Inject partials
  $html = $html -replace '<!--\s*@include header\s*-->', $header
  $html = $html -replace '<!--\s*@include footer\s*-->', $footer

  # The H9 catalog moved to its own route; preserve frozen page source markup.
  $html = $html.Replace('href="/#products"', 'href="/software/"')

  # Inject product groups (homepage) — grouped sections, then any bare-marker grid
  $html = $html -replace '<!--\s*@product-groups\s*-->', (Build-ProductGroupSections)
  $html = $html -replace '<!--\s*@trust-strip\s*-->',    (Build-TrustStrip)
  $html = $html -replace [regex]::Escape('{{catalogSummary}}'), (Build-CatalogSummary)
  # The standalone catalog includes the featured product as a normal card.
  $catalogCards = (Build-ProductCards $null $true) -replace '<h4 class="card-name">', '<h3 class="card-name">' -replace '</h4>', '</h3>'
  $html = $html -replace '<!--\s*@all-products\s*-->', $catalogCards
  $html = $html -replace '<!--\s*@products\s*-->', (Build-ProductCards $null)

  # Inject receipt cards (receipts page)
  $html = $html -replace '<!--\s*@receipts\s*-->', (Build-ReceiptCards)

  # Public truth index cards (/truth/ page) — same manifest model as the JSON
  $html = $html -replace '<!--\s*@truth-products\s*-->', (Build-TruthIndexCards)

  # Brand-level tokens
  $html = $html -replace [regex]::Escape('{{brand}}'),       (Html-Attr $manifest.brand)
  $html = $html -replace [regex]::Escape('{{tagline}}'),     (Html-Attr $manifest.tagline)
  $html = $html -replace [regex]::Escape('{{positioning}}'), (Html-Attr $manifest.positioning)

  # Latest site verification block
  $em = [char]0x2014
  if ($latestVerification.date) {
    $latestBlock = @"
<p>Latest verification event: <strong>$(Html-Attr $latestVerification.product)</strong> $em $(Html-Attr $latestVerification.event) on <time datetime="$(Html-Attr $latestVerification.date)">$(Html-Attr $latestVerification.date)</time>. Every public surface on this page is generated from the canonical <code class="inline">site-manifest.json</code> release/evidence model.</p>
"@
  } else {
    $latestBlock = @"
<p>No verified site verification event is recorded in the canonical <code class="inline">site-manifest.json</code> release/evidence model.</p>
"@
  }
  $html = $html -replace [regex]::Escape('{{latestVerification.block}}'), $latestBlock

  # Site verification receipt link, from canonical data. Previously the date was a
  # literal in proof.html, so the receipt could silently disagree with the receipt
  # actually shipped (and did: the template said 2026-08-20 while nothing tied that
  # to any manifest value).
  if ($manifest.siteVerification -and $manifest.siteVerification.receiptPath) {
    $rd = $manifest.siteVerification.receiptDate
    # Non-breaking hyphens (U+2011) keep the date atomic at 320-390px, where the
    # label wraps and a normal hyphen would split it ("2026-08-" / "20"). A nowrap
    # span cannot be used here: .button is a flex container, so the span would
    # become a separate flex item and reorder the label.
    $rdDisplay = $rd -replace '-', ([char]0x2011)
    $receiptLink = "<a class=`"button button-secondary`" href=`"$(Html-Attr $manifest.siteVerification.receiptPath)`" target=`"_blank`" rel=`"noopener`">View verification receipt ($(Html-Attr $rdDisplay))</a>"
  } else {
    $receiptLink = ''
  }
  $html = $html -replace [regex]::Escape('{{siteVerification.receiptLink}}'), $receiptLink

  # Named product tokens for pages discussing several products.
  foreach ($namedProduct in $allModuleState) {
    $namedTokens = ProductTokens $namedProduct
    foreach ($key in $namedTokens.Keys) {
      $nv = [string]$namedTokens[$key]
      if ($script:MarkupProductTokens -notcontains $key) { $nv = Html-Attr $nv }
      $html = $html.Replace('{{products.' + $namedProduct.id + '.' + $key + '}}', $nv)
    }
  }
  if ($html -match '\{\{products\.[^}]+\}\}') { throw "Unresolved named product token in $srcName" }

  # Product tokens (if bound)
  if ($productSlug) {
    $bound = $null
    $bound = $productStateSource.Get($productSlug)
    if (-not $bound) { throw "Template $srcName binds @product $productSlug but no such product in manifest" }
    $tokens = ProductTokens $bound
    $html = Replace-ProductTokens $html $tokens -Strict
  } else {
    $html = Replace-ProductTokens $html @{}
  }

  # Avoid implicit /favicon.ico requests while preserving each page's explicit icon.
  $head = [regex]::Match($html, '(?is)<head\b[^>]*>.*?</head>')
  if (-not $head.Success) { throw "Missing HTML head in $srcName" }
  $iconLinks = @([regex]::Matches($head.Value, '(?is)<link\b[^>]*\brel\s*=\s*["'']([^"'']*)["'']') | Where-Object { ($_.Groups[1].Value -split '\s+') -contains 'icon' })
  if ($iconLinks.Count -eq 0) {
    $defaultIcon = '<link href="/brand/proof-foundry-mark.svg" rel="icon" type="image/svg+xml"/>' + "`n"
    $headWithIcon = [regex]::Replace($head.Value, '(?i)</head>', $defaultIcon + '</head>')
    $html = $html.Remove($head.Index, $head.Length).Insert($head.Index, $headWithIcon)
  }

  # Generated-file warning (after doctype)
  $warning = "<!-- GENERATED FILE - DO NOT EDIT. Source: $srcName + site-manifest.json. Run scripts/build-site.ps1 to rebuild. -->`r`n"
  $html = $html -replace '(<!doctype[^>]*>\s*\r?\n)', "`$1$warning"

  return $html
}

# Root files
foreach ($f in $rootFiles) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { continue }
  $out = Process-Template $src $f
  $outPath = Join-Path $publicDir $f
  [System.IO.File]::WriteAllText($outPath, $out, [System.Text.Encoding]::UTF8)
}

# Directory-route files
foreach ($slug in $dirRoutes) {
  $src = Join-Path $root "$slug.html"
  if (-not (Test-Path $src)) { continue }
  $out = Process-Template $src "$slug.html"
  $dir = Join-Path $publicDir $slug
  New-Item -ItemType Directory $dir -Force | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $dir 'index.html'), $out, [System.Text.Encoding]::UTF8)
}

# H13 product routes — generated by the generic renderer from module registry +
# state adapter. Route == module.route (legacy URLs preserved by construction).
foreach ($module in ($productRegistry | Where-Object { $_.visibility -eq 'visible' })) {
  $shell = Render-ProductShell $module
  $out = Process-Template $null "products/$($module.id)/module.json+content.html" -OverrideHtml $shell
  $dir = Join-Path $publicDir $module.id
  New-Item -ItemType Directory $dir -Force | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $dir 'index.html'), $out, [System.Text.Encoding]::UTF8)
}

# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# Generate machine-readable proof registry
# ─────────────────────────────────────────────────────────────────────────────
$proofDir = Join-Path $publicDir 'proof'
New-Item -ItemType Directory $proofDir -Force | Out-Null
$registry = Build-ProofRegistry
$registryJson = $registry | ConvertTo-Json -Depth 10
$noBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $proofDir 'index.json'), $registryJson, $noBom)
Write-Host "==> Generated proof registry: /proof/index.json" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Public truth surface (H11): deterministic, sanitized, versioned JSON contract.
# ─────────────────────────────────────────────────────────────────────────────
$truthSource = Get-SourceIdentity
$truth = Build-PublicTruth $truthSource
$truthDir = Join-Path $publicDir 'truth'
$truthProductsDir = Join-Path $truthDir 'products'
New-Item -ItemType Directory $truthProductsDir -Force | Out-Null

$truthIndexJson = $truth.index | ConvertTo-Json -Depth 12
Test-PublicTruthSafe $truthIndexJson 'truth/index.json'
[System.IO.File]::WriteAllText((Join-Path $truthDir 'index.json'), ($truthIndexJson + "`n"), $noBom)
foreach ($doc in $truth.products) {
  $docJson = $doc | ConvertTo-Json -Depth 12
  Test-PublicTruthSafe $docJson "truth/products/$($doc.id).json"
  [System.IO.File]::WriteAllText((Join-Path $truthProductsDir "$($doc.id).json"), ($docJson + "`n"), $noBom)
}
Copy-Item (Join-Path $root 'schemas\public-truth-v1.schema.json') (Join-Path $truthDir 'schema-v1.json') -Force
Write-Host "==> Generated public truth: /truth/index.json + $($truth.products.Count) product records + schema-v1.json" -ForegroundColor Green

# Copy static assets
# ─────────────────────────────────────────────────────────────────────────────
Copy-Item (Join-Path $root 'styles.css')     $publicDir -Force
Copy-Item (Join-Path $root 'studio.css')     $publicDir -Force
Copy-Item (Join-Path $root 'experience.css') $publicDir -Force
Copy-Item (Join-Path $root 'signature.css')  $publicDir -Force
Copy-Item (Join-Path $root 'product-page.css') $publicDir -Force
Copy-Item (Join-Path $root 'experience.js') $publicDir -Force
if (Test-Path (Join-Path $root 'h9-homepage.css')) { Copy-Item (Join-Path $root 'h9-homepage.css') $publicDir -Force }
if (Test-Path (Join-Path $root 'h9-software.css')) { Copy-Item (Join-Path $root 'h9-software.css') $publicDir -Force }
if (Test-Path (Join-Path $root 'h9-homepage.js'))  { Copy-Item (Join-Path $root 'h9-homepage.js')  $publicDir -Force }
if (Test-Path (Join-Path $root 'h9-software.js'))  { Copy-Item (Join-Path $root 'h9-software.js')  $publicDir -Force }
if (Test-Path (Join-Path $root 'site.js'))   { Copy-Item (Join-Path $root 'site.js') $publicDir -Force }
Copy-Item (Join-Path $root 'CNAME')          $publicDir -Force
Copy-Item (Join-Path $root 'robots.txt')     $publicDir -Force
Copy-Item (Join-Path $root 'sitemap.xml')    $publicDir -Force
Copy-Item (Join-Path $root 'site-manifest.json') $publicDir -Force
Copy-Item (Join-Path $root 'brand')  $publicDir -Recurse -Force
Copy-Item (Join-Path $root 'assets') $publicDir -Recurse -Force

# assets/ ships published imagery only. Capture tooling has previously dropped
# diagnostic dumps here that carry local machine paths, so strip that class of
# file from the public output and say so out loud rather than shipping it.
$diagLeaks = @(Get-ChildItem (Join-Path $publicDir 'assets') -Recurse -File -Include '*-diag.json', '*.diag.json' -ErrorAction SilentlyContinue)
foreach ($leak in $diagLeaks) {
  Remove-Item $leak.FullName -Force
  Write-Host "    excluded diagnostic artifact from public output: $($leak.Name)" -ForegroundColor Yellow
}

# Expose deploy receipts publicly
if (Test-Path (Join-Path $root 'reports/deploy-receipts')) {
  $receiptsOut = Join-Path $publicDir 'reports/deploy-receipts'
  New-Item -ItemType Directory $receiptsOut -Force | Out-Null
  Copy-Item -Path (Join-Path $root 'reports/deploy-receipts\*') -Destination $receiptsOut -Recurse -Force
}

# ─────────────────────────────────────────────────────────────────────────────
# Generate _headers
#
# Cache-policy contract (2026-09-10): the former /assets/* and /brand/* rules
# shipped a one-year `immutable` contract for stable, human-readable filenames
# that are NOT content-fingerprinted. Replacing such a file could not propagate
# to any browser that had cached it (the 2026-09-10 stale-screenshot incident),
# so mutable names must never carry `immutable`. Zero fingerprinted asset
# filenames ship today, so no `immutable` rule is warranted at all: every
# asset revalidates, and replaced bytes propagate on the next fetch. If a
# content-fingerprinting convention is ever introduced, give ONLY that
# fingerprinted subset a long `immutable` rule and leave every mutable stable
# name on the revalidation policy below.
# ─────────────────────────────────────────────────────────────────────────────
# Route rules derive from the registry + literal dir routes — no product list.
$headerRoutes = @(foreach ($r in ($dirRoutes + @($productRegistry | Where-Object { $_.visibility -eq 'visible' } | ForEach-Object { $_.id }))) { "/$r/`n  Cache-Control: no-cache, must-revalidate" })
$headersContent = @"
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/*.html
  Cache-Control: no-cache, must-revalidate

$($headerRoutes -join "`n")
/truth/*
  Cache-Control: no-cache, must-revalidate

/assets/*
  Cache-Control: public, max-age=0, must-revalidate

/brand/*
  Cache-Control: public, max-age=0, must-revalidate
"@
# utf8NoBOM explicitly: a BOM at the start of _headers would be read as part of the
# first rule and silently void it. PowerShell 7's -Encoding UTF8 is already BOM-less,
# but 5.1's is not, so state it rather than depend on the host version.
[System.IO.File]::WriteAllText((Join-Path $publicDir '_headers'), $headersContent, (New-Object System.Text.UTF8Encoding $false))

# Copy _redirects from root
Copy-Item (Join-Path $root '_redirects') $publicDir -Force

$productCount = $allProductState.Count
Write-Host "==> Build complete: public/ regenerated. $productCount visible products, $($dirRoutes.Count) directory routes." -ForegroundColor Green
exit 0
