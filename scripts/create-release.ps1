param(
  [string]$Ver = "",
  [string]$RepoRoot = "",
  [switch]$Draft,
  [switch]$NotLatest
)

# Creates a GitHub Release for v<Ver> with the CHANGELOG section as the body.
# Requires the gh CLI and an authenticated session. The tag must exist.
# Idempotent: no-op when the release already exists. Use -NotLatest when
# backfilling historical releases so the newest version stays "Latest".

if (-not $RepoRoot) { $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") }
if (-not $Ver) {
  $versionFile = Join-Path $RepoRoot "VERSION"
  if (-not (Test-Path $versionFile)) { Write-Error "VERSION file not found: $versionFile"; exit 1 }
  $Ver = (Get-Content -Raw $versionFile).Trim()
}

$body = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "read-changelog-section.ps1") $Ver
if ($LASTEXITCODE -ne 0) { Write-Error "Could not read changelog section for $Ver"; exit 1 }

$tag = "v$Ver"
$notesFile = Join-Path $env:TEMP ("release-notes-" + [guid]::NewGuid().ToString("N") + ".md")
Set-Content -Path $notesFile -Value $body -Encoding UTF8
Push-Location $RepoRoot
try {
  $exists = (& git rev-parse --verify -q "$tag" 2>$null)
  if (-not $exists) { Remove-Item $notesFile -ErrorAction SilentlyContinue; Write-Error "Tag $tag does not exist; create it first (create-tag.ps1)."; exit 1 }

  $already = & gh release view $tag 2>$null
  if ($already) {
    Remove-Item $notesFile -ErrorAction SilentlyContinue
    Write-Host "create-release: GitHub release $tag already exists; nothing to do." -ForegroundColor Yellow
    exit 0
  }

  $releaseArgs = @("release", "create", $tag, "--title", "Release $tag", "--notes-file", $notesFile)
  if ($Draft) { $releaseArgs += "--draft" }
  if ($NotLatest) { $releaseArgs += "--latest=false" }
  & gh @releaseArgs
  if ($LASTEXITCODE -ne 0) { Remove-Item $notesFile -ErrorAction SilentlyContinue; Write-Error "gh release create failed"; exit 1 }
  Remove-Item $notesFile -ErrorAction SilentlyContinue
  Write-Host "create-release: created GitHub release $tag." -ForegroundColor Green
  exit 0
} finally {
  Remove-Item $notesFile -ErrorAction SilentlyContinue
  Pop-Location
}
