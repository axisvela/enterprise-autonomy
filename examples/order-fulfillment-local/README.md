# Local-Binary Order Fulfillment Exception Demo

This runnable example opens a stockout exception for `order-123`. It starts local AxisRobo binaries, records the observed inventory state in Ontovela, opens a human case in Symbivela, creates a durable Rheovela process instance, and uses Praxovela to create and verify an auditable manual-action handoff.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection for Symbivela | Four reachable local services |
| Record stockout | Order ID, inventory source, observed status | Ontovela assertion and resolved state |
| Create workspace and open case | Order-operations workspace, order reference, problem, permitted alternatives | Workspace owned by the operator and Symbivela case in `open` state |
| Start process | Case ID and actor | Rheovela `order-exception` instance |
| Create handoff | Case ID and approved manual action | Praxovela-governed local handoff record |
| Human decision | Selected action and required approval | Case moves to `resolving`, then `resolved` or `escalated` |

The demo intentionally does **not** update an order-management, inventory, carrier, payment, or customer-notification system. No locally implemented adapter for those systems was found. The operator must complete those actions in the organization's authorized business systems and attach the resulting references to the case.

## Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`
- Local checkout directories for `LIMENORA-open`, `ONTOVELA`, `RHEOVELA`, and `SYMBIVELA`
- A running local PostgreSQL instance for Symbivela, with database `symbivela` available
- The verified binaries: `limenora-edge.exe`, `ontovela.exe`, `rheo.exe`, and `symbivela.exe`

Copy `local.env.ps1.example` to `local.env.ps1`, then set your checkout root and PostgreSQL connection string. Do not commit `local.env.ps1`.

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

`GET /ready` must return `{"status":"ready","postgres":"ok"}` before running the scenario. Logs are written to `.local-logs/`.

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-order-exception.ps1
```

The script prints the created assertion, case, process instance, and Praxovela write/read results. Before opening the case it creates the `order-ops` workspace with `$Actor` as its owner, which grants that actor the required case-operation role. Praxovela is fail-closed: its policy allows only reading and writing the single handoff file under `.praxovela/`. Inspect the results manually:

```powershell
curl.exe -H "X-Tenant-ID: $TenantId" "http://localhost:8082/v1/twins/order-123/state/fulfillment_status"
curl.exe -H "X-SYMBIVELA-Tenant: $TenantId" -H "X-SYMBIVELA-Actor: $Actor" "http://localhost:8080/v1/exception-cases/order-123-stockout"
```

## Complete The Human Operation

1. Review the stockout assertion and confirm the external inventory system is the authoritative source.
2. In the organization's order system, review permitted alternatives: alternate location, split shipment, approved substitute, revised promise, refund, or cancellation.
3. Obtain the required customer or managerial approval before changing a promise, price, refund, or cancellation.
4. Update the authorized business systems manually and retain their transaction references.
5. Move the case to `resolved` only after the final order state and customer communication have been verified. Use `escalated` when no permitted alternative exists.

## Stop The Demo

Stop the four processes shown in `.local-logs/` or close the PowerShell sessions that started them. The example uses in-memory Ontovela state and a local Rheovela database path; remove `.local-data/` only when you intentionally want to discard the demo data.
