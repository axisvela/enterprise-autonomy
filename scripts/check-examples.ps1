param(
  [string]$DemoDir = (Join-Path $PSScriptRoot "..\examples\order-fulfillment-local")
)

$verify = Join-Path $DemoDir "verify.ps1"
if (-not (Test-Path $verify)) {
  Write-Host "check-examples: demo verify script not found at $verify" -ForegroundColor Red
  exit 1
}
& $verify
if ($LASTEXITCODE -eq 0) {
  Write-Host "check-examples: demo artifacts are consistent and complete." -ForegroundColor Green
  exit 0
}
Write-Host "check-examples: demo artifact checks failed." -ForegroundColor Red
exit 1
