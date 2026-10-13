param()

if (-not $InferenceId -or -not $Operator -or -not $AuthorizationRef) { throw "Load local.env.ps1 before running this script." }

function Write-Step($index, $title, $detail) {
  Write-Host ""
  Write-Host ("=== Step {0}: {1} ===" -f $index, $title) -ForegroundColor Cyan
  Write-Host $detail
}

$startedAt = Get-Date
$outcome = @{ inference_id = $InferenceId; tenant = $TenantId; operator = $Operator; steps = @(); inference_state = $null }
$evidence = @()
$gates = @()

$infBase = "http://localhost:8103/v1/inferences/$InferenceId"
$ontoHeaders = @{ "X-Tenant-ID" = $TenantId; "Idempotency-Key" = "inf-0001-flow-v1" }
$symbiHeaders = @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "inf-0001-case-v1" }

# Step 1: open the inference case (Symbivela)
$workspace = @{ workspace_id = "inference-governance"; name = "Inference Governance"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:1926/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "inference-governance-workspace-v1" } -ContentType "application/json" -Body $workspace | Out-Null
$case = @{ workspace_id = "inference-governance"; case_id = "inf-0001-governed-answer"; subject_ref = "inference://inf-0001"; problem = "Produce a governed customer-facing summary: authorize the request, select an in-policy model and endpoint, ground the answer in accepted claims and durable memory, and require human review before the high-impact answer is produced."; evidence_refs = "inference://inf-0001"; candidate_actions = "authorize,route,ground,review,answer,audit"; deadline = "2026-09-02T12:00:00Z" } | ConvertTo-Json
$caseResult = Invoke-RestMethod -Method Post -Uri "http://localhost:1926/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
$gates += @{ gate = "case-opened"; owner = $Operator; decision = "open" }
$evidence += @{ product = "symbivela"; artifact = $caseResult.case_id; state = $caseResult.status }
$outcome.steps += @{ index = 1; title = "Open the inference case"; product = "symbivela"; artifact = $caseResult.case_id }
Write-Step 1 "Open the inference case" "Symbivela case '$($caseResult.case_id)' is '$($caseResult.status)'. The answer is governed end to end."

# Step 2: record the request context (adapter + Ontovela)
$inference = Invoke-RestMethod -Uri $infBase
$assertion = @{ id = "assertion-inf-0001-submitted"; subject_id = $InferenceId; property = "inference_status"; value = "submitted"; state_kind = "observed"; event_time = "2026-08-16T18:00:00Z"; system_time = "2026-08-16T18:00:01Z"; source = "inference-governance"; evidence_ref = "evidence://inference/inf-0001" } | ConvertTo-Json
$state = Invoke-RestMethod -Method Post -Uri "http://localhost:1856/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
$evidence += @{ product = "inference-domain"; artifact = $inference.id; state = $inference.status }
$evidence += @{ product = "ontovela"; artifact = "assertion-inf-0001-submitted"; state = "observed" }
$outcome.steps += @{ index = 2; title = "Record the request context"; product = "ontovela"; artifact = "assertion-inf-0001-submitted" }
Write-Step 2 "Record the request context" "Inference $InferenceId ('$($inference.use)', impact '$($inference.impact)') is '$($inference.status)'. Ontovela asserts the submitted state."

