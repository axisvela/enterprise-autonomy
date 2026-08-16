# Procurement Demo — Detailed Operations Guide

Step-by-step walkthrough of the procurement demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: requester `e-1001`, procurement owner `procurement-owner`, finance approver `finance-lead`, receiver `warehouse-receiver`, supplier `supplier-b`, approval reference `approval://preq-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Procurement-domain adapter | `http://localhost:8092` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Request** (`preq-0001`): item `desk-chair-ergo`, quantity 1, cost center `CC-1001`, budget ref `budget-0001`, status `draft`, requester `e-1001`.
- **Budget** (`budget-0001`): `CC-1001`, `5000 USD` available.
- **Suppliers**: `supplier-a` (price 240, not preferred), `supplier-b` (price 220, preferred).

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Submit the request (procurement-domain adapter)

**Purpose.** The requester submits the request; the adapter records the action and moves the request to `submitted`.

**Request.**
```
POST http://localhost:8092/v1/requests/preq-0001/submit
Body:
{"requester":"e-1001","idempotency_key":"proc-submit-v1"}
```

**Response fields read by the script:** `request.status` (expected `submitted`).

**What to notice.** Submit is a governed action with an idempotency key. A requester who does not match the seeded owner is rejected (`403 requester_mismatch`) — the adapter does not accept arbitrary submit attribution.

## Step 2 — Open the governed case (Symbivela)

**Purpose.** Create the human authority that gates the purchase.

**Request 2a — create the workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: procurement-owner,
         Idempotency-Key: procurement-ops-workspace-v1
Body:
{"workspace_id":"procurement-ops","name":"Procurement Operations","owner_id":"procurement-owner"}
```

**Request 2b — open the case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: procurement-owner,
         Idempotency-Key: preq-0001-case-v1
Body:
{"workspace_id":"procurement-ops","case_id":"preq-0001-purchase","subject_ref":"request://preq-0001",
 "problem":"Purchasing required for item within budget envelope.",
 "evidence_refs":"budget://budget-0001",
 "candidate_actions":"preferred-supplier,standard-supplier,reject",
 "deadline":"2026-08-20T12:00:00Z"}
```

**What to notice.** The case names the accountable owner, the permitted supplier choices, and the budget evidence. No purchase may proceed without it.

## Step 3 — Record budget context (Ontovela)

**Purpose.** Establish the budget as an authoritative observed fact and confirm availability from the adapter.

**Request 3a — assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: preq-0001-budget-v1
Body:
{"id":"assertion-budget-0001-available","subject_id":"budget-0001","property":"availability",
 "value":"available","state_kind":"observed","event_time":"2026-08-16T09:00:00Z",
 "system_time":"2026-08-16T09:00:01Z","source":"finance-system","evidence_ref":"evidence://finance/budget-0001"}
```

**Request 3b — budget view.**
```
GET http://localhost:8092/v1/budget/budget-0001
```
Response: `{"id":"budget-0001","cost_center":"CC-1001","available":5000,"currency":"USD"}`.

**What to notice.** The world model records the budget fact with evidence; the adapter's view is the operational source the purchase will actually draw against. Two layers, one consistent fact.

## Step 4 — Approve with segregation of duties (procurement-domain adapter)

**Purpose.** Prove the requester cannot approve their own request, then record both required approvals.

**Request 4a — self-approval attempt (expect rejection).**
```
POST http://localhost:8092/v1/requests/preq-0001/approvals
Body:
{"role":"finance","approver":"e-1001","decision":"approve","approval_ref":"approval://preq-0001",
 "idempotency_key":"proc-self-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"segregation_of_duties_requester_cannot_approve_own_request"}`.

**Request 4b — finance approval.**
```
POST http://localhost:8092/v1/requests/preq-0001/approvals
Body:
{"role":"finance","approver":"finance-lead","decision":"approve","approval_ref":"approval://preq-0001",
 "idempotency_key":"proc-fin-v1"}
```

**Request 4c — procurement approval.**
```
POST http://localhost:8092/v1/requests/preq-0001/approvals
Body:
{"role":"procurement","approver":"procurement-owner","decision":"approve","approval_ref":"approval://preq-0001",
 "idempotency_key":"proc-pr-v1"}
```

**Response fields read by the script:** `request.status` (expected `approved` after both roles approve).

**What to notice.** Two subtleties:

1. **Segregation of duties is structural**: the adapter refuses the requester as an approver before any role logic runs.
2. **Both roles must approve**: a single role's approval leaves the request in `submitted`; the status becomes `approved` only when finance and procurement have both approved under the same reference.

## Step 5 — Create the durable procurement process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `procurement-workflow.json`.** Stages: `validate (requester) → approve (finance-lead, procurement-owner) → purchase (capability procurement.purchase.execute) → receive (warehouse-receiver) → close (procurement-owner)`.

**CLI — validate and define.**
```powershell
rheo workflow validate procurement-workflow.json
rheo workflow define --file procurement-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"procurement-request-to-receipt","project":"preq-0001","actor":"procurement-owner"}
```

**What to notice.** The `purchase` stage is capability-gated (`procurement.purchase.execute`): executing a purchase outside the process is not expressible in the workflow.

## Step 6 — Generate a sourcing plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation for supplier selection. A plan is not an authorization.

**Input file — `procurement-plan.json`.** Goal `goal-preq-0001-sourced` owned by `procurement-owner`; catalog offers `cap-preferred-supplier` (supplier-b, cost 220) and `cap-standard-supplier` (supplier-a, cost 240); hard budget ceiling 5000; soft preference for `supplier-b`; delegation with `evidenceDuty: ["approval://preq-0001"]`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of procurement-plan.json)
```

**What to notice.** The plan respects the hard budget and prefers the cheaper supplier, but remains a recommendation pending the human decisions already recorded.

## Step 7 — Execute the approved purchase (procurement-domain adapter)

**Purpose.** Show the purchase requires both approvals, then issue the PO.

**Request 7a — unapproved purchase attempt (expect rejection).**
```
POST http://localhost:8092/v1/requests/preq-0001/purchase-actions
Body:
{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"",
 "idempotency_key":"proc-buy-unapproved-v1"}
