# Local-Binary Simulation To Validation Demo

`proposal-sim-0001` for `automated-zone-inspection` runs a governed possible-world validation: case, scenario compilation, **evidence-before-decision**, **immutable simulation evidence**, review decision, durable process, validation plan, and release. The demo runs against real local binaries plus the simulation-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/simulation-outcome.json` and `.local-data/simulation-value-report.json`. You can see:

- **The validation lifecycle**: how `proposal-sim-0001` moves from `proposed` to `released` through scenarios, immutable evidence, and a review decision.
- **Evidence before decision**: a review decision before any simulation run is rejected.
- **Immutable evidence**: a second simulation run is rejected once evidence is recorded.
- **Review-group authority**: only designated reviewers may decide.
- **Approval-gated release**: release requires the exact decision reference.
- **The division of authority**: no single product releases; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** — the reviewer opens a governed validation case.
2. **Compile** — the simulation engineer compiles scenarios and the scope is asserted.
3. **Evidence gate** — a decision before evidence is rejected.
4. **Record** — the immutable simulation run is recorded; a second run is rejected.
5. **Decide** — the reviewer approves; a non-member decision is rejected.
6. **Process** — a durable validation process is opened.
7. **Plan** — a verified validation plan is generated (recommendation only).
8. **Release** — the proposal releases only after the approve decision citing the exact reference.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Validation workspace, proposal fields | Symbivela case `sim-0001-validation` in `open` state |
| Compile scenarios | Scenario fields, scope assertion | Scenario `scn-collision` + scope assertion |
| Evidence gate | Decision before evidence attempt | Adapter rejects with HTTP 403 |
| Record run | Run id, outcome, evidence ref | Immutable run `run-run-001`, proposal `evidence` |
| Immutability gate | Second run attempt | Adapter rejects with HTTP 409 |
| Review decision | Reviewer, rationale, decision ref | Proposal `decided` |
| Non-member gate | Non-member decision attempt | Adapter rejects with HTTP 403 |
| Start process | Workflow definition, actor | Rheovela `simulation-to-validation` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Release | Released by, exact decision ref | Proposal `released` |
| Release-ref gate | Wrong decision reference | Adapter rejects with HTTP 403 |
| Emit value report | Evidence and gates from all steps | `.local-data/simulation-value-report.json` |

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
| Simulation-domain adapter | `http://localhost:8097` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-simulation-validation.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8097/v1/proposals/proposal-sim-0001"
curl.exe "http://localhost:8097/v1/runs/run-run-001"
curl.exe "http://localhost:8097/v1/notifications/proposal-sim-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | An autonomous capability is released only after accepted, immutable simulation evidence and a review-group decision. |
| KPIs | Contract pass rate, re-verification coverage, waiver discipline, attestation completeness. |
| Decision gates | Case opened, scenarios compiled, simulation evidence, review decision. |
| Evidence produced | Case, scope assertion, scenario, immutable run, decision, release, denial records. |
| Adoption path | Evaluate one bounded operation; expand only after the review group accepts simulated evidence. |

See the [value framework](../../docs/example-value.md) and the [simulation domain adapter API](../../adapters/simulation-domain/API.md).

## Governance Patterns

This demo demonstrates the integrity layer plus **evidence-gated release** and **immutable simulation evidence** of the governance-pattern catalog (maintained in the private **`enterprise-autonomy-ee`** repository).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
