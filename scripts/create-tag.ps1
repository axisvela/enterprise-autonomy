param(
  [string]$Ver = "",
  [string]$RepoRoot = ""
)

# Creates the annotated release tag v<Ver> from the VERSION file (or an
# explicit version). No-op when the tag already exists. Requires git.

if (-not $RepoRoot) { $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") }
if (-not $Ver) {
  $versionFile = Join-Path $RepoRoot "VERSION"
  if (-not (Test-Path $versionFile)) { Write-Error "VERSION file not found: $versionFile"; exit 1 }
  $Ver = (Get-Content -Raw $versionFile).Trim()
}
if ($Ver -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Write-Error "Version must be major.minor.patch, got '$Ver'"; exit 1 }

$tag = "v$Ver"
Push-Location $RepoRoot
try {
  $exists = (& git rev-parse --verify -q "$tag" 2>$null)
  if ($exists) {
    Write-Host "create-tag: tag $tag already exists; nothing to do." -ForegroundColor Yellow
    exit 0
  }
  & git tag -a $tag -m "Release $tag"
  if ($LASTEXITCODE -ne 0) { Write-Error "git tag failed"; exit 1 }
  Write-Host "create-tag: created annotated tag $tag." -ForegroundColor Green
  exit 0
} finally {
  Pop-Location
}
