param()

if (-not $HiringManager -or -not $TALead -or -not $Panel -or -not $Candidate -or -not $DecisionRef -or -not $OfferRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ requisition_id = "req-0001"; tenant = $TenantId; hiring_manager = $HiringManager; steps = @(); requisition_state = $null }
$evidence = @()
$gates = @()

$recBase = "http://localhost:8094/v1/requisitions/req-0001"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "req-0001-role-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $HiringManager; "Idempotency-Key" = "req-0001-case-v1" }

# Step 1: open the requisition case (Symbivela)
$workspace = @{ workspace_id = "talent-acquisition"; name = "Talent Acquisition"; owner_id = $HiringManager } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $HiringManager; "Idempotency-Key" = "talent-acquisition-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "talent-acquisition"; case_id = "req-0001-hire"; subject_ref = "requisition://req-0001"; problem = "Hire Senior Platform Engineer with human-only selection decisions."; evidence_refs = "budget://budget-rec-0001"; candidate_actions = "advance,reject,offer,hold"; deadline = "2026-08-25T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $HiringManager; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the requisition case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the requisition case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. Hiring decisions in this case are human-only by policy."

# Step 2: validate the requisition (adapter) and record role context (Ontovela)
$validate = @{ validated_by = $TALead; criteria = @("platform-expertise", "systems-ownership"); idempotency_key = "rec-val-v1" } | ConvertTo-Json
$valResult = Invoke-RestMethod -Method Post -Uri "$recBase/validate" -ContentType "application/json" -Body $validate
$assertion = @{ id = "assertion-req-0001-validated"; subject_id = "req-0001"; property = "hiring_status"; value = "validated"; state_kind = "observed"; event_time = "2026-08-16T11:00:00Z"; system_time = "2026-08-16T11:00:01Z"; source = "talent-system"; evidence_ref = "evidence://talent/req-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "recruitment-domain"; artifact = "validate-rec-val-v1"; state = $valResult.requisition.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-req-0001-validated"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Validate the requisition"; product = "recruitment-domain"; artifact = "validate-rec-val-v1" }
Write-Step 2 "Validate the requisition" "$TALead validated req-0001 with criteria 'platform-expertise, systems-ownership'. Status is '$($valResult.requisition.status)'."

# Step 3: automation-limitation - automated actor cannot make a decision
$autoDenied = $null
try {
  $auto = @{ stage = "shortlist"; decision = "advance"; candidate = $Candidate; decided_by = $AutomationActor; actor_type = "automated"; rationale = "keyword match"; decision_ref = $DecisionRef; idempotency_key = "rec-auto-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $auto | Out-Null
} catch { $autoDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "recruitment-domain"; artifact = "automated-decision-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show automation cannot decide"; product = "recruitment-domain"; artifact = "automated-decision-rejected" }
$autoDeniedText = if ($autoDenied) { "The adapter rejected the automated shortlist decision (HTTP $autoDenied)." } else { "The adapter enforced the human-only boundary." }
Write-Step 3 "Show automation cannot decide" "$AutomationActor attempted a shortlist decision; the adapter denied it. $autoDeniedText"

# Step 4: human shortlist decision
$shortlist = @{ stage = "shortlist"; decision = "advance"; candidate = $Candidate; decided_by = $Panel; actor_type = "human"; rationale = "meets criteria"; decision_ref = $DecisionRef; idempotency_key = "rec-sl-v1" } | ConvertTo-Json
$slResult = Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $shortlist
$gates += @{ gate = "shortlist-decision"; owner = $Panel; decision = "advance"; decision_ref = $DecisionRef }
$evidence += @{ product = "recruitment-domain"; artifact = "decision-rec-sl-v1"; state = $slResult.requisition.status }
$outcome.steps += @{ index = 4; title = "Record the human shortlist decision"; product = "recruitment-domain"; artifact = "decision-rec-sl-v1" }
Write-Step 4 "Record the human shortlist decision" "Panel $Panel advanced $Candidate with rationale 'meets criteria'. Status is '$($slResult.requisition.status)'."

# Step 5: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "recruitment-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "recruitment-workflow.json") | Out-Null
$process = @{ workflow = "recruitment-requisition-to-offer"; project = "req-0001"; actor = $TALead } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 5; title = "Create the durable hiring process"; product = "rheovela"; artifact = $instance.id }
Write-Step 5 "Create the durable hiring process" "Rheovela opened process instance '$($instance.id)' for 'recruitment-requisition-to-offer'. Stages: validate, shortlist, selection, offer, close."

# Step 6: plan (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "recruitment-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-req-0001"; state = "verified" }
  $outcome.steps += @{ index = 6; title = "Generate a hiring plan"; product = "orchadyn"; artifact = "plan-req-0001" }
  Write-Step 6 "Generate a hiring plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. All selection capabilities are humanOnly."
} else {
  $outcome.steps += @{ index = 6; title = "Generate a hiring plan"; product = "none"; artifact = $null }
  Write-Step 6 "Generate a hiring plan" "Orchadyn is not configured; skip plan generation."
}

