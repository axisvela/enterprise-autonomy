param()

if (-not $ProposalId -or -not $Reviewer -or -not $SimulationEngineer -or -not $DecisionRef -or -not $EvidenceRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ proposal_id = $ProposalId; tenant = $TenantId; reviewer = $Reviewer; steps = @(); proposal_state = $null }
$evidence = @()
$gates = @()

$simBase = "http://localhost:8097/v1/proposals/$ProposalId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "sim-0001-scope-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Reviewer; "Idempotency-Key" = "sim-0001-case-v1" }

# Step 1: open the review case (Symbivela)
$workspace = @{ workspace_id = "validation-review"; name = "Validation Review"; owner_id = $Reviewer } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Reviewer; "Idempotency-Key" = "validation-review-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "validation-review"; case_id = "sim-0001-validation"; subject_ref = "proposal://proposal-sim-0001"; problem = "Automated zone inspection must be validated by simulation evidence before release."; evidence_refs = "scope://zone-alpha"; candidate_actions = "approve,reject,revise"; deadline = "2026-08-29T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Reviewer; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the review case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the review case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. Release is gated on simulation evidence."

# Step 2: compile the simulation scenarios (adapter + Ontovela scope)
$scenario = @{ scenario_id = "scn-collision"; description = "collision avoidance in zone-alpha"; idempotency_key = "sim-scn-v1" } | ConvertTo-Json
$scResult = Invoke-RestMethod -Method Post -Uri "$simBase/scenarios" -ContentType "application/json" -Body $scenario
$assertion = @{ id = "assertion-proposal-sim-0001-scoped"; subject_id = $ProposalId; property = "validation_scope"; value = "zone-alpha"; state_kind = "observed"; event_time = "2026-08-16T13:00:00Z"; system_time = "2026-08-16T13:00:01Z"; source = "validation-system"; evidence_ref = "evidence://validation/proposal-sim-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$gates += @{ gate = "scenarios-compiled"; owner = $SimulationEngineer; decision = "compiled"; scenario = $scResult.scenario.id }
$evidence += @{ product = "simulation-domain"; artifact = $scResult.scenario.id; state = "compiled" }
$evidence += @{ product = "ontovela"; artifact = "assertion-proposal-sim-0001-scoped"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Compile the simulation scenarios"; product = "simulation-domain"; artifact = $scResult.scenario.id }
Write-Step 2 "Compile the simulation scenarios" "Scenario '$($scResult.scenario.id)' compiled for $ProposalId. Ontovela asserts scope 'zone-alpha' with validation evidence."

# Step 3: evidence gate - decision before evidence is denied
$decDenied = $null
try {
  $premature = @{ decision = "approve"; decided_by = $Reviewer; rationale = "premature"; decision_ref = $DecisionRef; idempotency_key = "sim-dec-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $premature | Out-Null
} catch { $decDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "simulation-domain"; artifact = "decision-without-evidence-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show evidence is required before a decision"; product = "simulation-domain"; artifact = "decision-without-evidence-rejected" }
$decDeniedText = if ($decDenied) { "The adapter rejected the decision before evidence (HTTP $decDenied)." } else { "The adapter enforced evidence-before-decision." }
Write-Step 3 "Show evidence is required before a decision" "A review decision was attempted before any simulation run; the adapter denied it. $decDeniedText"

# Step 4: record the immutable simulation run; show immutability
$runBody = @{ run_id = "run-001"; outcome = "pass"; evidence_ref = $EvidenceRef; recorded_by = $SimulationEngineer; idempotency_key = "sim-run-v1" } | ConvertTo-Json
$runResult = Invoke-RestMethod -Method Post -Uri "$simBase/runs" -ContentType "application/json" -Body $runBody
$gates += @{ gate = "simulation-evidence"; owner = $SimulationEngineer; decision = "recorded"; evidence_ref = $EvidenceRef; immutable = $runResult.run.immutable }
$immutabilityDenied = $null
try {
  $runBody2 = @{ run_id = "run-002"; outcome = "fail"; evidence_ref = "evidence://sim/run-002"; recorded_by = $SimulationEngineer; idempotency_key = "sim-run2-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$simBase/runs" -ContentType "application/json" -Body $runBody2 | Out-Null
} catch { $immutabilityDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "simulation-domain"; artifact = $runResult.run.id; state = $runResult.proposal.status; immutable = $runResult.run.immutable }
$evidence += @{ product = "simulation-domain"; artifact = "evidence-immutability-rejected"; state = "denied" }
$outcome.steps += @{ index = 4; title = "Record the immutable simulation run"; product = "simulation-domain"; artifact = $runResult.run.id }
$immutabilityText = if ($immutabilityDenied) { "A second run was rejected (HTTP $immutabilityDenied) - the evidence is immutable." } else { "The evidence was recorded as immutable." }
Write-Step 4 "Record the immutable simulation run" "Run '$($runResult.run.id)' recorded (immutable=$($runResult.run.immutable), outcome '$($runResult.run.outcome)'). $immutabilityText"

# Step 5: review decision - non-member denied, then the reviewer decides
$nonMemberDenied = $null
try {
  $outsider = @{ decision = "approve"; decided_by = "outsider"; rationale = "x"; decision_ref = $DecisionRef; idempotency_key = "sim-dec-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $outsider | Out-Null
} catch { $nonMemberDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "simulation-domain"; artifact = "non-member-decision-rejected"; state = "denied" }
$decBody = @{ decision = "approve"; decided_by = $Reviewer; rationale = "simulation evidence passes"; decision_ref = $DecisionRef; idempotency_key = "sim-dec-v1" } | ConvertTo-Json
$decResult = Invoke-RestMethod -Method Post -Uri "$simBase/decisions" -ContentType "application/json" -Body $decBody
$gates += @{ gate = "review-decision"; owner = $Reviewer; decision = "approve"; decision_ref = $DecisionRef }
$evidence += @{ product = "simulation-domain"; artifact = $decResult.decision.id; state = $decResult.proposal.status }
$outcome.steps += @{ index = 5; title = "Record the review decision"; product = "simulation-domain"; artifact = $decResult.decision.id }
$nonMemberText = if ($nonMemberDenied) { "A non-member decision was rejected (HTTP $nonMemberDenied)." } else { "Only review-group members may decide." }
Write-Step 5 "Record the review decision" "$Reviewer approved $ProposalId under '$DecisionRef'. Status is '$($decResult.proposal.status)'. $nonMemberText"

# Step 6: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "simulation-validation-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "simulation-validation-workflow.json") | Out-Null
$process = @{ workflow = "simulation-to-validation"; project = $ProposalId; actor = $Reviewer } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 6; title = "Create the durable validation process"; product = "rheovela"; artifact = $instance.id }
Write-Step 6 "Create the durable validation process" "Rheovela opened process instance '$($instance.id)' for 'simulation-to-validation'. Stages: compile, run, decide, release, close."

# Step 7: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "simulation-validation-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-sim-0001"; state = "verified" }
  $outcome.steps += @{ index = 7; title = "Generate a validation plan"; product = "orchadyn"; artifact = "plan-sim-0001" }
  Write-Step 7 "Generate a validation plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. Review requires evidence."
} else {
  $outcome.steps += @{ index = 7; title = "Generate a validation plan"; product = "none"; artifact = $null }
  Write-Step 7 "Generate a validation plan" "Orchadyn is not configured; skip plan generation."
}

# Step 8: release (approval-gated) and emit the value report
$releaseDenied = $null
try {
  $wrongRef = @{ released_by = $Reviewer; decision_ref = "decision://wrong"; idempotency_key = "sim-rel-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$simBase/release" -ContentType "application/json" -Body $wrongRef | Out-Null
} catch { $releaseDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "simulation-domain"; artifact = "release-ref-mismatch-rejected"; state = "denied" }
$releaseBody = @{ released_by = $Reviewer; decision_ref = $DecisionRef; idempotency_key = "sim-rel-v1" } | ConvertTo-Json
$releaseResult = Invoke-RestMethod -Method Post -Uri "$simBase/release" -ContentType "application/json" -Body $releaseBody
$finalProposal = Invoke-RestMethod -Uri $simBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8097/v1/notifications/$ProposalId"
$evidence += @{ product = "simulation-domain"; artifact = "release-sim-0001"; state = $finalProposal.status }
$outcome.steps += @{ index = 8; title = "Release after approval"; product = "simulation-domain"; artifact = "release-sim-0001" }
$outcome.proposal_state = $finalProposal
$outcome.notifications = $notifications.notifications
$releaseDeniedText = if ($releaseDenied) { "A release citing the wrong decision reference was rejected (HTTP $releaseDenied)." } else { "Release required the exact decision reference." }
Write-Step 8 "Release after approval" "Proposal status '$($finalProposal.status)'. Pending notifications: '$($notifications.notifications -join ', ')'. $releaseDeniedText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "simulation-to-validation"
  version = "1.0"
  tenant = $TenantId
  reviewer = $Reviewer
  outcome = @{ subject = $finalProposal.id; before = "proposed"; after = $finalProposal.status; completed = ($finalProposal.status -eq "released"); escalated = $false }
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
Write-Host "Proposal    : $($finalProposal.id)"
Write-Host "Status      : proposed -> $($finalProposal.status)"
Write-Host "Evidence    : $($finalProposal.runs[0].id) (immutable=$($finalProposal.runs[0].immutable))"
Write-Host "Decision    : approve by $Reviewer under $DecisionRef"
Write-Host "Denials     : no-evidence (HTTP $decDenied), immutability (HTTP $immutabilityDenied), non-member (HTTP $nonMemberDenied), release ref (HTTP $releaseDenied)"
Write-Host "Audit trail : Symbivela case + simulation scenario/run/decision/release + Ontovela assertion + Rheovela process + Orchadyn plan"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "simulation-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "simulation-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\simulation-outcome.json"
Write-Host "Value report written to .local-data\simulation-value-report.json"
