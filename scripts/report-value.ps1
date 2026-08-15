param(
  [string]$ExamplesDir = (Join-Path $PSScriptRoot "..\examples")
)

$reports = Get-ChildItem -Path $ExamplesDir -Recurse -Filter "order-value-report.json" -ErrorAction SilentlyContinue
if ($reports.Count -eq 0) {
  Write-Host "report-value: no value reports found. Run a runnable demo first (e.g. examples\order-fulfillment-local\run-all.ps1)." -ForegroundColor Yellow
  exit 0
}

$summary = @()
foreach ($r in $reports) {
  $json = Get-Content -Raw $r.FullName | ConvertFrom-Json
  $summary += [pscustomobject]@{
    Example = $json.example
    Outcome = "$($json.outcome.before) -> $($json.outcome.after)"
    Products = $json.kpis.products_involved
    Gates = $json.kpis.gates_passed
    Evidence = $json.kpis.evidence_artifacts
    Steps = $json.kpis.steps_completed
    TimeSeconds = $json.kpis.time_to_resolve
    Report = $r.FullName
  }
}

$summary | Format-Table -AutoSize
Write-Host "report-value: aggregated $($summary.Count) value report(s)." -ForegroundColor Green
