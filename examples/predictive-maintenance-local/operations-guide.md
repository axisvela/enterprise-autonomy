# Predictive Maintenance Demo — Detailed Operations Guide

Step-by-step walkthrough of the predictive-maintenance demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: maintenance manager `maintenance-manager`, safety authority `safety-authority`, signal `signal-pm-0001`, asset `asset-pump-01`, decision reference `decision://pm-0001`, safety reference `safety://pm-0001`, approval reference `approval://pm-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Maintenance-domain adapter | `http://localhost:8095` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Signal** (`signal-pm-0001`): asset `asset-pump-01`, level `elevated`, status `pending` (a prediction, not a confirmed fault).
- **Asset** (`asset-pump-01`): `Cooling Pump 01`, zone `zone-b`, status `running`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the maintenance case (Symbivela)

**Purpose.** Create the human authority that governs the intervention.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: maintenance-manager,
         Idempotency-Key: maintenance-workspace-v1
Body:
{"workspace_id":"maintenance","name":"Maintenance Operations","owner_id":"maintenance-manager"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: maintenance-manager,
         Idempotency-Key: pm-0001-case-v1
Body:
{"workspace_id":"maintenance","case_id":"pm-0001-intervention","subject_ref":"signal://signal-pm-0001",
 "problem":"Elevated risk signal for cooling pump 01; intervention must be validated and safety-reviewed.",
 "evidence_refs":"asset://asset-pump-01",
 "candidate_actions":"monitor,inspect,repair,defer,stop","deadline":"2026-08-26T12:00:00Z"}
```

**What to notice.** The case names the accountable owner and the permitted actions, and frames the signal as requiring validation and safety review.

## Step 2 — Record the risk-signal context (adapter + Ontovela)

**Purpose.** Assert the elevated risk with evidence and confirm the signal and asset views.

**Request 2a — signal view.**
```
GET http://localhost:8095/v1/signals/signal-pm-0001
```
Response: `{"id":"signal-pm-0001","asset":"asset-pump-01","level":"elevated","status":"pending","confirmed":false}`.

**Request 2b — asset assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: pm-0001-asset-v1
Body:
{"id":"assertion-asset-pump-01-risk","subject_id":"asset-pump-01","property":"risk_level",
 "value":"elevated","state_kind":"observed","event_time":"2026-08-16T12:00:00Z",
 "system_time":"2026-08-16T12:00:01Z","source":"condition-monitoring",
 "evidence_ref":"evidence://monitoring/signal-pm-0001"}
```

**What to notice.** The signal is `pending` and `confirmed=false` — the world model asserts the *risk*, not a fault.

## Step 3 — Show a prediction is not a fault (work-order gate)

**Purpose.** Prove an unvalidated signal cannot schedule work.

**Request — work order on an unvalidated signal (expect rejection).**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/work-orders
Body:
{"scope":"replace bearing","approved_by":"maintenance-manager",
 "approval_ref":"approval://pm-0001","idempotency_key":"pm-wo-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"signal_not_validated_prediction_is_not_a_fault"}`.

**What to notice.** Prediction-vs-fact integrity is structural: no work order exists until the signal is validated, regardless of the approval attached.

## Step 4 — Validate the signal and decide (maintenance manager)

**Purpose.** Validate the signal and record the maintenance decision; prove an unconfirmed prediction cannot stop equipment.

**Request 4a — validate.**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/validate
Body:
{"validated_by":"maintenance-manager","confirmed":false,
 "note":"prediction based on vibration trend","idempotency_key":"pm-val-v1"}
```
Response: `signal.status` (`validated`). A non-manager validator is rejected (`403 only_maintenance_manager_can_validate`).

**Request 4b — unconfirmed stop (expect rejection).**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/decisions
Body:
{"decision":"stop","decided_by":"maintenance-manager","decision_ref":"decision://pm-0001",
 "idempotency_key":"pm-stop-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"unconfirmed_prediction_cannot_trigger_stop"}`.

**Request 4c — repair decision.**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/decisions
Body:
{"decision":"repair","decided_by":"maintenance-manager","decision_ref":"decision://pm-0001",
 "idempotency_key":"pm-dec-v1"}
```
Response: `decision.decision` (`repair`).

**What to notice.** Validation distinguishes prediction from confirmed fault; an unconfirmed signal can never escalate to a `stop`, but a validated signal can be decided as `repair`.

## Step 5 — Conduct the safety review (safety authority)

**Purpose.** Prove intrusive work requires an approved safety review, then record it.

**Request 5a — work order without safety review (expect rejection).**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/work-orders
Body:
{"scope":"replace bearing","approved_by":"maintenance-manager",
 "approval_ref":"approval://pm-0001","idempotency_key":"pm-wo-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"safety_review_required_for_intrusive_work"}`.

**Request 5b — safety review.**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/safety-reviews
Body:
{"reviewed_by":"safety-authority","outcome":"approve","safety_ref":"safety://pm-0001",
 "idempotency_key":"pm-safety-v1"}
```
Response: `safety.outcome` (`approve`). Only the safety authority may review (`403 only_safety_authority_can_review`).

**What to notice.** Safety is **conjunctive**: a repair decision alone is insufficient; the work order is only reachable after an approved safety review by the safety authority.

## Step 6 — Create the durable maintenance process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `predictive-maintenance-workflow.json`.** Stages: `validate (maintenance-manager) → decide (maintenance-manager) → safety (safety-authority) → schedule (capability maintenance.work.schedule) → close (maintenance-manager)`.

**CLI — validate and define.**
```powershell
rheo workflow validate predictive-maintenance-workflow.json
rheo workflow define --file predictive-maintenance-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"predictive-maintenance-to-work-order","project":"signal-pm-0001","actor":"maintenance-manager"}
```

**What to notice.** The `schedule` stage is capability-gated; the workflow models validation, decision, and safety as explicit stages mirroring the adapter's gates.

## Step 7 — Generate a maintenance plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `predictive-maintenance-plan.json`.** Goal `goal-pm-0001-safe`; catalog marks `cap-repair` as `intrusive: true, safetyRequired: true`; hard constraints for prediction-integrity and safety; delegation with `evidenceDuty: ["safety://pm-0001", "approval://pm-0001"]`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of predictive-maintenance-plan.json)
```

**What to notice.** The plan's catalog encodes safety-required intrusive work, so even the recommendation respects the safety gate.

## Step 8 — Schedule the work order and emit the value report

**Purpose.** Create the approved, safety-reviewed work order and reconstruct the lifecycle from evidence.

**Request.**
```
POST http://localhost:8095/v1/signals/signal-pm-0001/work-orders
Body:
{"scope":"replace bearing","approved_by":"maintenance-manager",
 "approval_ref":"approval://pm-0001","idempotency_key":"pm-wo-v1"}
```

**Response fields read by the script:** `work_order.id` (`wo-pm-wo-v1`), `work_order.status` (`scheduled`).

**Outputs written to `.local-data/`:** `maintenance-outcome.json` and `maintenance-value-report.json`.

**What to notice.** The value report's three denial entries (`unvalidated-work-order-rejected`, `unconfirmed-stop-rejected`, `no-safety-review-rejected`) make prediction-vs-fact integrity and the safety conjunctive gate measurable.

## Output Artifacts

### `maintenance-outcome.json`

```json
{
  "signal_id": "signal-pm-0001",
  "tenant": "tenant-a",
  "maintenance_manager": "maintenance-manager",
  "steps": [
    {"index": 1, "title": "Open the maintenance case", "product": "symbivela", "artifact": "pm-0001-intervention"},
    {"index": 2, "title": "Record the risk-signal context", "product": "ontovela", "artifact": "assertion-asset-pump-01-risk"},
    {"index": 3, "title": "Show a prediction is not a fault", "product": "maintenance-domain", "artifact": "unvalidated-work-order-rejected"},
    {"index": 4, "title": "Validate the signal and decide", "product": "maintenance-domain", "artifact": "decision-pm-dec-v1"},
    {"index": 5, "title": "Conduct the safety review", "product": "maintenance-domain", "artifact": "safety-pm-safety-v1"},
    {"index": 6, "title": "Create the durable maintenance process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a maintenance plan", "product": "orchadyn", "artifact": "plan-pm-0001"},
    {"index": 8, "title": "Schedule the work order", "product": "maintenance-domain", "artifact": "wo-pm-wo-v1"}
  ],
  "signal_state": {
    "id": "signal-pm-0001", "asset": "asset-pump-01", "level": "elevated", "status": "validated",
    "validated_by": "maintenance-manager", "confirmed": false,
    "validation_note": "prediction based on vibration trend",
    "decision": {"id": "decision-pm-dec-v1", "decision": "repair", "decided_by": "maintenance-manager", "decision_ref": "decision://pm-0001"},
    "safety": {"id": "safety-pm-safety-v1", "reviewed_by": "safety-authority", "outcome": "approve", "safety_ref": "safety://pm-0001"},
    "work_order": {"id": "wo-pm-wo-v1", "signal": "signal-pm-0001", "scope": "replace bearing", "approved_by": "maintenance-manager", "approval_ref": "approval://pm-0001", "status": "scheduled"}
  }
}
```

### `maintenance-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 11, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8095/healthz` | Adapter build failed or port busy | Check `.local-logs\maintenance-domain.err.log`; confirm `go` on PATH. |
| `403 signal_not_validated_prediction_is_not_a_fault` | Work order before validation | Validate the signal first. |
| `403 unconfirmed_prediction_cannot_trigger_stop` | Unconfirmed `stop` decision | This is the *expected* denial; an unconfirmed prediction cannot stop equipment. |
| `403 safety_review_required_for_intrusive_work` | Repair/stop without safety approval | Have the safety authority approve first. |
| `400 decision_does_not_require_work_order` | Work order for monitor/inspect/defer | Only repair/stop produce work orders. |
