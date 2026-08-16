param(
  [string]$Ver = "",
  [string]$RepoRoot = "",
  [switch]$Draft
)

# Creates a GitHub Release for v<Ver> with the CHANGELOG section as the body.
# Requires the gh CLI and an authenticated session. The tag must exist.

if (-not $RepoRoot) { $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") }
if (-not $Ver) {
  $versionFile = Join-Path $RepoRoot "VERSION"
  if (-not (Test-Path $versionFile)) { Write-Error "VERSION file not found: $versionFile"; exit 1 }
  $Ver = (Get-Content -Raw $versionFile).Trim()
}

$body = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "read-changelog-section.ps1") $Ver
if ($LASTEXITCODE -ne 0) { Write-Error "Could not read changelog section for $Ver"; exit 1 }

$tag = "v$Ver"
Push-Location $RepoRoot
try {
  $exists = (& git rev-parse --verify -q "$tag" 2>$null)
  if (-not $exists) { Write-Error "Tag $tag does not exist; create it first (create-tag.ps1)."; exit 1 }

  $releaseArgs = @("release", "create", $tag, "--title", "Release $tag", "--notes", $body)
  if ($Draft) { $releaseArgs += "--draft" }
  & gh @releaseArgs
  if ($LASTEXITCODE -ne 0) { Write-Error "gh release create failed"; exit 1 }
  Write-Host "create-release: created GitHub release $tag." -ForegroundColor Green
  exit 0
} finally {
  Pop-Location
}
