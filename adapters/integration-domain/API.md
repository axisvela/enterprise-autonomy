# Integration-Domain Adapter — API Reference

Local reference service for simulated integration-outage recovery. Not a production integration gateway.

Base URL: `http://localhost:8096` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"integration-domain-adapter"}
```

### `GET /v1/integrations/{id}`

Seeded `partner-shipping`:

```json
{"id":"partner-shipping","status":"down","last_seen":"2026-08-16T09:58:00Z","outage_since":"2026-08-16T10:00:00Z","actions":[]}
```

Errors: `404 integration_not_found`.

### `GET /v1/work/{id}`

Seeded `work-0001`:

```json
{"id":"work-0001","affects":"order-123","status":"inflight","actions":[]}
```

Errors: `404 work_not_found`.

### `POST /v1/work/{id}/preserve`

Preserves in-flight work. Requires `preserved_by`, `preserved_ref`, `idempotency_key`.

```json
{"preserved_by":"integration-owner","preserved_ref":"process://work-0001","idempotency_key":"int-pres-v1"}
```

`work.status` → `preserved`. Errors: `400` missing fields, `409 work_not_inflight`.

### `POST /v1/integrations/{id}/checks`

Integration owner records a reconnection check. Requires `checked_by`, `verified`, `evidence_ref`, `idempotency_key`.

```json
{"checked_by":"integration-owner","verified":true,"evidence_ref":"evidence://reconnect/partner-shipping","idempotency_key":"int-check-v1"}
```

`integration.status` → `checked` when verified. Errors: `400` missing fields, `403 only_integration_owner_can_check`.

### `POST /v1/work/{id}/resume`

Resumes work. Requires `resumed_by`, `idempotency_key`.

```json
{"resumed_by":"integration-owner","idempotency_key":"int-resume-v1"}
```

`work.status` → `resumed`. Gated on: preserved work **and** a verified integration.

Errors: `400` missing fields, `403 work_not_preserved`, `403 integration_not_verified`.

### `POST /v1/work/{id}/complete`

Completes work. Requires `completed_by`, `idempotency_key`.

```json
{"completed_by":"integration-owner","idempotency_key":"int-comp-v1"}
```

`work.status` → `completed`. Errors: `400` missing fields, `403 work_not_resumed`, `409 action_already_completed_no_silent_rerun`.

### `GET /v1/notifications/{id}`

```json
{"work_id":"work-0001","notifications":["outage-recovery-notification-pending:work-0001"]}
```

Errors: `404 work_not_found`.

## State Machine

```
integration: down -> checked
work:         inflight -> preserved -> resumed -> completed
```

`preserve` moves work to `preserved`; a verified integration check moves the integration to `checked`; `resume` requires preserved **and** checked; `complete` requires resumed. A second, different-idempotency `complete` is rejected — no silent re-execution.

## Recovery Integrity Model

- **Preserve-before-resume.** In-flight work must have a durable preservation reference before it can resume.
- **Verify-before-resume.** Resumption requires an integration-owner reconnection check that verified the integration.
- **No-silent-rerun.** Completed actions cannot be re-executed; only idempotent replays are permitted.

**Governance pattern:** recovery integrity (preserve, verify, never rerun); see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
