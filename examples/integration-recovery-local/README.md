# Local-Binary Integration Outage Recovery Demo

An outage on `partner-shipping` drives a governed recovery for in-flight work `work-0001`: case, outage context, **preserve-before-resume**, **verify-before-resume**, durable process, recovery plan, resume, and complete â€?with **no silent re-execution**. The demo runs against real local binaries plus the integration-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/integration-outcome.json` and `.local-data/integration-value-report.json`. You can see:

- **The recovery lifecycle**: how `work-0001` moves from `inflight` to `completed` through preservation, verification, resume, and completion.
- **Preserve-before-resume**: resume before preservation is rejected.
- **Verify-before-resume**: resume before the integration is verified is rejected.
- **No silent re-execution**: a second completion is rejected.
- **The division of authority**: no single product recovers work; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** â€?the integration owner opens a governed outage case.
2. **Detect** â€?the outage and in-flight work are asserted with evidence.
3. **Preserve gate** â€?resume before preservation is rejected.
4. **Preserve** â€?the in-flight work is preserved under a durable reference.
5. **Verify gate** â€?resume before verification is rejected; the integration is verified.
6. **Process** â€?a durable recovery process is opened.
7. **Plan** â€?a verified recovery plan is generated (recommendation only).
8. **Resume and complete** â€?the work resumes, completes, and a repeat completion is rejected.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Integration workspace, outage fields | Symbivela case `iro-0001-outage` in `open` state |
| Detect | Outage assertion, evidence ref | Ontovela outage assertion + integration/work views |
| Preserve gate | Resume before preservation attempt | Adapter rejects with HTTP 403 |
| Preserve | Durable preservation reference | Work `preserved` |
| Verify gate | Resume before verification attempt | Adapter rejects with HTTP 403 |
| Verify | Reconnection check, evidence ref | Integration `checked` |
| Start process | Workflow definition, actor | Rheovela `integration-outage-recovery` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Resume and complete | Resumed by, completed by | Work `resumed` then `completed` |
| No-silent-rerun gate | Second completion attempt | Adapter rejects with HTTP 409 |
| Emit value report | Evidence and gates from all steps | `.local-data/integration-value-report.json` |

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
| Integration-domain adapter | `http://localhost:8096` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-integration-recovery.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8096/v1/integrations/partner-shipping"
curl.exe "http://localhost:8096/v1/work/work-0001"
curl.exe "http://localhost:8096/v1/notifications/work-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | In-flight work survives an outage and resumes only after preservation and verified reconnection, with no silent re-execution. |
| KPIs | In-flight preservation, resume verification, outage evidence, escalation handling. |
| Decision gates | Case opened, work preserved, reconnect verified, work resumed. |
| Evidence produced | Case, outage assertion, preservation, reconnection check, resume, completion, denial records. |
| Adoption path | Pilot with a non-critical integration; expand after measuring preservation and resume verification. |

See the [value framework](../../docs/example-value.md) and the [integration domain adapter API](../../adapters/integration-domain/API.md).

## Governance Patterns

This demo demonstrates patterns [1â€?](../../docs/governance-patterns.md#integrity-patterns-cross-cutting) and [12](../../docs/governance-patterns.md#12-recovery-integrity-preserve-verify-never-rerun) of the [governance patterns catalog](../../docs/governance-patterns.md): **recovery integrity** â€?preserve before resume, verify before resume, never re-execute.

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
