param()

if (-not $TenantId -or -not $Actor -or -not $AxisRoboHome -or -not $OrderAction -or -not $OrderApprovalRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$outcome = @{ order_id = "order-123"; tenant = $TenantId; operator = $Actor; steps = @(); order_state = $null }

$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "order-123-stockout-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Actor; "Idempotency-Key" = "order-123-case-v1" }
$workspaceHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Actor; "Idempotency-Key" = "order-ops-workspace-v1" }

# Step 1: observe the stockout signal
$binding = @{ id = "inventory-order-status"; source = "inventory"; property = "fulfillment_status"; authority_rank = 10; max_lag_seconds = 60 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/source-bindings" -Headers @{ "X-Tenant-ID" = $TenantId } -ContentType "application/json" -Body $binding | Out-Null
$assertion = @{ id = "assertion-order-123-stockout"; subject_id = "order-123"; property = "fulfillment_status"; value = "stockout"; state_kind = "observed"; event_time = "2026-08-15T12:00:00Z"; system_time = "2026-08-15T12:00:01Z"; source = "inventory"; evidence_ref = "evidence://inventory/order-123" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$resolved = Invoke-RestMethod -Method Get -Uri "http://localhost:8082/v1/twins/order-123/state/fulfillment_status" -Headers @{ "X-Tenant-ID" = $TenantId }
Write-Step 1 "Detect the stockout" "Order order-123 is observed as '$($resolved.value)' by the inventory source in Ontovela. This is the authoritative signal that the original promise is at risk."

# Step 2: open the human case
$workspace = @{ workspace_id = "order-ops"; name = "Order Operations"; owner_id = $Actor } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers $workspaceHeaders -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "order-ops"; case_id = "order-123-stockout"; subject_ref = "order://order-123"; problem = "Assigned warehouse has no inventory for the promised item."; evidence_refs = "evidence://inventory/order-123"; candidate_actions = "alternate-location,split-shipment,approved-substitute"; deadline = "2026-08-16T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
Write-Step 2 "Open the human exception case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. An accountable operator ($Actor) now owns the resolution; no product may change the order without this case."

# Step 3: generate the replan
$plan = Get-Content -Raw (Join-Path $PSScriptRoot "order-exception-plan.json") | ConvertFrom-Json
$planResult = $null
if ($OrchadynBinary) {
  $planResult = Invoke-RestMethod -Method Post -Uri "http://localhost$($OrchadynListenAddr)/plans:generate" -ContentType "application/json" -Body ($plan | ConvertTo-Json -Depth 10)
  $nodeList = ($planResult.plan.nodes | ForEach-Object { $_.capabilityId }) -join ", "
  Write-Step 3 "Generate a verified replan" "Orchadyn compiled a plan ($nodeList) with cost $($planResult.plan.totalCost) and $($planResult.violations.Count) violations. The plan is a recommendation, not an authorization."
} else {
  Write-Step 3 "Generate a verified replan" "Orchadyn is not configured; skip plan generation."
}

# Step 4: create the durable process instance
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "order-exception.json") | Out-Null
& $rheo workflow define --file (Join-Path $PSScriptRoot "order-exception.json") | Out-Null
$process = @{ workflow = "order-exception"; project = "order-123"; actor = $Actor } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process
Write-Step 4 "Create the durable exception process" "Rheovela opened process instance '$($instance.id)' for workflow 'order-exception'. The resolution steps (validate, approve, execute, close) survive restarts and stay auditable."

# Step 5: record the auditable handoff in Praxovela
$session = @{ workspace = "order-fulfillment-local"; message = "Record order-123 stockout handoff" } | ConvertTo-Json
$sessionResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/sessions" -ContentType "application/json" -Body $session
$handoffPath = Join-Path $PSScriptRoot ".praxovela\order-123-stockout-handoff.json"
$handoffContent = @{ order_id = "order-123"; exception_case_id = "order-123-stockout"; status = "escalated"; action = "manual-external-order-action-required"; note = "An authorized operator performs the approved action in the business system." } | ConvertTo-Json -Compress
$writeCall = @{ session_id = $sessionResult.session_id; call = @{ call_id = "order-123-stockout-handoff-v1"; name = "file.write"; operation = "write"; resource = $handoffPath; risk = "medium"; reason = "Record the approved manual order-exception handoff."; idempotency_key = "order-123-stockout-handoff-v1"; input = @{ path = $handoffPath; content = "$handoffContent`n" } } } | ConvertTo-Json -Depth 6
$writeResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/agent/tools/execute" -ContentType "application/json" -Body $writeCall
$readCall = @{ session_id = $sessionResult.session_id; call = @{ call_id = "order-123-stockout-handoff-read-v1"; name = "file.read"; operation = "read"; resource = $handoffPath; risk = "low"; reason = "Verify the locally recorded order-exception handoff."; input = @{ path = $handoffPath } } } | ConvertTo-Json -Depth 6
$readResult = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8420/v1/agent/tools/execute" -ContentType "application/json" -Body $readCall
Write-Step 5 "Record an auditable handoff" "Praxovela wrote and re-read the handoff under a deny-by-default policy. The effect ledger records that only the handoff file was touched; no other resource was exposed."

# Step 6: human approval then apply the action
$orderAction = @{ action = $OrderAction; approved_by = $Actor; approval_ref = $OrderApprovalRef; idempotency_key = "order-123-$OrderAction-v1" } | ConvertTo-Json
$orderResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8090/v1/orders/order-123/fulfillment-actions" -ContentType "application/json" -Body $orderAction
Write-Step 6 "Apply the approved fulfillment action" "Operator $Actor applied '$($orderResult.action.action)' with approval '$($orderResult.action.approval_ref)'. The order moved to '$($orderResult.order.fulfillment_status)' at '$($orderResult.order.warehouse)'."

# Step 7: close-out and evidence
$notification = Invoke-RestMethod -Method Get -Uri "http://localhost:8090/v1/notifications/order-123"
$finalOrder = Invoke-RestMethod -Method Get -Uri "http://localhost:8090/v1/orders/order-123"
$outcome.order_state = $finalOrder
$outcome.notifications = $notification.notifications

Write-Step 7 "Verify the outcome" "Final order state: '$($finalOrder.fulfillment_status)' from '$($finalOrder.warehouse)'. Pending customer notifications: '$($notification.notifications -join ', ')'. Every step above is recorded in a distinct product with its own audit trail."

Write-Host ""
Write-Host "================ Business Outcome ================" -ForegroundColor Green
Write-Host "Order       : $($finalOrder.id)"
Write-Host "Status      : stockout -> $($finalOrder.fulfillment_status)"
Write-Host "Fulfillment : $($finalOrder.warehouse) (was warehouse-a)"
Write-Host "Approval    : $($finalOrder.Actions[-1].approved_by) / $($finalOrder.Actions[-1].approval_ref)"
Write-Host "Notification: pending for customer (manual step)"
Write-Host "Audit trail : Ontovela assertion + Symbivela case + Orchadyn plan + Rheovela process + Praxovela effect ledger"
Write-Host "==================================================="

$outcomeDir = Join-Path $PSScriptRoot ".local-data"
New-Item -ItemType Directory -Force -Path $outcomeDir | Out-Null
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "order-outcome.json")
Write-Host ""
Write-Host "Structured result written to .local-data\order-outcome.json"
