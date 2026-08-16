param(
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$CheckOnly
)

# Runs every runnable local demo end to end (start -> scenario -> verify -> stop)
# and aggregates their value reports into a combined dashboard.
#
#   .\run-all-demos.ps1                # run all demos
#   .\run-all-demos.ps1 -Only procurement-local,recruitment-local
#   .\run-all-demos.ps1 -Skip customer-case-local
#   .\run-all-demos.ps1 -CheckOnly     # verify structure only, no execution

$demos = @(
  @{ Name = "order-fulfillment-local"; Run = "run-order-exception.ps1"; Report = "order-value-report.json" },
  @{ Name = "procurement-local";       Run = "run-procurement.ps1";      Report = "procurement-value-report.json" },
  @{ Name = "customer-case-local";     Run = "run-customer-case.ps1";    Report = "customer-value-report.json" },
  @{ Name = "recruitment-local";       Run = "run-recruitment.ps1";      Report = "recruitment-value-report.json" },
  @{ Name = "predictive-maintenance-local"; Run = "run-predictive-maintenance.ps1"; Report = "maintenance-value-report.json" },
  @{ Name = "integration-recovery-local";  Run = "run-integration-recovery.ps1";   Report = "integration-value-report.json" },
  @{ Name = "simulation-validation-local"; Run = "run-simulation-validation.ps1";   Report = "simulation-value-report.json" },
  @{ Name = "compliance-audit-local";      Run = "run-compliance-audit.ps1";        Report = "compliance-value-report.json" },
  @{ Name = "fleet-mission-local";         Run = "run-fleet-mission.ps1";           Report = "fleet-value-report.json" }
)

$requiredFiles = @("README.md", "operations-guide.md", "local.env.ps1.example", "evidence-schema.md", "run-all.ps1", "verify.ps1", "start-services.ps1")
$results = @()
$anyFailure = $false

foreach ($demo in $demos) {
  $name = $demo.Name
  if ($Only.Count -gt 0 -and $name -notin $Only) { continue }
  if ($name -in $Skip) { Write-Host "run-all-demos: skipping $name (explicit)" -ForegroundColor Yellow; continue }

  $dir = Join-Path $PSScriptRoot $name
  $missing = @($requiredFiles | Where-Object { -not (Test-Path (Join-Path $dir $_)) })
  $runScript = Join-Path $dir $demo.Run
  if (-not (Test-Path $runScript)) { $missing += $demo.Run }

  if ($missing.Count -gt 0) {
    Write-Host "run-all-demos: FAIL $name - missing: $($missing -join ', ')" -ForegroundColor Red
    $results += [pscustomobject]@{ Demo = $name; Status = "structure-fail"; Reason = ($missing -join ", ") }
    $anyFailure = $true
    continue
  }

  if ($CheckOnly) {
    Write-Host "run-all-demos: OK $name (structure verified)" -ForegroundColor Green
    $results += [pscustomobject]@{ Demo = $name; Status = "structure-ok"; Reason = "" }
    continue
  }

  if (-not (Test-Path (Join-Path $dir "local.env.ps1"))) {
    Write-Host "run-all-demos: SKIP $name - local.env.ps1 not present (copy from local.env.ps1.example)" -ForegroundColor Yellow
    $results += [pscustomobject]@{ Demo = $name; Status = "skipped"; Reason = "no local.env.ps1" }
    continue
  }

  $status = "pass"
  $reason = ""
  Push-Location $dir
  try {
    . .\local.env.ps1
    Write-Host "run-all-demos: starting $name..." -ForegroundColor Cyan
    .\start-services.ps1
    if ($LASTEXITCODE -ne 0) { throw "start-services failed" }
    Write-Host "run-all-demos: running scenario for $name..." -ForegroundColor Cyan
    & .\$($demo.Run)
    if ($LASTEXITCODE -ne 0) { throw "scenario failed" }
    Write-Host "run-all-demos: verifying $name..." -ForegroundColor Cyan
    .\verify.ps1
    if ($LASTEXITCODE -ne 0) { throw "verify failed" }
  } catch {
    $status = "fail"
    $reason = $_.Exception.Message
    $anyFailure = $true
  } finally {
    Pop-Location
  }

  Write-Host "run-all-demos: stopping $name..." -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot "stop-demo.ps1")
  $results += [pscustomobject]@{ Demo = $name; Status = $status; Reason = $reason }
}

# Aggregate value reports
$dashboard = @{ generated_at = (Get-Date).ToString("o"); demos = @() }
foreach ($demo in $demos) {
  $reportPath = Join-Path $PSScriptRoot "$($demo.Name)\.local-data\$($demo.Report)"
  if (Test-Path $reportPath) {
    $json = Get-Content -Raw $reportPath | ConvertFrom-Json
    $dashboard.demos += [pscustomobject]@{
      example = $json.example
      outcome = "$($json.outcome.before) -> $($json.outcome.after)"
      products = $json.kpis.products_involved
      gates = $json.kpis.gates_passed
      evidence = $json.kpis.evidence_artifacts
      steps = $json.kpis.steps_completed
      time_seconds = $json.kpis.time_to_resolve
      completed = $json.outcome.completed
    }
  }
}
$stackDir = Join-Path $PSScriptRoot ".stack"
New-Item -ItemType Directory -Force -Path $stackDir | Out-Null
$dashboard | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $stackDir "all-demos-report.json")

Write-Host ""
Write-Host "================ Demo Summary ================" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "=============================================="
if ($dashboard.demos.Count -gt 0) {
  Write-Host "Combined value dashboard written to examples\.stack\all-demos-report.json" -ForegroundColor Green
}

if ($anyFailure) {
  Write-Host "run-all-demos: one or more demos failed." -ForegroundColor Red
  exit 1
}
Write-Host "run-all-demos: all selected demos passed." -ForegroundColor Green
exit 0
