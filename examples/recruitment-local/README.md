# Local-Binary Recruitment Requisition To Offer Demo

`req-0001` for a Senior Platform Engineer runs a governed hiring lifecycle: case, validation, **human-only decisions**, durable process, hiring plan, and offer. The demo runs against real local binaries plus the recruitment-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/recruitment-outcome.json` and `.local-data/recruitment-value-report.json`. You can see:

- **The hiring lifecycle**: how `req-0001` moves from `draft` to `closed` with an offer to a human-selected candidate.
- **Human-decision integrity**: an automated actor's shortlist decision is rejected before any stage logic runs.
- **Stage-gated decisions**: shortlist, selection, and offer decisions must follow the validated lifecycle.
- **The division of authority**: no single product hires; each contributes one governed step.
- **The audit trail**: case + validation + role assertion + human decisions + process + plan + offer.

## The Scenario In Business Terms

1. **Open** â€?the hiring manager opens a governed requisition case.
2. **Validate** â€?the TA lead validates the requisition and records criteria.
3. **Automation boundary** â€?an automated assistant's decision is rejected.
4. **Shortlist** â€?the panel records a human shortlist decision.
5. **Process** â€?a durable hiring process is opened.
6. **Plan** â€?a verified hiring plan is generated (recommendation only).
7. **Select and offer** â€?the hiring manager records selection and offer decisions; the TA lead issues the offer.
8. **Close** â€?the requisition closes and the value report is emitted.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Talent workspace, requisition fields | Symbivela case `req-0001-hire` in `open` state |
| Validate | TA lead, criteria, idempotency key | Requisition `validated` |
| Automation boundary | Automated shortlist decision | Adapter rejects with HTTP 403 |
| Shortlist | Human panel decision | Requisition `shortlisting` |
| Start process | Workflow definition, actor | Rheovela `recruitment-requisition-to-offer` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Selection + offer decisions | Human decisions with rationale | Requisition `offer` |
| Issue offer | Candidate, offer ref | Offer `offer-rec-offer-v1`, requisition `closed` |
| Emit value report | Evidence and gates from all steps | `.local-data/recruitment-value-report.json` |

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
| Recruitment-domain adapter | `http://localhost:8094` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-recruitment.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8094/v1/requisitions/req-0001"
curl.exe "http://localhost:8094/v1/candidates/cand-a"
curl.exe "http://localhost:8094/v1/notifications/req-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A requisition is filled through human-only decisions with an evidenced offer; automation never decides. |
| KPIs | Human-decision integrity, evidence completeness, cycle time, automation scope. |
| Decision gates | Case opened (hiring manager), shortlist (panel), selection + offer (hiring manager). |
| Evidence produced | Case, validation, role assertion, human decisions, process instance, plan, offer. |
| Adoption path | Pilot one role family; keep screening, selection, and offer decisions human, and review outcomes per cycle. |

See the [value framework](../../docs/example-value.md) and the [recruitment domain adapter API](../../adapters/recruitment-domain/API.md).

## Governance Patterns

This demo demonstrates patterns [1â€?](../../docs/governance-patterns.md#integrity-patterns-cross-cutting) and [10](../../docs/governance-patterns.md#10-automation-cannot-decide) of the [governance patterns catalog](../../docs/governance-patterns.md): **automation cannot decide** â€?screening, selection, and offer decisions are human-only.

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
