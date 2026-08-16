# Simulation Validation Demo — Detailed Operations Guide

Step-by-step walkthrough of the simulation-to-validation demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: reviewer `reviewer-a`, simulation engineer `simulation-engineer`, proposal `proposal-sim-0001`, decision reference `decision://sim-0001`, evidence reference `evidence://sim/run-001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Simulation-domain adapter | `http://localhost:8097` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Proposal** (`proposal-sim-0001`): capability `automated-zone-inspection`, scope `zone-alpha`, status `proposed`, review group `reviewer-a`, `reviewer-b`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the review case (Symbivela)

**Purpose.** Create the human authority that governs validation and release.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: reviewer-a,
         Idempotency-Key: validation-review-workspace-v1
Body:
{"workspace_id":"validation-review","name":"Validation Review","owner_id":"reviewer-a"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: reviewer-a,
         Idempotency-Key: sim-0001-case-v1
Body:
{"workspace_id":"validation-review","case_id":"sim-0001-validation","subject_ref":"proposal://proposal-sim-0001",
 "problem":"Automated zone inspection must be validated by simulation evidence before release.",
 "evidence_refs":"scope://zone-alpha",
 "candidate_actions":"approve,reject,revise","deadline":"2026-08-29T12:00:00Z"}
```

**What to notice.** The case frames release as evidence-gated.

## Step 2 — Compile the simulation scenarios (adapter + Ontovela)

**Purpose.** Compile the scenario set and assert the validation scope.

**Request 2a — compile scenario.**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/scenarios
Body:
{"scenario_id":"scn-collision","description":"collision avoidance in zone-alpha","idempotency_key":"sim-scn-v1"}
```
Response: `scenario.id` (`scn-collision`).

**Request 2b — scope assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: sim-0001-scope-v1
Body:
{"id":"assertion-proposal-sim-0001-scoped","subject_id":"proposal-sim-0001","property":"validation_scope",
 "value":"zone-alpha","state_kind":"observed","event_time":"2026-08-16T13:00:00Z",
 "system_time":"2026-08-16T13:00:01Z","source":"validation-system",
 "evidence_ref":"evidence://validation/proposal-sim-0001"}
```

**What to notice.** The scope is asserted with evidence before any run; validation is scoped to `zone-alpha`.

## Step 3 — Show evidence is required before a decision

**Purpose.** Prove evidence-before-decision is structural.

**Request — decision before evidence (expect rejection).**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/decisions
Body:
{"decision":"approve","decided_by":"reviewer-a","rationale":"premature",
 "decision_ref":"decision://sim-0001","idempotency_key":"sim-dec-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"simulation_evidence_required_before_decision"}`.

**What to notice.** No decision exists until simulation evidence is recorded — the review cannot precede the run.

## Step 4 — Record the immutable simulation run

**Purpose.** Record evidence that cannot be replaced.

**Request 4a — record the run.**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/runs
Body:
{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://sim/run-001",
 "recorded_by":"simulation-engineer","idempotency_key":"sim-run-v1"}
```
Response: `run.id` (`run-run-001`), `run.immutable` (`true`), `proposal.status` (`evidence`).

**Request 4b — second run (expect rejection).**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/runs
Body:
{"run_id":"run-002","outcome":"fail","evidence_ref":"evidence://sim/run-002",
 "recorded_by":"simulation-engineer","idempotency_key":"sim-run2-v1"}
```
The adapter responds `409 Conflict` with `{"error":"evidence_already_recorded_immutable"}`.

**What to notice.** Simulation evidence is **immutable**: once recorded, it cannot be replaced or supplemented with a different run.

## Step 5 — Record the review decision (review group)

**Purpose.** Prove review-group authority, then record the approve decision.

**Request 5a — non-member decision (expect rejection).**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/decisions
Body:
{"decision":"approve","decided_by":"outsider","rationale":"x",
 "decision_ref":"decision://sim-0001","idempotency_key":"sim-dec-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"not_review_group_member"}`.

**Request 5b — reviewer decision.**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/decisions
Body:
{"decision":"approve","decided_by":"reviewer-a","rationale":"simulation evidence passes",
 "decision_ref":"decision://sim-0001","idempotency_key":"sim-dec-v1"}
```
Response: `decision.decision` (`approve`), `proposal.status` (`decided`).

**What to notice.** Only designated review-group members may decide, and the decision is grounded in the recorded evidence.

## Step 6 — Create the durable validation process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `simulation-validation-workflow.json`.** Stages: `compile (simulation-engineer) → run (capability simulation.run.execute) → decide (review-group) → release (capability simulation.release.execute) → close (review-group)`.

**CLI — validate and define.**
```powershell
rheo workflow validate simulation-validation-workflow.json
rheo workflow define --file simulation-validation-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"simulation-to-validation","project":"proposal-sim-0001","actor":"reviewer-a"}
```

**What to notice.** The `run` and `release` stages are capability-gated; the workflow mirrors the evidence → decide → release ordering.

## Step 7 — Generate a validation plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `simulation-validation-plan.json`.** Goal `goal-sim-0001-validated`; catalog `cap-review` with `evidenceRequired: true` and `humanOnly: true`; hard constraints for evidence-before-decision and evidence-immutability.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of simulation-validation-plan.json)
```

**What to notice.** The plan encodes the evidence requirement, so even the recommendation respects evidence-before-decision.

## Step 8 — Release and emit the value report

**Purpose.** Release only after the approve decision citing the exact reference.

**Request 8a — wrong reference (expect rejection).**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/release
Body:
{"released_by":"reviewer-a","decision_ref":"decision://wrong","idempotency_key":"sim-rel-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"decision_ref_mismatch"}`.

**Request 8b — release.**
```
POST http://localhost:8097/v1/proposals/proposal-sim-0001/release
Body:
{"released_by":"reviewer-a","decision_ref":"decision://sim-0001","idempotency_key":"sim-rel-v1"}
```
Response: `proposal.status` (`released`).

**Outputs written to `.local-data/`:** `simulation-outcome.json` and `simulation-value-report.json`.

**What to notice.** Release is approval-gated and references the exact decision — the four denial records make the evidence-gated model measurable.

## Output Artifacts

### `simulation-outcome.json`

```json
{
  "proposal_id": "proposal-sim-0001",
  "tenant": "tenant-a",
  "reviewer": "reviewer-a",
  "steps": [
    {"index": 1, "title": "Open the review case", "product": "symbivela", "artifact": "sim-0001-validation"},
    {"index": 2, "title": "Compile the simulation scenarios", "product": "simulation-domain", "artifact": "scn-collision"},
    {"index": 3, "title": "Show evidence is required before a decision", "product": "simulation-domain", "artifact": "decision-without-evidence-rejected"},
    {"index": 4, "title": "Record the immutable simulation run", "product": "simulation-domain", "artifact": "run-run-001"},
    {"index": 5, "title": "Record the review decision", "product": "simulation-domain", "artifact": "decision-sim-dec-v1"},
    {"index": 6, "title": "Create the durable validation process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a validation plan", "product": "orchadyn", "artifact": "plan-sim-0001"},
    {"index": 8, "title": "Release after approval", "product": "simulation-domain", "artifact": "release-sim-0001"}
  ],
  "proposal_state": {
    "id": "proposal-sim-0001", "capability": "automated-zone-inspection", "scope": "zone-alpha",
    "status": "released",
    "review_group": ["reviewer-a", "reviewer-b"],
    "scenarios": [{"id": "scn-collision", "description": "collision avoidance in zone-alpha"}],
    "runs": [{"id": "run-run-001", "outcome": "pass", "evidence_ref": "evidence://sim/run-001", "immutable": true}],
    "decision": {"id": "decision-sim-dec-v1", "decision": "approve", "decided_by": "reviewer-a", "decision_ref": "decision://sim-0001"}
  }
}
```

### `simulation-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 12, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8097/healthz` | Adapter build failed or port busy | Check `.local-logs\simulation-domain.err.log`; confirm `go` on PATH. |
| `403 simulation_evidence_required_before_decision` | Decision before evidence | Record the simulation run first. |
| `409 evidence_already_recorded_immutable` | Second simulation run | This is the *expected* denial; evidence is immutable. |
| `403 not_review_group_member` | Non-member decision | Decide with a designated reviewer. |
| `403 release_requires_approval` / `decision_ref_mismatch` | Release without approve/right ref | Release only after the approve decision citing the exact reference. |
