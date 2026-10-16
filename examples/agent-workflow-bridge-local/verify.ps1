# Runs the Case 04 bridge calls through axond and prints the evidence.
$ErrorActionPreference = "Stop"
if (-not $env:AXON_API_KEY) { throw "Load local.env.ps1 before running this script." }

$base = "http://127.0.0.1:{0}" -f $env:AXOND_PORT
$H = @{ Authorization = "Bearer $($env:AXON_API_KEY)"; 'Content-Type' = 'application/json' }

Write-Output "[verify] axond health"
(Invoke-WebRequest -Uri "$base/health" -UseBasicParsing -TimeoutSec 5).Content

Write-Output "[verify] orchestrator wired?"
$log = Join-Path $PSScriptRoot ".local-logs\axond.err.log"
if (Test-Path $log) {
  (Select-String -Path $log -Pattern 'Orchestrator: Rheovela' | Select-Object -First 1 -ExpandProperty Line)
}

Write-Output "[verify] open run"
$inst = Invoke-RestMethod -Method Post -Uri "$base/v1/instances" -Headers $H -TimeoutSec 20 `
  -Body (@{ workflow = $env:WORKFLOW_ID; project = 'e2e-proj'; actor = 'e2e-operator' } | ConvertTo-Json -Compress)
$id = $inst.instance_id
Write-Output ("  instance={0} status={1}" -f $id, $inst.status)

Write-Output "[verify] get instance"
$got = Invoke-RestMethod -Method Get -Uri "$base/v1/instances/$id" -Headers $H -TimeoutSec 10
Write-Output ("  status={0} definition_id={1}" -f $got.status, $got.definition_id)

Write-Output "[verify] step enter/validate"
$step = Invoke-RestMethod -Method Post -Uri "$base/v1/instances/$id/steps" -Headers $H -TimeoutSec 10 `
  -Body (@{ action = 'enter'; stage = 'validate'; actor = 'e2e-operator' } | ConvertTo-Json -Compress)
Write-Output ("  {0}" -f ($step | ConvertTo-Json -Compress))

Write-Output "[verify] audit"
$audit = Invoke-RestMethod -Method Get -Uri "$base/v1/instances/$id/audit" -Headers $H -TimeoutSec 10
Write-Output ("  audit entries={0}" -f (($audit.entries | Measure-Object).Count))

Write-Output "[verify] done"
