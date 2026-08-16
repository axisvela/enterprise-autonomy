# Integration-Domain Reference Adapter

This local reference service adapts simulated integration-outage recovery views for runnable examples. It is not a production integration gateway or queue.

## Build And Start

```powershell
go build -o integration-domain-adapter.exe .
.\integration-domain-adapter.exe --addr :8096 --data-file .\integration-domain-data.json
```

`GET http://localhost:8096/healthz` returns `{"status":"ok","service":"integration-domain-adapter"}`.

## Seeded State

- Integration `partner-shipping`: status `down`, outage since `2026-08-16T10:00:00Z`.
- In-flight work `work-0001`: affects `order-123`, status `inflight`.

## Governance Model

- **Preserve before resume.** In-flight work must be preserved (durable reference) before it can resume (`403 work_not_preserved`).
- **Verify before resume.** Work can only resume after the integration's reconnection is verified by the integration owner (`403 integration_not_verified`).
- **No silent re-execution.** A completed action can never be re-executed (`409 action_already_completed_no_silent_rerun`); only the same idempotency key replays.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/integrations/{id}` | Integration state and last reconnection check. |
| `GET /v1/work/{id}` | In-flight work state. |
| `POST /v1/work/{id}/preserve` | Preserves in-flight work with a durable reference. |
| `POST /v1/integrations/{id}/checks` | Integration owner records a reconnection verification. |
| `POST /v1/work/{id}/resume` | Resumes work once preserved and verified. |
| `POST /v1/work/{id}/complete` | Completes work; re-execution is rejected. |
| `GET /v1/notifications/{id}` | Pending recovery notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
