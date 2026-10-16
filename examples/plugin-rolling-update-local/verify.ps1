# Runs the pinned plugin rolling-update / rollback suites and records the result
# per case into _reports/plugin-rolling-update.json (git-ignored).
param([switch]$Short)
$ErrorActionPreference = "Stop"
if (-not $env:PRAXOVELA_DIR) { throw "Load local.env.ps1 before running this script." }

$core = Join-Path $env:PRAXOVELA_DIR "packages\axon-core"
if (-not (Test-Path $core)) { throw "axon-core not found under PRAXOVELA_DIR: $core" }

$reportDir = Join-Path $PSScriptRoot "_reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$cases = @(
  @{ id = '01'; name = 'promote-and-rollback';    pkg = './internal/pluginruntime'; run = 'TestSBRP' },
  @{ id = '02'; name = 'post-publish-rollback';   pkg = './internal/pluginruntime'; run = 'TestRollbackPlugin' },
  @{ id = '02'; name = 'post-publish-rollback';   pkg = './internal/governance';    run = 'TestRuntimeManagerConformance' },
  @{ id = '03'; name = 'apply-unification';       pkg = './internal/pluginruntime'; run = 'TestApply' },
  @{ id = '03'; name = 'apply-unification';       pkg = './internal/governance';    run = 'Rollback|Update|Promote' },
  @{ id = '04'; name = 'deployed-lifecycle-e2e';  pkg = './cmd/axond';              run = 'TestGovernanceProcessLifecycleE2E' }
)

$results = @()
foreach ($c in $cases) {
  $label = "$($c.id)-$($c.name)"
  Write-Output "[verify] $label ($($c.pkg) -run $($c.run))"
  Push-Location $core
  try {
    $out = & go test $c.pkg -run $c.run -count=1 2>&1
    $ok = ($LASTEXITCODE -eq 0)
  } finally { Pop-Location }
  $last = ($out | Select-Object -Last 1)
  Write-Output ("  {0}  {1}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $last)
  $results += [pscustomobject]@{ case = $label; package = $c.pkg; run = $c.run; passed = $ok; output = $last }
}

$report = [pscustomobject]@{
  generated_at = (Get-Date).ToString('o')
  environment  = "PRAXOVELA_DIR=$env:PRAXOVELA_DIR"
  cases        = $results
  passed       = (($results | Where-Object { -not $_.passed } | Measure-Object).Count -eq 0)
}
$path = Join-Path $reportDir "plugin-rolling-update.json"
$report | ConvertTo-Json -Depth 5 | Set-Content $path
Write-Output "[verify] report: $path"
if (-not $report.passed) { throw "one or more cases failed; see $path" }
