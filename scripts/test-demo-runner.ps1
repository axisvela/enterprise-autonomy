param()

$ErrorActionPreference = "Stop"
$root = Join-Path ([IO.Path]::GetTempPath()) ("demo runner's tests " + [guid]::NewGuid().ToString("N"))
$shell = (Get-Process -Id $PID).Path
$source = Join-Path $PSScriptRoot "..\examples\run-all-demos.ps1"
$passed = 0
$fixtures = 0

function New-Fixture {
  $script:fixtures++
  $dir = New-Item -ItemType Directory -Path (Join-Path $root "case-$script:fixtures")
  Copy-Item -LiteralPath $source -Destination (Join-Path $dir "run-all-demos.ps1")
  $demo = New-Item -ItemType Directory -Path (Join-Path $dir "order-fulfillment-local")
  foreach ($name in @("README.md", "operations-guide.md", "local.env.ps1.example", "evidence-schema.md", "run-all.ps1")) {
    "fixture" | Set-Content -LiteralPath (Join-Path $demo $name)
  }
  foreach ($name in @("local.env.ps1", "start-services.ps1", "verify.ps1")) {
    "`$global:LASTEXITCODE = 0" | Set-Content -LiteralPath (Join-Path $demo $name)
  }
  "exit 0" | Set-Content -LiteralPath (Join-Path $dir "stop-demo.ps1")
  @'
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force .local-data | Out-Null
'{"example":"fixture","outcome":{"before":"pending","after":"done","completed":true},"kpis":{"gates_passed":1}}' | Set-Content .local-data/order-value-report.json
exit 0
'@ | Set-Content -LiteralPath (Join-Path $demo "run-order-exception.ps1")
  return $dir.FullName
}

function Invoke-Fixture($dir, $arguments, $expectedExit) {
  $ErrorActionPreference = "Continue"
  & $shell -NoProfile -NonInteractive -File (Join-Path $dir "run-all-demos.ps1") -Only order-fulfillment-local @arguments *> (Join-Path $dir "runner.log")
  $code = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  if ($code -ne $expectedExit) { throw "Expected exit $expectedExit, got $code; inspect $dir" }
  $reports = @(Get-ChildItem -LiteralPath (Join-Path $dir "_reports") -Recurse -Filter all-demos-report.json)
  if ($reports.Count -eq 0) { throw "No execution report in $dir" }
  return Get-Content -Raw -LiteralPath $reports[-1].FullName | ConvertFrom-Json
}

function Assert($condition, $message) {
  if (-not $condition) { throw $message }
}

