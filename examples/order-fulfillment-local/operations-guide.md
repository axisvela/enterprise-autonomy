# Order-Exception Demo — Detailed Operations Guide

This guide walks through the local order-exception demo step by step with the **exact requests and responses** each script issues. Read it alongside the [README](README.md), which describes the scenario and prerequisites.

## How To Read This Guide

Each step is documented with the same structure:

- **Purpose** — why the step exists and what it proves.
- **Request** — the exact HTTP method, URL, headers, and body the script sends.
- **Response** — the fields the script reads and what they mean.
- **What to notice** — the subtle governance behavior the step demonstrates.

Values are concrete: the tenant is `tenant-a`, the operator is `operations-lead`, and the order is `order-123`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Order-domain adapter | `http://localhost:8090` | `GET /healthz` |
| Inventory-domain adapter | `http://localhost:8091` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Headers and Idempotency

The script uses two conventions throughout:

- **Tenant headers**: Ontovela uses `X-Tenant-ID`; Symbivela uses `X-SYMBIVELA-Tenant` and `X-SYMBIVELA-Actor`.
- **Idempotency-Key**: every mutating call carries a stable key so re-running the demo does not duplicate artifacts (`order-123-stockout-v1`, `order-123-case-v1`, `order-ops-workspace-v1`, `inventory-order-123-reserve-v1`, `order-123-<action>-v1`).

Idempotency is the first of many governance details: **re-runs are safe by construction**.

## Prerequisites and Setup

### Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`.
- Local checkouts for `LIMENORA-open`, `ONTOVELA`, `RHEOVELA`, `SYMBIVELA`, and `PRAXOVELA` under `$AxisRoboHome`.
- A running PostgreSQL 18 instance with `symbivela`, `orchadyn`, and `moduregis` databases.
- Verified binaries for `limenora-edge.exe`, `ontovela.exe`, `rheo.exe`, and `symbivela.exe`.

### Prepare the environment file

Copy `local.env.ps1.example` to `local.env.ps1` and set the checkout root and connection strings. The file defines:

```powershell
$AxisRoboHome = "D:\profile\paper-code"
$TenantId = "tenant-a"
$Actor = "operations-lead"
$OrderAction = "alternate_location"
$OrderApprovalRef = "approval://order-123-stockout"
$env:DATABASE_URL = "postgres://symbivela:symbivela@localhost:5433/symbivela?sslmode=disable"
$env:ORCHADYN_DATABASE_URL = "postgres://orchadyn:orchadyn@localhost:5433/orchadyn?sslmode=disable"
$OrchadynBinary = "$PSScriptRoot\.orchadyn-release\orchadyn-api.exe"
$OrchadynMigrateBinary = "$PSScriptRoot\.orchadyn-release\orchadyn-migrate.exe"
$OrchadynSource = "D:\profile\paper-code\ORCHADYN"
$env:MODUREGIS_DATABASE_URL = "postgres://moduregis:moduregis@localhost:5433/moduregis?sslmode=disable"
$ModuregisListenAddr = ":8084"
$OrchadynListenAddr = ":1816"
```

`$OrderAction` and `$OrderApprovalRef` are the human decision inputs: the operator chooses the action and, after a real approval, records its reference.

### Migrate the Symbivela schema once

```powershell
$env:DATABASE_URL = "postgres://symbivela:symbivela@localhost:5433/symbivela?sslmode=disable"
Push-Location D:\profile\paper-code\SYMBIVELA\backend
$env:GOWORK = "off"
go run ./cmd/symbivela-migrate
Pop-Location
```

Expected: the migration command exits `0` with no error. The `orchadyn` and `moduregis` schemas are migrated automatically by `start-services.ps1` after it downloads their release binaries.

### Start the services

```powershell
. .\local.env.ps1
.\start-services.ps1
```

The script builds the two reference adapters from `../../adapters/` (with `GOWORK=off`), starts every service, and waits for each health endpoint. Expected final line:

```
All local services are ready.
```

If a service never becomes ready, the script throws with the failing URL; check `.local-logs/` for the specific service log.

## Step 1 — Detect the stockout (Ontovela)

