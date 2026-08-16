# Integration Recovery Demo — Detailed Operations Guide

Step-by-step walkthrough of the integration-outage-recovery demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: integration owner `integration-owner`, integration `partner-shipping`, in-flight work `work-0001`, preservation reference `process://work-0001`, evidence reference `evidence://reconnect/partner-shipping`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Integration-domain adapter | `http://localhost:8096` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Integration** (`partner-shipping`): status `down`, outage since `2026-08-16T10:00:00Z`.
- **In-flight work** (`work-0001`): affects `order-123`, status `inflight`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the outage case (Symbivela)

**Purpose.** Create the human authority that governs recovery of in-flight work.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: integration-owner,
         Idempotency-Key: integration-ops-workspace-v1
Body:
{"workspace_id":"integration-ops","name":"Integration Operations","owner_id":"integration-owner"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: integration-owner,
         Idempotency-Key: iro-0001-case-v1
Body:
{"workspace_id":"integration-ops","case_id":"iro-0001-outage","subject_ref":"integration://partner-shipping",
 "problem":"Partner shipping integration is down; in-flight work must be preserved and verified before resume.",
 "evidence_refs":"integration://partner-shipping",
 "candidate_actions":"preserve,verify,resume,complete,escalate","deadline":"2026-08-28T12:00:00Z"}
```

**What to notice.** The case governs the recovery lifecycle, including the escalation path.

## Step 2 — Detect the outage and record in-flight work (adapter + Ontovela)

**Purpose.** Assert the outage with evidence and confirm the integration and work views.

**Request 2a — integration view.**
```
GET http://localhost:8096/v1/integrations/partner-shipping
```
Response: `{"id":"partner-shipping","status":"down","outage_since":"2026-08-16T10:00:00Z",...}`.

**Request 2b — work view.**
```
GET http://localhost:8096/v1/work/work-0001
```
Response: `{"id":"work-0001","affects":"order-123","status":"inflight",...}`.

**Request 2c — outage assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: iro-0001-outage-v1
Body:
{"id":"assertion-partner-shipping-down","subject_id":"partner-shipping","property":"integration_status",
 "value":"down","state_kind":"observed","event_time":"2026-08-16T10:00:00Z",
 "system_time":"2026-08-16T10:00:01Z","source":"integration-monitor",
 "evidence_ref":"evidence://monitor/partner-shipping"}
```

**What to notice.** The outage is an evidence-bearing observed fact; the in-flight work is recorded as `inflight`.

## Step 3 — Show resume requires preservation (work-order gate)

**Purpose.** Prove preserve-before-resume is structural.

**Request — resume before preservation (expect rejection).**
```
POST http://localhost:8096/v1/work/work-0001/resume
Body:
{"resumed_by":"integration-owner","idempotency_key":"iro-resume-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"work_not_preserved"}`.

**What to notice.** Resume is impossible until the work is preserved — no recovery order can bypass preservation.

## Step 4 — Preserve the in-flight work

**Purpose.** Record the work under a durable preservation reference.

**Request.**
```
POST http://localhost:8096/v1/work/work-0001/preserve
Body:
{"preserved_by":"integration-owner","preserved_ref":"process://work-0001","idempotency_key":"iro-pres-v1"}
```
Response: `work.status` (`preserved`).

**What to notice.** Preservation ties the work to a durable reference so it survives the outage window.

## Step 5 — Verify the reconnection (integration owner)

**Purpose.** Prove verify-before-resume, then record the reconnection check.

**Request 5a — resume before verification (expect rejection).**
```
POST http://localhost:8096/v1/work/work-0001/resume
Body:
{"resumed_by":"integration-owner","idempotency_key":"iro-resume-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"integration_not_verified"}`.

**Request 5b — reconnection check.**
```
POST http://localhost:8096/v1/integrations/partner-shipping/checks
Body:
{"checked_by":"integration-owner","verified":true,
 "evidence_ref":"evidence://reconnect/partner-shipping","idempotency_key":"iro-check-v1"}
```
Response: `integration.status` (`checked`). Only the integration owner may check (`403 only_integration_owner_can_check`).

**What to notice.** Preservation alone is insufficient; the integration must be verified by the owner before any resume.

## Step 6 — Create the durable recovery process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `integration-recovery-workflow.json`.** Stages: `preserve (integration-owner) → verify (integration-owner) → resume (capability recovery.resume.execute) → complete (integration-owner) → close (integration-owner)`.

**CLI — validate and define.**
```powershell
rheo workflow validate integration-recovery-workflow.json
rheo workflow define --file integration-recovery-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"integration-outage-recovery","project":"work-0001","actor":"integration-owner"}
```

**What to notice.** The `resume` stage is capability-gated; the workflow mirrors the preserve → verify → resume ordering.

## Step 7 — Generate a recovery plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `integration-recovery-plan.json`.** Goal `goal-iro-0001-recovered`; catalog `cap-resume` with `preservationRequired: true` and `verificationRequired: true`; hard constraints for preserve-before-resume, verify-before-resume, and no-silent-rerun.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of integration-recovery-plan.json)
```

**What to notice.** The plan encodes the recovery ordering constraints, so even the recommendation respects preserve-and-verify-before-resume.

## Step 8 — Resume, complete, and prove no silent re-execution

**Purpose.** Complete recovery and demonstrate that a completed action cannot be re-executed.

**Request 8a — resume.**
```
POST http://localhost:8096/v1/work/work-0001/resume
Body:
{"resumed_by":"integration-owner","idempotency_key":"iro-resume-v1"}
```
Response: `work.status` (`resumed`).

**Request 8b — complete.**
```
POST http://localhost:8096/v1/work/work-0001/complete
Body:
{"completed_by":"integration-owner","idempotency_key":"iro-comp-v1"}
```
Response: `work.status` (`completed`).

**Request 8c — repeat completion (expect rejection).**
```
POST http://localhost:8096/v1/work/work-0001/complete
Body:
{"completed_by":"integration-owner","idempotency_key":"iro-comp2-v1"}
```
The adapter responds `409 Conflict` with `{"error":"action_already_completed_no_silent_rerun"}`.

**What to notice.** The recovery ends with a durable, non-re-executable outcome — the `silent-rerun-rejected` denial makes that measurable.

## Output Artifacts

### `integration-outcome.json`

```json
{
  "work_id": "work-0001",
  "tenant": "tenant-a",
  "integration_owner": "integration-owner",
  "steps": [
    {"index": 1, "title": "Open the outage case", "product": "symbivela", "artifact": "iro-0001-outage"},
    {"index": 2, "title": "Detect the outage and record in-flight work", "product": "ontovela", "artifact": "assertion-partner-shipping-down"},
    {"index": 3, "title": "Show resume requires preservation", "product": "integration-domain", "artifact": "resume-before-preserve-rejected"},
    {"index": 4, "title": "Preserve the in-flight work", "product": "integration-domain", "artifact": "preserve-iro-pres-v1"},
    {"index": 5, "title": "Verify the reconnection", "product": "integration-domain", "artifact": "check-iro-check-v1"},
    {"index": 6, "title": "Create the durable recovery process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a recovery plan", "product": "orchadyn", "artifact": "plan-iro-0001"},
    {"index": 8, "title": "Resume, complete, and close", "product": "integration-domain", "artifact": "complete-iro-comp-v1"}
  ],
  "work_state": {
    "id": "work-0001", "affects": "order-123", "status": "completed",
    "preserved_by": "integration-owner", "preserved_ref": "process://work-0001",
    "resumed_by": "integration-owner", "completed_by": "integration-owner"
  }
}
```

### `integration-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 11, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8096/healthz` | Adapter build failed or port busy | Check `.local-logs\integration-domain.err.log`; confirm `go` on PATH. |
| `403 work_not_preserved` | Resume before preservation | Preserve the work first. |
| `403 integration_not_verified` | Resume before reconnection check | Have the integration owner verify reconnection first. |
| `409 action_already_completed_no_silent_rerun` | Second completion | This is the *expected* denial; only idempotent replays are allowed. |
| `403 only_integration_owner_can_check` | Non-owner reconnection check | Check with `integration-owner`. |
