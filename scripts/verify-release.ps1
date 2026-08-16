param(
  [string]$RepoRoot = ""
)

# Full release checklist. Exits 0 when the repository is ready to tag and
# release, otherwise lists every failing check and exits 1. Used before
# create-tag.ps1 / create-release.ps1 and wired into the release workflow.

if (-not $RepoRoot) { $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..") }
$failures = @()
$warnings = @()

# 1. VERSION file exists and is well-formed
$versionFile = Join-Path $RepoRoot "VERSION"
if (-not (Test-Path $versionFile)) { $failures += "VERSION file missing" }
else {
  $ver = (Get-Content -Raw $versionFile).Trim()
  if ($ver -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { $failures += "VERSION '$ver' is not major.minor.patch" }
}

# 2. CHANGELOG section exists for the current version
$changelog = Join-Path $RepoRoot "CHANGELOG.md"
if (-not (Test-Path $changelog)) { $failures += "CHANGELOG.md missing" }
else {
  $content = Get-Content -Raw $changelog
  $escaped = [regex]::Escape($ver)
  if ($content -notmatch "##\s+$escaped\s*\(") { $failures += "CHANGELOG.md has no section for version $ver" }
}

# 3. Tag does not exist yet
Push-Location $RepoRoot
try {
  $tag = "v$ver"
  $exists = (& git rev-parse --verify -q "$tag" 2>$null)
  if ($exists) { $failures += "tag $tag already exists" }

  # 4. Working tree clean
  $status = (& git status --porcelain)
  if ($status) { $failures += "working tree is not clean ($($status.Count) changed path(s))" }
} finally { Pop-Location }

# 5. Validators
$validators = @(
  @{ Name = "check-links.ps1";    Script = "check-links.ps1" },
  @{ Name = "validate-demos.ps1"; Script = "validate-demos.ps1" },
  @{ Name = "validate-json.ps1";  Script = "validate-json.ps1" },
  @{ Name = "run-go-tests.ps1";   Script = "run-go-tests.ps1" }
)
foreach ($v in $validators) {
  $p = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $v.Script)
  if ($LASTEXITCODE -ne 0) { $failures += "$($v.Name) failed" }
}

# 6. check-release reports the version is prepared (exit 2)
$p = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "check-release.ps1")
if ($LASTEXITCODE -ne 2) { $failures += "check-release.ps1 did not report prepared (exit $LASTEXITCODE, expected 2)" }

# Report
if ($failures.Count -eq 0) {
  Write-Host "verify-release: READY to release v$ver." -ForegroundColor Green
  Write-Host "verify-release: run create-tag.ps1, push, then create-release.ps1" -ForegroundColor Green
  exit 0
}
Write-Host "verify-release: NOT ready to release v$ver." -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
Write-Host "verify-release: $($failures.Count) blocking issue(s)." -ForegroundColor Red
exit 1
