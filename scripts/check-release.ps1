param(
  [string]$Root = ""
)

if (-not $Root) { $Root = Resolve-Path (Join-Path $PSScriptRoot "..") }

# Decides whether a new tag/version is warranted. Run after commits (or in CI).
# Exit codes:
#   0 - no commits since the last tag (nothing to release)
#   1 - commits exist since the last tag: a new version/tag is warranted
#   2 - commits exist and VERSION/CHANGELOG are already prepared for the release

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

  Write-Host "check-release: last tag       = $lastTag"
  Write-Host "check-release: commits since  = $count"
  Write-Host "check-release: VERSION        = $version"
  Write-Host "check-release: changelog ready= $versionPrepared"

  if ($count -eq 0) {
    Write-Host "check-release: no commits since the last tag; no new release needed." -ForegroundColor Green
    exit 0
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
