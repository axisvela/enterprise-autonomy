# Local-Binary Procurement Request-To-Receipt Demo

`preq-0001` for `desk-chair-ergo` runs a governed purchasing lifecycle: submit, case, budget context, segregated approvals, durable process, sourcing plan, purchase, and receipt. The demo runs against real local binaries plus the procurement-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/procurement-outcome.json` and `.local-data/procurement-value-report.json`. You can see:

- **The purchasing lifecycle**: how `preq-0001` moves from `draft` to `closed` with a purchase order and a receipt.
- **Segregation of duties**: the requester's self-approval is rejected before any approval is recorded.
- **The approval chain**: finance approves the budget, procurement approves the supplier, and both must be present before a purchase.
- **The division of authority**: no single product purchases; each contributes one governed step.
- **The audit trail**: submit action + case + budget assertion + approvals + process + plan + PO + receipt.

## The Scenario In Business Terms

1. **Submit** — the requester submits `preq-0001` against a cost center and budget.
2. **Review** — the procurement owner opens a governed case.
3. **Context** — the budget is recorded as available in the world model.
4. **Approve** — finance approves the budget and procurement approves the supplier; self-approval is denied.
5. **Process** — a durable request-to-receipt process is opened.
6. **Plan** — a verified sourcing plan is generated (recommendation only).
7. **Purchase** — the approved purchase issues PO `po-preq-0001-supplier-b`; unapproved purchases are rejected.
8. **Receive and close** — receipt is confirmed, the request closes, and the value report is emitted.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Submit request | Requester, idempotency key | Request `submitted` |
| Open case | Procurement workspace, request reference, problem | Symbivela case `preq-0001-purchase` in `open` state |
| Record budget | Budget assertion, evidence ref | Ontovela assertion + budget availability |
| Approve (segregation) | Self-approval attempt | Adapter rejects with HTTP 403 |
| Approve budget and supplier | Two role approvals under one reference | Request `approved` |
| Start process | Workflow definition, actor | Rheovela `procurement-request-to-receipt` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Execute purchase | Approved purchase, approval ref | PO `po-preq-0001-supplier-b`, status `ordered` |
| Receive and close | Receiver, accepted flag | Receipt recorded, request `closed`, PO `received` |
| Emit value report | Evidence and gates from all steps | `.local-data/procurement-value-report.json` |

## Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`
- Local checkout directories for `LIMENORA-open`, `ONTOVELA`, `RHEOVELA`, `SYMBIVELA`, and `PRAXOVELA`
- A running PostgreSQL 18 instance with databases `symbivela`, `orchadyn`, and `moduregis`
- The verified binaries: `limenora-edge.exe`, `ontovela.exe`, `rheo.exe`, and `symbivela.exe`
- Optional: Orchadyn v0.7.0 and Moduregis v1.0.1 downloads on demand

Copy `local.env.ps1.example` to `local.env.ps1` and set your checkout root and connection strings. Do not commit `local.env.ps1`.

## Start The Services

```powershell
. .\local.env.ps1
.\start-services.ps1
```

| Service | Local address | Health check |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Procurement-domain adapter | `http://localhost:8092` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-procurement.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8092/v1/requests/preq-0001"
curl.exe "http://localhost:8092/v1/budget/budget-0001"
curl.exe "http://localhost:8092/v1/pos/po-preq-0001-supplier-b"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A governed purchase completes within budget with segregation of duties and a recorded approval chain. |
| KPIs | Products involved, gates passed, evidence artifacts, steps completed, time-to-resolve. |
| Decision gates | Case opened (procurement owner), budget approved (finance), supplier approved (procurement), purchase executed. |
| Evidence produced | Submit action, case, budget assertion, two approvals, process instance, plan, PO, receipt. |
| Adoption path | Replace the reference adapter and local databases with authorized systems, then enable one category and spend band. |

See the [value framework](../../docs/example-value.md) and the [procurement domain adapter API](../../adapters/procurement-domain/API.md).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them. Remove `.local-data/` only when you intentionally want to discard the demo data.
