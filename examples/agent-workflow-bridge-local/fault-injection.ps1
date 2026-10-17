# fault-injection.ps1 — R6 deployed work-item closure under injected failure.
#
# Requires the bridge stack from start-services.ps1 (axond + Rheovela + AEGIVELA)
# and `sqlite3` on PATH (or set $env:SQLITE3).
#
# The runtime has no HTTP "create work item" surface (a producer owns creation),
# so items are seeded into the running Rheovela DB, then the whole loop is driven
# through the deployed axond bridge:
#   1. claim -> complete                 (closure: effect -> outcome)
#   2. claim -> fail -> requeue -> claim -> complete  (retry policy)
#   3. max_attempts=1: claim -> fail     (terminal `failed`, not reclaimable)
#
# Result is written to .local-data\fault-injection-report.json.
param()
$ErrorActionPreference = "Stop"
if (-not $env:AXON_API_KEY) { throw "Load local.env.ps1 before running this script." }

$base   = "http://127.0.0.1:{0}" -f $env:AXOND_PORT
$H      = @{ Authorization = "Bearer $($env:AXON_API_KEY)"; 'Content-Type' = 'application/json' }
$sqlite = if ($env:SQLITE3) { $env:SQLITE3 } else { "sqlite3" }
$db     = Join-Path $PSScriptRoot ".local-data\rheo.db"
$report = [ordered]@{ case = "R6-fault-injection"; instance = ""; happy = @{}; retry = @{}; exhausted = @{}; retry_supported = $false }

function Post($path, $body) {
  Invoke-RestMethod -Method Post -Uri "$base$path" -Headers $H -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 15
}
function ListItems($instance) {
  Invoke-RestMethod -Method Get -Uri "$base/v1/work-items?instance=$instance" -Headers $H -TimeoutSec 10
}
function DbState($id) {
  (& $sqlite $db "select state from work_items where id='$id';" 2>$null | Out-String).Trim()
}
function DbAttempts($id) {
  (& $sqlite $db "select attempts from work_items where id='$id';" 2>$null | Out-String).Trim()
}
function Seed($id, $instance, $maxAttempts = 3) {
  & $sqlite $db "INSERT INTO work_items (id, instance_id, activity_id, state, assignee, attempts, max_attempts) VALUES ('$id','$instance','act-r6','ready','e2e-operator',0,$maxAttempts);" 2>$null | Out-Null
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

# --- 2. retry: claim -> fail -> requeue -> reclaim -> complete --------------
$retry = "wi-retry-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
Seed $retry $iid 3
$c1 = Post "/v1/work-items/$retry/claim" @{ lease = '30s' }
Post "/v1/work-items/$retry/fail" @{ token = $c1.token; error = 'injected-transient' } | Out-Null
$afterFail = DbState $retry
$c2 = $null; $retryErr = ""
try { $c2 = Post "/v1/work-items/$retry/claim" @{ lease = '30s' } } catch { $retryErr = $_.Exception.Message }
if ($c2) { Post "/v1/work-items/$retry/complete" @{ token = $c2.token } | Out-Null }
$retryFinal = DbState $retry
$report.retry = @{ work_item = $retry; state_after_fail = $afterFail; attempts_after_fail = (DbAttempts $retry); reclaimable = [bool]$c2; final_state = $retryFinal; reclaim_error = $retryErr }
$report.retry_supported = ($afterFail -eq 'ready') -and [bool]$c2 -and ($retryFinal -eq 'done')
Write-Output ("[fault-injection] retry: after_fail={0} reclaimable={1} final={2}" -f $afterFail, [bool]$c2, $retryFinal)

# --- 3. exhaustion: max_attempts=1 -> terminal failed -----------------------
$ex = "wi-exhaust-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
Seed $ex $iid 1
$c3 = Post "/v1/work-items/$ex/claim" @{ lease = '30s' }
Post "/v1/work-items/$ex/fail" @{ token = $c3.token; error = 'injected-terminal' } | Out-Null
$exState = DbState $ex
$exReclaimable = $true; $exErr = ""
try { Post "/v1/work-items/$ex/claim" @{ lease = '30s' } | Out-Null } catch { $exReclaimable = $false; $exErr = $_.Exception.Message }
$report.exhausted = @{ work_item = $ex; final_state = $exState; reclaimable = $exReclaimable; reclaim_error = $exErr }
Write-Output ("[fault-injection] exhausted: final_state={0} reclaimable={1}" -f $exState, $exReclaimable)

$out = Join-Path $PSScriptRoot ".local-data\fault-injection-report.json"
$report | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $out
Write-Output "[fault-injection] report: $out"
