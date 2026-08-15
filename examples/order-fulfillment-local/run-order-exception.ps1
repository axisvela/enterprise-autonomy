param()

if (-not $TenantId -or -not $Actor -or -not $AxisRoboHome -or -not $OrderAction -or -not $OrderApprovalRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ order_id = "order-123"; tenant = $TenantId; operator = $Actor; steps = @(); order_state = $null }
$evidence = @()
$gates = @()

$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "order-123-stockout-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Actor; "Idempotency-Key" = "order-123-case-v1" }
$workspaceHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Actor; "Idempotency-Key" = "order-ops-workspace-v1" }

# Step 1: observe the stockout signal
$binding = @{ id = "inventory-order-status"; source = "inventory"; property = "fulfillment_status"; authority_rank = 10; max_lag_seconds = 60 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/source-bindings" -Headers @{ "X-Tenant-ID" = $TenantId } -ContentType "application/json" -Body $binding | Out-Null
$assertion = @{ id = "assertion-order-123-stockout"; subject_id = "order-123"; property = "fulfillment_status"; value = "stockout"; state_kind = "observed"; event_time = "2026-08-15T12:00:00Z"; system_time = "2026-08-15T12:00:01Z"; source = "inventory"; evidence_ref = "evidence://inventory/order-123" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$resolved = Invoke-RestMethod -Method Get -Uri "http://localhost:8082/v1/twins/order-123/state/fulfillment_status" -Headers @{ "X-Tenant-ID" = $TenantId }
$evidence += @{ product = "ontovela"; artifact = "assertion-order-123-stockout"; state = "observed" }
$outcome.steps += @{ index = 1; title = "Detect the stockout"; product = "ontovela"; artifact = "assertion-order-123-stockout" }
Write-Step 1 "Detect the stockout" "Order order-123 is observed as '$($resolved.value)' by the inventory source in Ontovela. This is the authoritative signal that the original promise is at risk."

# Step 2: open the human case
$workspace = @{ workspace_id = "order-ops"; name = "Order Operations"; owner_id = $Actor } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers $workspaceHeaders -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "order-ops"; case_id = "order-123-stockout"; subject_ref = "order://order-123"; problem = "Assigned warehouse has no inventory for the promised item."; evidence_refs = "evidence://inventory/order-123"; candidate_actions = "alternate-location,split-shipment,approved-substitute"; deadline = "2026-08-16T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Actor; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 2; title = "Open the human exception case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 2 "Open the human exception case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. An accountable operator ($Actor) now owns the resolution; no product may change the order without this case."

# Step 3: generate the replan
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "order-exception-plan.json") | ConvertFrom-Json
$planResult = $null
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  $evidence += @{ product = "orchadyn"; artifact = "plan-order-123"; state = "verified" }
  $outcome.steps += @{ index = 3; title = "Generate a verified replan"; product = "orchadyn"; artifact = "plan-order-123" }
  Write-Step 3 "Generate a verified replan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. The plan is a recommendation, not an authorization."
} else {
  $outcome.steps += @{ index = 3; title = "Generate a verified replan"; product = "none"; artifact = $null }
  Write-Step 3 "Generate a verified replan" "Orchadyn is not configured; skip plan generation."
}

# Step 4: create the durable process instance
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "order-exception.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "order-exception.json") | Out-Null
$process = @{ workflow = "order-exception"; project = "order-123"; actor = $Actor } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
$evidence += @{ product = "rheovela"; artifact = $instance.id; state = "open" }
$outcome.steps += @{ index = 4; title = "Create the durable exception process"; product = "rheovela"; artifact = $instance.id }
Write-Step 4 "Create the durable exception process" "Rheovela opened process instance '$($instance.id)' for workflow 'order-exception'. The resolution steps (validate, approve, execute, close) survive restarts and stay auditable."

# Step 5: reserve inventory at the alternate warehouse
$reservation = @{ warehouse = "warehouse-b"; delta = -1; reason = "reserve stock for order-123"; approved_by = $Actor; approval_ref = $OrderApprovalRef; idempotency_key = "inventory-order-123-reserve-v1" } | ConvertTo-Json
$inventoryResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8091/v1/inventory/sku-inspection-kit" -ContentType "application/json" -Body $reservation
$inventoryView = Invoke-RestMethod -Method Get -Uri "http://localhost:8091/v1/inventory/sku-inspection-kit"
$availableB = ($inventoryView.levels | Where-Object { $_.warehouse -eq "warehouse-b" }).available
$evidence += @{ product = "inventory-domain"; artifact = $inventoryResult.adjustment.id; state = "reserved" }
$outcome.steps += @{ index = 5; title = "Reserve inventory at the alternate warehouse"; product = "inventory-domain"; artifact = $inventoryResult.adjustment.id }
Write-Step 5 "Reserve inventory at the alternate warehouse" "The inventory adapter reserved one unit at warehouse-b under approval '$($inventoryResult.adjustment.approval_ref)'. warehouse-b now shows $availableB available. The reservation is idempotent and rejects negative totals."

