param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "process-outcome.json"
$reportFile = Join-Path $dataDir "process-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing process-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing process-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "process-to-outcome") "value report identifies the example"
Assert-True ($report.outcome.after -eq "completed") "process reached completed state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 9) "at least 9 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "out-of-order-advance-rejected" }).Count -eq 1) "out-of-order denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "complete-before-terminal-rejected" }).Count -eq 1) "before-terminal denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "reopen-rejected" }).Count -eq 1) "reopen denial present"
Assert-True (($outcome.process_state.advances).Count -eq 3) "three stage advances recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the process-to-outcome demo produced a sequenced, terminal, immutable outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