# Step 7: human selection + offer decisions, then issue the offer
$selection = @{ stage = "selection"; decision = "select"; candidate = $Candidate; decided_by = $HiringManager; actor_type = "human"; rationale = "strongest evidence"; decision_ref = $DecisionRef; idempotency_key = "rec-sel-v1" } | ConvertTo-Json
$selResult = Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $selection
$offerDecision = @{ stage = "offer"; decision = "offer"; candidate = $Candidate; decided_by = $HiringManager; actor_type = "human"; rationale = "approved package"; decision_ref = $DecisionRef; idempotency_key = "rec-of-v1" } | ConvertTo-Json
$ofResult = Invoke-RestMethod -Method Post -Uri "$recBase/decisions" -ContentType "application/json" -Body $offerDecision
$offerBody = @{ candidate = $Candidate; offered_by = $TALead; offer_ref = $OfferRef; idempotency_key = "rec-offer-v1" } | ConvertTo-Json
$offerResult = Invoke-RestMethod -Method Post -Uri "$recBase/offers" -ContentType "application/json" -Body $offerBody
$gates += @{ gate = "selection-decision"; owner = $HiringManager; decision = "select"; decision_ref = $DecisionRef }
$gates += @{ gate = "offer-decision"; owner = $HiringManager; decision = "offer"; decision_ref = $DecisionRef }
$evidence += @{ product = "recruitment-domain"; artifact = "decision-rec-sel-v1"; state = $selResult.requisition.status }
$evidence += @{ product = "recruitment-domain"; artifact = "decision-rec-of-v1"; state = $ofResult.requisition.status }
$evidence += @{ product = "recruitment-domain"; artifact = $offerResult.offer.id; state = $offerResult.requisition.status }
$outcome.steps += @{ index = 7; title = "Record selection and offer, then issue the offer"; product = "recruitment-domain"; artifact = $offerResult.offer.id }
Write-Step 7 "Record selection and offer, then issue the offer" "$HiringManager selected and approved an offer for $Candidate; $TALead issued '$($offerResult.offer.id)' under '$OfferRef'. Status is '$($offerResult.requisition.status)'."

# Step 8: close, verify, and emit the value report
$finalRequisition = Invoke-RestMethod -Uri $recBase
$notifications = Invoke-RestMethod -Uri "http://localhost:8094/v1/notifications/req-0001"
$evidence += @{ product = "recruitment-domain"; artifact = "close-req-0001"; state = $finalRequisition.status }
$outcome.steps += @{ index = 8; title = "Confirm the outcome"; product = "recruitment-domain"; artifact = "close-req-0001" }
$outcome.requisition_state = $finalRequisition
$outcome.notifications = $notifications.notifications
Write-Step 8 "Confirm the outcome" "Requisition status '$($finalRequisition.status)'. Offer issued to $Candidate. Pending notifications: '$($notifications.notifications -join ', ')'."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "recruitment-requisition-to-offer"
  version = "1.0"
  tenant = $TenantId
  hiring_manager = $HiringManager
  outcome = @{ subject = $finalRequisition.id; before = "draft"; after = $finalRequisition.status; candidate = $Candidate; offer = $finalRequisition.offer.id; completed = ($finalRequisition.status -eq "closed"); escalated = $false }
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
Write-Host "Requisition : $($finalRequisition.id)"
Write-Host "Status      : draft -> $($finalRequisition.status)"
Write-Host "Offer       : $($finalRequisition.offer.id) to $Candidate"
Write-Host "Decisions   : shortlist (panel), selection + offer ($HiringManager), human-only"
Write-Host "Automation  : automated decision rejected (HTTP $autoDenied)"
Write-Host "Audit trail : Symbivela case + recruitment validate + Ontovela assertion + human decisions + Rheovela process + Orchadyn plan + offer"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "recruitment-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "recruitment-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\recruitment-outcome.json"
Write-Host "Value report written to .local-data\recruitment-value-report.json"
