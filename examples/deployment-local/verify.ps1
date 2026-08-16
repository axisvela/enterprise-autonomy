param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "deployment-outcome.json"
$reportFile = Join-Path $dataDir "deployment-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing deployment-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing deployment-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "sequenced-deployment") "value report identifies the example"
Assert-True ($report.outcome.after -eq "released") "deployment reached released state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.kpis.gates_passed -ge 5) "at least 5 gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 10) "at least 10 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "out-of-sequence-step-rejected" }).Count -eq 1) "out-of-sequence denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "unapproved-pause-rejected" }).Count -eq 1) "unapproved-deviation denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "released-step-rejected" }).Count -eq 1) "released-rerun denial present"
Assert-True (($outcome.deployment_state.steps_run).Count -eq 5) "five step executions recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the sequenced-deployment demo produced a sequenced, evidence-cited, immutable release." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
