# Inventory-Domain Adapter — API Reference

Local reference service for simulated multi-warehouse inventory views. Not a production WMS.

Base URL: `http://localhost:8091` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"inventory-domain-adapter"}
```

### `GET /v1/inventory/{sku}`

Returns per-warehouse availability and adjustment history.

Seeded `sku-inspection-kit`:

```json
{
  "sku": "sku-inspection-kit",
  "levels": [
    {"warehouse": "warehouse-a", "available": 0},
    {"warehouse": "warehouse-b", "available": 10}
  ],
  "adjustments": []
}
```

Errors: `404 {"error":"sku_not_found"}`, `405 {"error":"method_not_allowed"}`.

### `POST /v1/inventory/{sku}`

Applies an approved stock adjustment. Request requires all fields:

```json
{
  "warehouse": "warehouse-b",
  "delta": -1,
  "reason": "reserve stock for order-123",
  "approved_by": "operations-lead",
  "approval_ref": "approval://order-123-stockout",
  "idempotency_key": "inventory-order-123-reserve-v1"
}
```

Response:

```json
{
  "sku": "sku-inspection-kit",
  "adjustment": {
    "id": "adjustment-inventory-order-123-reserve-v1",
    "delta": -1,
    "reason": "reserve stock for order-123",
    "approved_by": "operations-lead",
    "approval_ref": "approval://order-123-stockout",
    "idempotency_key": "inventory-order-123-reserve-v1",
    "occurred_at": "<RFC3339>"
  },
  "replayed": false
}
```

Replaying the same `idempotency_key` returns `"replayed": true` without adjusting stock again.

## Adjustment Semantics

- `delta` is applied to the named warehouse's availability.
- The resulting availability can never be negative; an over-draw returns `422`.
- The adjustment is recorded with `approved_by` and `approval_ref`; there is no unauthored path.

## Errors

| Status | Body | When |
| --- | --- | --- |
| `400` | `{"error":"warehouse_approved_by_approval_ref_and_idempotency_key_are_required"}` | Any required field missing or empty. |
| `400` | `{"error":"delta_must_be_nonzero"}` | `delta` is `0`. |
| `400` | `{"error":"warehouse_not_found"}` | Unknown warehouse. |
| `404` | `{"error":"sku_not_found"}` | Unknown sku. |
| `422` | `{"error":"insufficient_stock"}` | Adjustment would make availability negative. |
| `405` | `{"error":"method_not_allowed"}` | Non-GET/POST method. |
| `200` | `"replayed": true` | Idempotency key already applied (not an error). |
