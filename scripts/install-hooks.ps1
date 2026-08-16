param()

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot
try {
  git config core.hooksPath .githooks
  $hook = Join-Path $repoRoot ".githooks\pre-commit"
  if (-not (Test-Path $hook)) { throw "Hook not found: $hook" }
  Write-Host "install-hooks: core.hooksPath is set to .githooks (pre-commit hook active)." -ForegroundColor Green
  Write-Host "install-hooks: on every commit, internal links are checked and the version is reported." -ForegroundColor Green
} finally {
  Pop-Location
}
