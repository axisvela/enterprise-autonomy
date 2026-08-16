# Process-Domain Adapter — API Reference

Local reference service for simulated durable process views. Not a production workflow engine.

Base URL: `http://localhost:8100` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"process-domain-adapter"}
```

### `GET /v1/processes/{id}`

Seeded `proc-0001`:

```json
{"id":"proc-0001","workflow":"onboarding","stages":["request","review","approve","complete"],
 "current_stage":"request","status":"initiated","advances":[]}
```

Errors: `404 process_not_found`.

### `POST /v1/processes/{id}/advance`

Advances to the exact next stage. Requires `from_stage`, `to_stage`, `decided_by`, `rationale`, `decision_ref`, `idempotency_key`.

```json
{"from_stage":"request","to_stage":"review","decided_by":"ops-lead","rationale":"submitted",
 "decision_ref":"decision://proc-0001","idempotency_key":"p-request-v1"}
```

The process reaches `awaiting-outcome` at the terminal stage.

Errors: `400` missing fields, `409 process_already_completed`, `409 stage_mismatch_current_is_<stage>`, `409 stage_mismatch_next_is_<stage>`.

### `POST /v1/processes/{id}/complete`

Completes the outcome. Requires `completed_by`, `idempotency_key`.

```json
{"completed_by":"ops-lead","idempotency_key":"p-comp-v1"}
```

`process.status` → `completed`. Gated on the terminal stage and at least one recorded advance.

Errors: `400` missing fields, `409 process_already_completed`, `403 outcome_not_reached_terminal_stage_required`, `403 no_stage_advances_recorded`.

### `GET /v1/notifications/{id}`

```json
{"process_id":"proc-0001","notifications":["process-outcome-notification-pending:proc-0001"]}
```

Errors: `404 process_not_found`.

## State Machine

```
initiated -> (request -> review -> approve -> complete) -> completed
```

`advance` moves strictly along the defined stage order; the outcome completes only at the terminal stage; a completed process is immutable.

**Governance pattern:** durable process lifecycle integrity (stage-sequenced gating, terminal-state enforcement, completed-process immutability); see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
