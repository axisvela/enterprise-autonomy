param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "order-outcome.json"
$reportFile = Join-Path $dataDir "order-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing order-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing order-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "order-fulfillment-exception") "value report identifies the example"
Assert-True ($report.outcome.after -ne "stockout") "order transitioned away from stockout (now $($report.outcome.after))"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.warehouse -eq "warehouse-b") "fulfillment moved to the alternate warehouse"
Assert-True ($report.kpis.products_involved -ge 6) "at least 6 products involved"
Assert-True ($report.kpis.gates_passed -ge 1) "at least one human gate passed"
Assert-True ($report.kpis.evidence_artifacts -ge 6) "at least 6 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.state -eq "denied" }).Count -ge 1) "governance-denial evidence is present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "action-approved" }).Count -eq 1) "action-approved gate recorded"
Assert-True ($outcome.notifications.Count -ge 1) "pending customer notification recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the demo produced a complete, governed, and verifiable outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
