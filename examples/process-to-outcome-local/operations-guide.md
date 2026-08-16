# Process-To-Outcome Demo — Detailed Operations Guide

Step-by-step walkthrough of the process-to-outcome demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: operator `ops-lead`, process `proc-0001`, decision reference `decision://proc-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Process-domain adapter | `http://localhost:8100` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Process** (`proc-0001`): workflow `onboarding`, stages `request → review → approve → complete`, current stage `request`, status `initiated`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the process case (Symbivela)

**Purpose.** Create the human authority that governs the process outcome.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: ops-lead,
         Idempotency-Key: process-ops-workspace-v1
Body:
{"workspace_id":"process-ops","name":"Process Operations","owner_id":"ops-lead"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: ops-lead,
         Idempotency-Key: proc-0001-case-v1
Body:
{"workspace_id":"process-ops","case_id":"proc-0001-outcome","subject_ref":"process://proc-0001",
 "problem":"Drive the onboarding process through its sequenced stages to a terminal outcome.",
 "evidence_refs":"process://proc-0001","candidate_actions":"advance,complete",
 "deadline":"2026-09-02T12:00:00Z"}
```

**What to notice.** The case governs the process outcome; the process itself is the source of truth for stage order.

## Step 2 — Record the process context (adapter + Ontovela)

**Purpose.** Assert the process state with evidence.

**Request 2a — process view.**
```
GET http://localhost:8100/v1/processes/proc-0001
```
Response: `{"id":"proc-0001","workflow":"onboarding","stages":["request","review","approve","complete"],"current_stage":"request","status":"initiated","advances":[]}`.

**Request 2b — process assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: proc-0001-flow-v1
Body:
{"id":"assertion-proc-0001-initiated","subject_id":"proc-0001","property":"process_status",
 "value":"initiated","state_kind":"observed","event_time":"2026-08-16T18:00:00Z",
 "system_time":"2026-08-16T18:00:01Z","source":"process-control","evidence_ref":"evidence://process/proc-0001"}
```

**What to notice.** The process state is evidence-bearing; the defined stage order is fixed.

## Step 3 — Show stages advance in order

**Purpose.** Prove stage-sequenced gating.

**Request — out-of-order advance (expect rejection).**
```
POST http://localhost:8100/v1/processes/proc-0001/advance
Body:
{"from_stage":"request","to_stage":"approve","decided_by":"ops-lead","rationale":"skip review",
 "decision_ref":"decision://proc-0001","idempotency_key":"p-skip-v1"}
```
The adapter responds `409 Conflict` with `{"error":"stage_mismatch_next_is_review"}`.

**What to notice.** The process can only advance to the exact next stage; a skip is rejected structurally.

## Step 4 — Advance through the stages

**Purpose.** Advance `request → review → approve → complete` with human attribution.

**Request — one advance (repeated for each pair).**
```
POST http://localhost:8100/v1/processes/proc-0001/advance
Body:
{"from_stage":"request","to_stage":"review","decided_by":"ops-lead","rationale":"stage request complete",
 "decision_ref":"decision://proc-0001","idempotency_key":"p-request-v1"}
```

After the final advance, `current_stage = complete`, `status = awaiting-outcome`.

**What to notice.** Every advance carries `decided_by`, `rationale`, and `decision_ref` — no unattributed stage movement.

## Step 5 — Show the outcome needs the terminal stage

**Purpose.** Prove terminal-state enforcement.

**Request — complete before terminal (expect rejection).** *(Demonstrated by attempting completion before the final advance in the script; shown here for the gate.)*
```
POST http://localhost:8100/v1/processes/proc-0001/complete
Body:
{"completed_by":"ops-lead","idempotency_key":"p-comp-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"outcome_not_reached_terminal_stage_required"}`.

**What to notice.** The outcome is unreachable until the terminal stage — completion cannot short-circuit the process.

## Step 6 — Wrap the process durably (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `process-to-outcome-workflow.json`.** Stages: `request (ops-lead) → review (ops-lead) → approve (ops-lead) → complete (capability process.complete.execute)`.

**CLI — validate and define.**
```powershell
rheo workflow validate process-to-outcome-workflow.json
rheo workflow define --file process-to-outcome-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"process-to-outcome","project":"proc-0001","actor":"ops-lead"}
```

**What to notice.** The `complete` stage is capability-gated; the durable wrapper mirrors the sequenced stages.

## Step 7 — Generate a process plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `process-to-outcome-plan.json`.** Catalog marks the four stages with `humanOnly`/`terminal`; hard constraints for stage-sequence, terminal-state, and immutable-outcome.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of process-to-outcome-plan.json)
```

**What to notice.** The plan encodes the stage sequence, so even the recommendation respects the ordering.

## Step 8 — Complete the outcome and show immutability

**Purpose.** Complete at the terminal stage and prove the process is immutable.

**Request 8a — complete.**
```
POST http://localhost:8100/v1/processes/proc-0001/complete
Body:
{"completed_by":"ops-lead","idempotency_key":"p-comp-v1"}
```
Response: `process.status` (`completed`).

**Request 8b — reopen (expect rejection).**
```
POST http://localhost:8100/v1/processes/proc-0001/advance
Body:
{"from_stage":"complete","to_stage":"request","decided_by":"ops-lead","rationale":"reopen",
 "decision_ref":"decision://proc-0001","idempotency_key":"p-reopen"}
```
The adapter responds `409 Conflict` with `{"error":"process_already_completed"}`.

**Outputs written to `.local-data/`:** `process-outcome.json` and `process-value-report.json`.

**What to notice.** A completed process is final; the three denial records make the lifecycle integrity measurable.

## Output Artifacts

### `process-outcome.json`

```json
{
  "process_id": "proc-0001",
  "tenant": "tenant-a",
  "operator": "ops-lead",
  "steps": [
    {"index": 1, "title": "Open the process case", "product": "symbivela", "artifact": "proc-0001-outcome"},
    {"index": 2, "title": "Record the process context", "product": "ontovela", "artifact": "assertion-proc-0001-initiated"},
    {"index": 3, "title": "Show stages advance in order", "product": "process-domain", "artifact": "out-of-order-advance-rejected"},
    {"index": 4, "title": "Advance through the stages", "product": "process-domain", "artifact": "advance-approve-v1"},
    {"index": 5, "title": "Show the outcome needs the terminal stage", "product": "process-domain", "artifact": "complete-before-terminal-rejected"},
    {"index": 6, "title": "Wrap the process durably", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a process plan", "product": "orchadyn", "artifact": "plan-proc-0001"},
    {"index": 8, "title": "Complete the outcome", "product": "process-domain", "artifact": "complete-p-comp-v1"}
  ],
  "process_state": {
    "id": "proc-0001", "workflow": "onboarding",
    "stages": ["request", "review", "approve", "complete"],
    "current_stage": "complete", "status": "completed",
    "completed_by": "ops-lead",
    "advances": [
      {"from_stage": "request", "to_stage": "review", "decided_by": "ops-lead"},
      {"from_stage": "review", "to_stage": "approve", "decided_by": "ops-lead"},
      {"from_stage": "approve", "to_stage": "complete", "decided_by": "ops-lead"}
    ]
  }
}
```

### `process-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 11, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8100/healthz` | Adapter build failed or port busy | Check `.local-logs\process-domain.err.log`; confirm `go` on PATH. |
| `409 stage_mismatch_next_is_<stage>` | Out-of-order advance | Advance to the exact next stage. |
| `403 outcome_not_reached_terminal_stage_required` | Complete before terminal | Reach the terminal stage first. |
| `409 process_already_completed` | Reopen after completion | This is the *expected* denial; the completed process is immutable. |
