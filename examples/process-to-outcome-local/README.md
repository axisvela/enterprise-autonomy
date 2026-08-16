# Local-Binary Process-To-Outcome Demo

`proc-0001` runs a governed durable long-running process: case, process context, **stage-sequenced advances**, **terminal-state enforcement**, durable wrapper, process plan, and **immutable completion**. The demo runs against real local binaries plus the process-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/process-outcome.json` and `.local-data/process-value-report.json`. You can see:

- **The durable process lifecycle**: how `proc-0001` moves from `initiated` through `request → review → approve → complete` to `completed`.
- **Stage-sequenced gating**: an out-of-order advance is rejected.
- **Terminal-state enforcement**: completion before the terminal stage is rejected.
- **Completed-process immutability**: a reopen after completion is rejected.
- **The division of authority**: no single product reaches the outcome; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** — the operator opens a governed process case.
2. **Context** — the process state is asserted with evidence.
3. **Stage gate** — an out-of-order advance is rejected.
4. **Advance** — the process advances through its sequenced stages with human attribution.
5. **Outcome gate** — completion before the terminal stage is rejected.
6. **Durable wrap** — the process is wrapped in a durable Rheovela instance.
7. **Plan** — a verified process plan is generated (recommendation only).
8. **Complete** — the outcome completes at the terminal stage; a reopen is rejected.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Process workspace, process fields | Symbivela case `proc-0001-outcome` in `open` state |
| Record context | Process assertion, evidence ref | Ontovela process assertion + process view |
| Stage gate | Out-of-order advance attempt | Adapter rejects with HTTP 409 |
| Advance stages | Three sequenced human advances | Process at `complete` / `awaiting-outcome` |
| Outcome gate | Complete before terminal | Adapter rejects with HTTP 403 |
| Wrap durably | Workflow definition, actor | Rheovela `process-to-outcome` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Complete | Completed by | Process `completed` |
| Reopen gate | Advance after completion | Adapter rejects with HTTP 409 |
| Emit value report | Evidence and gates from all steps | `.local-data/process-value-report.json` |

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
| Process-domain adapter | `http://localhost:8100` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-process-to-outcome.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8100/v1/processes/proc-0001"
curl.exe "http://localhost:8100/v1/notifications/proc-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A long-running process reaches its outcome only through sequenced human gates and a terminal state, and stays immutable once completed. |
| KPIs | Gate compliance, stage discipline, terminal-state enforcement, audit reconstructability. |
| Decision gates | Case opened, stage request, stage review, stage approve. |
| Evidence produced | Case, process assertion, three advances, completion, denial records. |
| Adoption path | Start with a single governed process; expand after measuring gate compliance. |

See the [value framework](../../docs/example-value.md) and the [process domain adapter API](../../adapters/process-domain/API.md).

## Governance Patterns

This demo demonstrates the integrity layer plus **durable process lifecycle integrity** (stage-sequenced gating, terminal-state enforcement, completed-process immutability) of the governance-pattern catalog (maintained in the private **`enterprise-autonomy-ee`** repository).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