**Purpose.** Establish the authoritative operational fact that the order promise is at risk. No product may act on this fact without a case (Step 2).

**Request 1a — bind the source.**
```
POST http://localhost:8082/v1/source-bindings
Header: X-Tenant-ID: tenant-a
Body:
{"id":"inventory-order-status","source":"inventory","property":"fulfillment_status","authority_rank":10,"max_lag_seconds":60}
```
This tells Ontovela that the `inventory` source is authoritative (`authority_rank: 10`) for `fulfillment_status` and that its observations must be fresher than 60 seconds.

**Request 1b — record the observation.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: order-123-stockout-v1
Body:
{"id":"assertion-order-123-stockout","subject_id":"order-123","property":"fulfillment_status",
 "value":"stockout","state_kind":"observed","event_time":"2026-08-15T12:00:00Z",
 "system_time":"2026-08-15T12:00:01Z","source":"inventory","evidence_ref":"evidence://inventory/order-123"}
```

**Request 1c — resolve the twin state.**
```
GET http://localhost:8082/v1/twins/order-123/state/fulfillment_status
Header: X-Tenant-ID: tenant-a
```
The resolved value is the latest state trusted under the source binding.

**What to notice.** The observation is *evidence-bearing*: it carries an `evidence_ref`, event time, and system time. Later steps never re-assert the fact; they cite it. This is the seed of the audit trail.

## Step 2 — Open the human exception case (Symbivela)

**Purpose.** Create the human authority that gates every change to the order. Until this case exists, **no product may change the order**.

**Request 2a — create the workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: operations-lead,
         Idempotency-Key: order-ops-workspace-v1
Body:
{"workspace_id":"order-ops","name":"Order Operations","owner_id":"operations-lead"}
```
The workspace grants `operations-lead` case-operation authority.

**Request 2b — open the exception case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: operations-lead,
         Idempotency-Key: order-123-case-v1
Body:
{"workspace_id":"order-ops","case_id":"order-123-stockout","subject_ref":"order://order-123",
 "problem":"Assigned warehouse has no inventory for the promised item.",
 "evidence_refs":"evidence://inventory/order-123",
 "candidate_actions":"alternate-location,split-shipment,approved-substitute",
 "deadline":"2026-08-16T12:00:00Z"}
```

**Response fields read by the script:** `case_id` and `status` (expected `open`).

**What to notice.** The case is the *control surface*, not a log. It names the accountable actor, the permitted `candidate_actions`, the evidence that supports it, and a deadline. Everything that follows is authorized through this case.

## Step 3 — Generate a verified replan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation for resolving the exception. A plan is *not* an authorization.

**Input file — `order-exception-plan.json`.** It defines:

- **Goal:** `goal-order-123-fulfilled` owned by `operations-lead` — *"order-123 fulfilled without an unapproved customer promise change"*.
- **Requirements:** source from an approved location, then fulfill.
- **Catalog:** `cap-alternate-location` (`order.sourcing`, cost 10) and `cap-fulfill` (`order.fulfillment`, cost 20), both region `warehouse-b`.
- **Constraints:** hard `region = warehouse-b` and hard budget ceiling 50.
- **Delegation:** `operations-lead` inherits `order.fulfillment` from `order-owner` and is delegated `order.sourcing`, with budget ceiling 50 and `evidenceDuty: ["approval://order-123-stockout"]`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of order-exception-plan.json)
```

**Response fields read by the script:** `plan.nodes` (capability ids), `plan.totalCost`, and `violations`.

**What to notice.** Three subtleties:

1. The plan is bounded by **hard constraints** (region, budget) and a **delegation chain** with an evidence duty — the plan can only recommend what the authority structure permits.
2. The goal itself forbids an *unapproved* promise change, so even a correct plan still waits for a human decision.
3. If `$OrchadynBinary` is `$null`, the demo runs without plan generation and reports "skip plan generation" — the scenario stays complete, proving the governance chain does not depend on any single product.

## Step 4 — Create the durable exception process (Rheovela)

**Purpose.** Wrap the resolution in a recoverable, approvable process so the work survives restarts and stays auditable.

**Input file — `order-exception.json`.** Defines the `order-exception` approval workflow with stages:

