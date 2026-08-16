# Procurement-Domain Reference Adapter

This local reference service adapts simulated purchasing views for runnable examples. It is not a production procurement or ERP integration.

## Build And Start

```powershell
go build -o procurement-domain-adapter.exe .
.\procurement-domain-adapter.exe --addr :8092 --data-file .\procurement-domain-data.json
```

`GET http://localhost:8092/healthz` returns `{"status":"ok","service":"procurement-domain-adapter"}`.

## Seeded State

- Request `preq-0001`: item `desk-chair-ergo`, quantity 1, cost center `CC-1001`, budget `budget-0001`, status `draft`, requester `e-1001`.
- Budget `budget-0001`: `5000 USD` available.
- Suppliers: `supplier-b` (preferred, price 220) and `supplier-a` (price 240).

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/requests/{id}` | Request with approvals, PO, receipt, and action history. |
| `POST /v1/requests/{id}/submit` | Submits the request. |
| `POST /v1/requests/{id}/approvals` | Records a `finance` or `procurement` approval; requester cannot approve own request. |
| `POST /v1/requests/{id}/purchase-actions` | Issues a PO once both approvals exist; decrements the budget. |
| `POST /v1/requests/{id}/receipts` | Records a receipt and closes the request. |
| `GET /v1/budget/{id}` | Budget availability. |
| `GET /v1/suppliers/{id}` | Supplier price and preference. |
| `GET /v1/pos/{id}` | Purchase order status. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
