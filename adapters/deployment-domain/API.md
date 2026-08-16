# Deployment-Domain Adapter — API Reference

Local reference service for simulated sequenced-autonomy views. Not a production release platform.

Base URL: `http://localhost:8102` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"deployment-domain-adapter"}
```

### `GET /v1/deployments/{id}`

Seeded `dep-0001`:

```json
{"id":"dep-0001","workflow":"release-pipeline","steps":["checkout","build","test","approve","production"],
 "current_step":"checkout","status":"initiated","steps_run":[],"deviations":[]}
```

Errors: `404 deployment_not_found`.

### `POST /v1/deployments/{id}/steps`

Executes the next step of the sequence autonomously. Requires `step`, `executed_by`, `evidence_ref`, `idempotency_key`.

```json
{"step":"checkout","executed_by":"release-automation","evidence_ref":"evidence://dep/checkout",
 "idempotency_key":"d-checkout-v1"}
```

`deployment.status` → `in-flight` (or `released` at the terminal step). Steps must be executed strictly in order and cite evidence.

Errors:
- `400` missing fields
- `409 step_out_of_sequence_next_is_<step>` (out-of-order execution)
- `409 step_already_executed_immutable` (re-executing a completed step)
- `409 deployment_already_released_immutable` (steps on a released deployment)
- `403 deployment_paused_deviation_review_required` (steps while paused)

### `POST /v1/deployments/{id}/deviations`

Records a human-approved deviation from the sequence. Requires `action` (`pause`/`skip`/`rollback`), `idempotency_key`, and for any non-trivial action `approved_by` and `approval_ref`. `skip` additionally requires `to_step`.

```json
{"action":"pause","approved_by":"release-lead","approval_ref":"approval://dep/pause",
 "idempotency_key":"d-pause-v1"}
```

- `pause` → status `paused`
- `skip` → advances to `to_step` (status `in-flight` or `released` at terminal)
- `rollback` → status `rolled-back`

Errors: `400` missing fields, `403 deviation_requires_human_approval` (no approval), `400 to_step_required_for_skip`, `409 deployment_already_released_immutable`.

### `GET /v1/notifications/{id}`

```json
{"deployment_id":"dep-0001","notifications":["release-notification-pending:dep-0001"]}
```

Errors: `404 deployment_not_found`.

## State Machine

```
initiated -> (checkout -> build -> test -> approve -> production) -> released
         \-> paused (approved deviation)
         \-> rolled-back (approved deviation)
```

`steps` advances strictly along the declared order and requires evidence; a completed step is immutable; a deviation requires human approval; a released deployment is immutable.

**Governance pattern:** sequenced autonomous execution (in-order gating, evidence-cited steps, step immutability, approval-required deviations, released-immutability); see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
