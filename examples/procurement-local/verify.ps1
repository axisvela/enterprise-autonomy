param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "procurement-outcome.json"
$reportFile = Join-Path $dataDir "procurement-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing procurement-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing procurement-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "procurement-request-to-receipt") "value report identifies the example"
Assert-True ($report.outcome.after -eq "closed") "request reached closed state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.po -like "po-preq-0001-*") "purchase order was issued"
Assert-True ($report.kpis.gates_passed -ge 3) "at least 3 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 7) "at least 7 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.state -eq "denied" }).Count -ge 2) "both denial demonstrations are present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "supplier-approved" }).Count -eq 1) "supplier-approved gate recorded"
Assert-True (($outcome.request_state.po.status) -eq "received") "PO is marked received"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the procurement demo produced a complete, governed, and verifiable outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
