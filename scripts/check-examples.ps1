param(
  [string]$DemosDir = (Join-Path $PSScriptRoot "..\examples")
)

$demos = @("order-fulfillment-local", "procurement-local")
$failures = @()
foreach ($demo in $demos) {
  $verify = Join-Path $DemosDir "$demo\verify.ps1"
  if (-not (Test-Path $verify)) {
    Write-Host "check-examples: demo verify script not found at $verify" -ForegroundColor Red
    $failures += $verify
    continue
  }
  Write-Host "check-examples: verifying $demo"
  & $verify
  if ($LASTEXITCODE -ne 0) { $failures += $demo }
}

if ($failures.Count -eq 0) {
  Write-Host "check-examples: all demo artifacts are consistent and complete." -ForegroundColor Green
  exit 0
}
Write-Host "check-examples: demo artifact checks failed for: $($failures -join ', ')" -ForegroundColor Red
exit 1
