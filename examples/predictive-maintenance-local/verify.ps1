param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "maintenance-outcome.json"
$reportFile = Join-Path $dataDir "maintenance-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing maintenance-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing maintenance-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "predictive-maintenance-to-work-order") "value report identifies the example"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.work_order -like "wo-*") "work order was scheduled"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 9) "at least 9 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "unvalidated-work-order-rejected" }).Count -eq 1) "prediction-vs-fact denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "unconfirmed-stop-rejected" }).Count -eq 1) "unconfirmed-stop denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "no-safety-review-rejected" }).Count -eq 1) "safety-review denial present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "safety-review" }).Count -eq 1) "safety-review gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the predictive-maintenance demo produced a validated, safety-reviewed outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
