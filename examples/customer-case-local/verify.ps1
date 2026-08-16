param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "customer-outcome.json"
$reportFile = Join-Path $dataDir "customer-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing customer-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing customer-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "customer-case-resolution") "value report identifies the example"
Assert-True ($report.outcome.after -eq "resolved") "case reached resolved state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.compensation -gt 0) "compensation amount recorded"
Assert-True ($report.kpis.gates_passed -ge 3) "at least 3 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 8) "at least 8 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "compensation-without-consent-rejected" }).Count -eq 1) "consent-denial evidence present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "compensation-without-approval-rejected" }).Count -eq 1) "approval-denial evidence present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "customer-consent" }).Count -eq 1) "customer-consent gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the customer-case demo produced a complete, consented, and verifiable outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
