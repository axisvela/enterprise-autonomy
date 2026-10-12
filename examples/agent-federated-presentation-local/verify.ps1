param()
$ErrorActionPreference = "Stop"
$report = Join-Path $PSScriptRoot ".local-data\fp1-value-report.json"
if (-not (Test-Path $report)) { throw "value report missing: $report" }
$data = Get-Content $report -Raw | ConvertFrom-Json
if (-not $data.passed) { throw "FP-1 scenarios failed" }
foreach ($s in $data.scenarios) {
  if (-not $s.passed) { throw "scenario $($s.id) failed: $($s.actual)" }
}
Write-Host "FP-1 value report verified: $($data.scenarios.Count) scenarios passed."
