param(
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$CheckOnly,
  [switch]$Strict,
  [string]$OutputRoot = (Join-Path $PSScriptRoot "_reports")
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
  @{ Name = "fleet-mission-local";         Run = "run-fleet-mission.ps1";           Report = "fleet-value-report.json" },
  @{ Name = "process-to-outcome-local";    Run = "run-process-to-outcome.ps1";      Report = "process-value-report.json" },
  @{ Name = "innovation-sandbox-local";    Run = "run-innovation-sandbox.ps1";      Report = "sandbox-value-report.json" },
  @{ Name = "deployment-local";            Run = "run-sequenced-deployment.ps1";    Report = "deployment-value-report.json" },
  @{ Name = "inference-governance-local";  Run = "run-inference-governance.ps1";    Report = "inference-value-report.json" },
  @{ Name = "agent-federated-presentation-local"; Run = "run-all.ps1"; Report = "fp1-value-report.json"; Required = @("README.md", "local.env.ps1.example", "evidence-schema.md", "run-all.ps1", "verify.ps1", "start-services.ps1") }
)

$requiredFiles = @("README.md", "operations-guide.md", "local.env.ps1.example", "evidence-schema.md", "run-all.ps1", "verify.ps1", "start-services.ps1")
$ErrorActionPreference = "Stop"
$unknown = @(@($Only) + @($Skip) | Where-Object { $_ -notin $demos.Name })
if ($unknown.Count -gt 0) { throw "Unknown demo names: $($unknown -join ', ')" }
$selected = @($demos | Where-Object { $Only.Count -eq 0 -or $_.Name -in $Only })
$executionID = "{0}-{1}" -f [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"), [guid]::NewGuid().ToString("N")
$runDir = New-Item -ItemType Directory -Path (Join-Path $OutputRoot $executionID) -Force
$shell = (Get-Process -Id $PID).Path
$dashboard = [ordered]@{
  execution_id = $executionID
  started_at = [DateTime]::UtcNow.ToString("o")
  finished_at = $null
  mode = $(if ($CheckOnly) { "structure-only" } else { "execution" })
  strict = [bool]$Strict
  required_scenarios = @($selected.Name)
  environment = @{ os = [Environment]::OSVersion.VersionString; architecture = $env:PROCESSOR_ARCHITECTURE; powershell = $PSVersionTable.PSVersion.ToString() }
  configuration = @{ only = @($Only); skip = @($Skip); credential_values_recorded = $false }
  runner_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash
  results = @()
  demos = @()
}

foreach ($demo in $selected) {
  $name = $demo.Name
  $dir = Join-Path $PSScriptRoot $name
  $scenarioDir = New-Item -ItemType Directory -Path (Join-Path $runDir $name)
  $result = [ordered]@{ demo = $name; status = "not-run"; reason = ""; started_at = [DateTime]::UtcNow.ToString("o"); finished_at = $null; phases = @(); artifacts = @(); findings = @(); data = @{ expected = "Fresh value report with outcome.completed=true after successful verification"; report = $demo.Report; configuration_source = "local.env.ps1 (values not recorded)" } }
  try {
    if ($name -in $Skip) {
      $result.status = "skipped"
      $result.reason = "explicit exclusion"
      continue
    }
    $required = if ($demo.ContainsKey("Required")) { $demo.Required } else { $requiredFiles }
    $missing = @(@($required) + @($demo.Run) | Where-Object { -not (Test-Path -LiteralPath (Join-Path $dir $_) -PathType Leaf) })
    if ($missing.Count -gt 0) { throw "Missing required files: $($missing -join ', ')" }
    if ($CheckOnly) {
      $result.status = "structure-only"
      continue
    }
    $config = Join-Path $dir "local.env.ps1"
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
      $result.status = "skipped"
      $result.reason = "no local.env.ps1"
      continue
    }
    $reportPath = Join-Path $dir ".local-data\$($demo.Report)"
    if (Test-Path -LiteralPath $reportPath) {
      Move-Item -LiteralPath $reportPath -Destination (Join-Path $scenarioDir "previous-report.json")
    }
    Push-Location $dir
    try {
      foreach ($phase in @(
        @{ Name = "start"; Script = (Join-Path $dir "start-services.ps1") },
        @{ Name = "scenario"; Script = (Join-Path $dir $demo.Run) },
        @{ Name = "verify"; Script = (Join-Path $dir "verify.ps1") }
      )) {
        $log = Join-Path $scenarioDir ($phase.Name + ".log")
        $started = [DateTime]::UtcNow.ToString("o")
        $command = "`$ErrorActionPreference = 'Stop'; `$global:LASTEXITCODE = 0; . '$($config.Replace("'", "''"))'; & '$($phase.Script.Replace("'", "''"))'; if (-not `$?) { exit 1 }; exit `$LASTEXITCODE"
        $ErrorActionPreference = "Continue"
        & $shell -NoProfile -NonInteractive -Command $command *> $log
        $phaseExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        $result.phases += @{ name = $phase.Name; started_at = $started; finished_at = [DateTime]::UtcNow.ToString("o"); exit_code = $phaseExit; log = ($phase.Name + ".log") }
        if ($phaseExit -ne 0) { throw "$($phase.Name) failed (exit $phaseExit)" }
      }
      if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw "No report produced by this execution" }
      $json = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
      if ($json.outcome.completed -isnot [bool] -or -not $json.outcome.completed) { throw "Report does not confirm a completed outcome" }
      $artifact = Join-Path $scenarioDir "value-report.json"
      Copy-Item -LiteralPath $reportPath -Destination $artifact
      $result.artifacts += @{ path = "value-report.json"; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact).Hash; bytes = (Get-Item -LiteralPath $artifact).Length }
      $result.status = "passed"
    } finally {
      $cleanupLog = Join-Path $scenarioDir "cleanup.log"
      $started = [DateTime]::UtcNow.ToString("o")
      try {
        $ErrorActionPreference = "Continue"
        & $shell -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot "stop-demo.ps1") *> $cleanupLog
        $cleanupExit = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        $result.phases += @{ name = "cleanup"; started_at = $started; finished_at = [DateTime]::UtcNow.ToString("o"); exit_code = $cleanupExit; log = "cleanup.log" }
        if ($cleanupExit -ne 0) { throw "cleanup failed (exit $cleanupExit)" }
      } catch {
        $result.findings += "Cleanup failed; inspect restricted cleanup.log"
        if ($result.status -eq "passed") { $result.status = "failed"; $result.reason = "cleanup failed" }
      } finally {
        Pop-Location
      }
    }
    if ($result.status -eq "passed") {
      $dashboard.demos += @{ demo = $name; execution_id = $executionID; report = "$name/value-report.json"; outcome = $json.outcome; kpis = $json.kpis }
    }
  } catch {
    $result.status = "failed"
    $result.reason = $_.Exception.Message
  } finally {
    foreach ($artifact in @(Get-ChildItem -LiteralPath $scenarioDir -Filter *.log)) {
      $result.artifacts += @{ path = $artifact.Name; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact.FullName).Hash; bytes = $artifact.Length }
    }
    $result.finished_at = [DateTime]::UtcNow.ToString("o")
    $dashboard.results += [pscustomobject]$result
  }
}
$counts = [ordered]@{}
foreach ($status in @("passed", "failed", "skipped", "blocked", "not-run", "structure-only")) {
  $counts[$status] = @($dashboard.results | Where-Object { $_.status -eq $status }).Count
}
$dashboard.counts = $counts
$satisfied = -not $CheckOnly -and $selected.Count -gt 0 -and $counts.passed -eq $selected.Count
$dashboard.acceptance = $(if ($satisfied) { "satisfied" } elseif ($CheckOnly) { "not-evaluated" } else { "unsatisfied" })
$dashboard.finished_at = [DateTime]::UtcNow.ToString("o")
$dashboard | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 (Join-Path $runDir "all-demos-report.json")
$dashboard.results | Format-Table demo,status,reason -AutoSize | Out-String | Write-Host
Write-Host "run-all-demos: execution=$executionID acceptance=$($dashboard.acceptance) report=$runDir"
if ($counts.failed -gt 0 -or ($Strict -and -not $satisfied)) { exit 1 }
exit 0
