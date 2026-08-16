# Recruitment-Domain Reference Adapter

This local reference service adapts simulated recruiting views for runnable examples. It is not a production ATS or HR system, and it does not make hiring decisions.

## Build And Start

```powershell
go build -o recruitment-domain-adapter.exe .
.\recruitment-domain-adapter.exe --addr :8094 --data-file .\recruitment-domain-data.json
```

`GET http://localhost:8094/healthz` returns `{"status":"ok","service":"recruitment-domain-adapter"}`.

## Seeded State

- Requisition `req-0001`: role `Senior Platform Engineer`, location `Remote`, hiring manager `hiring-manager-1`, TA lead `ta-lead-1`, budget ref `budget-rec-0001`, status `draft`, candidates `cand-a`, `cand-b`, `cand-c`.
- Candidates: `cand-a`, `cand-b`, `cand-c` (evaluation records start empty).

## Governance Model

- **Automation cannot decide.** Any decision recorded with `actor_type: automated` is rejected (`403 automation_cannot_make_hiring_decisions`). Automation may administer, schedule, and organize evidence, but never screen, select, or extend offers.
- **Stage-gated.** Decisions must follow the lifecycle: `validate → shortlist → selection → offer`.
- **Human-attributed.** Every decision requires a human `decided_by`, a `rationale`, and a `decision_ref`.
- **Offer-gated.** An offer can be issued only after an `offer`-stage human decision for the same candidate.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/requisitions/{id}` | Requisition with criteria, candidates, decisions, offer, and action history. |
| `POST /v1/requisitions/{id}/validate` | TA lead validates the requisition and records criteria. |
| `POST /v1/requisitions/{id}/decisions` | Records a human decision (shortlist/selection/offer); automated decisions are rejected. |
| `POST /v1/requisitions/{id}/offers` | Issues an offer after the offer-stage decision. |
| `GET /v1/candidates/{id}` | Candidate evaluation records. |
| `GET /v1/notifications/{id}` | Pending offer and rejection notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
