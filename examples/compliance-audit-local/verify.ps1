param()

$dataDir = Join-Path $PSScriptRoot ".local-data"
$outcomeFile = Join-Path $dataDir "compliance-outcome.json"
$reportFile = Join-Path $dataDir "compliance-value-report.json"

$failures = @()
function Assert-True($condition, $message) {
  if ($condition) { Write-Host "PASS: $message" -ForegroundColor Green }
  else { Write-Host "FAIL: $message" -ForegroundColor Red; $script:failures += $message }
}

if (-not (Test-Path $outcomeFile)) { Write-Host "FAIL: missing $outcomeFile" -ForegroundColor Red; $failures += "missing compliance-outcome.json" }
if (-not (Test-Path $reportFile)) { Write-Host "FAIL: missing $reportFile" -ForegroundColor Red; $failures += "missing compliance-value-report.json" }
if ($failures.Count -gt 0) { exit 1 }

$outcome = Get-Content -Raw $outcomeFile | ConvertFrom-Json
$report = Get-Content -Raw $reportFile | ConvertFrom-Json

Assert-True ($report.example -eq "compliance-request-to-audit") "value report identifies the example"
Assert-True ($report.outcome.after -eq "released") "case reached released state"
Assert-True ($report.outcome.completed) "outcome is marked completed"
Assert-True ($report.outcome.package -like "package-*") "audit package was released"
Assert-True ($report.kpis.gates_passed -ge 4) "at least 4 human gates passed"
Assert-True ($report.kpis.evidence_artifacts -ge 10) "at least 10 evidence artifacts recorded"
Assert-True ($report.kpis.steps_completed -ge 8) "all 8 business steps completed"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "attestation-without-evidence-rejected" }).Count -eq 1) "completeness denial present"
Assert-True (($report.evidence | Where-Object { $_.artifact -eq "non-attestor-rejected" }).Count -eq 1) "non-attestor denial present"
Assert-True (($report.gates | Where-Object { $_.gate -eq "attestation" }).Count -eq 1) "attestation gate recorded"

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "VERIFY OK: the compliance-audit demo produced a complete, attested, released package." -ForegroundColor Green
} else {
  Write-Host "VERIFY FAILED: $($failures.Count) check(s) did not pass." -ForegroundColor Red
  exit 1
}
