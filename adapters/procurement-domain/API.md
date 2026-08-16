# Procurement-Domain Adapter — API Reference

Local reference service for simulated purchasing views: requests, budget, suppliers, purchase orders, and receipts. Not a production procurement or ERP system.

Base URL: `http://localhost:8092` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"procurement-domain-adapter"}
```

### `GET /v1/requests/{id}`

Returns the request with approvals, PO, receipt, and action history.

Seeded `preq-0001`:

```json
{
  "id": "preq-0001", "requester": "e-1001", "item": "desk-chair-ergo", "quantity": 1,
  "cost_center": "CC-1001", "budget_ref": "budget-0001", "status": "draft",
  "approvals": [], "actions": []
}
```

Errors: `404 {"error":"request_not_found"}`.

### `POST /v1/requests/{id}/submit`

Submits the request. Requires `requester` and `idempotency_key`.

```json
{"requester":"e-1001","idempotency_key":"proc-submit-v1"}
```

`request.status` → `submitted`. Errors: `400` missing fields, `403 requester_mismatch`, `409 request_not_draft`.

### `POST /v1/requests/{id}/approvals`

Records a role approval. Requires `role`, `approver`, `decision`, `approval_ref`, `idempotency_key`.

```json
{"role":"finance","approver":"finance-lead","decision":"approve","approval_ref":"approval://preq-0001","idempotency_key":"proc-fin-v1"}
```

- `role` must be `finance` or `procurement`; `decision` must be `approve` or `reject`.
- `request.status` → `approved` only after both roles have approved.
- A `reject` sets `request.status` → `rejected`.

Errors: `400` missing fields or unsupported role/decision, `403 segregation_of_duties_requester_cannot_approve_own_request`.

### `POST /v1/requests/{id}/purchase-actions`

Issues a purchase order. Requires `supplier`, `approved_by`, `approval_ref`, `idempotency_key`.

```json
{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"approval://preq-0001","idempotency_key":"proc-buy-v1"}
```

Creates `po-preq-0001-supplier-b` (amount 220), decrements the budget, and sets `request.status` → `ordered`.

Errors: `400` missing fields or unknown supplier, `403 request_not_approved` or `required_approvals_missing`, `422 insufficient_budget`.

### `POST /v1/requests/{id}/receipts`

Records a receipt and closes the request. Requires `received_by`, `accepted`, `idempotency_key`.

```json
{"received_by":"warehouse-receiver","accepted":true,"idempotency_key":"proc-rcv-v1"}
```

Sets `po.status` → `received` (or `discrepancy` when not accepted) and `request.status` → `closed`.

Errors: `400` missing fields, `403 no_purchase_order`.

### `GET /v1/budget/{id}`

```json
{"id":"budget-0001","cost_center":"CC-1001","available":5000,"currency":"USD"}
```

Errors: `404 budget_not_found`.

### `GET /v1/suppliers/{id}`

```json
{"id":"supplier-b","preferred":true,"price":220}
```

Errors: `404 supplier_not_found`.

### `GET /v1/pos/{id}`

```json
{"id":"po-preq-0001-supplier-b","supplier":"supplier-b","amount":220,"status":"received"}
```

Errors: `404 po_not_found`.

## State Machine

```
draft -> submitted -> approved -> ordered -> closed
                    \-> rejected
```

`approved` requires both `finance` and `procurement` approvals under the same approval reference. Every mutating call is idempotent (`"replayed": true` on repeat keys).

## Errors

| Status | Body | When |
| --- | --- | --- |
| `400` | `..._are_required` | Any required field missing or empty. |
| `400` | `{"error":"unsupported_role"}` | Role not `finance` or `procurement`. |
| `400` | `{"error":"decision_must_be_approve_or_reject"}` | Invalid decision. |
| `400` | `{"error":"supplier_not_found"}` | Unknown supplier. |
| `403` | `{"error":"segregation_of_duties_requester_cannot_approve_own_request"}` | Requester approves own request. |
| `403` | `{"error":"requester_mismatch"}` | Submit attributor differs from the seeded requester. |
| `403` | `{"error":"request_not_approved"}` / `required_approvals_missing` | Purchase before both approvals. |
| `403` | `{"error":"no_purchase_order"}` | Receipt before any PO. |
| `404` | `{...not_found}` | Unknown request/budget/supplier/po. |
| `409` | `{"error":"request_not_draft"}` | Re-submit after submission. |
| `422` | `{"error":"insufficient_budget"}` | Supplier price exceeds budget. |
| `200` | `"replayed": true` | Idempotency key already applied (not an error). |
