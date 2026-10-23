param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

# Runs go test + go vet across reference-adapter modules and external A2A
# interoperability examples. Exits non-zero if any module fails.

$adapters = @("order-domain", "inventory-domain", "procurement-domain", "customer-domain", "recruitment-domain", "maintenance-domain", "integration-domain", "simulation-domain", "compliance-domain", "fleet-domain", "process-domain", "sandbox-domain", "deployment-domain", "inference-domain")
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

  $a2aExample = Join-Path $RepoRoot "examples\a2a-adk-order-cancellation"
  if (-not (Test-Path (Join-Path $a2aExample "go.mod"))) {
    $failures += "a2a-adk-order-cancellation missing go.mod"
  } else {
    Push-Location $a2aExample
    go vet ./...
    if ($LASTEXITCODE -ne 0) {
      $failures += "a2a-adk-order-cancellation vet failed"
    } else {
    go test ./...
    if ($LASTEXITCODE -ne 0) { $failures += "a2a-adk-order-cancellation tests failed" }
    }
    Pop-Location
    if ($LASTEXITCODE -eq 0) { Write-Host "run-go-tests: a2a-adk-order-cancellation OK" -ForegroundColor Green }
  }
} finally {
  $env:GOWORK = $previousGoWork
}

if ($failures.Count -eq 0) {
  Write-Host "run-go-tests: all $($adapters.Count) adapter modules and the A2A example vet and test OK." -ForegroundColor Green
  exit 0
}
$failures | ForEach-Object { Write-Host "run-go-tests: $_" -ForegroundColor Red }
Write-Host "run-go-tests: $($failures.Count) failure(s)." -ForegroundColor Red
exit 1
