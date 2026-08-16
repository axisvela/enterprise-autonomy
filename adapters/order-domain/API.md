# Order-Domain Adapter — API Reference

Local reference service for simulated order, inventory, payment, carrier, and customer-notification views. Not a production OMS.

Base URL: `http://localhost:8090` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"order-domain-adapter"}
```

### `GET /v1/orders/{id}`

Returns the current order, fulfillment, payment, carrier, notifications, and action history.

Seeded `order-123`:

```json
{
  "id": "order-123",
  "sku": "sku-inspection-kit",
  "quantity": 1,
  "warehouse": "warehouse-a",
  "fulfillment_status": "stockout",
  "payment_status": "authorized",
  "carrier_status": "not_dispatched",
  "notifications": [],
  "actions": []
}
```

Errors: `404 {"error":"order_not_found"}`.

### `POST /v1/orders/{id}/fulfillment-actions`

Applies an approved fulfillment action. Request requires all four fields:

```json
{
  "action": "alternate_location",
  "approved_by": "operations-lead",
  "approval_ref": "approval://order-123-stockout",
  "idempotency_key": "order-123-alternate_location-v1"
}
```

Response:

```json
{
  "order": { "...": "updated order state" },
  "action": {
    "id": "action-order-123-alternate_location-v1",
    "action": "alternate_location",
    "approved_by": "operations-lead",
    "approval_ref": "approval://order-123-stockout",
    "idempotency_key": "order-123-alternate_location-v1",
    "occurred_at": "<RFC3339>"
  },
  "replayed": false
}
```

Replaying the same `idempotency_key` returns `"replayed": true` without applying the action again.

### `GET /v1/inventory/{sku}`

```json
{"sku":"sku-inspection-kit","warehouse-a_available":0,"warehouse-b_available":10}
```

### `GET /v1/payments/{id}`

```json
{"order_id":"order-123","payment_status":"authorized"}
```

### `GET /v1/shipments/{id}`

```json
{"order_id":"order-123","carrier_status":"not_dispatched"}
```

### `GET /v1/notifications/{id}`

```json
{"order_id":"order-123","notifications":["customer-notification-pending:action-order-123-alternate_location-v1"]}
```

## Action Semantics and State Transitions

| Action | warehouse | fulfillment_status | carrier_status | notification |
| --- | --- | --- | --- | --- |
| `alternate_location` | `warehouse-b` | `replanned` | `awaiting_dispatch` | added |
| `split_shipment` | unchanged | `replanned` | `awaiting_dispatch` | added |
| `approved_substitute` | unchanged | `replanned` | `awaiting_dispatch` | added |
| `cancel` | unchanged | `cancelled` | `not_dispatched` | added |

Every accepted action appends `customer-notification-pending:<action-id>` and records the full action with `approved_by` and `approval_ref`.

## Errors

| Status | Body | When |
| --- | --- | --- |
| `400` | `{"error":"action_approved_by_approval_ref_and_idempotency_key_are_required"}` | Any required field missing or empty. |
| `400` | `{"error":"unsupported_action"}` | Action not in the supported set. |
| `404` | `{"error":"order_not_found"}` | Unknown order id. |
| `200` | `"replayed": true` | Idempotency key already applied (not an error). |

The adapter has **no bypass path**: an empty `approved_by`/`approval_ref` is rejected, never treated as "no approval required".

**Governance pattern:** deny-by-default with no bypass and shared approval references; see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
