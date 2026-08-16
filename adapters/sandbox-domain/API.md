# Sandbox-Domain Adapter — API Reference

Local reference service for simulated innovation-sandbox views. Not a production policy platform.

Base URL: `http://localhost:8101` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"sandbox-domain-adapter"}
```

### `GET /v1/proposals/{id}`

Seeded `proposal-sandbox-0001`:

```json
{"id":"proposal-sandbox-0001","capability":"batch-report-generation","sandbox_scope":"report-generation-scope",
 "status":"proposed","review_group":["reviewer-a","reviewer-b"],"experiments":[]}
```

Errors: `404 proposal_not_found`.

### `POST /v1/proposals/{id}/experiments`

Records a sandbox experiment. Requires `experiment_id`, `scope`, `outcome` (`pass`/`fail`/`inconclusive`), `evidence_ref`, `recorded_by`, `idempotency_key`.

```json
{"experiment_id":"exp-001","scope":"report-generation-scope","outcome":"pass",
 "evidence_ref":"evidence://sand/exp-001","recorded_by":"sandbox-engineer","idempotency_key":"s-exp1"}
```

`proposal.status` → `experimenting`. Errors: `400` missing/invalid fields, `403 sandbox_boundary_experiment_outside_scope`, `409 proposal_not_explorable`.

### `POST /v1/proposals/{id}/decisions`

Review group records a policy decision. Requires `decision` (`release`/`restrict`/`reject`), `decided_by`, `rationale`, `policy_ref`, `idempotency_key`.

```json
{"decision":"release","decided_by":"reviewer-a","rationale":"evidence passes",
 "policy_ref":"policy://sand-0001","idempotency_key":"s-dec"}
```

`proposal.status` → `decided`. Gated on evidence and review-group membership; the decision is immutable.

Errors: `400` missing/invalid fields, `403 experiment_evidence_required_before_policy`, `403 not_designated_reviewer`, `409 policy_already_recorded_immutable`.

### `POST /v1/proposals/{id}/apply`

Applies the policy decision. Requires `applied_by`, `policy_ref`, `idempotency_key`.

```json
{"applied_by":"reviewer-a","policy_ref":"policy://sand-0001","idempotency_key":"s-ap"}
```

`proposal.status` → `released` (release) or `restricted`; `applied = true`. Errors: `400` missing fields, `403 policy_decision_required_before_apply`, `403 policy_ref_mismatch`, `409 rejected_proposal_cannot_be_applied`.

### `GET /v1/notifications/{id}`

```json
{"proposal_id":"proposal-sandbox-0001","notifications":["policy-apply-notification-pending:proposal-sandbox-0001"]}
```

Errors: `404 proposal_not_found`.

## State Machine

```
proposed -> experimenting -> decided -> released | restricted
```

The first experiment moves to `experimenting`; the policy decision moves to `decided` and is immutable; `apply` releases or restricts the capability.

**Governance patterns:** sandbox boundary, evidence-based policy, designated reviewer, immutable policy; see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