```
validate  (role order-operations)  -> approve (role operations-lead)
approve   (role operations-lead)   -> execute (capability order.exception.execute)
execute   (capability)             -> close   (role order-operations)
```

**CLI — validate and define the workflow.**
```powershell
rheo workflow validate order-exception.json
rheo workflow define --file order-exception.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"order-exception","project":"order-123","actor":"operations-lead"}
```

**Response fields read by the script:** `instance.id`.

**What to notice.** The workflow is *capability-gated*: the `execute` stage requires `order.exception.execute`. Durable process plus capability gating means the approved action cannot be executed outside the process, and the whole resolution survives restarts.

## Step 5 — Reserve inventory at the alternate warehouse (inventory-domain adapter)

**Purpose.** Show that even a supporting system change requires the same approval — the reserve is not a private action.

**Request.**
```
POST http://localhost:8091/v1/inventory/sku-inspection-kit
Body:
{"warehouse":"warehouse-b","delta":-1,"reason":"reserve stock for order-123",
 "approved_by":"operations-lead","approval_ref":"approval://order-123-stockout",
 "idempotency_key":"inventory-order-123-reserve-v1"}
```

**Response fields read by the script:** `adjustment.id` and `adjustment.approval_ref`; the script then re-reads `GET /v1/inventory/sku-inspection-kit` to confirm `warehouse-b` availability dropped from 10 to 9.

**What to notice.** Two behaviors:

1. The adapter **requires** `approved_by` and `approval_ref` — it has no unauthored path. An unapproved reserve is rejected before touching stock.
2. The reserve is **idempotent** (same `idempotency_key` replays without double-reserving) and **cannot go negative** (a delta beyond availability returns HTTP 422).

## Step 6 — Record an auditable handoff (Praxovela)

**Purpose.** Record, under a deny-by-default policy, the fact that the remaining external actions are performed by an authorized operator in the organization's business systems.

**Boundaries — `praxovela-boundaries.yaml` and `praxovela-policy.yaml`.** Network is `allow: false`; the policy allows exactly two local operations:

```yaml
rules:
  - capability_id: file.write
    resource: ...\.praxovela\order-123-stockout-handoff.json
    risk: medium
    actor_id: axon-core
    action: allow
  - capability_id: file.read
    resource: ...\.praxovela\order-123-stockout-handoff.json
    risk: low
    actor_id: axon-core
    action: allow
```

**Request — open a session.**
```
POST http://127.0.0.1:8420/v1/sessions
Body:
{"workspace":"order-fulfillment-local","message":"Record order-123 stockout handoff"}
```
Response: `session_id`.

**Request — write the handoff.**
```
POST http://127.0.0.1:8420/v1/agent/tools/execute
Body (call object):
{"session_id":"<session_id>",
 "call":{"call_id":"order-123-stockout-handoff-v1","name":"file.write","operation":"write",
         "resource":"...\.praxovela\order-123-stockout-handoff.json","risk":"medium",
         "reason":"Record the approved manual order-exception handoff.",
         "idempotency_key":"order-123-stockout-handoff-v1",
         "input":{"path":"...\.praxovela\order-123-stockout-handoff.json",
                  "content":"{\"order_id\":\"order-123\",\"exception_case_id\":\"order-123-stockout\",\"status\":\"escalated\",\"action\":\"manual-external-order-action-required\",\"note\":\"An authorized operator performs the approved action in the business system.\"}\n"}}}
```

**Request — read it back to verify.** The same endpoint with `file.read` on the same resource.

**What to notice.** This is deny-by-default in action: the runtime holds the policy file path in its policy, network is disabled, and only the single handoff file is reachable. The **effect ledger** records what was touched and what was *not* exposed — the agent could not have touched anything else even if asked.

## Step 7 — Show the governance effect, then apply the approved action (order-domain adapter)

**Purpose.** Prove the adapter enforces approval, then apply the operator's approved decision.

**Request 7a — attempt an *unapproved* action (expect rejection).**
```
POST http://localhost:8090/v1/orders/order-123/fulfillment-actions
Body:
{"action":"alternate_location","approved_by":"","approval_ref":"",
 "idempotency_key":"order-123-unapproved-v1"}
```
The adapter responds `400 Bad Request` with:
```json
{"error":"action_approved_by_approval_ref_and_idempotency_key_are_required"}
```

