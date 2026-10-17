# fault-injection.ps1 — R6 deployed work-item closure under injected failure.
#
# Requires the bridge stack from start-services.ps1 (axond + Rheovela + AEGIVELA)
# and `sqlite3` on PATH (or set $env:SQLITE3).
#
# It seeds work items directly into the running Rheovela DB (the runtime has no
# HTTP "create work item" surface; a producer owns creation), then drives the
# whole loop through the deployed axond bridge:
#   1. claim -> complete        (closure: effect -> outcome)
#   2. claim -> fail (injected) (fault: item becomes `failed`, not reclaimable)
#
# Result is written to .local-data\fault-injection-report.json.
param()
$ErrorActionPreference = "Stop"
if (-not $env:AXON_API_KEY) { throw "Load local.env.ps1 before running this script." }

$base   = "http://127.0.0.1:{0}" -f $env:AXOND_PORT
$H      = @{ Authorization = "Bearer $($env:AXON_API_KEY)"; 'Content-Type' = 'application/json' }
$sqlite = if ($env:SQLITE3) { $env:SQLITE3 } else { "sqlite3" }
$db     = Join-Path $PSScriptRoot ".local-data\rheo.db"
$report = [ordered]@{ case = "R6-fault-injection"; instance = ""; happy = @{}; injected = @{}; retry_supported = $false }

function Post($path, $body) {
  Invoke-RestMethod -Method Post -Uri "$base$path" -Headers $H -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 15
}
function ListItems($instance) {
  Invoke-RestMethod -Method Get -Uri "$base/v1/work-items?instance=$instance" -Headers $H -TimeoutSec 10
}
function DbState($id) {
  (& $sqlite $db "select state from work_items where id='$id';" 2>$null | Out-String).Trim()
}
function Seed($id, $instance) {
  & $sqlite $db "INSERT INTO work_items (id, instance_id, activity_id, state, assignee) VALUES ('$id','$instance','act-r6','ready','e2e-operator');" 2>$null | Out-Null
}

$inst = Post "/v1/instances" @{ workflow = $env:WORKFLOW_ID; project = 'fault-injection'; actor = 'e2e-operator' }
$iid = $inst.instance_id
$report.instance = $iid
Write-Output "[fault-injection] instance=$iid status=$($inst.status)"

# --- 1. happy closure: claim -> complete ------------------------------------
$ok = "wi-ok-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
Seed $ok $iid
$listed = @(ListItems $iid)
$seen = ($listed | Where-Object { $_.id -eq $ok }).Count -gt 0
$claim = Post "/v1/work-items/$ok/claim" @{ lease = '30s' }
Post "/v1/work-items/$ok/complete" @{ token = $claim.token } | Out-Null
$okState = DbState $ok
$report.happy = @{ work_item = $ok; listed = $seen; claim_token = $claim.token; final_state = $okState; closed = ($okState -eq 'done') }
Write-Output ("[fault-injection] happy: listed={0} final_state={1}" -f $seen, $okState)

# --- 2. injected failure: claim -> fail -------------------------------------
$bad = "wi-bad-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
Seed $bad $iid
$claim2 = Post "/v1/work-items/$bad/claim" @{ lease = '30s' }
Post "/v1/work-items/$bad/fail" @{ token = $claim2.token; error = 'injected-transient' } | Out-Null
$badState = DbState $bad
$reclaimable = $true; $reclaimErr = ""
try { Post "/v1/work-items/$bad/claim" @{ lease = '30s' } | Out-Null }
catch { $reclaimable = $false; $reclaimErr = $_.Exception.Message }
$report.injected = @{ work_item = $bad; final_state = $badState; reclaimable = $reclaimable; reclaim_error = $reclaimErr }
$report.retry_supported = $reclaimable
Write-Output ("[fault-injection] injected fail: final_state={0} reclaimable={1}" -f $badState, $reclaimable)

$out = Join-Path $PSScriptRoot ".local-data\fault-injection-report.json"
$report | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $out
Write-Output "[fault-injection] report: $out"
