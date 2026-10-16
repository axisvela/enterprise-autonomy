param(
  [string]$Root = ""
)

if (-not $Root) { $Root = Resolve-Path (Join-Path $PSScriptRoot "..") }

# Decides whether a new tag/version is warranted. Run after commits (or in CI).
# Exit codes:
#   0 - no commits since the last tag (nothing to release)
#   1 - commits exist since the last tag: a new version/tag is warranted
#       (also returned when the current VERSION is already tagged, so the
#        release workflow skips instead of failing verify-release)
#   2 - commits exist, VERSION is untagged, and VERSION/CHANGELOG are prepared

$git = "git"
Push-Location $Root
try {
  $lastTagRaw = (& $git describe --tags --abbrev=0 2>$null)
  $lastTag = if ($lastTagRaw) { ($lastTagRaw | Select-Object -First 1).Trim() } else { "<none>" }

  $count = 0
  if ($lastTag -ne "<none>") {
    $count = [int]((& $git rev-list --count "$lastTag..HEAD" 2>$null).Trim())
  } else {
    $count = [int]((& $git rev-list --count HEAD 2>$null).Trim())
  }

  $versionFile = Join-Path $Root "VERSION"
  $version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "<missing>" }

  $changelog = Join-Path $Root "CHANGELOG.md"
  $versionPrepared = $false
  if (Test-Path $changelog) {
    $content = Get-Content $changelog -Raw
    $versionPrepared = ($content -match "##\s+$([regex]::Escape($version))\s*\(") -or ($content -match "##\s+Unreleased")
  }

  # A version whose tag already exists has already been released; it is not a
  # new release candidate even if commits have landed since.
  $tagExists = $false
  if ($version -match '^[0-9]+\.[0-9]+\.[0-9]+$') {
    $tagExists = [bool](& $git rev-parse --verify -q "v$version" 2>$null)
  }

  Write-Host "check-release: last tag       = $lastTag"
  Write-Host "check-release: commits since  = $count"
  Write-Host "check-release: VERSION        = $version"
  Write-Host "check-release: tag exists     = $tagExists"
  Write-Host "check-release: changelog ready= $versionPrepared"

  if ($count -eq 0) {
    Write-Host "check-release: no commits since the last tag; no new release needed." -ForegroundColor Green
    exit 0
  }
  if ($tagExists) {
    Write-Host "check-release: v$version is already tagged; bump VERSION for a new release." -ForegroundColor Yellow
    exit 1
  }
  if ($versionPrepared) {
    Write-Host "check-release: $count commit(s) since $lastTag and $version is prepared. Tag and release." -ForegroundColor Green
    exit 2
  }
  Write-Host "check-release: $count commit(s) since $lastTag. Bump VERSION, add a CHANGELOG entry, then tag." -ForegroundColor Yellow
  exit 1
} finally {
  Pop-Location
}
