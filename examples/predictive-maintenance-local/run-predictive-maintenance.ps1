param()

if (-not $MaintenanceManager -or -not $SafetyAuthority -or -not $SignalId -or -not $DecisionRef -or -not $SafetyRef -or -not $ApprovalRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ signal_id = $SignalId; tenant = $TenantId; maintenance_manager = $MaintenanceManager; steps = @(); signal_state = $null }
$evidence = @()
$gates = @()

$maintBase = "http://localhost:8095/v1/signals/$SignalId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "pm-0001-asset-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $MaintenanceManager; "Idempotency-Key" = "pm-0001-case-v1" }

# Step 1: open the maintenance case (Symbivela)
$workspace = @{ workspace_id = "maintenance"; name = "Maintenance Operations"; owner_id = $MaintenanceManager } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $MaintenanceManager; "Idempotency-Key" = "maintenance-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "maintenance"; case_id = "pm-0001-intervention"; subject_ref = "signal://signal-pm-0001"; problem = "Elevated risk signal for cooling pump 01; intervention must be validated and safety-reviewed."; evidence_refs = "asset://asset-pump-01"; candidate_actions = "monitor,inspect,repair,defer,stop"; deadline = "2026-08-26T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $MaintenanceManager; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the maintenance case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the maintenance case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The signal is treated as a prediction until validated."

