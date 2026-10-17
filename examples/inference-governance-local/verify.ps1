param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "inference-outcome.json"
$reportFile = Join-Path $dataDir "inference-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing inference-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing inference-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "inference-governance") "value report identifies the example"
Assert-True ($report.outcome.after -eq "audited") "inference reached audited state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.kpis.gates_passed -ge 5) "at least 5 gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 12) "at least 12 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 10) "all 10 business steps completed"
Assert-True (@($report.evidence | Where-Object { $_.artifact -eq "unauthorized-route-rejected" }).Count -eq 1) "un-authorized route denial present"
Assert-True (@($report.evidence | Where-Object { $_.artifact -eq "out-of-policy-model-rejected" }).Count -eq 1) "out-of-policy model denial present"
Assert-True (@($report.evidence | Where-Object { $_.artifact -eq "unreviewed-answer-rejected" }).Count -eq 1) "unreviewed-answer denial present"
Assert-True (@($report.evidence | Where-Object { $_.artifact -eq "audited-inference-immutable" }).Count -eq 1) "post-audit immutability denial present"
Assert-True ($outcome.inference_state.route.model -eq "model-alpha") "route selected model-alpha"
Assert-True ($outcome.inference_state.grounding.claim_refs.Count -ge 1) "answer grounded in claims"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the inference-governance demo produced an authorized, policy-selected, grounded, reviewed, audited answer." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
