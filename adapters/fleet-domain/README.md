# Fleet-Domain Reference Adapter

This local reference service adapts simulated physical-mission views for runnable examples. It is not a production robotics fleet control plane.

## Build And Start

```powershell
go build -o fleet-domain-adapter.exe .
.\fleet-domain-adapter.exe --addr :8099 --data-file .\fleet-domain-data.json
```

`GET http://localhost:8099/healthz` returns `{"status":"ok","service":"fleet-domain-adapter"}`.

## Seeded State

- Mission `mission-alpha-001`: zone `zone-alpha`, objective `inspect racks`, status `planned`, operator `ops-lead`, boundary `["zone-alpha"]`.

## Governance Model

- **Autonomous boundary enforcement.** Telemetry outside the mission boundary is rejected and the mission is frozen (`403 boundary_deviation_mission_frozen`) — no human needed, the boundary is hard.
- **Pause-and-review.** An exception pauses the mission; a review decision is required before resume/adjust/cancel (`403 operator_review_required_mission_must_be_paused`).
- **Operator-gated review.** Only the mission operator may review (`403 not_mission_operator`), and the decision carries an `approval_ref`.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/missions/{id}` | Mission with boundary, exception, review, and action history. |
| `POST /v1/missions/{id}/start` | Starts the mission (operator-gated). |
| `POST /v1/missions/{id}/telemetry` | Records position; out-of-boundary is frozen. |
| `POST /v1/missions/{id}/exceptions` | Raises an exception and pauses the mission. |
| `POST /v1/missions/{id}/reviews` | Operator reviews (resume/adjust/cancel) with an approval reference. |
| `POST /v1/missions/{id}/complete` | Completes an active mission. |
| `GET /v1/notifications/{id}` | Pending operator-review and completion notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
