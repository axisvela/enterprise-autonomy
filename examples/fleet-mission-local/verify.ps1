param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "fleet-outcome.json"
$reportFile = Join-Path $dataDir "fleet-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing fleet-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing fleet-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "fleet-mission-exception") "value report identifies the example"
Assert-True ($report.outcome.after -eq "completed") "mission reached completed state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.kpis.gates_passed -ge 5) "at least 5 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 9) "at least 9 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "boundary-deviation-frozen" }).Count -eq 1) "boundary-enforcement denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "non-operator-review-rejected" }).Count -eq 1) "non-operator denial present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "exception-paused" }).Count -eq 1) "exception-paused gate recorded"
Assert-True (($report.gates | Where-Object { $_.gate -eq "operator-review" }).Count -eq 1) "operator-review gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the fleet-mission demo produced a bounded, reviewed, completed outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
