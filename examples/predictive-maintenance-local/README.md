# Local-Binary Predictive Maintenance To Work Order Demo

`signal-pm-0001` for `Cooling Pump 01` runs a governed maintenance lifecycle: case, risk context, **prediction-vs-fact validation**, maintenance decision, **safety review**, durable process, maintenance plan, and work order. The demo runs against real local binaries plus the maintenance-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/maintenance-outcome.json` and `.local-data/maintenance-value-report.json`. You can see:

- **The maintenance lifecycle**: how a `pending` risk signal becomes a scheduled work order through validation, decision, and safety review.
- **Prediction is not a fault**: a work order on an unvalidated signal is rejected before anything schedules.
- **Safety is conjunctive**: intrusive work requires both a maintenance decision and an approved safety review.
- **The division of authority**: no single product intervenes; each contributes one governed step.
- **The audit trail**: case + signal validation/decision/safety + asset assertion + process + plan + work order.

## The Scenario In Business Terms

1. **Open** — the maintenance manager opens a governed case.
2. **Context** — the elevated risk signal and asset state are asserted.
3. **Prediction gate** — a work order on an unvalidated signal is rejected.
4. **Validate and decide** — the maintenance manager validates the signal and records a `repair` decision; an unconfirmed `stop` is rejected.
5. **Safety review** — the safety authority approves intrusive work; without it the work order is rejected.
6. **Process** — a durable maintenance process is opened.
7. **Plan** — a verified maintenance plan is generated (recommendation only).
8. **Schedule** — the approved, safety-reviewed work order is created and the value report is emitted.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Maintenance workspace, signal fields | Symbivela case `pm-0001-intervention` in `open` state |
| Record context | Risk assertion, evidence ref | Ontovela asset-risk assertion + signal view |
| Prediction gate | Work order on unvalidated signal | Adapter rejects with HTTP 403 |
| Validate + decide | Maintenance manager validation, repair decision | Signal `validated`, decision `repair` |
| Unconfirmed-stop gate | `stop` decision on unconfirmed signal | Adapter rejects with HTTP 403 |
| Safety review | Safety authority approval | Safety review `approve` |
| No-safety gate | Work order without safety review | Adapter rejects with HTTP 403 |
| Start process | Workflow definition, actor | Rheovela `predictive-maintenance-to-work-order` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Schedule work order | Validated + decided + safety-approved scope | Work order `wo-pm-wo-v1`, status `scheduled` |
| Emit value report | Evidence and gates from all steps | `.local-data/maintenance-value-report.json` |

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
| Maintenance-domain adapter | `http://localhost:8095` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-predictive-maintenance.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8095/v1/signals/signal-pm-0001"
curl.exe "http://localhost:8095/v1/assets/asset-pump-01"
curl.exe "http://localhost:8095/v1/workorders/wo-pm-wo-v1"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | An equipment risk signal leads to an approved, safety-reviewed intervention without treating a prediction as a confirmed fault. |
| KPIs | Signal-to-intervention, gate compliance, evidence quality, false-alarm handling. |
| Decision gates | Case opened (maintenance manager), signal validated, maintenance decision, safety review. |
| Evidence produced | Case, signal validation/decision/safety, asset assertion, process instance, plan, work order. |
| Adoption path | Pilot on non-critical assets; measure prediction and intervention quality before broader robotic work. |

See the [value framework](../../docs/example-value.md) and the [maintenance domain adapter API](../../adapters/maintenance-domain/API.md).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
