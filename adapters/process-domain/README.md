# Process-Domain Reference Adapter

This local reference service adapts simulated durable long-running process views for runnable examples. It is not a production workflow engine.

## Build And Start

```powershell
go build -o process-domain-adapter.exe .
.\process-domain-adapter.exe --addr :8100 --data-file .\process-domain-data.json
```

`GET http://localhost:8100/healthz` returns `{"status":"ok","service":"process-domain-adapter"}`.

## Seeded State

- Process `proc-0001`: workflow `onboarding`, stages `request → review → approve → complete`, current stage `request`, status `initiated`.

## Governance Model

- **Stage-sequenced gating.** A process can only advance to the exact next stage; skipping or reordering is rejected (`409 stage_mismatch`).
- **Terminal-state enforcement.** The outcome completes only at the terminal stage (`403 outcome_not_reached_terminal_stage_required`).
- **Completed-process immutability.** A completed process cannot be advanced or completed again (`409 process_already_completed`).
- **Human-attributed advances.** Every stage transition carries `decided_by`, `rationale`, and `decision_ref`.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/processes/{id}` | Process with current stage, advances, and status. |
| `POST /v1/processes/{id}/advance` | Advances to the next stage (stage-sequenced, human-attributed). |
| `POST /v1/processes/{id}/complete` | Completes the outcome at the terminal stage. |
| `GET /v1/notifications/{id}` | Pending outcome notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
