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
  [string]$OutDir
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$root = (Resolve-Path "$PSScriptRoot/..").Path
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

  # Internal route (starts with /) must have a source template {id}.html
  if ($p.route -like '/*') {
    $src = Join-Path $root ("$($p.id).html")
    if (-not (Test-Path $src)) { $errors += "$tag internal route $($p.route) but no template $($p.id).html" }
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
      $gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
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
foreach ($tpl in @(Get-ChildItem -Path $root -Filter '*.html' -File)) {
  $tplText = [System.IO.File]::ReadAllText($tpl.FullName)
  foreach ($m in [regex]::Matches($tplText, '(?<![0-9a-fA-F])[0-9a-fA-F]{64}(?![0-9a-fA-F])')) {
    $key = $m.Value.ToLowerInvariant()
    if ($canonicalDigests.ContainsKey($key)) {
      $useToken = if ($canonicalDigests.ContainsKey("token:$key")) { $canonicalDigests["token:$key"] } else { '{{product.artifactSha256}}' }
      $errors += "[template] $($tpl.Name) hardcodes the canonical SHA-256 of $($canonicalDigests[$key]); replace the literal with $useToken so the digest cannot drift from the manifest"
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

function Html-Attr($s) { return ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;') }

function IsExternalUrl($url) {
  return $url -like 'http://*' -or $url -like 'https://*'
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
  $tokens['version']             = $p.version
  $tokens['meta']                = MetaLine $p
  $tokens['statusLine']          = StatusLine $p
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

  # proofStrip — typed status + version + platform + tests + verification dimension summary
  $pills = @()
  $pills += "<span class=`"proof-pill`"><strong>Status</strong> $($tokens['statusLabel'])</span>"
  $ver = if ($tokens['versionLabel']) { $tokens['versionLabel'] } else { '&mdash;' }
  $pills += "<span class=`"proof-pill`"><strong>Version</strong> $ver</span>"
  if ($canVer -and $canVer -ne $pubVer) {
    $candidateLabel = if ($p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE') { 'Next' } else { 'Candidate' }
    $pills += "<span class=`"proof-pill`"><strong>$candidateLabel</strong> v$canVer</span>"
  }
  $pills += "<span class=`"proof-pill`"><strong>Platform</strong> $($tokens['platform'])</span>"
  if ($tokens['testStatus']) {
    $pills += "<span class=`"proof-pill`"><strong>Tests</strong> $($tokens['testStatus'])</span>"
  }
  $pills += "<span class=`"proof-pill`"><strong>Proof</strong> $($tokens['proofStatus'])</span>"
  if ($tokens['lastVerified']) {
    $pills += "<span class=`"proof-pill`"><strong>Verified</strong> $($tokens['lastVerified'])</span>"
  }
  $tokens['proofStrip'] = "<div class=`"proof-strip`">" + ($pills -join "`n          ") + "</div>"

  # downloadBlock — derive from canonical artifact if available, else legacy fields
  $dlUrl = if ($tokens['artifactDownloadUrl']) { $tokens['artifactDownloadUrl'] } else { $p.downloadUrl }
  if ([string]::IsNullOrWhiteSpace($dlUrl)) {
    $mutedLabel = if (-not [string]::IsNullOrWhiteSpace($p.disabledDownloadLabel)) { $p.disabledDownloadLabel }
                  elseif ($p.state -eq 'proof') { 'No public build yet' }
                  else { 'Coming soon' }
    $tokens['downloadBlock'] = "<span class=`"button button-muted`" aria-disabled=`"true`">$mutedLabel</span>"
  } else {
    $url = $dlUrl
    $label = if ($p.downloadLabel) { $p.downloadLabel } else { 'Download' }
    $extAttr = ''
    $dlAttr = ''
    if (IsExternalUrl $url) { $extAttr = ' target="_blank" rel="noopener"' }
    if (IsFileDownload $url) { $dlAttr = ' download' }
    $tokens['downloadBlock'] = "<a class=`"button button-primary`" href=`"$url`"$extAttr$dlAttr>$label</a>"
    $sha256Link = if ($tokens['artifactSha256Url']) { $tokens['artifactSha256Url'] } else { $p.sha256Url }
    if (-not [string]::IsNullOrWhiteSpace($sha256Link)) {
      $tokens['downloadBlock'] += " <a class=`"button button-secondary`" href=`"$sha256Link`" target=`"_blank`" rel=`"noopener`">SHA-256</a>"
    }
  }

  # hashBlock — full primary artifact SHA-256 with copy control wrapper
  $primarySha = if ($tokens['artifactSha256']) { $tokens['artifactSha256'] } else { $p.sha256 }
  if (-not [string]::IsNullOrWhiteSpace($primarySha)) {
    $tokens['hashBlock'] = @"
<div class="code-block sha256-block" data-sha256="$primarySha">
  <code class="sha256-value">$primarySha</code>
  <button type="button" class="sha256-copy" aria-label="Copy SHA-256" title="Copy SHA-256">Copy</button>
</div>
<p class="note">Windows verification: <code class="inline">Get-FileHash ".\$($tokens['artifactFilename'])" -Algorithm SHA256</code></p>
"@
  } else {
    $tokens['hashBlock'] = ''
  }

  # releaseNoteBlock
  if (-not [string]::IsNullOrWhiteSpace($p.releaseNote)) {
    $tokens['releaseNoteBlock'] = "<p class=`"note`">$($p.releaseNote)</p>"
  } else {
    $tokens['releaseNoteBlock'] = ''
  }

  # limits as HTML (for optional product-page token)
  if ($p.limits -and $p.limits.Count -gt 0) {
    $limItems = $p.limits | ForEach-Object { "<li>$_</li>" }
    $tokens['limitsBlock'] = "<ul class=`"limits-list`">" + ($limItems -join '') + "</ul>"
  } else {
    $tokens['limitsBlock'] = ''
  }

  return $tokens
}

# Apply {{product.X}} substitution to a string given a tokens hashtable
function Replace-ProductTokens($text, $tokens, [switch]$Strict) {
  foreach ($key in $tokens.Keys) {
    $text = $text -replace [regex]::Escape("{{product.$key}}"), $tokens[$key]
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
  # Product pages map to the "products" nav item
  $productIds = @()
  foreach ($p in $manifest.products) { $productIds += $p.id }
  if ($productIds -contains $activeId) { $activeId = 'products' }

  $links = @()
  foreach ($item in $manifest.nav) {
    $cur = ''
    if ($item.id -eq $activeId) { $cur = ' aria-current="page"' }
    $links += "<a href=`"$($item.href)`"$cur>$($item.label)</a>"
  }
  return ($links -join "`n        ")
}

function Build-FooterProducts {
  $items = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    $items += "<li><a href=`"$($p.route)`">$($p.name)</a></li>"
  }
  return ($items -join "`n          ")
}

function Build-ProductCards {
  $cardTemplate = Read-File (Join-Path $partialsDir 'product-card.html')
  $cards = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    # Reality Gate is featured above the software grid as the studio platform anchor
    if ($p.id -eq 'reality-gate') { continue }
    $t = ProductTokens $p
    $card = $cardTemplate
    $card = $card -replace [regex]::Escape('{{name}}'),         $t['name']
    $card = $card -replace [regex]::Escape('{{route}}'),        $t['route']
    $card = $card -replace [regex]::Escape('{{state}}'),        $t['state']
    $card = $card -replace [regex]::Escape('{{statusLabel}}'),  $t['statusLabel']
    $card = $card -replace [regex]::Escape('{{summary}}'),      $t['summary']
    $card = $card -replace [regex]::Escape('{{cardSummary}}'),  $t['cardSummary']
    $card = $card -replace [regex]::Escape('{{statusLine}}'),   $t['statusLine']
    $card = $card -replace [regex]::Escape('{{markSvg}}'),      $t['markSvg']
    $card = $card -replace [regex]::Escape('{{id}}'),           $t['id']
    $card = $card -replace [regex]::Escape('{{meta}}'),         $t['meta']
    $card = $card -replace [regex]::Escape('{{cta}}'),          $t['cta']
    $cards += $card
  }
  return ($cards -join "`n`n          ")
}

function Build-ProofRegistry {
  # Emit a canonical, machine-readable proof registry as a PowerShell object.
  $entries = @()
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
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

function Build-LatestVerification {
  # Return a generated "latest site verification" summary based on the most recent
  # verification.verifiedAt or release.publishedAt across all visible products.
  # Returns null properties when no evidence exists so the template cannot
  # fabricate a "Latest" claim.
  $latestDate = $null
  $latestProduct = $null
  $latestEvent = $null
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
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
      $hasDownload = ($p.artifacts -and ($p.artifacts | Where-Object { $_.downloadUrl }).Count -gt 0) -or $p.downloadUrl
      $value = if ($hasDownload) { 'VERIFIED' } else { 'NOT_PUBLISHED' }
      $cssClass = if ($hasDownload) { 'verified' } else { 'not-published' }
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
  foreach ($p in $manifest.products) {
    if (-not $p.visible) { continue }
    $t = ProductTokens $p

    # status text and CSS class from canonical productStatus
    $ps = if ($p.productStatus) { $manifest.statusTaxonomy.$($p.productStatus) } else { if ($p.proofStatus) { $p.proofStatus } else { 'verification pending' } }
    $statusClass = if ($p.productStatus) { $p.productStatus.ToLower() } else { ($p.state -replace ' ', '-') }

    # route link
    if ($p.route -like 'http*') {
      $routeLink = "<a href=`"$($p.route)`" target=`"_blank`" rel=`"noopener`">External link</a>"
    } elseif ($p.route -like '/*') {
      $routeLink = "<a href=`"$($p.route)`">$($p.route)</a>"
    } else {
      $routeLink = '<span style="color:var(--muted);">N/A</span>'
    }

    # public version / candidate version
    $publicVer = if ($p.release -and $p.release.publicVersion) { $p.release.publicVersion } else { $p.version }
    $candidateVer = if ($p.release -and $p.release.candidateVersion) { $p.release.candidateVersion } else { '' }
    if ($publicVer) {
      $verHtml = "<dd>v$publicVer</dd>"
      if ($candidateVer -and $candidateVer -ne $publicVer) {
        $candidateLabel = if ($p.release -and $p.release.releaseStatus -eq 'PUBLIC_RELEASE') { 'Next' } else { 'Candidate' }
        $verHtml += "<dd class='candidate-version'>$candidateLabel v$candidateVer</dd>"
      }
    } else {
      $verHtml = '<dd style="color:var(--muted);">Unreleased</dd>'
    }

    # primary artifact + full SHA-256
    $primaryArtifact = $null
    if ($p.artifacts) { foreach ($a in $p.artifacts) { if (-not [string]::IsNullOrWhiteSpace($a.sha256)) { $primaryArtifact = $a; break } } }
    if (-not $primaryArtifact -and $p.sha256) { $primaryArtifact = @{ filename = if ($t['artifactFilename']) { $t['artifactFilename'] } else { '' }; sha256 = $p.sha256; downloadUrl = $p.downloadUrl; sha256Url = $p.sha256Url } }

    if ($primaryArtifact -and $primaryArtifact.sha256) {
      $fn = if ($primaryArtifact.filename) { $primaryArtifact.filename } else { 'Artifact' }
      # Name the build this checksum covers. The card's "Public version" row sits a
      # few lines above, so an unattributed hash reads as the public release's
      # checksum. For a product on HOLD (Lights Out: public v11.1.2, artifacts
      # v11.1.3) that would be a false public claim, so say which build it is.
      $artifactVersions = @([regex]::Matches("$($primaryArtifact.filename) $($primaryArtifact.downloadUrl)", '(?<![\d.])(\d+\.\d+\.\d+)(?![\d.])') |
                            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      $scopeNote = ''
      if ($publicVer -and $artifactVersions.Count -gt 0 -and ($artifactVersions -notcontains $publicVer)) {
        $scopeLabel = if ($candidateVer -and ($artifactVersions -contains $candidateVer)) { "candidate v$candidateVer" } else { "v$($artifactVersions[0])" }
        $scopeNote = " <span class=`"sha256-scope`">$scopeLabel &mdash; not the public v$publicVer</span>"
      }
      $shaBlock = @"
        <p class="sha256-file">Checksum covers <span class="sha256-filename">$fn</span>$scopeNote</p>
        <div class="sha256-block" data-sha256="$($primaryArtifact.sha256)">
          <code class="sha256-value">$($primaryArtifact.sha256)</code>
          <button type="button" class="sha256-copy" aria-label="Copy SHA-256 for $fn" title="Copy SHA-256">Copy</button>
        </div>
        <p class="sha256-prefix-note">SHA-256 prefix: <span class="code" title="$($primaryArtifact.sha256)">$($primaryArtifact.sha256.Substring(0,16))&hellip;</span></p>
"@
    } else {
      $shaBlock = '<p style="color:var(--muted);">No public artifact hash.</p>'
    }

    # typed verification matrix
    $matrixDims = @('ARTIFACT_HASH_PUBLISHED','ARTIFACT_HASH_VERIFIED','ARTIFACT_CUSTODY','RUNTIME_VALIDATION','REALITY_GATE','PUBLIC_DOWNLOAD','CODE_SIGNING','RELEASE_AUTHORIZATION','PUBLICATION_STATUS')
    $matrixRows = @()
    foreach ($dim in $matrixDims) {
      $r = Get-VerificationStatus $dim $p
      $matrixRows += "<div><dt>$($r[0])</dt><dd class=`"status-$($r[2])`">$($r[1])</dd></div>"
    }
    $matrix = "<dl class='receipt-fields verification-matrix'>" + ($matrixRows -join '') + "</dl>"

    # evidence links from canonical evidence and legacy proofLinks
    $evidenceLinks = @()
    $seenEvidence = @{}
    if ($p.evidence) {
      foreach ($e in $p.evidence) {
        if ($e.url -and -not $seenEvidence.ContainsKey($e.url)) {
          $evidenceLinks += "<a href=`"$($e.url)`" target=`"_blank`" rel=`"noopener`">$($e.label)</a>"
          $seenEvidence[$e.url] = $true
        }
      }
    }
    if ($p.proofLinks -and $p.proofLinks.Count -gt 0) {
      foreach ($link in $p.proofLinks) {
        if ($link -and -not $seenEvidence.ContainsKey($link)) {
          $base = $link -split '/' | Select-Object -Last 1
          $evidenceLinks += "<a href=`"$link`" target=`"_blank`" rel=`"noopener`">$base</a>"
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
      $timestamps[-1] += " $em $($p.verification.verifiedAt)"
    }
    if ($p.release -and $p.release.publishedAt) { $timestamps += "Published $em $($p.release.publishedAt)" }
    if ($p.lastVerified -and (-not $p.verification -or -not $p.verification.verifiedAt)) { $timestamps += "Last verified $em $($p.lastVerified)" }
    $timestampHtml = if ($timestamps.Count -gt 0) { "<dd>$($timestamps -join '<br>')</dd>" } else { '<dd style="color:var(--muted);">N/A</dd>' }

    # limits
    $limitsHtml = ''
    if ($p.limits -and $p.limits.Count -gt 0) {
      $limItems = $p.limits | ForEach-Object { "<li>$_</li>" }
      $limitsHtml = "<ul class='limits-list'>" + ($limItems -join '') + "</ul>"
    }

    # download action
    $dlUrl = if ($primaryArtifact -and $primaryArtifact.downloadUrl) { $primaryArtifact.downloadUrl } else { $p.downloadUrl }
    if ([string]::IsNullOrWhiteSpace($dlUrl)) {
      $label = if ($p.state -eq 'proof') { 'No public download yet' } else { 'Download coming soon' }
      $action = "<span class=`"button button-muted`" style=`"display:block; text-align:center;`" aria-disabled=`"true`">$label</span>"
    } else {
      $ext = if (IsExternalUrl $dlUrl) { ' target="_blank" rel="noopener"' } else { '' }
      $dl = if (IsFileDownload $dlUrl) { ' download' } else { '' }
      $action = "<a class=`"button button-primary`" style=`"display:block; text-align:center;`" href=`"$dlUrl`"$ext$dl>$($t['downloadLabel'])</a>"
    }

    $build = if ($p.build) { $p.build } else { 'Release details coming soon.' }

    $cards += @"
        <article class="receipt-card" data-status="$($p.productStatus)" data-platform="$($t['platform'])">
          <div class="receipt-card-head">
            <div>
              <h3>$($t['name'])</h3>
              <span class="platform-badge">$($t['platform'])</span>
            </div>
            <span class="status-indicator $statusClass">$ps</span>
          </div>
          <p class="build-desc">$build</p>

          <div class="receipt-section">
            <h4 class="receipt-section-title">Release</h4>
            <dl class="receipt-fields">
              <div><dt>Route</dt><dd>$routeLink</dd></div>
              <div><dt>Public version</dt>$verHtml</div>
              <div><dt>Release state</dt><dd>$($t['releaseStatus'])</dd></div>
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
# Map: source file  ->  output path under public/
$dirRoutes = @('reality-gate','forgecast','lights-out','cache-vault','cleanroom','ghostlayer','proofshot','founders','proof','roadmap')
$rootFiles = @('index.html','404.html')

# Pre-compute latest site verification so templates can inject it
$latestVerification = Build-LatestVerification

$headerPartial = Read-File (Join-Path $partialsDir 'header.html')
$footerPartial = Read-File (Join-Path $partialsDir 'footer.html')

function Process-Template($srcPath, $srcName) {
  $html = Read-File $srcPath

  # Extract @page id
  $pageId = ''
  if ($html -match '<!--\s*@page\s+(\S+)\s*-->') { $pageId = $Matches[1] }
  $html = $html -replace '<!--\s*@page\s+\S+\s*-->\s*\r?\n?', ''

  # Extract @product slug (binds product tokens)
  $productSlug = ''
  if ($html -match '<!--\s*@product\s+(\S+)\s*-->') { $productSlug = $Matches[1] }
  $html = $html -replace '<!--\s*@product\s+\S+\s*-->\s*\r?\n?', ''

  # Resolve nav + cta
  $navLinks = Build-NavLinks $pageId
  $navCta = "<a class=`"button button-primary nav-cta`" href=`"$($manifest.navCta.href)`">$($manifest.navCta.label)</a>"
  $header = $headerPartial
  $header = $header -replace [regex]::Escape('{{nav-links}}'), $navLinks
  $header = $header -replace [regex]::Escape('{{nav-cta}}'),   $navCta

  $footer = $footerPartial -replace [regex]::Escape('{{footer-products}}'), (Build-FooterProducts)

  # Inject partials
  $html = $html -replace '<!--\s*@include header\s*-->', $header
  $html = $html -replace '<!--\s*@include footer\s*-->', $footer

  # Inject product cards (homepage)
  $html = $html -replace '<!--\s*@products\s*-->', (Build-ProductCards)

  # Inject receipt cards (receipts page)
  $html = $html -replace '<!--\s*@receipts\s*-->', (Build-ReceiptCards)

  # Brand-level tokens
  $html = $html -replace [regex]::Escape('{{brand}}'),       $manifest.brand
  $html = $html -replace [regex]::Escape('{{tagline}}'),     $manifest.tagline
  $html = $html -replace [regex]::Escape('{{positioning}}'), $manifest.positioning

  # Latest site verification block
  $em = [char]0x2014
  if ($latestVerification.date) {
    $latestBlock = @"
<p>Latest verification event: <strong>$($latestVerification.product)</strong> $em $($latestVerification.event) on <time datetime="$($latestVerification.date)">$($latestVerification.date)</time>. Every public surface on this page is generated from the canonical <code class="inline">site-manifest.json</code> release/evidence model.</p>
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
    $receiptLink = "<a class=`"button button-secondary`" href=`"$($manifest.siteVerification.receiptPath)`" target=`"_blank`" rel=`"noopener`">View verification receipt ($rdDisplay)</a>"
  } else {
    $receiptLink = ''
  }
  $html = $html -replace [regex]::Escape('{{siteVerification.receiptLink}}'), $receiptLink

  # Product tokens (if bound)
  if ($productSlug) {
    $bound = $null
    foreach ($p in $manifest.products) { if ($p.id -eq $productSlug) { $bound = $p; break } }
    if (-not $bound) { throw "Template $srcName binds @product $productSlug but no such product in manifest" }
    $tokens = ProductTokens $bound
    $html = Replace-ProductTokens $html $tokens -Strict
  } else {
    $html = Replace-ProductTokens $html @{}
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

# Copy static assets
# ─────────────────────────────────────────────────────────────────────────────
Copy-Item (Join-Path $root 'styles.css')     $publicDir -Force
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
# ─────────────────────────────────────────────────────────────────────────────
$headersContent = @"
/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/*.html
  Cache-Control: no-cache, must-revalidate

/reality-gate/
  Cache-Control: no-cache, must-revalidate
/forgecast/
  Cache-Control: no-cache, must-revalidate
/lights-out/
  Cache-Control: no-cache, must-revalidate
/cache-vault/
  Cache-Control: no-cache, must-revalidate
/cleanroom/
  Cache-Control: no-cache, must-revalidate
/ghostlayer/
  Cache-Control: no-cache, must-revalidate
/proofshot/
  Cache-Control: no-cache, must-revalidate
/founders/
  Cache-Control: no-cache, must-revalidate
/proof/
  Cache-Control: no-cache, must-revalidate
/roadmap/
  Cache-Control: no-cache, must-revalidate

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/brand/*
  Cache-Control: public, max-age=31536000, immutable
"@
# utf8NoBOM explicitly: a BOM at the start of _headers would be read as part of the
# first rule and silently void it. PowerShell 7's -Encoding UTF8 is already BOM-less,
# but 5.1's is not, so state it rather than depend on the host version.
[System.IO.File]::WriteAllText((Join-Path $publicDir '_headers'), $headersContent, (New-Object System.Text.UTF8Encoding $false))

# Copy _redirects from root
Copy-Item (Join-Path $root '_redirects') $publicDir -Force

$productCount = ($manifest.products | Where-Object { $_.visible }).Count
Write-Host "==> Build complete: public/ regenerated. $productCount visible products, $($dirRoutes.Count) directory routes." -ForegroundColor Green
exit 0
