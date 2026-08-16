param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "sandbox-outcome.json"
$reportFile = Join-Path $dataDir "sandbox-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing sandbox-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing sandbox-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "innovation-sandbox-to-policy") "value report identifies the example"
Assert-True ($report.outcome.completed) "outcome is marked applied"
Assert-True ($report.outcome.applied -eq $true) "policy was applied"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 9) "at least 9 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "sandbox-boundary-rejected" }).Count -eq 1) "sandbox-boundary denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "decision-without-evidence-rejected" }).Count -eq 1) "evidence-gate denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "policy-immutability-rejected" }).Count -eq 1) "immutability denial present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "policy-decision" }).Count -eq 1) "policy-decision gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the innovation-sandbox demo produced a bounded, evidence-based, applied outcome." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
