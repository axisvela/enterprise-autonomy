# Fleet Mission Demo — Detailed Operations Guide

Step-by-step walkthrough of the fleet-mission-exception demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: operator `ops-lead`, mission `mission-alpha-001`, boundary `zone-alpha`, approval reference `approval://mission-alpha-001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Fleet-domain adapter | `http://localhost:8099` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Mission** (`mission-alpha-001`): zone `zone-alpha`, objective `inspect racks`, status `planned`, operator `ops-lead`, boundary `["zone-alpha"]`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the mission case (Symbivela)

**Purpose.** Create the human authority that governs the mission.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: ops-lead,
         Idempotency-Key: fleet-ops-workspace-v1
Body:
{"workspace_id":"fleet-ops","name":"Fleet Operations","owner_id":"ops-lead"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: ops-lead,
         Idempotency-Key: fleet-0001-case-v1
Body:
{"workspace_id":"fleet-ops","case_id":"fleet-0001-mission","subject_ref":"mission://mission-alpha-001",
 "problem":"Bounded inspection of zone-alpha; exceptions must pause for operator review.",
 "evidence_refs":"zone://zone-alpha","candidate_actions":"resume,adjust,cancel",
 "deadline":"2026-08-31T12:00:00Z"}
```

**What to notice.** The case frames the mission as bounded with exception pause-and-review.

## Step 2 — Record the mission context (adapter + Ontovela)

**Purpose.** Assert the mission boundary with evidence.

**Request 2a — mission view.**
```
GET http://localhost:8099/v1/missions/mission-alpha-001
```
Response: `{"id":"mission-alpha-001","zone":"zone-alpha","objective":"inspect racks","status":"planned","operator":"ops-lead","boundary":["zone-alpha"],"actions":[]}`.

**Request 2b — boundary assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: fleet-0001-zone-v1
Body:
{"id":"assertion-mission-alpha-001-bounded","subject_id":"mission-alpha-001","property":"mission_boundary",
 "value":"zone-alpha","state_kind":"observed","event_time":"2026-08-16T16:00:00Z",
 "system_time":"2026-08-16T16:00:01Z","source":"fleet-control","evidence_ref":"evidence://fleet/mission-alpha-001"}
```

**What to notice.** The boundary is an evidence-bearing fact; the mission is scoped to `zone-alpha`.

## Step 3 — Start and enforce the boundary

**Purpose.** Prove boundary enforcement is autonomous.

**Request 3a — start.**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/start
Body:
{"started_by":"ops-lead","idempotency_key":"fleet-start-v1"}
```
Response: `mission.status` (`running`).

**Request 3b — out-of-boundary telemetry (expect rejection).**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/telemetry
Body:
{"position":"zone-omega","status":"running","idempotency_key":"fleet-tl-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"boundary_deviation_mission_frozen"}`.

**Request 3c — in-bound telemetry.**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/telemetry
Body:
{"position":"zone-alpha","status":"running","idempotency_key":"fleet-tl2-v1"}
```

**What to notice.** Boundary enforcement needs no human: out-of-bound telemetry is frozen automatically, and the mission continues only inside its boundary.

## Step 4 — Pause on the exception

**Purpose.** An exception always pauses the mission for review.

**Request.**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/exceptions
Body:
{"type":"obstacle","detail":"rack-07 blocked","raised_by":"fleet-runtime","idempotency_key":"fleet-ex-v1"}
```
Response: `exception.type` (`obstacle`), `mission.status` (`paused`).

**What to notice.** The mission cannot continue past an exception — pause is automatic.

## Step 5 — Review and resume the mission (operator-gated)

**Purpose.** Prove only the operator may review, then resume with an approval reference.

**Request 5a — non-operator review (expect rejection).**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/reviews
Body:
{"reviewed_by":"outsider","decision":"resume","approval_ref":"approval://mission-alpha-001","idempotency_key":"fleet-rv-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"not_mission_operator"}`.

**Request 5b — operator review.**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/reviews
Body:
{"reviewed_by":"ops-lead","decision":"resume","approval_ref":"approval://mission-alpha-001","idempotency_key":"fleet-rv-v1"}
```
Response: `review.decision` (`resume`), `mission.status` (`resumed`).

**What to notice.** Resume is approval-cited and operator-gated — the mission does not continue on its own.

## Step 6 — Create the durable mission process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `fleet-mission-workflow.json`.** Stages: `start (ops-lead) → pause (capability fleet.exception.pause) → review (ops-lead) → resume (capability fleet.resume.execute) → close (ops-lead)`.

**CLI — validate and define.**
```powershell
rheo workflow validate fleet-mission-workflow.json
rheo workflow define --file fleet-mission-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"fleet-mission-exception","project":"mission-alpha-001","actor":"ops-lead"}
```

**What to notice.** The `pause` and `resume` stages are capability-gated; the workflow mirrors start → pause → review → resume ordering.

## Step 7 — Generate a mission plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `fleet-mission-plan.json`.** Goal `goal-fleet-0001-safe`; catalog `cap-boundary` with `autonomous: true`; `cap-review` with `pauseRequired: true` and `operatorOnly: true`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of fleet-mission-plan.json)
```

**What to notice.** The plan encodes the autonomous boundary and pause-and-review constraints.

## Step 8 — Complete and emit the value report

**Purpose.** Complete the active mission and reconstruct the lifecycle from evidence.

**Request.**
```
POST http://localhost:8099/v1/missions/mission-alpha-001/complete
Body:
{"completed_by":"ops-lead","idempotency_key":"fleet-cmp-v1"}
```
Response: `mission.status` (`completed`).

**Outputs written to `.local-data/`:** `fleet-outcome.json` and `fleet-value-report.json`.

**What to notice.** The value report's denial records (`boundary-deviation-frozen`, `non-operator-review-rejected`) make the autonomous boundary and operator gate measurable.

## Output Artifacts

### `fleet-outcome.json`

```json
{
  "mission_id": "mission-alpha-001",
  "tenant": "tenant-a",
  "operator": "ops-lead",
  "steps": [
    {"index": 1, "title": "Open the mission case", "product": "symbivela", "artifact": "fleet-0001-mission"},
    {"index": 2, "title": "Record the mission context", "product": "ontovela", "artifact": "assertion-mission-alpha-001-bounded"},
    {"index": 3, "title": "Start and enforce the boundary", "product": "fleet-domain", "artifact": "start-fleet-start-v1"},
    {"index": 4, "title": "Pause on the exception", "product": "fleet-domain", "artifact": "exception-fleet-ex-v1"},
    {"index": 5, "title": "Review and resume the mission", "product": "fleet-domain", "artifact": "review-fleet-rv-v1"},
    {"index": 6, "title": "Create the durable mission process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a mission plan", "product": "orchadyn", "artifact": "plan-fleet-0001"},
    {"index": 8, "title": "Complete the mission", "product": "fleet-domain", "artifact": "complete-fleet-cmp-v1"}
  ],
  "mission_state": {
    "id": "mission-alpha-001", "zone": "zone-alpha", "objective": "inspect racks",
    "status": "completed", "operator": "ops-lead", "boundary": ["zone-alpha"],
    "position": "zone-alpha",
    "exception": {"id": "exception-fleet-ex-v1", "type": "obstacle", "detail": "rack-07 blocked"},
    "review": {"id": "review-fleet-rv-v1", "reviewed_by": "ops-lead", "decision": "resume", "approval_ref": "approval://mission-alpha-001"}
  }
}
```

### `fleet-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 5, `evidence_artifacts` 11, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8099/healthz` | Adapter build failed or port busy | Check `.local-logs\fleet-domain.err.log`; confirm `go` on PATH. |
| `403 boundary_deviation_mission_frozen` | Out-of-bound telemetry | This is the *expected* denial; the mission is frozen automatically. |
| `403 operator_review_required_mission_must_be_paused` | Review of an active mission | Review only after an exception pauses the mission. |
| `403 not_mission_operator` | Non-operator start/review | Act as `ops-lead`. |
| `409 mission_not_active` | Telemetry/complete on a non-active mission | Operate while the mission is running/resumed. |