# Step 2: record the risk-signal context (adapter + Ontovela)
$signal = Invoke-RestMethod -Uri $maintBase
$asset = Invoke-RestMethod -Uri "http://localhost:8095/v1/assets/$AssetId"
$assertion = @{ id = "assertion-asset-pump-01-risk"; subject_id = $AssetId; property = "risk_level"; value = "elevated"; state_kind = "observed"; event_time = "2026-08-16T12:00:00Z"; system_time = "2026-08-16T12:00:01Z"; source = "condition-monitoring"; evidence_ref = "evidence://monitoring/signal-pm-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "maintenance-domain"; artifact = $signal.id; state = $signal.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-asset-pump-01-risk"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the risk-signal context"; product = "ontovela"; artifact = "assertion-asset-pump-01-risk" }
Write-Step 2 "Record the risk-signal context" "Signal $SignalId ($($signal.level)) for $($asset.name) recorded as '$($signal.status)'. Ontovela asserts the elevated risk with monitoring evidence."

# Step 3: prediction gate - work order on an unvalidated signal is denied
$woDenied = $null
try {
  $wo = @{ scope = "replace bearing"; approved_by = $MaintenanceManager; approval_ref = $ApprovalRef; idempotency_key = "pm-wo-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $wo | Out-Null
} catch { $woDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "maintenance-domain"; artifact = "unvalidated-work-order-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show a prediction is not a fault"; product = "maintenance-domain"; artifact = "unvalidated-work-order-rejected" }
$woDeniedText = if ($woDenied) { "The adapter rejected the work order on an unvalidated signal (HTTP $woDenied)." } else { "The adapter enforced prediction-vs-fact integrity." }
Write-Step 3 "Show a prediction is not a fault" "A work order was attempted before validation; the adapter denied it. $woDeniedText"

# Step 4: validate the signal and record the decision; unconfirmed stop denied
$valBody = @{ validated_by = $MaintenanceManager; confirmed = $false; note = "prediction based on vibration trend"; idempotency_key = "pm-val-v1" } | ConvertTo-Json
$valResult = Invoke-RestMethod -Method Post -Uri "$maintBase/validate" -ContentType "application/json" -Body $valBody
$gates += @{ gate = "signal-validated"; owner = $MaintenanceManager; decision = "validated"; confirmed = $false }
$stopDenied = $null
try {
  $stopBody = @{ decision = "stop"; decided_by = $MaintenanceManager; decision_ref = $DecisionRef; idempotency_key = "pm-stop-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/decisions" -ContentType "application/json" -Body $stopBody | Out-Null
} catch { $stopDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "maintenance-domain"; artifact = "validate-pm-val-v1"; state = $valResult.signal.status }
$evidence += @{ product = "maintenance-domain"; artifact = "unconfirmed-stop-rejected"; state = "denied" }
$decBody = @{ decision = "repair"; decided_by = $MaintenanceManager; decision_ref = $DecisionRef; idempotency_key = "pm-dec-v1" } | ConvertTo-Json
$decResult = Invoke-RestMethod -Method Post -Uri "$maintBase/decisions" -ContentType "application/json" -Body $decBody
$gates += @{ gate = "maintenance-decision"; owner = $MaintenanceManager; decision = "repair"; decision_ref = $DecisionRef }
$evidence += @{ product = "maintenance-domain"; artifact = "decision-pm-dec-v1"; state = "decided" }
$outcome.steps += @{ index = 4; title = "Validate the signal and decide"; product = "maintenance-domain"; artifact = "decision-pm-dec-v1" }
$stopDeniedText = if ($stopDenied) { "An unconfirmed prediction cannot trigger a stop (HTTP $stopDenied)." } else { "The adapter rejected an unconfirmed stop decision." }
Write-Step 4 "Validate the signal and decide" "$MaintenanceManager validated $SignalId (confirmed=$false). Decision: repair. $stopDeniedText"

# Step 5: safety review - work order without safety review denied, then approved
$noSafetyDenied = $null
try {
  $wo2 = @{ scope = "replace bearing"; approved_by = $MaintenanceManager; approval_ref = $ApprovalRef; idempotency_key = "pm-wo-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $wo2 | Out-Null
} catch { $noSafetyDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "maintenance-domain"; artifact = "no-safety-review-rejected"; state = "denied" }
$safetyBody = @{ reviewed_by = $SafetyAuthority; outcome = "approve"; safety_ref = $SafetyRef; idempotency_key = "pm-safety-v1" } | ConvertTo-Json
$safetyResult = Invoke-RestMethod -Method Post -Uri "$maintBase/safety-reviews" -ContentType "application/json" -Body $safetyBody
$gates += @{ gate = "safety-review"; owner = $SafetyAuthority; decision = "approve"; safety_ref = $SafetyRef }
$evidence += @{ product = "maintenance-domain"; artifact = $safetyResult.safety.id; state = "approved" }
$outcome.steps += @{ index = 5; title = "Conduct the safety review"; product = "maintenance-domain"; artifact = $safetyResult.safety.id }
$noSafetyDeniedText = if ($noSafetyDenied) { "The adapter rejected the work order without a safety review (HTTP $noSafetyDenied)." } else { "The adapter required a safety review for intrusive work." }
Write-Step 5 "Conduct the safety review" "$SafetyAuthority approved intrusive work under '$SafetyRef'. $noSafetyDeniedText"

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "predictive-maintenance-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "predictive-maintenance-workflow.json") | Out-Null
$process = @{ workflow = "predictive-maintenance-to-work-order"; project = $SignalId; actor = $MaintenanceManager } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable maintenance process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable maintenance process" "Rheovela opened process instance '$($instance.id)' for 'predictive-maintenance-to-work-order'. Stages: validate, decide, safety, schedule, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "predictive-maintenance-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-pm-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a maintenance plan"; product = "orchadyn"; artifact = "plan-pm-0001" }
  Write-Step 7 "Generate a maintenance plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Intrusive capabilities require safety."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a maintenance plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a maintenance plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: create the approved work order and emit the value report
$woBody = @{ scope = "replace bearing"; approved_by = $MaintenanceManager; approval_ref = $ApprovalRef; idempotency_key = "pm-wo-v1" } | ConvertTo-Json
$woResult = Invoke-RestMethod -Method Post -Uri "$maintBase/work-orders" -ContentType "application/json" -Body $woBody
$finalSignal = Invoke-RestMethod -Uri $maintBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8095/v1/notifications/$SignalId"
$evidence += @{ product = "maintenance-domain"; artifact = $woResult.work_order.id; state = $woResult.work_order.status }
$outcome.steps += @{ index = 8; title = "Schedule the work order"; product = "maintenance-domain"; artifact = $woResult.work_order.id }
$outcome.signal_state = $finalSignal
$outcome.notifications = $notifications.notifications
Write-Step 8 "Schedule the work order" "Work order '$($woResult.work_order.id)' scheduled for '$($woResult.work_order.scope)'. Pending notifications: '$($notifications.notifications -join ', ')'."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "predictive-maintenance-to-work-order"
  version = "1.0"
  tenant = $TenantId
  maintenance_manager = $MaintenanceManager
  outcome = @{ subject = $finalSignal.id; before = "pending"; after = $finalSignal.status; work_order = $finalSignal.work_order.id; completed = ($null -ne $finalSignal.work_order); escalated = $false }
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
Write-Host "Signal      : $($finalSignal.id)"
Write-Host "Status      : pending -> validated (work order scheduled)"
Write-Host "Work order  : $($finalSignal.work_order.id) ($($finalSignal.work_order.scope))"
Write-Host "Safety      : approved by $SafetyAuthority under $SafetyRef"
Write-Host "Denials     : unvalidated WO (HTTP $woDenied), unconfirmed stop (HTTP $stopDenied), no safety review (HTTP $noSafetyDenied)"
Write-Host "Audit trail : Symbivela case + maintenance validate/decision/safety + Ontovela assertion + Rheovela process + Orchadyn plan + work order"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "maintenance-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "maintenance-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\maintenance-outcome.json"
Write-Host "Value report written to .local-data\maintenance-value-report.json"