```
The adapter responds `400 Bad Request` with `{"error":"supplier_approved_by_approval_ref_and_idempotency_key_are_required"}`.

**Request 7b — approved purchase.**
```
POST http://localhost:8092/v1/requests/preq-0001/purchase-actions
Body:
{"supplier":"supplier-b","approved_by":"procurement-owner","approval_ref":"approval://preq-0001",
 "idempotency_key":"proc-buy-v1"}
```

**Response fields read by the script:** `po.id` (`po-preq-0001-supplier-b`), `po.amount` (220), `request.status` (`ordered`).

**What to notice.** The purchase is **approval-cited**: it requires both recorded approvals and carries the exact `approval_ref`. The budget is decremented by the supplier price (5000 → 4780).

## Step 8 — Receive, close, and emit the value report

**Purpose.** Confirm the receipt, close the request, and reconstruct the lifecycle from evidence.

**Request.**
```
POST http://localhost:8092/v1/requests/preq-0001/receipts
Body:
{"received_by":"warehouse-receiver","accepted":true,"idempotency_key":"proc-rcv-v1"}
```

**Response fields read by the script:** `receipt.id`, then `GET /v1/requests/preq-0001` for the final `status` (`closed`) and `po.status` (`received`).

**Outputs written to `.local-data/`:** `procurement-outcome.json` and `procurement-value-report.json`.

**What to notice.** The receipt requires an existing PO — you cannot close a request that was never purchased. The value report's denial entries (`self-approval-rejected`, `unapproved-purchase-rejected`) make the governance effect measurable.

## Output Artifacts

### `procurement-outcome.json`

```json
{
  "request_id": "preq-0001",
  "tenant": "tenant-a",
  "requester": "e-1001",
  "steps": [
    {"index": 1, "title": "Submit the request", "product": "procurement-domain", "artifact": "submit-proc-submit-v1"},
    {"index": 2, "title": "Open the governed case", "product": "symbivela", "artifact": "preq-0001-purchase"},
    {"index": 3, "title": "Record budget context", "product": "ontovela", "artifact": "assertion-budget-0001-available"},
    {"index": 4, "title": "Approve budget and supplier", "product": "procurement-domain", "artifact": "approval-proc-pr-v1"},
    {"index": 5, "title": "Create the durable procurement process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 6, "title": "Generate a sourcing plan", "product": "orchadyn", "artifact": "plan-preq-0001"},
    {"index": 7, "title": "Execute the approved purchase", "product": "procurement-domain", "artifact": "po-preq-0001-supplier-b"},
    {"index": 8, "title": "Confirm receipt and close", "product": "procurement-domain", "artifact": "receipt-proc-rcv-v1"}
  ],
  "request_state": {
    "id": "preq-0001", "requester": "e-1001", "item": "desk-chair-ergo", "quantity": 1,
    "cost_center": "CC-1001", "budget_ref": "budget-0001", "status": "closed",
    "approvals": [
      {"role": "finance", "approver": "finance-lead", "decision": "approve", "approval_ref": "approval://preq-0001"},
      {"role": "procurement", "approver": "procurement-owner", "decision": "approve", "approval_ref": "approval://preq-0001"}
    ],
    "po": {"id": "po-preq-0001-supplier-b", "supplier": "supplier-b", "amount": 220, "status": "received"}
  }
}
```

### `procurement-value-report.json`

Example KPIs: `products_involved` 6, `gates_passed` 4, `evidence_artifacts` 9, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8092/healthz` | Adapter build failed or port busy | Check `.local-logs\procurement-domain.err.log`; confirm `go` on PATH. |
| Request stuck at `submitted` | One approval role missing | Record both finance and procurement approvals under the same reference. |
| `403 segregation_of_duties` | Requester approved own request | This is the *expected* denial; use finance/procurement approvers. |
| `403 request_not_approved` | Purchase attempted before approvals | Complete both approvals first. |
| `422 insufficient_budget` | Supplier price exceeds budget | Choose a cheaper supplier or raise the budget. |
