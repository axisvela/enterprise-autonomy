param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Runs go test + go vet across every reference-adapter module. Exits non-zero
# if any module fails. Used by CI and pre-commit verification.

$adapters = @("order-domain", "inventory-domain", "procurement-domain", "customer-domain", "recruitment-domain", "maintenance-domain", "integration-domain", "simulation-domain", "compliance-domain", "fleet-domain", "process-domain")
$failures = @()
$previousGoWork = $env:GOWORK
$env:GOWORK = "off"
try {
  foreach ($name in $adapters) {
    $dir = Join-Path $RepoRoot "adapters\$name"
    if (-not (Test-Path (Join-Path $dir "go.mod"))) { $failures += "$name missing go.mod"; continue }
    Push-Location $dir
    go vet ./...
    if ($LASTEXITCODE -ne 0) { $failures += "$name vet failed"; Pop-Location; continue }
    go test ./...
    if ($LASTEXITCODE -ne 0) { $failures += "$name tests failed"; Pop-Location; continue }
    Pop-Location
    Write-Host "run-go-tests: $name OK" -ForegroundColor Green
  }
} finally {
  $env:GOWORK = $previousGoWork
}

if ($failures.Count -eq 0) {
  Write-Host "run-go-tests: all $($adapters.Count) adapter modules vet and test OK." -ForegroundColor Green
  exit 0
}
$failures | ForEach-Object { Write-Host "run-go-tests: $_" -ForegroundColor Red }
Write-Host "run-go-tests: $($failures.Count) failure(s)." -ForegroundColor Red
exit 1