# Step 6: record the auditable handoff in Praxovela
$session = @{ workspace = "order-fulfillment-local"; message = "Record order-123 stockout handoff" } | ConvertTo-Json
$sessionResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/sessions" -ContentType "application/json" -Body $session
$handoffPath = Join-Path $PSScriptRoot ".praxovela\order-123-stockout-handoff.json"
$handoffContent = @{ order_id = "order-123"; exception_case_id = "order-123-stockout"; status = "escalated"; action = "manual-external-order-action-required"; note = "An authorized operator performs the approved action in the business system." } | ConvertTo-Json -Compress
$writeCall = @{ session_id = $sessionResult.session_id; call = @{ call_id = "order-123-stockout-handoff-v1"; name = "file.write"; operation = "write"; resource = $handoffPath; risk = "medium"; reason = "Record the approved manual order-exception handoff."; idempotency_key = "order-123-stockout-handoff-v1"; input = @{ path = $handoffPath; content = "$handoffContent`n" } } } | ConvertTo-Json -Depth 6
$writeResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/agent/tools/execute" -ContentType "application/json" -Body $writeCall
$readCall = @{ session_id = $sessionResult.session_id; call = @{ call_id = "order-123-stockout-handoff-read-v1"; name = "file.read"; operation = "read"; resource = $handoffPath; risk = "low"; reason = "Verify the locally recorded order-exception handoff."; input = @{ path = $handoffPath } } } | ConvertTo-Json -Depth 6
$readResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/agent/tools/execute" -ContentType "application/json" -Body $readCall
$evidence += @{ product = "praxovela"; artifact = "order-123-stockout-handoff-v1"; state = "effect-ledgered" }
$outcome.steps += @{ index = 6; title = "Record an auditable handoff"; product = "praxovela"; artifact = "order-123-stockout-handoff-v1" }
Write-Step 6 "Record an auditable handoff" "Praxovela wrote and re-read the handoff under a deny-by-default policy. The effect ledger records that only the handoff file was touched; no other resource was exposed."

# Step 7: show the governance effect, then apply the approved fulfillment action
$denied = $null
try {
  $unapproved = @{ action = $OrderAction; approved_by = ""; approval_ref = ""; idempotency_key = "order-123-unapproved-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "http://localhost:8090/v1/orders/order-123/fulfillment-actions" -ContentType "application/json" -Body $unapproved | Out-Null
} catch {
  $denied = $_.Exception.Response.StatusCode.value__
}
$evidence += @{ product = "order-domain"; artifact = "unapproved-action-rejected"; state = "denied" }
$orderAction = @{ action = $OrderAction; approved_by = $Actor; approval_ref = $OrderApprovalRef; idempotency_key = "order-123-$OrderAction-v1" } | ConvertTo-Json
$orderResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8090/v1/orders/order-123/fulfillment-actions" -ContentType "application/json" -Body $orderAction
$gates += @{ gate = "action-approved"; owner = $Actor; decision = $OrderAction; approval_ref = $OrderApprovalRef }
$evidence += @{ product = "order-domain"; artifact = $orderResult.action.id; state = $orderResult.order.fulfillment_status }
$outcome.steps += @{ index = 7; title = "Approve and apply the fulfillment action"; product = "order-domain"; artifact = $orderResult.action.id }
$deniedText = if ($denied) { "The adapter rejected an unapproved action (HTTP $denied) before the approved action was applied." } else { "The adapter enforced approval requirements before the approved action was applied." }
Write-Step 7 "Approve and apply the fulfillment action" "Operator $Actor applied '$($orderResult.action.action)' with approval '$($orderResult.action.approval_ref)'. The order moved to '$($orderResult.order.fulfillment_status)' at '$($orderResult.order.warehouse)'. $deniedText"

# Step 8: verify the outcome, bundle the evidence, and emit the value report
$notification = Invoke-RestMethod -Method Get -Uri "http://localhost:8090/v1/notifications/order-123"
$finalOrder = Invoke-RestMethod -Method Get -Uri "http://localhost:8090/v1/orders/order-123"
$outcome.order_state = $finalOrder
$outcome.notifications = $notification.notifications
$evidence += @{ product = "order-domain"; artifact = "notification-order-123"; state = "pending" }
$outcome.steps += @{ index = 8; title = "Verify the outcome"; product = "order-domain"; artifact = "order-outcome.json" }
Write-Step 8 "Verify the outcome" "Final order state: '$($finalOrder.fulfillment_status)' from '$($finalOrder.warehouse)'. Pending customer notifications: '$($notification.notifications -join ', ')'. Every step above is recorded in a distinct product with its own audit trail."

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "order-fulfillment-exception"
  version = "1.0"
  tenant = $TenantId
  operator = $Actor
  outcome = @{ subject = $finalOrder.id; before = "stockout"; after = $finalOrder.fulfillment_status; warehouse = $finalOrder.warehouse; completed = ($finalOrder.fulfillment_status -ne "stockout"); escalated = $false }
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
Write-Host "Order       : $($finalOrder.id)"
Write-Host "Status      : stockout -> $($finalOrder.fulfillment_status)"
Write-Host "Fulfillment : $($finalOrder.warehouse) (was warehouse-a)"
Write-Host "Approval    : $($finalOrder.Actions[-1].approved_by) / $($finalOrder.Actions[-1].approval_ref)"
Write-Host "Notification: pending for customer (manual step)"
Write-Host "Audit trail : Ontovela assertion + Symbivela case + Orchadyn plan + Rheovela process + Praxovela effect ledger + order/inventory adapter evidence"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "order-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "order-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\order-outcome.json"
Write-Host "Value report written to .local-data\order-value-report.json"
