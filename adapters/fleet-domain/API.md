# Fleet-Domain Adapter â€?API Reference

Local reference service for simulated physical-mission views. Not a production fleet control plane.

Base URL: `http://localhost:8099` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"fleet-domain-adapter"}
```

### `GET /v1/missions/{id}`

Seeded `mission-alpha-001`:

```json
{"id":"mission-alpha-001","zone":"zone-alpha","objective":"inspect racks","status":"planned",
 "operator":"ops-lead","boundary":["zone-alpha"],"actions":[]}
```

Errors: `404 mission_not_found`.

### `POST /v1/missions/{id}/start`

Starts the mission. Requires `started_by` (the operator), `idempotency_key`.

```json
{"started_by":"ops-lead","idempotency_key":"fleet-start-v1"}
```

`mission.status` â†?`running`, position set to the mission zone.

Errors: `400` missing fields, `403 not_mission_operator`, `409 mission_not_planned`.

### `POST /v1/missions/{id}/telemetry`

Records position. Requires `position`, `status`, `idempotency_key`. If `position` is outside the boundary the adapter rejects with `403 boundary_deviation_mission_frozen`; if `status` is `exception` the mission pauses.

```json
{"position":"zone-alpha","status":"running","idempotency_key":"fleet-tl2-v1"}
```

Errors: `400` missing fields, `409 mission_not_active`, `403 boundary_deviation_mission_frozen`.

### `POST /v1/missions/{id}/exceptions`

Raises an exception and pauses the mission. Requires `type`, `detail`, `raised_by`, `idempotency_key`.

```json
{"type":"obstacle","detail":"rack-07 blocked","raised_by":"fleet-runtime","idempotency_key":"fleet-ex-v1"}
```

`mission.status` â†?`paused`. Errors: `400` missing fields, `409 mission_not_active`.

### `POST /v1/missions/{id}/reviews`

Operator reviews a paused mission. Requires `reviewed_by`, `decision` (`resume`/`adjust`/`cancel`), `approval_ref`, `idempotency_key`.

```json
{"reviewed_by":"ops-lead","decision":"resume","approval_ref":"approval://mission-alpha-001","idempotency_key":"fleet-rv-v1"}
```

`mission.status` â†?`resumed` (resume/adjust) or `cancelled`. Gated on a paused mission and the mission operator.

Errors: `400` missing/invalid fields, `403 operator_review_required_mission_must_be_paused`, `403 not_mission_operator`, `409 no_exception_to_review`.

### `POST /v1/missions/{id}/complete`

Completes an active mission. Requires `completed_by`, `idempotency_key`.

```json
{"completed_by":"ops-lead","idempotency_key":"fleet-cmp-v1"}
```

`mission.status` â†?`completed`. Errors: `400` missing fields, `403 mission_not_active`.

### `GET /v1/notifications/{id}`

```json
{"mission_id":"mission-alpha-001","notifications":["operator-review-pending:exception-fleet-ex-v1","mission-complete-notification-pending:mission-alpha-001"]}
```

Errors: `404 mission_not_found`.

## State Machine

```
planned -> running -> paused -> resumed -> completed
                        \-> cancelled
```

`start` moves `planned â†?running`; an exception or exception-status telemetry moves to `paused`; an operator review resumes/adjusts/cancels; `complete` requires an active mission.

## Fleet Governance Model

- **Autonomous boundary enforcement.** Out-of-boundary telemetry is frozen without human involvement.
- **Pause-and-review.** Exceptions always pause; only an operator review (with approval reference) resumes.
- **Operator-gated.** Only the mission operator may start or review.

**Governance pattern:** [Autonomous boundary and pause-and-review](../../docs/governance-patterns.md#15-autonomous-boundary-pause-and-review) from the [governance patterns catalog](../../docs/governance-patterns.md).
