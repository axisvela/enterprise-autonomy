# Local-Binary Fleet Mission Exception Demo

`mission-alpha-001` for `inspect racks` runs a governed physical mission: case, mission context, **autonomous boundary enforcement**, **pause-and-review**, durable process, mission plan, operator review, and completion. The demo runs against real local binaries plus the fleet-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/fleet-outcome.json` and `.local-data/fleet-value-report.json`. You can see:

- **The mission lifecycle**: how `mission-alpha-001` moves from `planned` to `completed` through start, boundary enforcement, exception, operator review, and completion.
- **Autonomous boundary enforcement**: out-of-boundary telemetry is frozen without human involvement.
- **Pause-and-review**: an exception always pauses; resume requires an operator review with an approval reference.
- **Operator-gated**: only the mission operator may start or review.
- **The division of authority**: no single product flies the mission; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** â€?the operator opens a governed mission case.
2. **Context** â€?the mission boundary is asserted with evidence.
3. **Start and enforce** â€?the mission starts; out-of-boundary telemetry is frozen, in-bound telemetry proceeds.
4. **Pause** â€?an obstacle exception pauses the mission.
5. **Review** â€?the operator resumes with an approval reference; a non-operator review is rejected.
6. **Process** â€?a durable mission process is opened.
7. **Plan** â€?a verified mission plan is generated (recommendation only).
8. **Complete** â€?the mission completes and the value report is emitted.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Fleet workspace, mission fields | Symbivela case `fleet-0001-mission` in `open` state |
| Record context | Boundary assertion, evidence ref | Ontovela boundary assertion + mission view |
| Start mission | Operator, idempotency key | Mission `running` |
| Boundary gate | Out-of-boundary telemetry | Adapter freezes with HTTP 403 |
| Raise exception | Obstacle exception | Mission `paused` |
| Non-operator gate | Outsider review attempt | Adapter rejects with HTTP 403 |
| Operator review | Resume decision, approval ref | Mission `resumed` |
| Start process | Workflow definition, actor | Rheovela `fleet-mission-exception` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Complete | Completed by | Mission `completed` |
| Emit value report | Evidence and gates from all steps | `.local-data/fleet-value-report.json` |

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
| Fleet-domain adapter | `http://localhost:8099` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-fleet-mission.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8099/v1/missions/mission-alpha-001"
curl.exe "http://localhost:8099/v1/notifications/mission-alpha-001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A physical mission stays bounded and recoverable: exceptions pause for operator review instead of continuing unobserved. |
| KPIs | Boundary compliance, pause-and-review rate, evidence completeness, human-approval rate. |
| Decision gates | Case opened, mission bounded, mission started, exception paused, operator review. |
| Evidence produced | Case, boundary assertion, start, telemetry, exception, review, completion, denial records. |
| Adoption path | Pilot with a limited zone and a repeatable objective before expanding coverage. |

See the [value framework](../../docs/example-value.md) and the [fleet domain adapter API](../../adapters/fleet-domain/API.md).

## Governance Patterns

This demo demonstrates patterns [1](../../docs/governance-patterns.md#1-deny-by-default-no-bypass), [3](../../docs/governance-patterns.md#3-plan-is-a-recommendation-not-an-authorization), [4](../../docs/governance-patterns.md#4-deny-by-default-runtime-effect-ledger), [5](../../docs/governance-patterns.md#5-audit-trail-is-a-chain), [6](../../docs/governance-patterns.md#6-idempotency-makes-reruns-safe), and [15](../../docs/governance-patterns.md#15-autonomous-boundary-pause-and-review) of the [governance patterns catalog](../../docs/governance-patterns.md): **autonomous boundary enforcement** and **pause-and-review**.

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
