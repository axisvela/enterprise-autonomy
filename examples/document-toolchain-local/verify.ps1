# Runs the pinned document-toolchain suites and records the result per case.
$ErrorActionPreference = "Stop"
if (-not $env:PRAXOVELA_DIR) { throw "Load local.env.ps1 before running this script." }
$repo = $env:PRAXOVELA_DIR
$reportDir = Join-Path $PSScriptRoot "_reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

# pkg = module dir relative to the repo; tests run inside that module.
$cases = @(
  @{ id = '01'; name = 'parse-and-fallback';      dir = 'packages\janus-gateway'; pkg = './internal/parser';     run = 'Test' },
  @{ id = '02'; name = 'generate-and-render';     dir = 'packages\janus-gateway'; pkg = './pkg/adapters';        run = 'TestDoc' }
)
# NOTE: a formatter-availability case was dropped deliberately. `internal/format`
# has NO test files, so running it reports "[no test files]" — which this script
# would have counted as PASS. An unverified claim must not look green.

$results = @()
foreach ($c in $cases) {
  $label = "$($c.id)-$($c.name)"
  $dir = Join-Path $repo $c.dir
  if (-not (Test-Path $dir)) { throw "module not found: $dir" }
  Write-Output "[verify] $label ($($c.pkg) -run $($c.run))"
  Push-Location $dir
  try { $out = & go test $c.pkg -run $c.run -count=1 2>&1; $ok = ($LASTEXITCODE -eq 0) } finally { Pop-Location }
  $last = ($out | Select-Object -Last 1)
  Write-Output ("  {0}  {1}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $last)
  $results += [pscustomobject]@{ case = $label; package = $c.pkg; run = $c.run; passed = $ok; output = $last }
}

$report = [pscustomobject]@{
  generated_at = (Get-Date).ToString('o')
  environment  = "PRAXOVELA_DIR=$repo"
  cases        = $results
  passed       = (($results | Where-Object { -not $_.passed } | Measure-Object).Count -eq 0)
}
$path = Join-Path $reportDir "document-toolchain.json"
$report | ConvertTo-Json -Depth 5 | Set-Content $path
Write-Output "[verify] report: $path"
if (-not $report.passed) { throw "one or more cases failed; see $path" }
