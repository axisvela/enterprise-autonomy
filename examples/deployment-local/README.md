# Local-Binary Sequenced-Deployment Demo

`dep-0001` for the `release-pipeline` workflow runs a governed sequenced release lifecycle: case, pipeline context, **sequence gate**, **evidence-cited autonomous steps**, **deviation gate**, durable process, pipeline plan, and **immutable release**. The demo runs against real local binaries plus the deployment-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/deployment-outcome.json` and `.local-data/deployment-value-report.json`. You can see:

- **The sequenced release lifecycle**: how `dep-0001` moves from `initiated` through `checkout → build → test → approve → production` to `released`.
- **Sequence integrity**: an out-of-sequence step is rejected.
- **Evidence-cited execution**: each autonomous step cites the evidence it produced.
- **Approval-required deviations**: an unapproved pause is rejected.
- **Released immutability**: a released deployment cannot be re-run.
- **The division of authority**: no single product releases the deployment; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** — the release lead opens a governed deployment case.
2. **Context** — the pipeline state is asserted with evidence.
3. **Sequence gate** — an out-of-sequence step is rejected.
4. **Execute** — autonomous steps advance the pipeline, each citing evidence.
5. **Deviation gate** — an unapproved pause is rejected.
6. **Durable wrap** — the deployment is wrapped in a durable Rheovela instance.
7. **Plan** — a verified deployment plan is generated (recommendation only).
8. **Release** — the pipeline reaches the terminal step; a re-run is rejected.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Deployment workspace, pipeline fields | Symbivela case `dep-0001-release` in `open` state |
| Record context | Pipeline assertion, evidence ref | Ontovela pipeline assertion + deployment view |
| Sequence gate | Out-of-sequence step attempt | Adapter rejects with HTTP 409 |
| Execute steps | Three evidence-cited autonomous steps | Deployment at `test` / `in-flight` |
| Deviation gate | Unapproved pause attempt | Adapter rejects with HTTP 403 |
| Wrap durably | Workflow definition, actor | Rheovela `sequenced-deployment` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Release | Final step evidence | Deployment `released` |
| Immutability gate | Re-run after release | Adapter rejects with HTTP 409 |
| Emit value report | Evidence and gates from all steps | `.local-data/deployment-value-report.json` |

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
| Deployment-domain adapter | `http://localhost:8102` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-sequenced-deployment.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8102/v1/deployments/dep-0001"
curl.exe "http://localhost:8102/v1/notifications/dep-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A release pipeline advances autonomously, strictly in sequence and citing evidence, while deviations require human approval and the released deployment stays immutable. |
| KPIs | Sequence compliance, evidence coverage, deviation approvals, release immutability. |
| Decision gates | Case opened, pipeline sequenced, deviation review, release acceptance. |
| Evidence produced | Case, pipeline assertion, five step executions, denial records. |
| Adoption path | Start with a single low-risk pipeline; expand after measuring sequence compliance and deviation reviews. |

See the [value framework](../../docs/example-value.md) and the [deployment domain adapter API](../../adapters/deployment-domain/API.md).

## Governance Patterns

This demo demonstrates the integrity layer plus **sequenced autonomous execution** (in-order gating, evidence-cited steps, step immutability, approval-required deviations, released-immutability) of the governance-pattern catalog (maintained in the private **`enterprise-autonomy-ee`** repository).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
