# Innovation Sandbox Demo — Detailed Operations Guide

Step-by-step walkthrough of the innovation-sandbox-to-policy demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: reviewer `reviewer-a`, sandbox engineer `sandbox-engineer`, proposal `proposal-sandbox-0001`, sandbox scope `report-generation-scope`, policy reference `policy://sand-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Sandbox-domain adapter | `http://localhost:8101` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Proposal** (`proposal-sandbox-0001`): capability `batch-report-generation`, sandbox scope `report-generation-scope`, status `proposed`, review group `reviewer-a`, `reviewer-b`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the sandbox case (Symbivela)

**Purpose.** Create the human authority that governs exploration and policy.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: reviewer-a,
         Idempotency-Key: innovation-sandbox-workspace-v1
Body:
{"workspace_id":"innovation-sandbox","name":"Innovation Sandbox","owner_id":"reviewer-a"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: reviewer-a,
         Idempotency-Key: sand-0001-case-v1
Body:
{"workspace_id":"innovation-sandbox","case_id":"sand-0001-policy","subject_ref":"proposal://proposal-sandbox-0001",
 "problem":"Explore batch-report-generation inside its sandbox and record an evidence-based policy decision.",
 "evidence_refs":"scope://report-generation-scope",
 "candidate_actions":"release,restrict,reject","deadline":"2026-09-03T12:00:00Z"}
```

**What to notice.** The case frames exploration as sandbox-bounded and policy as evidence-based.

## Step 2 — Record the sandbox context (adapter + Ontovela)

**Purpose.** Assert the sandbox scope with evidence.

**Request 2a — proposal view.**
```
GET http://localhost:8101/v1/proposals/proposal-sandbox-0001
```
Response: `{"id":"proposal-sandbox-0001","capability":"batch-report-generation","sandbox_scope":"report-generation-scope","status":"proposed","review_group":["reviewer-a","reviewer-b"],"experiments":[]}`.

**Request 2b — scope assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: sand-0001-scope-v1
Body:
{"id":"assertion-sand-0001-scoped","subject_id":"proposal-sandbox-0001","property":"sandbox_scope",
 "value":"report-generation-scope","state_kind":"observed","event_time":"2026-08-16T19:00:00Z",
 "system_time":"2026-08-16T19:00:01Z","source":"innovation-control","evidence_ref":"evidence://sandbox/proposal-sandbox-0001"}
```

**What to notice.** The sandbox scope is an evidence-bearing fact; experiments are confined to it.

## Step 3 — Show the sandbox boundary

**Purpose.** Prove sandbox confinement is structural.

**Request — out-of-scope experiment (expect rejection).**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/experiments
Body:
{"experiment_id":"exp-out","scope":"outside-scope","outcome":"pass","evidence_ref":"evidence://sand/exp-out",
 "recorded_by":"sandbox-engineer","idempotency_key":"s-exp-out"}
```
The adapter responds `403 Forbidden` with `{"error":"sandbox_boundary_experiment_outside_scope"}`.

**What to notice.** Experiments cannot escape the sandbox scope — confinement is structural, not procedural.

## Step 4 — Show policy needs experiment evidence

**Purpose.** Prove evidence-based policy.

**Request — decision before evidence (expect rejection).**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/decisions
Body:
{"decision":"release","decided_by":"reviewer-a","rationale":"premature","policy_ref":"policy://sand-0001",
 "idempotency_key":"s-dec"}
```
The adapter responds `403 Forbidden` with `{"error":"experiment_evidence_required_before_policy"}`.

**What to notice.** A policy decision cannot precede sandbox evidence.

## Step 5 — Record the sandbox experiment

**Purpose.** Record evidence inside the sandbox.

**Request.**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/experiments
Body:
{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"pass",
 "evidence_ref":"evidence://sand/exp-001","recorded_by":"sandbox-engineer","idempotency_key":"s-exp1"}
```
Response: `experiment.id` (`experiment-exp-001`), `proposal.status` (`experimenting`).

**What to notice.** The experiment is recorded with evidence inside the sandbox scope.

## Step 6 — Create the durable sandbox process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `innovation-sandbox-workflow.json`.** Stages: `explore (capability sandbox.experiment.execute) → decide (review-group) → apply (capability sandbox.apply.execute) → close (review-group)`.

**CLI — validate and define.**
```powershell
rheo workflow validate innovation-sandbox-workflow.json
rheo workflow define --file innovation-sandbox-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"innovation-sandbox-to-policy","project":"proposal-sandbox-0001","actor":"reviewer-a"}
```

**What to notice.** The `explore` and `apply` stages are capability-gated; the workflow mirrors explore → decide → apply.

## Step 7 — Generate a sandbox plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `innovation-sandbox-plan.json`.** Catalog `cap-experiment` with `boundaryRequired: true`; `cap-decide` with `evidenceRequired`, `reviewerOnly`, and `immutable`; hard sandbox-boundary, evidence-based-policy, and policy-immutable constraints.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of innovation-sandbox-plan.json)
```

