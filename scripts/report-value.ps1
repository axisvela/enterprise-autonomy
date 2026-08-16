param(
  [string]$ExamplesDir = (Join-Path $PSScriptRoot "..\examples")
)

# Aggregates all runnable demo value reports into a dashboard table and a
# combined JSON file at examples\.stack\all-demos-report.json.

$demoDirs = @("order-fulfillment-local", "procurement-local", "customer-case-local", "recruitment-local", "predictive-maintenance-local", "integration-recovery-local", "simulation-validation-local", "compliance-audit-local", "fleet-mission-local", "process-to-outcome-local", "innovation-sandbox-local")
$reports = @()
foreach ($name in $demoDirs) {
  $reportPath = Join-Path $ExamplesDir "$name\.local-data\*value-report.json"
  $file = Get-ChildItem -Path $reportPath -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($file) {
    $json = Get-Content -Raw $file.FullName | ConvertFrom-Json
    $reports += [pscustomobject]@{
      Demo = $name
      Example = $json.example
      Outcome = "$($json.outcome.before) -> $($json.outcome.after)"
      Products = $json.kpis.products_involved
      Gates = $json.kpis.gates_passed
      Evidence = $json.kpis.evidence_artifacts
      Steps = $json.kpis.steps_completed
      TimeSeconds = $json.kpis.time_to_resolve
      Completed = $json.outcome.completed
      Report = $file.FullName
    }
  }
}

if ($reports.Count -eq 0) {
  Write-Host "report-value: no value reports found. Run a demo first (e.g. examples\run-all-demos.ps1)." -ForegroundColor Yellow
  exit 0
}

Write-Host ""
Write-Host "================ Example Value Dashboard ================" -ForegroundColor Cyan
$reports | Format-Table Demo, Example, Outcome, Products, Gates, Evidence, Steps, TimeSeconds, Completed -AutoSize | Out-String | Write-Host
Write-Host "=========================================================="

$stackDir = Join-Path $ExamplesDir ".stack"
New-Item -ItemType Directory -Force -Path $stackDir | Out-Null
$dashboard = @{ generated_at = (Get-Date).ToString("o"); demos = $reports }
$dashboard | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $stackDir "all-demos-report.json")
Write-Host "report-value: aggregated $($reports.Count) value report(s)." -ForegroundColor Green
Write-Host "Combined dashboard: examples\.stack\all-demos-report.json" -ForegroundColor Green
