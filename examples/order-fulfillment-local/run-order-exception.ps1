param()

if (-not $TenantId -or -not $Actor -or -not $AxisRoboHome) { throw "Load local.env.ps1 before running this script." }

$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "order-123-stockout-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Actor; "Idempotency-Key" = "order-123-case-v1" }

$binding = @{ id = "inventory-order-status"; source = "inventory"; property = "fulfillment_status"; authority_rank = 10; max_lag_seconds = 60 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/source-bindings" -Headers @{ "X-Tenant-ID" = $TenantId } -ContentType "application/json" -Body $binding

$assertion = @{ id = "assertion-order-123-stockout"; subject_id = "order-123"; property = "fulfillment_status"; value = "stockout"; state_kind = "observed"; event_time = "2026-08-15T12:00:00Z"; system_time = "2026-08-15T12:00:01Z"; source = "inventory"; evidence_ref = "evidence://inventory/order-123" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion

$workspace = @{ workspace_id = "order-ops"; name = "Order Operations"; owner_id = $Actor } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers $symbiHeaders -ContentType "application/json" -Body $workspace

$case = @{ workspace_id = "order-ops"; case_id = "order-123-stockout"; subject_ref = "order://order-123"; problem = "Assigned warehouse has no inventory for the promised item."; evidence_refs = "evidence://inventory/order-123"; candidate_actions = "alternate-location,split-shipment,approved-substitute"; deadline = "2026-08-16T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case

$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow validate (Join-Path $PSScriptRoot "order-exception.json")
& $rheo workflow define --file (Join-Path $PSScriptRoot "order-exception.json")
$process = @{ workflow = "order-exception"; project = "order-123"; actor = $Actor } | ConvertTo-Json
$instance = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $process

[PSCustomObject]@{ assertion = $state; exception_case = $caseResult; process_instance = $instance } | ConvertTo-Json -Depth 10
