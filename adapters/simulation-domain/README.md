# Simulation-Domain Reference Adapter

This local reference service adapts simulated possible-world validation views for runnable examples. It is not a production simulation or experimentation platform.

## Build And Start

```powershell
go build -o simulation-domain-adapter.exe .
.\simulation-domain-adapter.exe --addr :8097 --data-file .\simulation-domain-data.json
```

`GET http://localhost:8097/healthz` returns `{"status":"ok","service":"simulation-domain-adapter"}`.

## Seeded State

- Proposal `proposal-sim-0001`: capability `automated-zone-inspection`, scope `zone-alpha`, status `proposed`, review group `reviewer-a`, `reviewer-b`.

## Governance Model

- **Evidence before decision.** A review decision cannot be recorded without at least one recorded simulation run (`403 simulation_evidence_required_before_decision`).
- **Immutable evidence.** A simulation run, once recorded, cannot be replaced; a second run with a different id is rejected (`409 evidence_already_recorded_immutable`).
- **Review-group decision.** Only designated review-group members may record the decision (`403 not_review_group_member`).
- **Approval-gated release.** A proposal goes live only after an `approve` decision citing the exact decision reference (`403 release_requires_approval`, `403 decision_ref_mismatch`).

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/proposals/{id}` | Proposal with scenarios, runs, decision, and action history. |
| `POST /v1/proposals/{id}/scenarios` | Compiles a simulation scenario. |
| `POST /v1/proposals/{id}/runs` | Records immutable simulation evidence. |
| `POST /v1/proposals/{id}/decisions` | Review group records the decision (evidence-gated). |
| `POST /v1/proposals/{id}/release` | Releases the proposal after an approve decision. |
| `GET /v1/runs/{id}` | A recorded simulation run. |
| `GET /v1/notifications/{id}` | Pending release notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
