# Sandbox-Domain Reference Adapter

This local reference service adapts simulated innovation-sandbox views for runnable examples. It is not a production policy or sandbox platform.

## Build And Start

```powershell
go build -o sandbox-domain-adapter.exe .
.\sandbox-domain-adapter.exe --addr :8101 --data-file .\sandbox-domain-data.json
```

`GET http://localhost:8101/healthz` returns `{"status":"ok","service":"sandbox-domain-adapter"}`.

## Seeded State

- Proposal `proposal-sandbox-0001`: capability `batch-report-generation`, sandbox scope `report-generation-scope`, status `proposed`, review group `reviewer-a`, `reviewer-b`.

## Governance Model

- **Sandbox boundary.** An experiment outside the proposal's sandbox scope is rejected (`403 sandbox_boundary_experiment_outside_scope`).
- **Evidence-based policy.** A policy decision requires at least one sandbox experiment (`403 experiment_evidence_required_before_policy`).
- **Designated reviewer.** Only review-group members may decide (`403 not_designated_reviewer`).
- **Immutable policy.** A recorded policy decision cannot be changed (`409 policy_already_recorded_immutable`).
- **Policy-gated apply.** The capability is applied only after a policy decision citing the exact reference; rejected proposals cannot be applied.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/proposals/{id}` | Proposal with sandbox scope, experiments, decision, and apply state. |
| `POST /v1/proposals/{id}/experiments` | Records a sandbox experiment (boundary-gated). |
| `POST /v1/proposals/{id}/decisions` | Review group records a release/restrict/reject policy decision. |
| `POST /v1/proposals/{id}/apply` | Applies the policy decision. |
| `GET /v1/notifications/{id}` | Pending policy-apply notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
