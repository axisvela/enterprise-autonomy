# Runs the pinned memory-engine suites and records the result per case.
$ErrorActionPreference = "Stop"
if (-not $env:PRAXOVELA_DIR) { throw "Copy local.env.ps1.example to local.env.ps1, edit it, and dot-source it first." }
$repo = $env:PRAXOVELA_DIR
$reportDir = Join-Path $PSScriptRoot "_reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$cases = @(
  @{ id = '01'; name = 'contract-and-noop'; dir = 'packages\contracts'; pkg = './memory';    run = 'Test' },
  @{ id = '02'; name = 'mnemovela-client';  dir = 'packages\adapters';  pkg = './mnemovela'; run = 'Test' }
)

$results = @()
foreach ($c in $cases) {
  $label = "$($c.id)-$($c.name)"
  $dir = Join-Path $repo $c.dir
  if (-not (Test-Path $dir)) { throw "module not found: $dir" }
  Write-Output "[verify] $label ($($c.pkg) -run $($c.run))"
  Push-Location $dir
  try { $out = & go test $c.pkg -run $c.run -count=1 2>&1; $ok = ($LASTEXITCODE -eq 0) } finally { Pop-Location }
  $last = ($out | Select-Object -Last 1)
  # "[no test files]" must never be recorded as PASS.
  $hasTests = -not ($last -match 'no test files')
  $passed = ($ok -and $hasTests)
  Write-Output ("  {0}  {1}" -f ($(if ($passed) { 'PASS' } elseif (-not $hasTests) { 'NOT VERIFIED (no test files)' } else { 'FAIL' })), $last)
  $results += [pscustomobject]@{ case = $label; package = $c.pkg; run = $c.run; passed = $passed; has_tests = $hasTests; output = $last }
}

$report = [pscustomobject]@{
  generated_at = (Get-Date).ToString('o')
  environment  = "PRAXOVELA_DIR=$repo"
  cases        = $results
  passed       = (($results | Where-Object { -not $_.passed } | Measure-Object).Count -eq 0)
}
$path = Join-Path $reportDir "memory-engine.json"
$report | ConvertTo-Json -Depth 5 | Set-Content $path
Write-Output "[verify] report: $path"
if (-not $report.passed) { throw "one or more cases failed or were not verified; see $path" }
