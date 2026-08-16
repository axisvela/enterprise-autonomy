param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "recruitment-outcome.json"
$reportFile = Join-Path $dataDir "recruitment-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing recruitment-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing recruitment-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "recruitment-requisition-to-offer") "value report identifies the example"
Assert-True ($report.outcome.after -eq "closed") "requisition reached closed state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.offer -like "offer-*") "offer was issued"
Assert-True ($report.outcome.candidate -eq "cand-a") "candidate recorded"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 8) "at least 8 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "automated-decision-rejected" }).Count -eq 1) "automation-denial evidence present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "offer-decision" }).Count -eq 1) "offer-decision gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the recruitment demo produced a human-decided, verifiable outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