**What to notice.** The plan encodes the sandbox boundary and evidence requirement.

## Step 8 — Decide and apply the policy; show immutability

**Purpose.** Record the policy decision, apply it, and prove the decision is immutable.

**Request 8a — non-reviewer decision (expect rejection).**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/decisions
Body:
{"decision":"release","decided_by":"outsider","rationale":"x","policy_ref":"policy://sand-0001","idempotency_key":"s-dec"}
```
The adapter responds `403 Forbidden` with `{"error":"not_designated_reviewer"}`.

**Request 8b — policy decision.**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/decisions
Body:
{"decision":"release","decided_by":"reviewer-a","rationale":"sandbox evidence passes",
 "policy_ref":"policy://sand-0001","idempotency_key":"s-dec"}
```
Response: `decision.decision` (`release`), `proposal.status` (`decided`).

**Request 8c — second decision (expect rejection).**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/decisions
Body:
{"decision":"restrict","decided_by":"reviewer-a","rationale":"change","policy_ref":"policy://sand-0001","idempotency_key":"s-dec2"}
```
The adapter responds `409 Conflict` with `{"error":"policy_already_recorded_immutable"}`.

**Request 8d — apply.**
```
POST http://localhost:8101/v1/proposals/proposal-sandbox-0001/apply
Body:
{"applied_by":"reviewer-a","policy_ref":"policy://sand-0001","idempotency_key":"s-ap"}
```
Response: `proposal.status` (`released`), `proposal.applied` (`true`).

**Outputs written to `.local-data/`:** `sandbox-outcome.json` and `sandbox-value-report.json`.

**What to notice.** The policy decision is immutable; the four denial records make the sandbox-to-policy governance measurable.

## Output Artifacts

### `sandbox-outcome.json`

```json
{
  "proposal_id": "proposal-sandbox-0001",
  "tenant": "tenant-a",
  "reviewer": "reviewer-a",
  "steps": [
    {"index": 1, "title": "Open the sandbox case", "product": "symbivela", "artifact": "sand-0001-policy"},
    {"index": 2, "title": "Record the sandbox context", "product": "ontovela", "artifact": "assertion-sand-0001-scoped"},
    {"index": 3, "title": "Show the sandbox boundary", "product": "sandbox-domain", "artifact": "sandbox-boundary-rejected"},
    {"index": 4, "title": "Show policy needs experiment evidence", "product": "sandbox-domain", "artifact": "decision-without-evidence-rejected"},
    {"index": 5, "title": "Record the sandbox experiment", "product": "sandbox-domain", "artifact": "experiment-exp-001"},
    {"index": 6, "title": "Create the durable sandbox process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a sandbox plan", "product": "orchadyn", "artifact": "plan-sand-0001"},
    {"index": 8, "title": "Decide and apply the policy", "product": "sandbox-domain", "artifact": "apply-s-ap"}
  ],
  "proposal_state": {
    "id": "proposal-sandbox-0001", "capability": "batch-report-generation",
    "sandbox_scope": "report-generation-scope", "status": "released",
    "review_group": ["reviewer-a", "reviewer-b"],
    "experiments": [{"id": "experiment-exp-001", "scope": "report-generation-scope", "outcome": "pass", "evidence_ref": "evidence://sand/exp-001"}],
    "decision": {"id": "policy-s-dec", "decision": "release", "decided_by": "reviewer-a", "policy_ref": "policy://sand-0001"},
    "applied": true
  }
}
```

### `sandbox-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 11, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8101/healthz` | Adapter build failed or port busy | Check `.local-logs\sandbox-domain.err.log`; confirm `go` on PATH. |
| `403 sandbox_boundary_experiment_outside_scope` | Experiment outside sandbox | Explore only inside `report-generation-scope`. |
| `403 experiment_evidence_required_before_policy` | Decision before evidence | Record a sandbox experiment first. |
| `403 not_designated_reviewer` | Non-reviewer decision | Decide with a review-group member. |
| `409 policy_already_recorded_immutable` | Second policy decision | This is the *expected* denial; the policy decision is immutable. |
