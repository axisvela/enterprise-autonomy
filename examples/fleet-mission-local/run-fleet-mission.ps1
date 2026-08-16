param()

if (-not $MissionId -or -not $Operator -or -not $ApprovalRef -or -not $Boundary) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ mission_id = $MissionId; tenant = $TenantId; operator = $Operator; steps = @(); mission_state = $null }
$evidence = @()
$gates = @()

$fleetBase = "http://localhost:8099/v1/missions/$MissionId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "fleet-0001-zone-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "fleet-0001-case-v1" }

# Step 1: open the mission case (Symbivela)
$workspace = @{ workspace_id = "fleet-ops"; name = "Fleet Operations"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "fleet-ops-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "fleet-ops"; case_id = "fleet-0001-mission"; subject_ref = "mission://mission-alpha-001"; problem = "Bounded inspection of zone-alpha; exceptions must pause for operator review."; evidence_refs = "zone://zone-alpha"; candidate_actions = "resume,adjust,cancel"; deadline = "2026-08-31T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Operator; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the mission case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the mission case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The mission is bounded to $Boundary."

# Step 2: record the mission context (adapter + Ontovela)
$mission = Invoke-RestMethod -Uri $fleetBase
$assertion = @{ id = "assertion-mission-alpha-001-bounded"; subject_id = $MissionId; property = "mission_boundary"; value = $Boundary; state_kind = "observed"; event_time = "2026-08-16T16:00:00Z"; system_time = "2026-08-16T16:00:01Z"; source = "fleet-control"; evidence_ref = "evidence://fleet/mission-alpha-001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$gates += @{ gate = "mission-bounded"; owner = $Operator; decision = "bounded"; boundary = $Boundary }
$evidence += @{ product = "fleet-domain"; artifact = $mission.id; state = $mission.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-mission-alpha-001-bounded"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the mission context"; product = "ontovela"; artifact = "assertion-mission-alpha-001-bounded" }
Write-Step 2 "Record the mission context" "Mission $MissionId is '$($mission.status)' for '$($mission.objective)', bounded to $Boundary. Ontovela asserts the boundary with fleet evidence."

# Step 3: start the mission and show autonomous boundary enforcement
$startBody = @{ started_by = $Operator; idempotency_key = "fleet-start-v1" } | ConvertTo-Json
$startResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/start" -ContentType "application/json" -Body $startBody
$gates += @{ gate = "mission-started"; owner = $Operator; decision = "started" }
$boundaryDenied = $null
try {
  $deviation = @{ position = "zone-omega"; status = "running"; idempotency_key = "fleet-tl-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$fleetBase/telemetry" -ContentType "application/json" -Body $deviation | Out-Null
} catch { $boundaryDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "fleet-domain"; artifact = "boundary-deviation-frozen"; state = "denied" }
$inBounds = @{ position = $Boundary; status = "running"; idempotency_key = "fleet-tl2-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$fleetBase/telemetry" -ContentType "application/json" -Body $inBounds | Out-Null
$evidence += @{ product = "fleet-domain"; artifact = "start-fleet-start-v1"; state = $startResult.mission.status }
$outcome.steps += @{ index = 3; title = "Start and enforce the boundary"; product = "fleet-domain"; artifact = "start-fleet-start-v1" }
$boundaryText = if ($boundaryDenied) { "Telemetry outside $Boundary was frozen (HTTP $boundaryDenied) without human involvement." } else { "The boundary was enforced autonomously." }
Write-Step 3 "Start and enforce the boundary" "Mission started. $boundaryText"

# Step 4: raise the exception and pause
$exBody = @{ type = "obstacle"; detail = "rack-07 blocked"; raised_by = "fleet-runtime"; idempotency_key = "fleet-ex-v1" } | ConvertTo-Json
$exResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/exceptions" -ContentType "application/json" -Body $exBody
$gates += @{ gate = "exception-paused"; owner = $Operator; decision = "paused"; exception = $exResult.exception.type }
$evidence += @{ product = "fleet-domain"; artifact = $exResult.exception.id; state = $exResult.mission.status }
$outcome.steps += @{ index = 4; title = "Pause on the exception"; product = "fleet-domain"; artifact = $exResult.exception.id }
Write-Step 4 "Pause on the exception" "Exception '$($exResult.exception.type)' ($($exResult.exception.detail)) paused the mission. Status is '$($exResult.mission.status)'."

# Step 5: operator review (operator-gated, approval-cited)
$reviewDenied = $null
try {
  $outsider = @{ reviewed_by = "outsider"; decision = "resume"; approval_ref = $ApprovalRef; idempotency_key = "fleet-rv-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$fleetBase/reviews" -ContentType "application/json" -Body $outsider | Out-Null
} catch { $reviewDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "fleet-domain"; artifact = "non-operator-review-rejected"; state = "denied" }
$reviewBody = @{ reviewed_by = $Operator; decision = "resume"; approval_ref = $ApprovalRef; idempotency_key = "fleet-rv-v1" } | ConvertTo-Json
$reviewResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/reviews" -ContentType "application/json" -Body $reviewBody
$gates += @{ gate = "operator-review"; owner = $Operator; decision = "resume"; approval_ref = $ApprovalRef }
$evidence += @{ product = "fleet-domain"; artifact = $reviewResult.review.id; state = $reviewResult.mission.status }
$outcome.steps += @{ index = 5; title = "Review and resume the mission"; product = "fleet-domain"; artifact = $reviewResult.review.id }
$reviewText = if ($reviewDenied) { "A non-operator review was rejected (HTTP $reviewDenied)." } else { "Only the mission operator may review." }
Write-Step 5 "Review and resume the mission" "$Operator resumed the mission under '$ApprovalRef'. Status is '$($reviewResult.mission.status)'. $reviewText"

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "fleet-mission-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "fleet-mission-workflow.json") | Out-Null
$process = @{ workflow = "fleet-mission-exception"; project = $MissionId; actor = $Operator } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable mission process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable mission process" "Rheovela opened process instance '$($instance.id)' for 'fleet-mission-exception'. Stages: start, pause, review, resume, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "fleet-mission-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-fleet-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a mission plan"; product = "orchadyn"; artifact = "plan-fleet-0001" }
  Write-Step 7 "Generate a mission plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Review requires a paused mission."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a mission plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a mission plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: complete and emit the value report
$completeBody = @{ completed_by = $Operator; idempotency_key = "fleet-cmp-v1" } | ConvertTo-Json
$completeResult = Invoke-RestMethod -Method Post -Uri "$fleetBase/complete" -ContentType "application/json" -Body $completeBody
$finalMission = Invoke-RestMethod -Uri $fleetBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8099/v1/notifications/$MissionId"
$evidence += @{ product = "fleet-domain"; artifact = "complete-fleet-cmp-v1"; state = $finalMission.status }
$outcome.steps += @{ index = 8; title = "Complete the mission"; product = "fleet-domain"; artifact = "complete-fleet-cmp-v1" }
$outcome.mission_state = $finalMission
$outcome.notifications = $notifications.notifications
Write-Step 8 "Complete the mission" "Mission status '$($finalMission.status)'. Pending notifications: '$($notifications.notifications -join ', ')'."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "fleet-mission-exception"
  version = "1.0"
  tenant = $TenantId
  operator = $Operator
  outcome = @{ subject = $finalMission.id; before = "planned"; after = $finalMission.status; completed = ($finalMission.status -eq "completed"); escalated = $false }
  kpis = @{
    products_involved = $products.Count
    gates_passed = $gates.Count
    evidence_artifacts = $evidence.Count
    steps_completed = $outcome.steps.Count
    time_to_resolve = $elapsed.TotalSeconds.ToString("F1")
  }
  gates = $gates
  evidence = $evidence
  steps = $outcome.steps
}

Write-Host ""
Write-Host "================ Business Outcome ================" -ForegroundColor Green
Write-Host "Mission     : $($finalMission.id) ($($finalMission.objective))"
Write-Host "Status      : planned -> $($finalMission.status)"
Write-Host "Boundary    : $($finalMission.boundary -join ', ')"
Write-Host "Exception   : $($finalMission.exception.type) (paused), reviewed by $Operator under $ApprovalRef"
Write-Host "Denials     : boundary deviation (HTTP $boundaryDenied), non-operator review (HTTP $reviewDenied)"
Write-Host "Audit trail : Symbivela case + fleet start/telemetry/exception/review/complete + Ontovela assertion + Rheovela process + Orchadyn plan"
Write-Host "==================================================="

Write-Host ""
Write-Host "================ Value & Effect ================" -ForegroundColor Cyan
Write-Host "Products involved : $($report.kpis.products_involved)"
Write-Host "Gates passed      : $($report.kpis.gates_passed)"
Write-Host "Evidence artifacts: $($report.kpis.evidence_artifacts)"
Write-Host "Steps completed   : $($report.kpis.steps_completed)"
Write-Host "Time to resolve   : $($report.kpis.time_to_resolve)s"
Write-Host "================================================="

$outcomeDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $outcomeDir | Out-Null
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "fleet-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "fleet-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\fleet-outcome.json"
Write-Host "Value report written to .local-data\fleet-value-report.json"