try {
  New-Item -ItemType Directory -Path $root | Out-Null
  $dir = New-Fixture
  $report = Invoke-Fixture $dir @("-Strict") 0
  Assert ($report.acceptance -eq "satisfied" -and $report.counts.passed -eq 1 -and $report.demos.Count -eq 1) "Pass was not recorded"
  Assert ($report.results[0].phases.Count -eq 4 -and $report.results[0].artifacts[0].sha256.Length -eq 64) "Missing phase or artifact evidence"
  $passed++

  $report = Invoke-Fixture $dir @("-Strict") 0
  $reports = @(Get-ChildItem -LiteralPath (Join-Path $dir "_reports") -Recurse -Filter all-demos-report.json)
  Assert ($reports.Count -eq 2) "Retry overwrote a previous execution"
  Assert (@($reports | ForEach-Object { (Get-Content -Raw $_.FullName | ConvertFrom-Json).execution_id } | Select-Object -Unique).Count -eq 2) "Execution IDs reused"
  $passed++

  $dir = New-Fixture
  Remove-Item -LiteralPath (Join-Path $dir "order-fulfillment-local/local.env.ps1")
  $report = Invoke-Fixture $dir @("-Strict") 1
  Assert ($report.counts.skipped -eq 1 -and $report.acceptance -eq "unsatisfied" -and $report.demos.Count -eq 0) "Strict skip accepted"
  $report = Invoke-Fixture $dir @() 0
  Assert ($report.acceptance -eq "unsatisfied") "Non-strict skip mislabeled as acceptance"
  $passed++

  $dir = New-Fixture
  $report = Invoke-Fixture $dir @("-Strict", "-Skip", "order-fulfillment-local") 1
  Assert ($report.counts.skipped -eq 1) "Explicit skip disappeared from inventory"
  $passed++

  $dir = New-Fixture
  $report = Invoke-Fixture $dir @("-CheckOnly") 0
  Assert ($report.counts.'structure-only' -eq 1 -and $report.acceptance -eq "not-evaluated" -and $report.demos.Count -eq 0) "Structure check reported execution"
  $null = Invoke-Fixture $dir @("-CheckOnly", "-Strict") 1
  $passed++

  foreach ($phase in @("start-services.ps1", "run-order-exception.ps1", "verify.ps1")) {
    $dir = New-Fixture
    "exit 7" | Set-Content -LiteralPath (Join-Path $dir "order-fulfillment-local/$phase")
    $report = Invoke-Fixture $dir @("-Strict") 1
    Assert ($report.counts.failed -eq 1 -and $report.demos.Count -eq 0) "Stage failure accepted: $phase"
    Assert ($report.results[0].phases[-1].name -eq "cleanup") "No cleanup after $phase failure"
    $passed++
  }

  $dir = New-Fixture
  "exit 9" | Set-Content -LiteralPath (Join-Path $dir "stop-demo.ps1")
  $report = Invoke-Fixture $dir @("-Strict") 1
  Assert ($report.counts.failed -eq 1 -and $report.results[0].findings.Count -eq 1 -and $report.demos.Count -eq 0) "Cleanup failure hidden"
  $passed++

  $dir = New-Fixture
  $null = Invoke-Fixture $dir @("-Strict") 0
  "exit 0" | Set-Content -LiteralPath (Join-Path $dir "order-fulfillment-local/run-order-exception.ps1")
  $null = Invoke-Fixture $dir @("-Strict") 1
  $all = @(Get-ChildItem -LiteralPath (Join-Path $dir "_reports") -Recurse -Filter all-demos-report.json | ForEach-Object { Get-Content -Raw $_.FullName | ConvertFrom-Json })
  Assert (@($all | Where-Object { $_.acceptance -eq "unsatisfied" -and $_.demos.Count -eq 0 }).Count -eq 1) "Old report reused after missing current report"
  Assert (@(Get-ChildItem -LiteralPath (Join-Path $dir "_reports") -Recurse -Filter previous-report.json).Count -eq 1) "Old evidence not preserved"
  $passed++

  foreach ($body in @("'invalid json'", "'{`"outcome`":{`"completed`":false}}'", "'{`"outcome`":{`"completed`":`"true`"}}'")) {
    $dir = New-Fixture
    "New-Item -ItemType Directory -Force .local-data | Out-Null`n$body | Set-Content .local-data/order-value-report.json`nexit 0" | Set-Content -LiteralPath (Join-Path $dir "order-fulfillment-local/run-order-exception.ps1")
    $report = Invoke-Fixture $dir @("-Strict") 1
    Assert ($report.counts.failed -eq 1 -and $report.demos.Count -eq 0) "Invalid outcome accepted"
    $passed++
  }

  $dir = New-Fixture
  Remove-Item -LiteralPath (Join-Path $dir "order-fulfillment-local/verify.ps1")
  $report = Invoke-Fixture $dir @("-Strict") 1
  Assert ($report.counts.failed -eq 1 -and $report.results[0].phases.Count -eq 0) "Missing fixture did not fail before execution"
  $passed++

  $dir = New-Fixture
  $ErrorActionPreference = "Continue"
  & $shell -NoProfile -NonInteractive -File (Join-Path $dir "run-all-demos.ps1") -Only nonexistent *> (Join-Path $dir "unknown.log")
  $code = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  Assert ($code -ne 0) "Unknown scenario silently accepted"
  $passed++

  Write-Host "test-demo-runner: passed=$passed failed=0 skipped=0 (synthetic fixtures, no live services)"
} catch {
  Write-Host "test-demo-runner: passed=$passed failed=1; fixture evidence retained at $root"
  throw
} finally {
  if ($passed -eq 15) { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }
}

exit 0