**Request 7b — apply the *approved* action.**
```
POST http://localhost:8090/v1/orders/order-123/fulfillment-actions
Body:
{"action":"alternate_location","approved_by":"operations-lead",
 "approval_ref":"approval://order-123-stockout",
 "idempotency_key":"order-123-alternate_location-v1"}
```

**Response fields read by the script:** `action.action`, `action.approval_ref`, `order.fulfillment_status`, and `order.warehouse`. After `alternate_location`, the order moves to `fulfillment_status = replanned` at `warehouse-b`, `carrier_status = awaiting_dispatch`, and a pending customer notification is added.

**What to notice.** The rejection and the success are *both* part of the demo's value:

1. The adapter has **no bypass path** — an empty approval is not treated as "no approval required".
2. The approved action carries the **exact approval reference** (`approval://order-123-stockout`) that Step 2's case and Step 3's delegation both cite, so the state change is traceable to the human decision.

## Step 8 — Verify the outcome and emit the value report

**Purpose.** Confirm the final state and reconstruct the whole story from per-product evidence.

**Requests.**
```
GET http://localhost:8090/v1/orders/order-123            -> final order
GET http://localhost:8090/v1/notifications/order-123     -> pending notification
```

**Outputs written to `.local-data/`:**
- `order-outcome.json` — the business outcome (final order state, notifications, steps).
- `order-value-report.json` — the machine-readable value report (example, outcome, KPIs, gates, evidence, steps).

**What to notice.** The audit trail is **not one artifact but a chain**: Ontovela assertion + Symbivela case + Orchadyn plan + Rheovela instance + Praxovela effect ledger + inventory reservation + order action + notification. Each product owns one link; together they reconstruct the decision, the approval, and the effect.

## Output Artifacts

All artifacts are written to `.local-data/`.

### `order-outcome.json`

The business outcome. Example after a successful `alternate_location`:

```json
{
  "order_id": "order-123",
  "tenant": "tenant-a",
  "operator": "operations-lead",
  "steps": [
    {"index": 1, "title": "Detect the stockout", "product": "ontovela", "artifact": "assertion-order-123-stockout"},
    {"index": 2, "title": "Open the human exception case", "product": "symbivela", "artifact": "order-123-stockout"},
    {"index": 3, "title": "Generate a verified replan", "product": "orchadyn", "artifact": "plan-order-123"},
    {"index": 4, "title": "Create the durable exception process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 5, "title": "Reserve inventory at the alternate warehouse", "product": "inventory-domain", "artifact": "adjustment-inventory-order-123-reserve-v1"},
    {"index": 6, "title": "Record an auditable handoff", "product": "praxovela", "artifact": "order-123-stockout-handoff-v1"},
    {"index": 7, "title": "Approve and apply the fulfillment action", "product": "order-domain", "artifact": "action-order-123-alternate_location-v1"},
    {"index": 8, "title": "Verify the outcome", "product": "order-domain", "artifact": "order-outcome.json"}
  ],
  "order_state": {
    "id": "order-123", "sku": "sku-inspection-kit", "quantity": 1,
    "warehouse": "warehouse-b", "fulfillment_status": "replanned",
    "payment_status": "authorized", "carrier_status": "awaiting_dispatch",
    "notifications": ["customer-notification-pending:action-order-123-alternate_location-v1"],
    "actions": [
      {"id": "action-order-123-alternate_location-v1", "action": "alternate_location",
       "approved_by": "operations-lead", "approval_ref": "approval://order-123-stockout",
       "idempotency_key": "order-123-alternate_location-v1", "occurred_at": "<timestamp>"}
    ]
  },
  "notifications": ["customer-notification-pending:action-order-123-alternate_location-v1"]
}
```

### `order-value-report.json`

The machine-readable value report. Example:

