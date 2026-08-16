# Recruitment Demo — Detailed Operations Guide

Step-by-step walkthrough of the recruitment demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: hiring manager `hiring-manager-1`, TA lead `ta-lead-1`, panel `panel-1`, candidate `cand-a`, automated actor `recruiter-assistant`, decision reference `decision://req-0001`, offer reference `offer://req-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Recruitment-domain adapter | `http://localhost:8094` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Requisition** (`req-0001`): role `Senior Platform Engineer`, location `Remote`, hiring manager `hiring-manager-1`, TA lead `ta-lead-1`, budget `budget-rec-0001`, status `draft`, candidates `cand-a`, `cand-b`, `cand-c`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the requisition case (Symbivela)

**Purpose.** Create the human authority that governs the hiring lifecycle.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: hiring-manager-1,
         Idempotency-Key: talent-acquisition-workspace-v1
Body:
{"workspace_id":"talent-acquisition","name":"Talent Acquisition","owner_id":"hiring-manager-1"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: hiring-manager-1,
         Idempotency-Key: req-0001-case-v1
Body:
{"workspace_id":"talent-acquisition","case_id":"req-0001-hire","subject_ref":"requisition://req-0001",
 "problem":"Hire Senior Platform Engineer with human-only selection decisions.",
 "evidence_refs":"budget://budget-rec-0001",
 "candidate_actions":"advance,reject,offer,hold","deadline":"2026-08-25T12:00:00Z"}
```

**What to notice.** The case names the accountable owner and states the human-only policy up front.

## Step 2 — Validate the requisition (recruitment-domain adapter + Ontovela)

**Purpose.** Record structured, job-related criteria and assert the validated state.

**Request 2a — validate.**
```
POST http://localhost:8094/v1/requisitions/req-0001/validate
Body:
{"validated_by":"ta-lead-1","criteria":["platform-expertise","systems-ownership"],
 "idempotency_key":"rec-val-v1"}
```
Response: `requisition.status` (`validated`). A non-TA-lead validator is rejected (`403 only_ta_lead_can_validate`).

**Request 2b — role context assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: req-0001-role-v1
Body:
{"id":"assertion-req-0001-validated","subject_id":"req-0001","property":"hiring_status",
 "value":"validated","state_kind":"observed","event_time":"2026-08-16T11:00:00Z",
 "system_time":"2026-08-16T11:00:01Z","source":"talent-system","evidence_ref":"evidence://talent/req-0001"}
```

**What to notice.** Criteria are recorded before any candidate assessment, and the validated state is asserted in the world model with evidence.

## Step 3 — Show automation cannot decide (recruitment-domain adapter)

**Purpose.** Prove the human-decision boundary is structural.

**Request — automated shortlist attempt (expect rejection).**
```
POST http://localhost:8094/v1/requisitions/req-0001/decisions
Body:
{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"recruiter-assistant",
 "actor_type":"automated","rationale":"keyword match","decision_ref":"decision://req-0001",
 "idempotency_key":"rec-auto-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"automation_cannot_make_hiring_decisions"}`.

**What to notice.** The denial runs **before** stage or candidate checks. Automation can administer, schedule, and organize evidence, but it cannot record any hiring decision.

## Step 4 — Record the human shortlist decision

**Purpose.** The panel advances the candidate with a human attribution and rationale.

**Request.**
```
POST http://localhost:8094/v1/requisitions/req-0001/decisions
Body:
{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"panel-1",
 "actor_type":"human","rationale":"meets criteria","decision_ref":"decision://req-0001",
 "idempotency_key":"rec-sl-v1"}
```
Response: `requisition.status` (`shortlisting`).

**What to notice.** Every decision requires `decided_by`, `rationale`, and `decision_ref` — no unattributed screening.

## Step 5 — Create the durable hiring process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `recruitment-workflow.json`.** Stages: `validate (ta-lead) → shortlist (panel) → selection (hiring-manager) → offer (capability recruitment.offer.execute) → close (ta-lead)`.

**CLI — validate and define.**
```powershell
rheo workflow validate recruitment-workflow.json
rheo workflow define --file recruitment-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"recruitment-requisition-to-offer","project":"req-0001","actor":"ta-lead-1"}
```

**What to notice.** The `offer` stage is capability-gated; the workflow stages mirror the human-decision lifecycle.

## Step 6 — Generate a hiring plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `recruitment-plan.json`.** Goal `goal-req-0001-filled`; catalog selection capabilities marked `humanOnly: true`; hard constraint `automation-cannot-decide`; delegation with `evidenceDuty: ["decision://req-0001"]`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of recruitment-plan.json)
```

**What to notice.** The plan's catalog encodes the human-only constraint, so even the recommendation respects the boundary.

## Step 7 — Record selection and offer, then issue the offer

**Purpose.** The hiring manager records both human decisions; the TA lead issues the offer.

**Request 7a — selection decision.**
```
POST http://localhost:8094/v1/requisitions/req-0001/decisions
Body:
{"stage":"selection","decision":"select","candidate":"cand-a","decided_by":"hiring-manager-1",
 "actor_type":"human","rationale":"strongest evidence","decision_ref":"decision://req-0001",
 "idempotency_key":"rec-sel-v1"}
```

**Request 7b — offer decision.**
```
POST http://localhost:8094/v1/requisitions/req-0001/decisions
Body:
{"stage":"offer","decision":"offer","candidate":"cand-a","decided_by":"hiring-manager-1",
 "actor_type":"human","rationale":"approved package","decision_ref":"decision://req-0001",
 "idempotency_key":"rec-of-v1"}
```

**Request 7c — issue the offer.**
```
POST http://localhost:8094/v1/requisitions/req-0001/offers
Body:
{"candidate":"cand-a","offered_by":"ta-lead-1","offer_ref":"offer://req-0001",
 "idempotency_key":"rec-offer-v1"}
```
Response: `offer.id` (`offer-rec-offer-v1`), `requisition.status` (`closed`).

**What to notice.** The offer is gated on an offer-stage human decision for the same candidate (`403 no_offer_decision_for_candidate` otherwise) and on the lifecycle position (`409 offer_decision_required_first`).

## Step 8 — Confirm the outcome and emit the value report

**Purpose.** Confirm the closed state and reconstruct the lifecycle from evidence.

**Requests.**
```
GET http://localhost:8094/v1/requisitions/req-0001      -> final requisition
GET http://localhost:8094/v1/notifications/req-0001     -> pending notifications
```

**Outputs written to `.local-data/`:** `recruitment-outcome.json` and `recruitment-value-report.json`.

**What to notice.** The value report's `automated-decision-rejected` denial entry makes the human-decision boundary measurable.

## Output Artifacts

### `recruitment-outcome.json`

```json
{
  "requisition_id": "req-0001",
  "tenant": "tenant-a",
  "hiring_manager": "hiring-manager-1",
  "steps": [
    {"index": 1, "title": "Open the requisition case", "product": "symbivela", "artifact": "req-0001-hire"},
    {"index": 2, "title": "Validate the requisition", "product": "recruitment-domain", "artifact": "validate-rec-val-v1"},
    {"index": 3, "title": "Show automation cannot decide", "product": "recruitment-domain", "artifact": "automated-decision-rejected"},
    {"index": 4, "title": "Record the human shortlist decision", "product": "recruitment-domain", "artifact": "decision-rec-sl-v1"},
    {"index": 5, "title": "Create the durable hiring process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 6, "title": "Generate a hiring plan", "product": "orchadyn", "artifact": "plan-req-0001"},
    {"index": 7, "title": "Record selection and offer, then issue the offer", "product": "recruitment-domain", "artifact": "offer-rec-offer-v1"},
    {"index": 8, "title": "Confirm the outcome", "product": "recruitment-domain", "artifact": "close-req-0001"}
  ],
  "requisition_state": {
    "id": "req-0001", "role": "Senior Platform Engineer", "location": "Remote",
    "hiring_manager": "hiring-manager-1", "ta_lead": "ta-lead-1", "status": "closed",
    "criteria": ["platform-expertise", "systems-ownership"],
    "candidates": ["cand-a", "cand-b", "cand-c"],
    "decisions": [
      {"stage": "shortlist", "decision": "advance", "candidate": "cand-a", "decided_by": "panel-1", "actor_type": "human"},
      {"stage": "selection", "decision": "select", "candidate": "cand-a", "decided_by": "hiring-manager-1", "actor_type": "human"},
      {"stage": "offer", "decision": "offer", "candidate": "cand-a", "decided_by": "hiring-manager-1", "actor_type": "human"}
    ],
    "offer": {"id": "offer-rec-offer-v1", "candidate": "cand-a", "offered_by": "ta-lead-1", "status": "issued"}
  }
}
```

### `recruitment-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 9, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8094/healthz` | Adapter build failed or port busy | Check `.local-logs\recruitment-domain.err.log`; confirm `go` on PATH. |
| `403 automation_cannot_make_hiring_decisions` | Automated actor tried to decide | This is the *expected* denial; use human `actor_type`. |
| `409 <stage>_required_first` | Decision out of lifecycle order | Follow validate → shortlist → selection → offer. |
| `403 only_ta_lead_can_validate` | Non-TA-lead validation | Validate with `ta-lead-1`. |
| `403 no_offer_decision_for_candidate` | Offer without offer-stage decision | Record the offer decision for the candidate first. |
