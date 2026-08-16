# Sequenced-Deployment Local Demo — Detailed Operations Guide

`dep-0001` for the `release-pipeline` workflow runs through a governed sequenced lifecycle: case, pipeline context, **sequence gate**, **evidence-cited autonomous steps**, **deviation gate**, durable process, pipeline plan, and **immutable release**.

All commands below assume the services are running (see the [README](README.md)).

## Prerequisites

- The `local.env.ps1` file copied from `local.env.ps1.example` and loaded: `. .\local.env.ps1`
- Services started: `.\start-services.ps1`
- Or run everything in one step: `.\run-all.ps1`

## Step-by-Step Requests and Expected Responses

### Step 1 — Open the deployment case (Symbivela)

```powershell
$workspace = @{ workspace_id = "deployment-ops"; name = "Deployment Operations"; owner_id = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/workspaces" -Headers @{ "X-SYMBIVELA-Tenant" = $TenantId; "X-SYMBIVELA-Actor" = $Operator; "Idempotency-Key" = "deployment-ops-workspace-v1" } -ContentType "application/json" -Body $workspace

$case = @{ workspace_id = "deployment-ops"; case_id = "dep-0001-release"; subject_ref = "deployment://dep-0001"; problem = "..."; evidence_refs = "deployment://dep-0001"; candidate_actions = "steps,deviations,release"; deadline = "2026-09-02T12:00:00Z" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/exception-cases" -Headers $symbiHeaders -ContentType "application/json" -Body $case
```

**Expected:** Symbivela returns a case with `case_id: dep-0001-release` in state `open`. The release outcome is driven by the sequenced pipeline.

### Step 2 — Record the pipeline context (adapter + Ontovela)

```powershell
curl.exe "http://localhost:8102/v1/deployments/dep-0001"
```

**Expected:**

```json
{"id":"dep-0001","workflow":"release-pipeline","steps":["checkout","build","test","approve","production"],
 "current_step":"checkout","status":"initiated","steps_run":[],"deviations":[]}
```

Then assert the initiated state to Ontovela:

```powershell
$assertion = @{ id = "assertion-dep-0001-initiated"; subject_id = $DeploymentId; property = "deployment_status"; value = "initiated"; state_kind = "observed"; event_time = "2026-08-16T18:00:00Z"; system_time = "2026-08-16T18:00:01Z"; source = "deployment-control"; evidence_ref = "evidence://deployment/dep-0001" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8082/v1/assertions" -Headers $ontoHeaders -ContentType "application/json" -Body $assertion
```

**Expected:** Ontovela returns a stored assertion (`observed`).

### Step 3 — Sequence gate (deployment-domain, denied)

An autonomous executor attempts to skip ahead to `test` before `checkout`:

```powershell
$skipBody = @{ step = "test"; executed_by = $Automation; evidence_ref = "evidence://dep/test"; idempotency_key = "d-skip-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8102/v1/deployments/dep-0001/steps" -ContentType "application/json" -Body $skipBody
```

**Expected:** HTTP 409

```json
{"error":"step_out_of_sequence_next_is_checkout"}
```

### Step 4 — Execute the sequenced autonomous steps

Each step cites its evidence:

```powershell
$stepBody = @{ step = "checkout"; executed_by = $Automation; evidence_ref = "evidence://dep/checkout"; idempotency_key = "d-checkout-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8102/v1/deployments/dep-0001/steps" -ContentType "application/json" -Body $stepBody
```

Repeat for `build` and `test` with matching evidence refs and idempotency keys.

**Expected:** each returns `200` with `status: in-flight`, `current_step` advancing `checkout → build → test`.

### Step 5 — Deviation gate (deployment-domain, denied)

An unapproved pause is attempted:

```powershell
$noApproval = @{ action = "pause"; idempotency_key = "d-pause-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8102/v1/deployments/dep-0001/deviations" -ContentType "application/json" -Body $noApproval
```

**Expected:** HTTP 403

```json
{"error":"deviation_requires_human_approval"}
```

### Step 6 — Durable process wrapper (Rheovela)

```powershell
$rheo = Join-Path $AxisRoboHome "RHEOVELA\rheo.exe"
& $rheo workflow define --file ".\sequenced-deployment-workflow.json"
$processBody = @{ workflow = "sequenced-deployment"; project = $DeploymentId; actor = $Operator } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/v1/instances" -ContentType "application/json" -Body $processBody
```

**Expected:** Rheovela returns an instance id, e.g. `inst-...`, in state `open`.

### Step 7 — Plan (Orchadyn, optional)

```powershell
$plan = Get-Content -Raw ".\sequenced-deployment-plan.json"
Invoke-RestMethod -Method Post -Uri "http://localhost:1816/plans:generate" -ContentType "application/json" -Body $plan
```

**Expected:** Orchadyn returns a verified plan listing the sequenced capabilities and 0 violations (when configured).

### Step 8 — Terminal step and release immutability

Execute `approve` and `production`:

```powershell
$stepBody = @{ step = "approve"; executed_by = $Automation; evidence_ref = "evidence://dep/approve"; idempotency_key = "d-approve-v1" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8102/v1/deployments/dep-0001/steps" -ContentType "application/json" -Body $stepBody
# repeat for "production"
```

Then attempt to re-run a released step:

```powershell
$reopenBody = @{ step = "checkout"; executed_by = $Automation; evidence_ref = "evidence://dep/checkout"; idempotency_key = "d-reopen" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://localhost:8102/v1/deployments/dep-0001/steps" -ContentType "application/json" -Body $reopenBody
```

**Expected:** the terminal step returns `status: released`; the re-run is rejected with HTTP 409 `deployment_already_released_immutable`.

## Output Artifacts

| Artifact | Location | Contents |
| --- | --- | --- |
| Deployment outcome | `.local-data/deployment-outcome.json` | deployment id, tenant, operator, steps, final deployment state, notifications |
| Value report | `.local-data/deployment-value-report.json` | example, outcome, KPIs, gates, evidence, steps |

## Idempotency

Every mutating call carries a stable idempotency key. Re-running the demo does not duplicate artifacts; the adapter returns `"replayed": true` for the same key. Governance works on reruns too.

## Verification

```powershell
.\verify.ps1
```

## Troubleshooting

- **Port conflicts:** the deployment-domain adapter listens on `:8102`. Free it (`Stop-Process` or `..\stop-demo.ps1`) before re-running.
- **Services not ready:** confirm `.\start-services.ps1` reported "All local services are ready." If a binary is missing, check the paths in `local.env.ps1`.
- **No `.local-data`:** the scenario must complete before `verify.ps1` can validate the artifacts.
