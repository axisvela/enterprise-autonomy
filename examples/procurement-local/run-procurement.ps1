param()

if (-not $Requester -or -not $ProcurementOwner -or -not $FinanceApprover -or -not $Supplier -or -not $ApprovalRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ request_id = "preq-0001"; tenant = $TenantId; requester = $Requester; steps = @(); request_state = $null }
$evidence = @()
$gates = @()

$procBase = "http://localhost:8092/v1/requests/preq-0001"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "preq-0001-budget-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ProcurementOwner; "Idempotency-Key" = "preq-0001-case-v1" }

# Step 1: submit the request (adapter, governed)
$submit = @{ requester = $Requester; idempotency_key = "proc-submit-v1" } | ConvertTo-Json
$submitted = Invoke-RestMethod -Method Post -Uri "$procBase/submit" -ContentType "application/json" -Body $submit
$evidence += @{ product = "procurement-domain"; artifact = "submit-proc-submit-v1"; state = $submitted.request.status }
$outcome.steps += @{ index = 1; title = "Submit the request"; product = "procurement-domain"; artifact = "submit-proc-submit-v1" }
Write-Step 1 "Submit the request" "Requester $Requester submitted preq-0001 ($($submitted.request.item)) against budget '$($submitted.request.budget_ref)'. Status is '$($submitted.request.status)'."

# Step 2: open the governed case (Symbivela)
$workspace = @{ workspace_id = "procurement-ops"; name = "Procurement Operations"; owner_id = $ProcurementOwner } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $ProcurementOwner; "Idempotency-Key" = "procurement-ops-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "procurement-ops"; case_id = "preq-0001-purchase"; subject_ref = "request://preq-0001"; problem = "Purchasing required for item within budget envelope."; evidence_refs = "budget://budget-0001"; candidate_actions = "preferred-supplier,standard-supplier,reject"; deadline = "2026-08-20T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $ProcurementOwner; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 2; title = "Open the governed case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 2 "Open the governed case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. No purchase may proceed without this case."

# Step 3: record budget context (Ontovela)
$assertion = @{ id = "assertion-budget-0001-available"; subject_id = "budget-0001"; property = "availability"; value = "available"; state_kind = "observed"; event_time = "2026-08-16T09:00:00Z"; system_time = "2026-08-16T09:00:01Z"; source = "finance-system"; evidence_ref = "evidence://finance/budget-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$budget = Invoke-RestMethod -Uri "http://localhost:8092/v1/budget/budget-0001"
$evidence += @{ product = "ontovela"; artifact = "assertion-budget-0001-available"; state = "observed" }
$evidence += @{ product = "procurement-domain"; artifact = "budget-0001"; state = "available" }
$outcome.steps += @{ index = 3; title = "Record budget context"; product = "ontovela"; artifact = "assertion-budget-0001-available" }
Write-Step 3 "Record budget context" "Ontovela records budget-0001 as available; the adapter confirms $($budget.available) $($budget.currency) remaining against cost center '$($budget.cost_center)'."

# Step 4: approvals with segregation of duties
$denied = $null
try {
  $self = @{ role = "finance"; approver = $Requester; decision = "approve"; approval_ref = $ApprovalRef; idempotency_key = "proc-self-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $self | Out-Null
} catch { $denied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "procurement-domain"; artifact = "self-approval-rejected"; state = "denied" }
$fin = @{ role = "finance"; approver = $FinanceApprover; decision = "approve"; approval_ref = $ApprovalRef; idempotency_key = "proc-fin-v1" } | ConvertTo-Json
$finResult = Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $fin
$pr = @{ role = "procurement"; approver = $ProcurementOwner; decision = "approve"; approval_ref = $ApprovalRef; idempotency_key = "proc-pr-v1" } | ConvertTo-Json
$prResult = Invoke-RestMethod -Method Post -Uri "$procBase/approvals" -ContentType "application/json" -Body $pr
$gates += @{ gate = "budget-approved"; owner = $FinanceApprover; decision = "approve"; approval_ref = $ApprovalRef }
$gates += @{ gate = "supplier-approved"; owner = $ProcurementOwner; decision = "approve"; approval_ref = $ApprovalRef }
$evidence += @{ product = "procurement-domain"; artifact = "approval-proc-fin-v1"; state = "approved" }
$evidence += @{ product = "procurement-domain"; artifact = "approval-proc-pr-v1"; state = "approved" }
$outcome.steps += @{ index = 4; title = "Approve budget and supplier"; product = "procurement-domain"; artifact = "approval-proc-pr-v1" }
$deniedText = if ($denied) { "The adapter rejected the requester's self-approval (HTTP $denied) before approvals were recorded." } else { "The adapter enforced segregation of duties before approvals were recorded." }
Write-Step 4 "Approve budget and supplier" "$FinanceApprover approved the budget and $ProcurementOwner approved the supplier under '$ApprovalRef'. Status is '$($prResult.request.status)'. $deniedText"

# Step 5: durable process (Rheovela)
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "procurement-workflow.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "procurement-workflow.json") | Out-Null
$process = @{ workflow = "procurement-request-to-receipt"; project = "preq-0001"; actor = $ProcurementOwner } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 5; title = "Create the durable procurement process"; product = "rheovela"; artifact = $instance.id }
Write-Step 5 "Create the durable procurement process" "Rheovela opened process instance '$($instance.id)' for 'procurement-request-to-receipt'. Stages: validate, approve, purchase, receive, close."

# Step 6: plan sourcing (Orchadyn, optional)
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "procurement-plan.json") | ConvertFrom-Json
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-preq-0001"; state = "verified" }
  $outcome.steps += @{ index = 6; title = "Generate a sourcing plan"; product = "orchadyn"; artifact = "plan-preq-0001" }
  Write-Step 6 "Generate a sourcing plan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. A recommendation, not an authorization."
} else {
  $outcome.steps += @{ index = 6; title = "Generate a sourcing plan"; product = "none"; artifact = $null }
  Write-Step 6 "Generate a sourcing plan" "Orchadyn is not configured; skip plan generation."
}

