# Maintenance-Domain Reference Adapter

This local reference service adapts simulated predictive-maintenance views for runnable examples. It is not a production CMMS or condition-monitoring system.

## Build And Start

```powershell
go build -o maintenance-domain-adapter.exe .
.\maintenance-domain-adapter.exe --addr :8095 --data-file .\maintenance-domain-data.json
```

`GET http://localhost:8095/healthz` returns `{"status":"ok","service":"maintenance-domain-adapter"}`.

## Seeded State

- Signal `signal-pm-0001`: asset `asset-pump-01`, level `elevated`, status `pending` (a prediction, not a confirmed fault).
- Asset `asset-pump-01`: `Cooling Pump 01`, zone `zone-b`, status `running`.

## Governance Model

- **Prediction is not a fault.** A work order cannot be created on an unvalidated signal (`403 signal_not_validated_prediction_is_not_a_fault`), and an unconfirmed prediction cannot trigger a `stop` decision.
- **Safety is conjunctive.** `repair` and `stop` work orders require an approved safety review by the safety authority (`403 safety_review_required_for_intrusive_work`).
- **Decisions gate work orders.** A maintenance decision must be recorded first; `monitor`, `inspect`, and `defer` never produce a work order.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/assets/{id}` | Asset state. |
| `GET /v1/signals/{id}` | Signal with validation, decision, safety, and work-order state. |
| `POST /v1/signals/{id}/validate` | Maintenance manager validates the signal (prediction vs. confirmed fault). |
| `POST /v1/signals/{id}/decisions` | Records the maintenance decision. |
| `POST /v1/signals/{id}/safety-reviews` | Safety authority approves or blocks intrusive work. |
| `POST /v1/signals/{id}/work-orders` | Creates a work order once validated + decided + safety-approved. |
| `GET /v1/workorders/{id}` | Work order state. |
| `GET /v1/notifications/{id}` | Pending work-order notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
