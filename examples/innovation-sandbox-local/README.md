# Local-Binary Innovation Sandbox To Policy Demo

`proposal-sandbox-0001` for `batch-report-generation` runs a governed innovation lifecycle: case, sandbox context, **sandbox boundary**, **evidence-based policy decision**, durable process, sandbox plan, and **immutable policy apply**. The demo runs against real local binaries plus the sandbox-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/sandbox-outcome.json` and `.local-data/sandbox-value-report.json`. You can see:

- **The innovation lifecycle**: how the proposal moves from `proposed` through `experimenting` to `released`.
- **Sandbox boundary**: an experiment outside the sandbox scope is rejected.
- **Evidence-based policy**: a policy decision before experiment evidence is rejected.
- **Designated reviewer**: only review-group members may decide.
- **Immutable policy**: a recorded policy decision cannot be changed.
- **The division of authority**: no single product sets policy; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** — the reviewer opens a governed sandbox case.
2. **Context** — the sandbox scope is asserted with evidence.
3. **Sandbox gate** — an out-of-scope experiment is rejected.
4. **Policy gate** — a decision before experiment evidence is rejected.
5. **Explore** — a sandbox experiment is recorded inside the scope.
6. **Process** — a durable sandbox process is opened.
7. **Plan** — a verified sandbox plan is generated (recommendation only).
8. **Decide and apply** — the reviewer records the policy and applies it; a second decision is rejected.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Sandbox workspace, proposal fields | Symbivela case `sand-0001-policy` in `open` state |
| Record context | Scope assertion, evidence ref | Ontovela sandbox-scope assertion + proposal view |
| Sandbox gate | Out-of-scope experiment | Adapter rejects with HTTP 403 |
| Policy gate | Decision before evidence | Adapter rejects with HTTP 403 |
| Explore | In-scope experiment | Proposal `experimenting` |
| Start process | Workflow definition, actor | Rheovela `innovation-sandbox-to-policy` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Decide | Reviewer policy decision | Proposal `decided` |
| Immutability gate | Second policy decision | Adapter rejects with HTTP 409 |
| Apply | Applied by, policy ref | Proposal `released`, applied=true |
| Emit value report | Evidence and gates from all steps | `.local-data/sandbox-value-report.json` |

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
| Sandbox-domain adapter | `http://localhost:8101` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-innovation-sandbox.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8101/v1/proposals/proposal-sandbox-0001"
curl.exe "http://localhost:8101/v1/notifications/proposal-sandbox-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A proposed capability is explored inside a sandbox and reaches policy only on experiment evidence, with an immutable decision. |
| KPIs | Boundary compliance, evidence-before-policy, reviewer discipline, policy immutability. |
| Decision gates | Case opened, sandbox scoped, experiment evidence, policy decision. |
| Evidence produced | Case, scope assertion, experiment, decision, apply, denial records. |
| Adoption path | Pilot with a low-impact capability before expanding the sandbox. |

See the [value framework](../../docs/example-value.md) and the [sandbox domain adapter API](../../adapters/sandbox-domain/API.md).

## Governance Patterns

This demo demonstrates the integrity layer plus **sandbox boundary**, **evidence-based policy**, **designated reviewer**, and **immutable policy** of the governance-pattern catalog (maintained in the private **`enterprise-autonomy-ee`** repository).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
