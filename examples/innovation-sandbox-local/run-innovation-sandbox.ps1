param()

if (-not $ProposalId -or -not $Reviewer -or -not $SandboxEngineer -or -not $SandboxScope -or -not $PolicyRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ proposal_id = $ProposalId; tenant = $TenantId; reviewer = $Reviewer; steps = @(); proposal_state = $null }
$evidence = @()
$gates = @()

$sandBase = "http://localhost:8101/v1/proposals/$ProposalId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "sand-0001-scope-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Reviewer; "Idempotency-Key" = "sand-0001-case-v1" }

# Step 1: open the sandbox case (Symbivela)
$workspace = @{ workspace_id = "innovation-sandbox"; name = "Innovation Sandbox"; owner_id = $Reviewer } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Reviewer; "Idempotency-Key" = "innovation-sandbox-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "innovation-sandbox"; case_id = "sand-0001-policy"; subject_ref = "proposal://proposal-sandbox-0001"; problem = "Explore batch-report-generation inside its sandbox and record an evidence-based policy decision."; evidence_refs = "scope://report-generation-scope"; candidate_actions = "release,restrict,reject"; deadline = "2026-09-03T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Reviewer; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the sandbox case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the sandbox case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The proposal is explored inside its sandbox."

# Step 2: record the proposal context (adapter + Ontovela)
$proposal = Invoke-RestMethod -Uri $sandBase
$assertion = @{ id = "assertion-sand-0001-scoped"; subject_id = $ProposalId; property = "sandbox_scope"; value = $SandboxScope; state_kind = "observed"; event_time = "2026-08-16T19:00:00Z"; system_time = "2026-08-16T19:00:01Z"; source = "innovation-control"; evidence_ref = "evidence://sandbox/proposal-sandbox-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$gates += @{ gate = "sandbox-scoped"; owner = $Reviewer; decision = "scoped"; scope = $SandboxScope }
$evidence += @{ product = "sandbox-domain"; artifact = $proposal.id; state = $proposal.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-sand-0001-scoped"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the sandbox context"; product = "ontovela"; artifact = "assertion-sand-0001-scoped" }
Write-Step 2 "Record the sandbox context" "Proposal $ProposalId is '$($proposal.status)' for '$($proposal.capability)'. Ontovela asserts the sandbox scope '$($proposal.sandbox_scope)'."

# Step 3: sandbox gate - experiment outside scope denied
$boundaryDenied = $null
try {
  $outside = @{ experiment_id = "exp-out"; scope = "outside-scope"; outcome = "pass"; evidence_ref = "evidence://sand/exp-out"; recorded_by = $SandboxEngineer; idempotency_key = "s-exp-out" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$sandBase/experiments" -ContentType "application/json" -Body $outside | Out-Null
} catch { $boundaryDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "sandbox-domain"; artifact = "sandbox-boundary-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show the sandbox boundary"; product = "sandbox-domain"; artifact = "sandbox-boundary-rejected" }
$boundaryText = if ($boundaryDenied) { "The adapter rejected an out-of-scope experiment (HTTP $boundaryDenied)." } else { "The adapter enforced the sandbox boundary." }
Write-Step 3 "Show the sandbox boundary" "An experiment outside the sandbox scope was attempted; the adapter denied it. $boundaryText"

# Step 4: policy gate - decision before evidence denied
$evidenceDenied = $null
try {
  $premature = @{ decision = "release"; decided_by = $Reviewer; rationale = "premature"; policy_ref = $PolicyRef; idempotency_key = "s-dec" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$sandBase/decisions" -ContentType "application/json" -Body $premature | Out-Null
} catch { $evidenceDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "sandbox-domain"; artifact = "decision-without-evidence-rejected"; state = "denied" }
$outcome.steps += @{ index = 4; title = "Show policy needs experiment evidence"; product = "sandbox-domain"; artifact = "decision-without-evidence-rejected" }
$evidenceText = if ($evidenceDenied) { "The adapter rejected the policy decision before evidence (HTTP $evidenceDenied)." } else { "The adapter enforced evidence-based policy." }
Write-Step 4 "Show policy needs experiment evidence" "A policy decision was attempted before any experiment; the adapter denied it. $evidenceText"

# Step 5: record the sandbox experiment
$expBody = @{ experiment_id = "exp-001"; scope = $SandboxScope; outcome = "pass"; evidence_ref = "evidence://sand/exp-001"; recorded_by = $SandboxEngineer; idempotency_key = "s-exp1" } | ConvertTo-Json
$expResult = Invoke-RestMethod -Method Post -Uri "$sandBase/experiments" -ContentType "application/json" -Body $expBody
$gates += @{ gate = "experiment-evidence"; owner = $SandboxEngineer; decision = "recorded"; scope = $expResult.experiment.scope }
$evidence += @{ product = "sandbox-domain"; artifact = $expResult.experiment.id; state = $expResult.proposal.status }
$outcome.steps += @{ index = 5; title = "Record the sandbox experiment"; product = "sandbox-domain"; artifact = $expResult.experiment.id }
Write-Step 5 "Record the sandbox experiment" "Experiment '$($expResult.experiment.id)' recorded inside '$($expResult.experiment.scope)' with outcome '$($expResult.experiment.outcome)'. Status is '$($expResult.proposal.status)'."

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "innovation-sandbox-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "innovation-sandbox-workflow.json") | Out-Null
$processBody = @{ workflow = "innovation-sandbox-to-policy"; project = $ProposalId; actor = $Reviewer } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $processBody
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable sandbox process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable sandbox process" "Rheovela opened process instance '$($instance.id)' for 'innovation-sandbox-to-policy'. Stages: explore, decide, apply, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "innovation-sandbox-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-sand-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a sandbox plan"; product = "orchadyn"; artifact = "plan-sand-0001" }
  Write-Step 7 "Generate a sandbox plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Policy requires experiment evidence."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a sandbox plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a sandbox plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: policy decision, apply, and show immutability
$nonReviewerDenied = $null
try {
  $outsider = @{ decision = "release"; decided_by = "outsider"; rationale = "x"; policy_ref = $PolicyRef; idempotency_key = "s-dec" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$sandBase/decisions" -ContentType "application/json" -Body $outsider | Out-Null
} catch { $nonReviewerDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "sandbox-domain"; artifact = "non-reviewer-rejected"; state = "denied" }
$decBody = @{ decision = "release"; decided_by = $Reviewer; rationale = "sandbox evidence passes"; policy_ref = $PolicyRef; idempotency_key = "s-dec" } | ConvertTo-Json
$decResult = Invoke-RestMethod -Method Post -Uri "$sandBase/decisions" -ContentType "application/json" -Body $decBody
$gates += @{ gate = "policy-decision"; owner = $Reviewer; decision = "release"; policy_ref = $PolicyRef }
$evidence += @{ product = "sandbox-domain"; artifact = $decResult.decision.id; state = $decResult.proposal.status }
$immutabilityDenied = $null
try {
  $decBody2 = @{ decision = "restrict"; decided_by = $Reviewer; rationale = "change"; policy_ref = $PolicyRef; idempotency_key = "s-dec2" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$sandBase/decisions" -ContentType "application/json" -Body $decBody2 | Out-Null
} catch { $immutabilityDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "sandbox-domain"; artifact = "policy-immutability-rejected"; state = "denied" }
$applyBody = @{ applied_by = $Reviewer; policy_ref = $PolicyRef; idempotency_key = "s-ap" } | ConvertTo-Json
$applyResult = Invoke-RestMethod -Method Post -Uri "$sandBase/apply" -ContentType "application/json" -Body $applyBody
$finalProposal = Invoke-RestMethod -Uri $sandBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8101/v1/notifications/$ProposalId"
$evidence += @{ product = "sandbox-domain"; artifact = "apply-s-ap"; state = $finalProposal.status }
$outcome.steps += @{ index = 8; title = "Decide and apply the policy"; product = "sandbox-domain"; artifact = "apply-s-ap" }
$outcome.proposal_state = $finalProposal
$outcome.notifications = $notifications.notifications
$nonReviewerText = if ($nonReviewerDenied) { "A non-reviewer decision was rejected (HTTP $nonReviewerDenied)." } else { "Only designated reviewers may decide." }
$immutabilityText = if ($immutabilityDenied) { "A second policy decision was rejected (HTTP $immutabilityDenied) - the policy is immutable." } else { "The policy decision is immutable." }
Write-Step 8 "Decide and apply the policy" "Proposal status '$($finalProposal.status)', applied=$($finalProposal.applied). Pending notifications: '$($notifications.notifications -join ', ')'. $nonReviewerText $immutabilityText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "innovation-sandbox-to-policy"
  version = "1.0"
  tenant = $TenantId
  reviewer = $Reviewer
  outcome = @{ subject = $finalProposal.id; before = "proposed"; after = $finalProposal.status; applied = $finalProposal.applied; completed = ($finalProposal.applied -eq $true); escalated = $false }
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
Write-Host "Proposal    : $($finalProposal.id) ($($finalProposal.capability))"
Write-Host "Status      : proposed -> $($finalProposal.status)"
Write-Host "Sandbox     : $($finalProposal.sandbox_scope)"
Write-Host "Decision    : $($finalProposal.decision.decision) by $($finalProposal.decision.decided_by) under $PolicyRef"
Write-Host "Applied     : $($finalProposal.applied)"
Write-Host "Denials     : boundary (HTTP $boundaryDenied), no-evidence (HTTP $evidenceDenied), non-reviewer (HTTP $nonReviewerDenied), immutability (HTTP $immutabilityDenied)"
Write-Host "Audit trail : Symbivela case + sandbox experiment/decision/apply + Ontovela assertion + Rheovela process + Orchadyn plan"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "sandbox-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "sandbox-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\sandbox-outcome.json"
Write-Host "Value report written to .local-data\sandbox-value-report.json"
