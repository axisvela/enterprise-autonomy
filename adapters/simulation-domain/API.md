# Simulation-Domain Adapter — API Reference

Local reference service for simulated possible-world validation. Not a production simulation platform.

Base URL: `http://localhost:8097` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"simulation-domain-adapter"}
```

### `GET /v1/proposals/{id}`

Seeded `proposal-sim-0001`:

```json
{"id":"proposal-sim-0001","capability":"automated-zone-inspection","scope":"zone-alpha",
 "status":"proposed","review_group":["reviewer-a","reviewer-b"],"scenarios":[],"runs":[]}
```

Errors: `404 proposal_not_found`.

### `POST /v1/proposals/{id}/scenarios`

Compiles a simulation scenario. Requires `scenario_id`, `description`, `idempotency_key`.

```json
{"scenario_id":"scn-collision","description":"collision avoidance in zone-alpha","idempotency_key":"sim-scn-v1"}
```

Errors: `400` missing fields, `409 proposal_not_proposed`.

### `POST /v1/proposals/{id}/runs`

Records immutable simulation evidence. Requires `run_id`, `outcome` (`pass`/`fail`/`inconclusive`), `evidence_ref`, `recorded_by`, `idempotency_key`.

```json
{"run_id":"run-001","outcome":"pass","evidence_ref":"evidence://sim/run-001",
 "recorded_by":"simulation-engineer","idempotency_key":"sim-run-v1"}
```

`proposal.status` → `evidence`; the run is `immutable: true`.

Errors: `400` missing/invalid outcome, `409 evidence_already_recorded_immutable`.

### `POST /v1/proposals/{id}/decisions`

Review group records the decision. Requires `decision` (`approve`/`reject`/`revise`), `decided_by`, `rationale`, `decision_ref`, `idempotency_key`.

```json
{"decision":"approve","decided_by":"reviewer-a","rationale":"evidence passes",
 "decision_ref":"decision://sim-0001","idempotency_key":"sim-dec-v1"}
```

`proposal.status` → `decided`. Gated on recorded evidence and review-group membership.

Errors: `400` missing/invalid fields, `403 simulation_evidence_required_before_decision`, `403 not_review_group_member`.

### `POST /v1/proposals/{id}/release`

Releases the proposal. Requires `released_by`, `decision_ref`, `idempotency_key`.

```json
{"released_by":"reviewer-a","decision_ref":"decision://sim-0001","idempotency_key":"sim-rel-v1"}
```

`proposal.status` → `released`. Gated on an `approve` decision citing the exact `decision_ref`.

Errors: `400` missing fields, `403 release_requires_approval`, `403 decision_ref_mismatch`.

### `GET /v1/runs/{id}`

```json
{"id":"run-run-001","outcome":"pass","evidence_ref":"evidence://sim/run-001","recorded_by":"simulation-engineer","immutable":true}
```

Errors: `404 run_not_found`.

### `GET /v1/notifications/{id}`

```json
{"proposal_id":"proposal-sim-0001","notifications":["release-notification-pending:proposal-sim-0001"]}
```

Errors: `404 proposal_not_found`.

## State Machine

```
proposed -> evidence -> decided -> released
```

`scenarios` applies while `proposed`; the first recorded run moves to `evidence`; the review decision moves to `decided`; an `approve` decision moves to `released`.

## Validation Integrity Model

- **Evidence-before-decision.** No decision without recorded simulation evidence.
- **Immutable evidence.** One immutable run per proposal; re-recording is rejected.
- **Review-group authority.** Only designated members decide.
- **Approval-gated release.** Release requires an approve decision citing the exact reference.

**Governance pattern:** evidence-gated release and immutable simulation; see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