```json
{
  "example": "order-fulfillment-exception",
  "version": "1.0",
  "tenant": "tenant-a",
  "operator": "operations-lead",
  "outcome": {"subject": "order-123", "before": "stockout", "after": "replanned",
              "warehouse": "warehouse-b", "completed": true, "escalated": false},
  "kpis": {"products_involved": 7, "gates_passed": 2, "evidence_artifacts": 8,
           "steps_completed": 8, "time_to_resolve": "1.4"},
  "gates": [
    {"gate": "case-opened", "owner": "operations-lead", "decision": "open"},
    {"gate": "action-approved", "owner": "operations-lead", "decision": "alternate_location",
     "approval_ref": "approval://order-123-stockout"}
  ],
  "evidence": [
    {"product": "ontovela", "artifact": "assertion-order-123-stockout", "state": "observed"},
    {"product": "symbivela", "artifact": "order-123-stockout", "state": "open"},
    {"product": "rheovela", "artifact": "<instance-id>", "state": "open"},
    {"product": "inventory-domain", "artifact": "adjustment-inventory-order-123-reserve-v1", "state": "reserved"},
    {"product": "praxovela", "artifact": "order-123-stockout-handoff-v1", "state": "effect-ledgered"},
    {"product": "order-domain", "artifact": "unapproved-action-rejected", "state": "denied"},
    {"product": "order-domain", "artifact": "action-order-123-alternate_location-v1", "state": "replanned"},
    {"product": "order-domain", "artifact": "notification-order-123", "state": "pending"}
  ],
  "steps": []
}
```

See [evidence-schema.md](evidence-schema.md) for the field contract.

## Seed Data and Idempotency

The demo starts from fixed seed data so every run is reproducible:

- **Order** (`order-123`): `sku = sku-inspection-kit`, `quantity = 1`, `warehouse = warehouse-a`, `fulfillment_status = stockout`, `payment_status = authorized`, `carrier_status = not_dispatched`.
- **Inventory** (`sku-inspection-kit`): `warehouse-a = 0` available, `warehouse-b = 10` available.
- **Plan** (`order-exception-plan.json`): goal, two requirements, two catalog capabilities (cost 10 and 20), hard region/budget constraints, and a delegation chain with evidence duty.
- **Workflow** (`order-exception.json`): `validate → approve → execute → close` with role and capability assignments.

**Idempotency.** Every mutating call carries a stable key:

| Call | Key |
| --- | --- |
| Ontovela assertion | `order-123-stockout-v1` |
| Symbivela workspace | `order-ops-workspace-v1` |
| Symbivela case | `order-123-case-v1` |
| Inventory reservation | `inventory-order-123-reserve-v1` |
| Praxovela handoff | `order-123-stockout-handoff-v1` |
| Order action | `order-123-<action>-v1` |

Re-running the demo replays each call without duplicating artifacts: the order adapter returns `"replayed": true`, the inventory adapter applies the adjustment once, and Symbivela/Ontovela accept the stable keys.

## Verification and Troubleshooting

### Verify the outcome

```powershell
.\verify.ps1
```

`verify.ps1` runs ten assertions: report identifies the example, order moved off `stockout`, outcome marked completed, fulfillment at `warehouse-b`, at least 6 products involved, at least 1 gate, at least 6 evidence artifacts, all 8 steps, governance-denial evidence present, `action-approved` gate recorded, and a pending notification. It prints `VERIFY OK` and exits `0`, or lists the failing checks and exits `1`.

### One-command run

```powershell
.\run-all.ps1
```

This loads `local.env.ps1`, starts services, runs the scenario, and verifies the outcome in sequence.

### Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Binary not found: ...` | Product checkout path wrong | Correct the path in `local.env.ps1`. |
| `Service did not become ready: ...` | Database missing or port busy | Confirm `symbivela`/`orchadyn`/`moduregis` databases; check `.local-logs/`. |
| `GET /ready` not `{"postgres":"ok"}` | Symbivela cannot reach PostgreSQL | Fix `$env:DATABASE_URL`. |
| Orchadyn step prints "skip plan generation" | `$OrchadynBinary = $null` | Set it to a downloaded release to enable plan generation. |
| Order adapter returns `400 ...required` | Missing `approved_by`/`approval_ref` | This is the *expected* governance denial; supply the approved values. |
| Value report missing | Scenario did not reach step 8 | Run `run-order-exception.ps1` fully; check `.local-logs/`. |