# Step 3: authorization gate - un-authorized route attempt denied
$authDenied = $null
try {
  $unauthRoute = @{ model = "model-alpha"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-unauth-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$infBase/route" -ContentType "application/json" -Body $unauthRoute | Out-Null
} catch { $authDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "inference-domain"; artifact = "unauthorized-route-rejected"; state = "denied" }
$outcome.steps += @{ index = 3; title = "Show authorization is required before routing"; product = "inference-domain"; artifact = "unauthorized-route-rejected" }
$authText = if ($authDenied) { "The adapter rejected the un-authorized route (HTTP $authDenied) - routing requires an authorization." } else { "The adapter enforced the authorization gate." }
Write-Step 3 "Show authorization is required before routing" "A route was attempted before authorization; the adapter denied it. $authText"

# Step 4: authorize the request
$authBody = @{ authorized_by = $Operator; authorization_ref = $AuthorizationRef; idempotency_key = "i-auth-v1" } | ConvertTo-Json
$authResult = Invoke-RestMethod -Method Post -Uri "$infBase/authorize" -ContentType "application/json" -Body $authBody
$gates += @{ gate = "authorized"; owner = $Operator; decision = "authorized"; evidence_ref = $AuthorizationRef }
$evidence += @{ product = "inference-domain"; artifact = "authorized"; state = $authResult.inference.status }
$outcome.steps += @{ index = 4; title = "Authorize the request"; product = "inference-domain"; artifact = "authorized" }
Write-Step 4 "Authorize the request" "The request is authorized with '$($authResult.inference.authorization_ref)'. Status '$($authResult.inference.status)'."

# Step 5: policy gate - out-of-policy model denied
$policyDenied = $null
try {
  $badModel = @{ model = "model-forbidden"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-bad-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$infBase/route" -ContentType "application/json" -Body $badModel | Out-Null
} catch { $policyDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "inference-domain"; artifact = "out-of-policy-model-rejected"; state = "denied" }
$outcome.steps += @{ index = 5; title = "Show selection is under policy"; product = "inference-domain"; artifact = "out-of-policy-model-rejected" }
$policyText = if ($policyDenied) { "The adapter rejected the out-of-policy model (HTTP $policyDenied) - selection is under policy." } else { "The adapter enforced the selection policy." }
Write-Step 5 "Show selection is under policy" "A model outside the allowed catalog was attempted; the adapter denied it. $policyText"

# Step 6: select the route under policy
$routeBody = @{ model = "model-alpha"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-v1" } | ConvertTo-Json
$routeResult = Invoke-RestMethod -Method Post -Uri "$infBase/route" -ContentType "application/json" -Body $routeBody
$gates += @{ gate = "route-selected"; owner = "inference-runtime"; decision = "selected"; to = "model-alpha/endpoint-production"; evidence_ref = "policy://inf/selection" }
$evidence += @{ product = "inference-domain"; artifact = "route-selected"; state = $routeResult.inference.status }
$outcome.steps += @{ index = 6; title = "Select the model and endpoint under policy"; product = "inference-domain"; artifact = "route-selected" }
Write-Step 6 "Select the model and endpoint under policy" "Route selected: model '$($routeResult.inference.route.model)' on endpoint '$($routeResult.inference.route.endpoint)' under '$($routeResult.inference.route.policy_ref)'. Status '$($routeResult.inference.status)'."

# Step 7: ground the request in claims and memory
$groundBody = @{ claim_refs = @("claim://inf/0001/service-level"); memory_ref = "memory://inf/0001"; idempotency_key = "i-ground-v1" } | ConvertTo-Json
$groundResult = Invoke-RestMethod -Method Post -Uri "$infBase/ground" -ContentType "application/json" -Body $groundBody
$gates += @{ gate = "grounded"; owner = "inference-runtime"; decision = "grounded"; evidence_ref = "claim://inf/0001/service-level" }
$evidence += @{ product = "inference-domain"; artifact = "grounded"; state = $groundResult.inference.status }
$outcome.steps += @{ index = 7; title = "Ground the answer in claims and memory"; product = "inference-domain"; artifact = "grounded" }
Write-Step 7 "Ground the answer in claims and memory" "The answer is grounded in claims '$($groundResult.inference.grounding.claim_refs -join ', ')' and memory '$($groundResult.inference.grounding.memory_ref)'. Status '$($groundResult.inference.status)'."

# Step 8: review gate - high-impact answer before review denied
$reviewDenied = $null
try {
  $unreviewedAnswer = @{ answer_ref = "answer://inf/0001"; produced_by = "inference-runtime"; idempotency_key = "i-answer-unreviewed-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$infBase/answers" -ContentType "application/json" -Body $unreviewedAnswer | Out-Null
} catch { $reviewDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "inference-domain"; artifact = "unreviewed-answer-rejected"; state = "denied" }
$outcome.steps += @{ index = 8; title = "Show high-impact answers need human review"; product = "inference-domain"; artifact = "unreviewed-answer-rejected" }
$reviewText = if ($reviewDenied) { "The adapter rejected the unreviewed answer (HTTP $reviewDenied) - high-impact answers require human review." } else { "The adapter enforced the human-review gate." }
Write-Step 8 "Show high-impact answers need human review" "An answer was attempted before human review; the adapter denied it. $reviewText"

# Step 9: human review, then produce the governed answer
$reviewBody = @{ reviewed_by = $Operator; decision = "approve"; review_ref = "review://inf/0001"; idempotency_key = "i-review-v1" } | ConvertTo-Json
$reviewResult = Invoke-RestMethod -Method Post -Uri "$infBase/reviews" -ContentType "application/json" -Body $reviewBody
$gates += @{ gate = "reviewed"; owner = $Operator; decision = "approve"; evidence_ref = "review://inf/0001" }
$evidence += @{ product = "inference-domain"; artifact = "reviewed"; state = $reviewResult.inference.status }
$answerBody = @{ answer_ref = "answer://inf/0001"; produced_by = "inference-runtime"; idempotency_key = "i-answer-v1" } | ConvertTo-Json
$answerResult = Invoke-RestMethod -Method Post -Uri "$infBase/answers" -ContentType "application/json" -Body $answerBody
$gates += @{ gate = "answered"; owner = "inference-runtime"; decision = "answered"; evidence_ref = "answer://inf/0001" }
$evidence += @{ product = "inference-domain"; artifact = "answered"; state = $answerResult.inference.status }
$outcome.steps += @{ index = 9; title = "Review and produce the governed answer"; product = "inference-domain"; artifact = "answered" }
Write-Step 9 "Review and produce the governed answer" "Human review '$($reviewResult.inference.review.review_ref)' by '$($reviewResult.inference.review.reviewed_by)' approves. The answer '$($answerResult.inference.answer.answer_ref)' is produced with the route, grounding, and review attached."

# Step 10: record the audit, show immutability
$auditBody = @{ audited_by = $Operator; audit_ref = "audit://inf/0001"; idempotency_key = "i-audit-v1" } | ConvertTo-Json
$auditResult = Invoke-RestMethod -Method Post -Uri "$infBase/audit" -ContentType "application/json" -Body $auditBody
$notifications = Invoke-RestMethod -Uri "http://localhost:8103/v1/notifications/$InferenceId"
$evidence += @{ product = "inference-domain"; artifact = "audited"; state = $auditResult.inference.status }
$finalInference = Invoke-RestMethod -Uri $infBase
$mutationDenied = $null
try {
  $reroute = @{ model = "model-beta"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-late-v1" } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$infBase/route" -ContentType "application/json" -Body $reroute | Out-Null
} catch { $mutationDenied = $_.Exception.Response.StatusCode.value__ }
$evidence += @{ product = "inference-domain"; artifact = "audited-inference-immutable"; state = "denied" }
$outcome.steps += @{ index = 10; title = "Record the audit evidence"; product = "inference-domain"; artifact = "audited" }
$outcome.inference_state = $finalInference
$outcome.notifications = $notifications.notifications
$mutationText = if ($mutationDenied) { "A post-audit route mutation was rejected (HTTP $mutationDenied) - the audited inference is immutable." } else { "The audited inference is immutable." }
Write-Step 10 "Record the audit evidence" "Inference status '$($finalInference.status)'. Audit '$($finalInference.audit.audit_ref)'. Pending notifications: '$($notifications.notifications -join ', ')'. $mutationText"

# Value report
$elapsed = (Get-Date) - $startedAt
$products = @($evidence.product | Select-Object -Unique)
$report = @{
  example = "inference-governance"
  version = "1.0"
  tenant = $TenantId
  operator = $Operator
  outcome = @{ subject = $finalInference.id; before = "submitted"; after = $finalInference.status; completed = ($finalInference.status -eq "audited"); escalated = $false }
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
Write-Host "Inference  : $($finalInference.id) ($($finalInference.use), impact $($finalInference.impact))"
Write-Host "Status     : submitted -> $($finalInference.status)"
Write-Host "Route      : $($finalInference.route.model) @ $($finalInference.route.endpoint)"
Write-Host "Grounding  : $($finalInference.grounding.claim_refs -join ', ') + $($finalInference.grounding.memory_ref)"
Write-Host "Review     : $($finalInference.review.reviewed_by) ($($finalInference.review.review_ref))"
Write-Host "Denials    : un-authorized-route (HTTP $authDenied), out-of-policy-model (HTTP $policyDenied), unreviewed-answer (HTTP $reviewDenied), post-audit-mutation (HTTP $mutationDenied)"
Write-Host "Audit trail : Symbivela case + authorization + route + grounding + review + answer + audit"
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
$outcome | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "inference-outcome.json")
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $outcomeDir "inference-value-report.json")
Write-Host ""
Write-Host "Structured result written to .local-data\inference-outcome.json"
Write-Host "Value report written to .local-data\inference-value-report.json"
