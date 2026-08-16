param(
  [string]$Root = ""
)

# Verifies that every release tag has a matching GitHub Release. Prevents the
# regression where a tag exists but no release was published (the v0.1.0 through
# v0.13.0 backfill). The current VERSION's tag is excluded: during a release
# window CI may observe the tag before the release step publishes it.
# Requires the gh CLI and an authenticated session (GH_TOKEN in CI).

if (-not $Root) { $Root = Resolve-Path (Join-Path $PSScriptRoot "..") }

$versionFile = Join-Path $Root "VERSION"
if (-not (Test-Path $versionFile)) { Write-Error "VERSION file not found: $versionFile"; exit 1 }
$current = (Get-Content $versionFile -Raw).Trim()

Push-Location $Root
try {
  $tags = @(& git tag 2>$null) | Where-Object { $_ -match '^v[0-9]+\.[0-9]+\.[0-9]+$' }
  $tags = $tags | Where-Object { $_ -ne "v$current" }

  $releaseTags = @()
  $raw = & gh release list --limit 200 2>$null
  foreach ($line in $raw) {
    $fields = $line -split "`t"
    if ($fields.Count -ge 3) { $releaseTags += $fields[2] }
  }

  $missing = @()
  foreach ($t in $tags) {
    if ($releaseTags -notcontains $t) { $missing += $t }
  }

  if ($missing.Count -eq 0) {
    Write-Host "check-releases: every release tag has a GitHub release ($($tags.Count) tag(s))." -ForegroundColor Green
    exit 0
  }
  Write-Host "check-releases: $($missing.Count) tag(s) without a GitHub release:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  Write-Host "check-releases: backfill with: scripts/create-release.ps1 -Ver <version>" -ForegroundColor Yellow
  exit 1
} finally {
  Pop-Location
}
