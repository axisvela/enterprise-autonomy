# Maintenance-Domain Adapter — API Reference

Local reference service for simulated predictive-maintenance views. Not a production CMMS.

Base URL: `http://localhost:8095` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"maintenance-domain-adapter"}
```

### `GET /v1/assets/{id}`

```json
{"id":"asset-pump-01","name":"Cooling Pump 01","zone":"zone-b","status":"running"}
```

Errors: `404 asset_not_found`.

### `GET /v1/signals/{id}`

Seeded `signal-pm-0001`:

```json
{"id":"signal-pm-0001","asset":"asset-pump-01","level":"elevated","status":"pending",
 "confirmed":false,"actions":[]}
```

Errors: `404 signal_not_found`.

### `POST /v1/signals/{id}/validate`

Maintenance manager validates the signal. Requires `validated_by`, `confirmed`, `note`, `idempotency_key`.

```json
{"validated_by":"maintenance-manager","confirmed":false,
 "note":"prediction based on vibration trend","idempotency_key":"pm-val-v1"}
```

`signal.status` → `validated`; `confirmed` records whether the signal is a confirmed fault or an unconfirmed prediction.

Errors: `400` missing fields, `403 only_maintenance_manager_can_validate`, `409 signal_already_validated`.

### `POST /v1/signals/{id}/decisions`

Records the maintenance decision. Requires `decision` (`monitor`/`inspect`/`repair`/`defer`/`stop`), `decided_by`, `decision_ref`, `idempotency_key`.

```json
{"decision":"repair","decided_by":"maintenance-manager","decision_ref":"decision://pm-0001","idempotency_key":"pm-dec-v1"}
```

Errors: `400` missing/invalid decision, `409 signal_must_be_validated_first`, `403 unconfirmed_prediction_cannot_trigger_stop`.

### `POST /v1/signals/{id}/safety-reviews`

Safety authority reviews intrusive work. Requires `reviewed_by`, `outcome` (`approve`/`block`), `safety_ref`, `idempotency_key`.

```json
{"reviewed_by":"safety-authority","outcome":"approve","safety_ref":"safety://pm-0001","idempotency_key":"pm-safety-v1"}
```

Errors: `400` missing/invalid outcome, `403 only_safety_authority_can_review`.

### `POST /v1/signals/{id}/work-orders`

Creates a work order. Requires `scope`, `approved_by`, `approval_ref`, `idempotency_key`.

```json
{"scope":"replace bearing","approved_by":"maintenance-manager","approval_ref":"approval://pm-0001","idempotency_key":"pm-wo-v1"}
```

Creates `wo-pm-wo-v1` (status `scheduled`). Gated on: validated signal, a recorded decision, and (for `repair`/`stop`) an approved safety review.

Errors: `400` missing fields or decision that does not require work (`monitor`/`inspect`/`defer`), `403 signal_not_validated_prediction_is_not_a_fault`, `403 no_maintenance_decision`, `403 safety_review_required_for_intrusive_work`.

### `GET /v1/workorders/{id}`

```json
{"id":"wo-pm-wo-v1","signal":"signal-pm-0001","scope":"replace bearing","approved_by":"maintenance-manager","approval_ref":"approval://pm-0001","status":"scheduled"}
```

Errors: `404 work_order_not_found`.

### `GET /v1/notifications/{id}`

```json
{"signal_id":"signal-pm-0001","notifications":["work-order-notification-pending:wo-pm-wo-v1"]}
```

Errors: `404 signal_not_found`.

## State Machine

```
pending -> validated -> (decision) -> (safety review) -> work order (scheduled)
```

`validate` moves `pending → validated`. A decision must follow validation. `repair`/`stop` additionally require an approved safety review before a work order can be created. Every mutating call is idempotent (`"replayed": true` on repeat keys).

## Integrity Model

- **Prediction-vs-fact**: unvalidated signals are never treated as faults; an unconfirmed prediction cannot trigger a `stop`.
- **Safety conjunctive**: intrusive work requires both a maintenance decision and an approved safety review.
- **Decision-scoped work**: only `repair`/`stop` produce work orders; `monitor`/`inspect`/`defer` do not.

**Governance patterns:** prediction-is-not-a-fault and safety conjunctive; see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
