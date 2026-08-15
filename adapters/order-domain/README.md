# Order-Domain Reference Adapter

This local reference service adapts simulated order, inventory, payment, carrier, and customer-notification views for the executable order-exception example. It is not a production OMS, payment, carrier, or notification integration.

## Build And Start

```powershell
go build -o order-domain-adapter.exe .
.\order-domain-adapter.exe --addr :8090 --data-file .\order-domain-data.json
```

`GET http://localhost:8090/healthz` returns `{"status":"ok","service":"order-domain-adapter"}`.

## Seeded State

`order-123` starts as a stockout at `warehouse-a`; `sku-inspection-kit` has no stock there and ten units at `warehouse-b`.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/orders/order-123` | Current order, fulfillment, payment, carrier, notifications, and action history. |
| `GET /v1/inventory/sku-inspection-kit` | Reference inventory view. |
| `GET /v1/payments/order-123` | Reference payment view. |
| `GET /v1/shipments/order-123` | Reference carrier view. |
| `GET /v1/notifications/order-123` | Pending customer-notification records. |
| `POST /v1/orders/order-123/fulfillment-actions` | Applies an approved fulfillment action. |

The action request requires all fields:

```json
{
  "action": "alternate_location",
  "approved_by": "operations-lead",
  "approval_ref": "approval://order-123-stockout",
  "idempotency_key": "order-123-alternate-location-v1"
}
```

Supported actions: `alternate_location`, `split_shipment`, `approved_substitute`, and `cancel`. The adapter persists outcomes in its data file and returns the updated order plus action evidence.
