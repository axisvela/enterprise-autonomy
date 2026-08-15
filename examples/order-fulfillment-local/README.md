# Local-Binary Order Fulfillment Exception Demo

A stockout on `order-123` triggers an end-to-end exception workflow across six AxisRobo products. Each step is executed against real local binaries and produces an observable business artifact, not just a test call.

## What You Get From Running It

The run script prints a **step-by-step business report** and writes `.local-data/order-outcome.json`. You can see:

- **Order lifecycle**: how `order-123` moves from `stockout` at `warehouse-a` to a fulfilled state at an alternate location.
- **The governance chain**: who opened the case, which plan was approved, which approval reference authorized the change, and what evidence each product recorded.
- **The division of authority**: no single product changes the order; each contributes one governed step (observe, review, plan, process, handoff, execute).
- **The audit trail**: one assertion, one case, one plan, one process instance, one effect-ledger entry, and one order action that together reconstruct the whole story.

## The Scenario In Business Terms

1. **Detect** — inventory reports `stockout` for the order.
2. **Review** — an operator opens a governed exception case; nothing may change the order without it.
3. **Replan** — a verified alternate-fulfillment plan is generated (recommendation only).
4. **Process** — a durable exception process is opened so the resolution survives restarts.
5. **Handoff** — Praxovela records the operator's action under a deny-by-default policy.
6. **Approve and act** — the operator applies the approved fulfillment action to the order adapter.
7. **Verify** — final order state and pending customer notification are confirmed.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection for Symbivela | All listed local services reachable and healthy |
| Record stockout | Order ID, inventory source, observed status | Ontovela assertion and resolved state |
| Create workspace and open case | Order-operations workspace, order reference, problem, permitted alternatives | Workspace owned by the operator and Symbivela case in `open` state |
| Start process | Case ID and actor | Rheovela `order-exception` instance |
| Generate replan | Order goal, capability catalog, constraints | Verified Orchadyn plan and violation report |
| Apply approved action | Action, approver, approval reference | Persisted order, carrier, and notification state in the local adapter |
| Human decision | Selected action and required approval | Case moves to `resolving`, then `resolved` or `escalated` |

The demo intentionally does **not** update an order-management, inventory, carrier, payment, or customer-notification system. No locally implemented adapter for those systems was found. The operator must complete those actions in the organization's authorized business systems and attach the resulting references to the case.

## Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`
- Local checkout directories for `LIMENORA-open`, `ONTOVELA`, `RHEOVELA`, `SYMBIVELA`, and `PRAXOVELA`
- A running PostgreSQL 18 instance (for example `D:\app\PostgreSQL\18` on port `5433`), with databases `symbivela`, `orchadyn`, and `moduregis` available
- The verified binaries: `limenora-edge.exe`, `ontovela.exe`, `rheo.exe`, and `symbivela.exe`
- Optional: Orchadyn runs from the `axisrobo/orchadyn-open` v0.7.0 release, which the start script downloads on demand; Moduregis releases are downloaded on demand from v1.0.1

Copy `local.env.ps1.example` to `local.env.ps1`, then set your checkout root and the PostgreSQL 18 connection strings. `$OrchadynSource` points at the ORCHADYN checkout used for migration files; set `$OrchadynBinary = $null` to run without Orchadyn. Do not commit `local.env.ps1`.

Prepare the `symbivela` schema once on the PostgreSQL 18 instance:

```powershell
$env:DATABASE_URL = "postgres://symbivela:symbivela@localhost:5433/symbivela?sslmode=disable"
Push-Location D:\profile\paper-code\SYMBIVELA\backend
$env:GOWORK = "off"
go run ./cmd/symbivela-migrate
Pop-Location
```

The `orchadyn` schema is migrated automatically by the start script after it downloads the release binaries and copies `backend/migrations` from `$OrchadynSource`.

## Start The Services

Open PowerShell in this directory and run:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

The script starts:

| Service | Local address | Health check |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Order-domain adapter | `http://localhost:8090` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

`GET /ready` must return `{"status":"ready","postgres":"ok"}` before running the scenario. Logs are written to `.local-logs/`.

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-order-exception.ps1
```

The script runs the seven business steps, prints a human-readable report for each, and ends with an outcome summary showing the order transition, the approval used, and the audit trail. It also writes `.local-data/order-outcome.json`.

The `order-ops` workspace is created with `$Actor` as its owner so that actor has case-operation authority. Praxovela runs fail-closed: its policy allows only reading and writing the single handoff file under `.praxovela/`.

To inspect live state yourself:

```powershell
curl.exe -H "X-Tenant-ID: $TenantId" "http://localhost:8082/v1/twins/order-123/state/fulfillment_status"
curl.exe -H "X-SYMBIVELA-Tenant: $TenantId" -H "X-SYMBIVELA-Actor: $Actor" "http://localhost:8080/v1/exception-cases/order-123-stockout"
curl.exe "http://localhost:8090/v1/orders/order-123"
```

## Complete The Human Operation

1. Review the stockout assertion and the Orchadyn plan, and confirm the inventory view before approving an action.
2. Set `$OrderAction` and `$OrderApprovalRef` in `local.env.ps1` after the responsible person approves the action.
3. Run the scenario. The adapter accepts only an action with `approved_by`, `approval_ref`, and an idempotency key, then persists the resulting order, carrier, and notification state.
4. Inspect `GET http://localhost:8090/v1/orders/order-123` and `GET http://localhost:8090/v1/notifications/order-123` before marking the case resolved.
5. Replace this reference adapter and any local Orchadyn database with authorized production integrations before real business use.

## Stop The Demo

Stop the four processes shown in `.local-logs/` or close the PowerShell sessions that started them. The example uses in-memory Ontovela state and a local Rheovela database path; remove `.local-data/` only when you intentionally want to discard the demo data.
