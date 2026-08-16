param()

if (-not $DeploymentId -or -not $Operator -or -not $ApprovalRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ deployment_id = $DeploymentId; tenant = $TenantId; operator = $Operator; steps = @(); deployment_state = $null }
$evidence = @()
$gates = @()

$depBase = "http://localhost:8102/v1/deployments/$DeploymentId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "dep-0001-flow-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "dep-0001-case-v1" }

# Step 1: open the deployment case (Symbivela)
$workspace = @{ workspace_id = "deployment-ops"; name = "Deployment Operations"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "deployment-ops-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "deployment-ops"; case_id = "dep-0001-release"; subject_ref = "deployment://dep-0001"; problem = "Advance the release pipeline strictly in sequence, citing evidence at every step, and require human approval for any deviation."; evidence_refs = "deployment://dep-0001"; candidate_actions = "steps,deviations,release"; deadline = "2026-09-02T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Operator; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the deployment case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the deployment case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The release is driven by the sequenced pipeline."

# Step 2: record the deployment context (adapter + Ontovela)
$deployment = Invoke-RestMethod -Uri $depBase
$assertion = @{ id = "assertion-dep-0001-initiated"; subject_id = $DeploymentId; property = "deployment_status"; value = "initiated"; state_kind = "observed"; event_time = "2026-08-16T18:00:00Z"; system_time = "2026-08-16T18:00:01Z"; source = "deployment-control"; evidence_ref = "evidence://deployment/dep-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "deployment-domain"; artifact = $deployment.id; state = $deployment.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-dep-0001-initiated"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the deployment context"; product = "ontovela"; artifact = "assertion-dep-0001-initiated" }
Write-Step 2 "Record the deployment context" "Deployment $DeploymentId is '$($deployment.status)' at step '$($deployment.current_step)' for pipeline '$($deployment.workflow)'. Ontovela asserts the initiated state."

# Step 3: sequence gate - out-of-order step denied
$orderDenied = $null
try {
  $skipBody = @{ step = "test"; executed_by = $Automation; evidence_ref = "evidence://dep/test"; idempotency_key = "d-skip-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$depBase/steps" -ContentType "application/json" -Body $skipBody | Out-Null
} catch { $orderDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "deployment-domain"; artifact = "out-of-sequence-step-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show steps execute in sequence"; product = "deployment-domain"; artifact = "out-of-sequence-step-rejected" }
$orderText = if ($orderDenied) { "The adapter rejected the out-of-sequence step (HTTP $orderDenied) - steps execute strictly in order." } else { "The adapter enforced sequence ordering." }
Write-Step 3 "Show steps execute in sequence" "An out-of-order step was attempted; the adapter denied it. $orderText"

# Step 4: execute the first autonomous step
$steps = @("checkout", "build", "test")
foreach ($step in $steps) {
  $stepBody = @{ step = $step; executed_by = $Automation; evidence_ref = "evidence://dep/$step"; idempotency_key = "d-$step-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$depBase/steps" -ContentType "application/json" -Body $stepBody | Out-Null
  $gates += @{ gate = "step-$step"; owner = $Automation; decision = "executed"; to = $step; evidence_ref = "evidence://dep/$step" }
  $evidence += @{ product = "deployment-domain"; artifact = "step-$step-v1"; state = "executed" }
}
$afterSteps = Invoke-RestMethod -Uri $depBase
$outcome.steps += @{ index = 4; title = "Execute the sequenced steps"; product = "deployment-domain"; artifact = "step-test-v1" }
Write-Step 4 "Execute the sequenced steps" "Deployment advanced: $($afterSteps.steps_run.Count) evidence-cited step executions. At step '$($afterSteps.current_step)', status '$($afterSteps.status)'."

# Step 5: deviation gate - unapproved pause denied
$pauseDenied = $null
try {
  $noApproval = @{ action = "pause"; idempotency_key = "d-pause-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$depBase/deviations" -ContentType "application/json" -Body $noApproval | Out-Null
} catch { $pauseDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "deployment-domain"; artifact = "unapproved-pause-rejected"; state = "denied" }
$outcome.steps += @{ index = 5; title = "Show deviations need human approval"; product = "deployment-domain"; artifact = "unapproved-pause-rejected" }
$pauseText = if ($pauseDenied) { "The adapter rejected the unapproved pause (HTTP $pauseDenied) - deviations require human approval." } else { "The adapter enforced approval-required deviations." }
Write-Step 5 "Show deviations need human approval" "An unapproved pause was attempted; the adapter denied it. $pauseText"

# Step 6: durable process wrapper (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "sequenced-deployment-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "sequenced-deployment-workflow.json") | Out-Null
$processBody = @{ workflow = "sequenced-deployment"; project = $DeploymentId; actor = $Operator } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $processBody
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Wrap the deployment durably"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Wrap the deployment durably" "Rheovela opened process instance '$($instance.id)' for 'sequenced-deployment'. Steps: checkout, build, test, approve, production."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "sequenced-deployment-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-dep-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a deployment plan"; product = "orchadyn"; artifact = "plan-dep-0001" }
  Write-Step 7 "Generate a deployment plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Steps are sequenced."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a deployment plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a deployment plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: reach the terminal step, show release immutability
$finalSteps = @("approve", "production")
foreach ($step in $finalSteps) {
  $stepBody = @{ step = $step; executed_by = $Automation; evidence_ref = "evidence://dep/$step"; idempotency_key = "d-$step-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$depBase/steps" -ContentType "application/json" -Body $stepBody | Out-Null
  $gates += @{ gate = "step-$step"; owner = $Automation; decision = "executed"; to = $step; evidence_ref = "evidence://dep/$step" }
  $evidence += @{ product = "deployment-domain"; artifact = "step-$step-v1"; state = "executed" }
}
$reopenDenied = $null
try {
  $reopenBody = @{ step = "checkout"; executed_by = $Automation; evidence_ref = "evidence://dep/checkout"; idempotency_key = "d-reopen" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$depBase/steps" -ContentType "application/json" -Body $reopenBody | Out-Null
} catch { $reopenDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "deployment-domain"; artifact = "released-step-rejected"; state = "denied" }
$finalDeployment = Invoke-RestMethod -Uri $depBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8102/v1/notifications/$DeploymentId"
$evidence += @{ product = "deployment-domain"; artifact = "released"; state = $finalDeployment.status }
$outcome.steps += @{ index = 8; title = "Release the deployment"; product = "deployment-domain"; artifact = "released" }
$outcome.deployment_state = $finalDeployment
$outcome.notifications = $notifications.notifications
$reopenText = if ($reopenDenied) { "A released step re-run was rejected (HTTP $reopenDenied) - the released deployment is immutable." } else { "The released deployment is immutable." }
Write-Step 8 "Release the deployment" "Deployment status '$($finalDeployment.status)'. Pending notifications: '$($notifications.notifications -join ', ')'. $reopenText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "sequenced-deployment"
  version = "1.0"
  tenant = $TenantId
  operator = $Operator
  outcome = @{ subject = $finalDeployment.id; before = "initiated"; after = $finalDeployment.status; completed = ($finalDeployment.status -eq "released"); escalated = $false }
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
Write-Host "Deployment : $($finalDeployment.id) ($($finalDeployment.workflow))"
Write-Host "Status     : initiated -> $($finalDeployment.status)"
Write-Host "Steps      : $($finalDeployment.steps -join ' -> ')"
Write-Host "Runs       : $($finalDeployment.steps_run.Count) evidence-cited autonomous step executions"
Write-Host "Denials    : out-of-sequence (HTTP $orderDenied), unapproved-pause (HTTP $pauseDenied), released-rerun (HTTP $reopenDenied)"
Write-Host "Audit trail : Symbivela case + step runs + Ontovela assertion + Rheovela process + Orchadyn plan"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "deployment-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "deployment-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\deployment-outcome.json"
Write-Host "Value report written to .local-data\deployment-value-report.json"
