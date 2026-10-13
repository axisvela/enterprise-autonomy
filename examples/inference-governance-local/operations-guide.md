# Inference-Governance Local Demo â€?Detailed Operations Guide

`inf-0001` for the `customer-facing-summary` use runs through a governed inference lifecycle: case, request context, **authorization gate**, **selection-policy gate**, **grounding gate**, **human-review gate**, governed answer, and **immutable audit**.

All commands below assume the services are running (see the [README](README.md)).

## Prerequisites

- The `local.env.ps1` file copied from `local.env.ps1.example` and loaded: `. .\local.env.ps1`
- Services started: `.\start-services.ps1`
- Or run everything in one step: `.\run-all.ps1`

## Step-by-Step Requests and Expected Responses

### Step 1 â€?Open the inference case (Symbivela)

```powershell
$workspace = @{ workspace_id = "inference-governance"; name = "Inference Governance"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:1926/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "inference-governance-workspace-v1" } -ContentType "application/json" -Body $workspace

$case = @{ workspace_id = "inference-governance"; case_id = "inf-0001-governed-answer"; subject_ref = "inference://inf-0001"; problem = "..."; evidence_refs = "inference://inf-0001"; candidate_actions = "authorize,route,ground,review,answer,audit"; deadline = "2026-09-02T12:00:00Z" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:1926/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
```

**Expected:** Symbivela returns a case with `case_id: inf-0001-governed-answer` in state `open`. The answer is governed end to end.

### Step 2 â€?Record the request context (adapter + Ontovela)

```powershell
curl.exe "http://localhost:8103/v1/inferences/inf-0001"
```

**Expected:**

```json
{"id":"inf-0001","use":"customer-facing-summary","impact":"high","status":"submitted"}
```

Then assert the submitted state to Ontovela:

```powershell
$assertion = @{ id = "assertion-inf-0001-submitted"; subject_id = $InferenceId; property = "inference_status"; value = "submitted"; state_kind = "observed"; event_time = "2026-08-16T18:00:00Z"; system_time = "2026-08-16T18:00:01Z"; source = "inference-governance"; evidence_ref = "evidence://inference/inf-0001" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:1856/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
```

**Expected:** Ontovela returns a stored assertion (`observed`).

### Step 3 â€?Authorization gate (inference-domain, denied)

An un-authorized route is attempted before any authorization:

```powershell
$unauthRoute = @{ model = "model-alpha"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-unauth-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/route" -ContentType "application/json" -Body $unauthRoute
```

**Expected:** HTTP 403

```json
{"error":"authorization_required_before_route"}
```

### Step 4 â€?Authorize the request

```powershell
$authBody = @{ authorized_by = $Operator; authorization_ref = $AuthorizationRef; idempotency_key = "i-auth-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/authorize" -ContentType "application/json" -Body $authBody
```

**Expected:** `200` with `status: authorized` and the `authorization_ref` recorded.

### Step 5 â€?Selection-policy gate (inference-domain, denied)

A model outside the allowed catalog is attempted:

```powershell
$badModel = @{ model = "model-forbidden"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-bad-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/route" -ContentType "application/json" -Body $badModel
```

**Expected:** HTTP 403

```json
{"error":"model_out_of_policy_model-forbidden"}
```

### Step 6 â€?Select the route under policy

```powershell
$routeBody = @{ model = "model-alpha"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/route" -ContentType "application/json" -Body $routeBody
```

**Expected:** `200` with `status: routed`, `route.model: model-alpha`, `route.endpoint: endpoint-production`, `route.policy_ref` recorded.

### Step 7 â€?Ground the answer in claims and memory

```powershell
$groundBody = @{ claim_refs = @("claim://inf/0001/service-level"); memory_ref = "memory://inf/0001"; idempotency_key = "i-ground-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/ground" -ContentType "application/json" -Body $groundBody
```

**Expected:** `200` with `status: grounded` and the grounding refs attached.

### Step 8 â€?Human-review gate (inference-domain, denied)

A high-impact answer is attempted before human review:

```powershell
$unreviewedAnswer = @{ answer_ref = "answer://inf/0001"; produced_by = $Automation; idempotency_key = "i-answer-unreviewed-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/answers" -ContentType "application/json" -Body $unreviewedAnswer
```

**Expected:** HTTP 403

```json
{"error":"human_review_required_before_answer"}
```

### Step 9 â€?Review and produce the governed answer

```powershell
$reviewBody = @{ reviewed_by = $Operator; decision = "approve"; review_ref = "review://inf/0001"; idempotency_key = "i-review-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/reviews" -ContentType "application/json" -Body $reviewBody

$answerBody = @{ answer_ref = "answer://inf/0001"; produced_by = $Automation; idempotency_key = "i-answer-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/answers" -ContentType "application/json" -Body $answerBody
```

**Expected:** the review returns `status: reviewed`; the answer returns `status: answered` with the answer ref recorded.

### Step 10 â€?Audit and immutability

```powershell
$auditBody = @{ audited_by = $Operator; audit_ref = "audit://inf/0001"; idempotency_key = "i-audit-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/audit" -ContentType "application/json" -Body $auditBody

$reroute = @{ model = "model-beta"; endpoint = "endpoint-production"; policy_ref = "policy://inf/selection"; idempotency_key = "i-route-late-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8103/v1/inferences/inf-0001/route" -ContentType "application/json" -Body $reroute
```

**Expected:** the audit returns `status: audited`; the post-audit mutation is rejected with HTTP 409 `inference_audited_immutable`.

## Output Artifacts

| Artifact | Location | Contents |
| --- | --- | --- |
| Inference outcome | `.local-data/inference-outcome.json` | inference id, tenant, operator, steps, final inference state, notifications |
| Value report | `.local-data/inference-value-report.json` | example, outcome, KPIs, gates, evidence, steps |

## Idempotency

Every mutating call carries a stable idempotency key. Re-running the demo does not duplicate artifacts; the adapter returns `"replayed": true` for the same key. Governance works on reruns too.

## Verification

```powershell
.\verify.ps1
```

## Troubleshooting

- **Port conflicts:** the inference-domain adapter listens on `:8103`. Free it (`Stop-Process` or `..\stop-demo.ps1`) before re-running.
- **Services not ready:** confirm `.\start-services.ps1` reported "All local services are ready." If a binary is missing, check the paths in `local.env.ps1`.
- **No `.local-data`:** the scenario must complete before `verify.ps1` can validate the artifacts.
