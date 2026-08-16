param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "integration-outcome.json"
$reportFile = Join-Path $dataDir "integration-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing integration-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing integration-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "integration-outage-recovery") "value report identifies the example"
Assert-True ($report.outcome.after -eq "completed") "work reached completed state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 9) "at least 9 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "resume-before-preserve-rejected" }).Count -eq 1) "preserve-denial evidence present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "resume-before-verify-rejected" }).Count -eq 1) "verify-denial evidence present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "silent-rerun-rejected" }).Count -eq 1) "silent-rerun denial evidence present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "reconnect-verified" }).Count -eq 1) "reconnect-verified gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the integration-recovery demo produced a preserved, verified, completed outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