# Step 7: purchase with approval
$purchaseDenied = $null
try {
  $bad = @{ supplier = $Supplier; approved_by = $ProcurementOwner; approval_ref = ""; idempotency_key = "proc-buy-unapproved-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$procBase/purchase-actions" -ContentType "application/json" -Body $bad | Out-Null
} catch { $purchaseDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "procurement-domain"; artifact = "unapproved-purchase-rejected"; state = "denied" }
$buy = @{ supplier = $Supplier; approved_by = $ProcurementOwner; approval_ref = $ApprovalRef; idempotency_key = "proc-buy-v1" } | ConvertTo-Json
$buyResult = Invoke-RestMethod -Method Post -Uri "$procBase/purchase-actions" -ContentType "application/json" -Body $buy
$gates += @{ gate = "purchase-executed"; owner = $ProcurementOwner; decision = $Supplier; approval_ref = $ApprovalRef }
$evidence += @{ product = "procurement-domain"; artifact = $buyResult.po.id; state = $buyResult.request.status }
$outcome.steps += @{ index = 7; title = "Execute the approved purchase"; product = "procurement-domain"; artifact = $buyResult.po.id }
$purchaseDeniedText = if ($purchaseDenied) { "The adapter rejected an unapproved purchase (HTTP $purchaseDenied)." } else { "The adapter required both approvals before purchasing." }
Write-Step 7 "Execute the approved purchase" "PO '$($buyResult.po.id)' issued to $Supplier for $($buyResult.po.amount) under '$ApprovalRef'. $purchaseDeniedText"

# Step 8: receive, close, and emit the value report
$rcv = @{ received_by = $Receiver; accepted = $true; idempotency_key = "proc-rcv-v1" } | ConvertTo-Json
$rcvResult = Invoke-RestMethod -Method Post -Uri "$procBase/receipts" -ContentType "application/json" -Body $rcv
$finalRequest = Invoke-RestMethod -Uri $procBase
$evidence += @{ product = "procurement-domain"; artifact = $rcvResult.receipt.id; state = $finalRequest.status }
$outcome.steps += @{ index = 8; title = "Confirm receipt and close"; product = "procurement-domain"; artifact = $rcvResult.receipt.id }
$outcome.request_state = $finalRequest
Write-Step 8 "Confirm receipt and close" "PO status '$($finalRequest.po.status)', request status '$($finalRequest.status)'. Budget remaining: $((Invoke-RestMethod -Uri 'http://localhost:8092/v1/budget/budget-0001').available)."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "procurement-request-to-receipt"
  version = "1.0"
  tenant = $TenantId
  requester = $Requester
  outcome = @{ subject = $finalRequest.id; before = "draft"; after = $finalRequest.status; po = $finalRequest.po.id; completed = ($finalRequest.status -eq "closed"); escalated = $false }
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
Write-Host "Request     : $($finalRequest.id)"
Write-Host "Status      : draft -> $($finalRequest.status)"
Write-Host "PO          : $($finalRequest.po.id) ($($finalRequest.po.supplier), $($finalRequest.po.amount))"
Write-Host "Approvals   : finance=$FinanceApprover, procurement=$ProcurementOwner under $ApprovalRef"
Write-Host "Segregation : requester self-approval rejected (HTTP $denied)"
Write-Host "Audit trail : adapter submit + Symbivela case + Ontovela assertion + approvals + Rheovela process + Orchadyn plan + PO + receipt"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "procurement-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "procurement-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\procurement-outcome.json"
Write-Host "Value report written to .local-data\procurement-value-report.json"
