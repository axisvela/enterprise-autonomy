# Inventory-Domain Reference Adapter

This local reference service adapts simulated multi-warehouse inventory views for runnable examples. It is not a production WMS or inventory integration.

## Build And Start

```powershell
go build -o inventory-domain-adapter.exe .
.\inventory-domain-adapter.exe --addr :8091 --data-file .\inventory-domain-data.json
```

`GET http://localhost:8091/healthz` returns `{"status":"ok","service":"inventory-domain-adapter"}`.

## Seeded State

`sku-inspection-kit` has zero available units at `warehouse-a` and ten at `warehouse-b`.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/inventory/{sku}` | Current per-warehouse availability and adjustment history. |
| `POST /v1/inventory/{sku}` | Applies an approved stock adjustment. |

The adjustment request requires all fields:

```json
{
  "warehouse": "warehouse-b",
  "delta": -2,
  "reason": "reserved for order-123",
  "approved_by": "operations-lead",
  "approval_ref": "approval://order-123-stockout",
  "idempotency_key": "inventory-order-123-reserve-v1"
}
```

Adjustments are idempotent and reject negative totals. The adapter persists outcomes in its data file and returns the updated record plus adjustment evidence.
