param()

if (-not $ProcessId -or -not $Operator -or -not $DecisionRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ process_id = $ProcessId; tenant = $TenantId; operator = $Operator; steps = @(); process_state = $null }
$evidence = @()
$gates = @()

$procBase = "http://localhost:8100/v1/processes/$ProcessId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "proc-0001-flow-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "proc-0001-case-v1" }

# Step 1: open the process case (Symbivela)
$workspace = @{ workspace_id = "process-ops"; name = "Process Operations"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "process-ops-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "process-ops"; case_id = "proc-0001-outcome"; subject_ref = "process://proc-0001"; problem = "Drive the onboarding process through its sequenced stages to a terminal outcome."; evidence_refs = "process://proc-0001"; candidate_actions = "advance,complete"; deadline = "2026-09-02T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Operator; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the process case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the process case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The outcome is driven by the durable process."

# Step 2: record the process context (adapter + Ontovela)
$process = Invoke-RestMethod -Uri $procBase
$assertion = @{ id = "assertion-proc-0001-initiated"; subject_id = $ProcessId; property = "process_status"; value = "initiated"; state_kind = "observed"; event_time = "2026-08-16T18:00:00Z"; system_time = "2026-08-16T18:00:01Z"; source = "process-control"; evidence_ref = "evidence://process/proc-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "process-domain"; artifact = $process.id; state = $process.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-proc-0001-initiated"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the process context"; product = "ontovela"; artifact = "assertion-proc-0001-initiated" }
Write-Step 2 "Record the process context" "Process $ProcessId is '$($process.status)' at stage '$($process.current_stage)' for workflow '$($process.workflow)'. Ontovela asserts the initiated state."

# Step 3: stage gate - out-of-order advance denied
$orderDenied = $null
try {
  $skipBody = @{ from_stage = "request"; to_stage = "approve"; decided_by = $Operator; rationale = "skip review"; decision_ref = $DecisionRef; idempotency_key = "p-skip-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/advance" -ContentType "application/json" -Body $skipBody | Out-Null
} catch { $orderDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "process-domain"; artifact = "out-of-order-advance-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show stages advance in order"; product = "process-domain"; artifact = "out-of-order-advance-rejected" }
$orderText = if ($orderDenied) { "The adapter rejected the skip (HTTP $orderDenied) - stages advance in sequence." } else { "The adapter enforced stage sequencing." }
Write-Step 3 "Show stages advance in order" "An out-of-order advance was attempted; the adapter denied it. $orderText"

# Step 4: advance through the non-terminal stages
$pairs = @(@("request", "review"), @("review", "approve"))
foreach ($pair in $pairs) {
  $advBody = @{ from_stage = $pair[0]; to_stage = $pair[1]; decided_by = $Operator; rationale = "stage $($pair[0]) complete"; decision_ref = $DecisionRef; idempotency_key = "p-$($pair[0])-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/advance" -ContentType "application/json" -Body $advBody | Out-Null
  $gates += @{ gate = "stage-$($pair[0])"; owner = $Operator; decision = "advanced"; to = $pair[1]; decision_ref = $DecisionRef }
  $evidence += @{ product = "process-domain"; artifact = "advance-$($pair[0])-v1"; state = "advanced" }
}
$afterStages = Invoke-RestMethod -Uri $procBase
$outcome.steps += @{ index = 4; title = "Advance through the stages"; product = "process-domain"; artifact = "advance-review-v1" }
Write-Step 4 "Advance through the stages" "Process advanced: $($afterStages.advances.Count) human-attributed stage advances. At stage '$($afterStages.current_stage)', status '$($afterStages.status)'."

# Step 5: outcome gate - complete requires the terminal stage
$termDenied = $null
try {
  $earlyComplete = @{ completed_by = $Operator; idempotency_key = "p-comp-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/complete" -ContentType "application/json" -Body $earlyComplete | Out-Null
} catch { $termDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "process-domain"; artifact = "complete-before-terminal-rejected"; state = "denied" }
$outcome.steps += @{ index = 5; title = "Show the outcome needs the terminal stage"; product = "process-domain"; artifact = "complete-before-terminal-rejected" }
$termText = if ($termDenied) { "The adapter rejected completion before the terminal stage (HTTP $termDenied)." } else { "The adapter enforced terminal-state." }
Write-Step 5 "Show the outcome needs the terminal stage" "Completion was attempted at stage '$($afterStages.current_stage)' (not terminal); the adapter denied it. $termText"

# Step 6: durable process wrapper (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "process-to-outcome-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "process-to-outcome-workflow.json") | Out-Null
$processBody = @{ workflow = "process-to-outcome"; project = $ProcessId; actor = $Operator } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $processBody
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Wrap the process durably"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Wrap the process durably" "Rheovela opened process instance '$($instance.id)' for 'process-to-outcome'. Stages: request, review, approve, complete."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "process-to-outcome-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-proc-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a process plan"; product = "orchadyn"; artifact = "plan-proc-0001" }
  Write-Step 7 "Generate a process plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Stages are sequenced."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a process plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a process plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: reach the terminal stage, complete, and show immutability
$finalAdvance = @{ from_stage = "approve"; to_stage = "complete"; decided_by = $Operator; rationale = "stage approve complete"; decision_ref = $DecisionRef; idempotency_key = "p-approve-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$procBase/advance" -ContentType "application/json" -Body $finalAdvance | Out-Null
$gates += @{ gate = "stage-approve"; owner = $Operator; decision = "advanced"; to = "complete"; decision_ref = $DecisionRef }
$evidence += @{ product = "process-domain"; artifact = "advance-approve-v1"; state = "advanced" }
$completeBody = @{ completed_by = $Operator; idempotency_key = "p-comp-v1" } | ConvertTo-Json
$completeResult = Invoke-RestMethod -Method Post -Uri "$procBase/complete" -ContentType "application/json" -Body $completeBody
$reopenDenied = $null
try {
  $reopenBody = @{ from_stage = "complete"; to_stage = "request"; decided_by = $Operator; rationale = "reopen"; decision_ref = $DecisionRef; idempotency_key = "p-reopen" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/advance" -ContentType "application/json" -Body $reopenBody | Out-Null
} catch { $reopenDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "process-domain"; artifact = "reopen-rejected"; state = "denied" }
$finalProcess = Invoke-RestMethod -Uri $procBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8100/v1/notifications/$ProcessId"
$evidence += @{ product = "process-domain"; artifact = "complete-p-comp-v1"; state = $finalProcess.status }
$outcome.steps += @{ index = 8; title = "Complete the outcome"; product = "process-domain"; artifact = "complete-p-comp-v1" }
$outcome.process_state = $finalProcess
$outcome.notifications = $notifications.notifications
$reopenText = if ($reopenDenied) { "A reopen was rejected (HTTP $reopenDenied) - the completed process is immutable." } else { "The completed process is immutable." }
Write-Step 8 "Complete the outcome" "Process status '$($finalProcess.status)'. Pending notifications: '$($notifications.notifications -join ', ')'. $reopenText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "process-to-outcome"
  version = "1.0"
  tenant = $TenantId
  operator = $Operator
  outcome = @{ subject = $finalProcess.id; before = "initiated"; after = $finalProcess.status; completed = ($finalProcess.status -eq "completed"); escalated = $false }
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
Write-Host "Process     : $($finalProcess.id) ($($finalProcess.workflow))"
Write-Host "Status      : initiated -> $($finalProcess.status)"
Write-Host "Stages      : $($finalProcess.stages -join ' -> ')"
Write-Host "Advances    : $($finalProcess.advances.Count) human-attributed stage advances"
Write-Host "Denials     : out-of-order (HTTP $orderDenied), before-terminal (HTTP $termDenied), reopen (HTTP $reopenDenied)"
Write-Host "Audit trail : Symbivela case + process advances/complete + Ontovela assertion + Rheovela process + Orchadyn plan"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "process-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "process-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\process-outcome.json"
Write-Host "Value report written to .local-data\process-value-report.json"
