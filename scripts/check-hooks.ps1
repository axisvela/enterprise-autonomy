param()

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot
try {
  $hooksPath = (git config core.hooksPath) -replace '[\r\n]', ''
  $hook = Join-Path $repoRoot ".githooks\pre-commit"
  $failures = @()
  if ($hooksPath -ne ".githooks") { $failures += "core.hooksPath is '$hooksPath', expected '.githooks' (run install-hooks.ps1)" }
  if (-not (Test-Path $hook)) { $failures += "pre-commit hook file missing at .githooks\pre-commit" }
  if ($failures.Count -eq 0) {
    Write-Host "check-hooks: pre-commit hook is installed and active." -ForegroundColor Green
    exit 0
  }
  $failures | ForEach-Object { Write-Host "check-hooks: $_" -ForegroundColor Red }
  exit 1
} finally {
  Pop-Location
}
