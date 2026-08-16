# Local-Binary Customer Case Resolution Demo

`cs-0001` for a billing overcharge runs a governed customer-service lifecycle: case, verified facts, **customer consent**, service-lead approval, durable process, resolution plan, compensation, and close. The demo runs against real local binaries plus the customer-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/customer-outcome.json` and `.local-data/customer-value-report.json`. You can see:

- **The resolution lifecycle**: how `cs-0001` moves from `open` to `resolved` with a consented, approved compensation.
- **Consent governance**: compensation without customer consent is rejected before any money moves.
- **Conjunctive authority**: consent AND service-lead approval are both required; each denial is demonstrated.
- **The division of authority**: no single product commits a customer remedy; each contributes one governed step.
- **The audit trail**: case + facts + account assertion + consent + approval + process + plan + compensation + close.

## The Scenario In Business Terms

1. **Open** — the service lead opens a governed case.
2. **Verify** — the agent records a verified billing fact and the account context is asserted.
3. **Consent** — the customer consents to the compensation; without consent the remedy is denied.
4. **Approve** — the service lead approves the resolution; without approval the remedy is denied.
5. **Process** — a durable case-resolution process is opened.
6. **Plan** — a verified resolution plan is generated (recommendation only).
7. **Resolve** — the consented, approved compensation is applied to the account.
8. **Close** — the case closes with evidence and the value report is emitted.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Customer-service workspace, case fields | Symbivela case `cs-0001-billing` in `open` state |
| Verify facts | Verified claim, source, evidence | customer-domain fact + Ontovela account assertion |
| Consent gate | Compensation without consent attempt | Adapter rejects with HTTP 403 |
| Capture consent | Customer, decision, consent ref | customer-domain consent (`consented`) |
| Approval gate | Compensation without approval attempt | Adapter rejects with HTTP 403 |
| Start process | Workflow definition, actor | Rheovela `customer-case-resolution` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Apply resolution | Consent + approval cited compensation | Account credited, case `resolving` |
| Close | Closed by, idempotency key | Case `resolved`, value report emitted |

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
| Customer-domain adapter | `http://localhost:8093` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-customer-case.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8093/v1/cases/cs-0001"
curl.exe "http://localhost:8093/v1/accounts/acct-2001"
curl.exe "http://localhost:8093/v1/notifications/cs-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A customer remedy is delivered only with customer consent and service-lead approval, with every commitment recorded. |
| KPIs | Products involved, gates passed, evidence artifacts, steps completed, time-to-resolve. |
| Decision gates | Case opened (service lead), customer consent, resolution approved (service lead). |
| Evidence produced | Case, verified facts, account assertion, consent, approval, process instance, plan, compensation, close. |
| Adoption path | Replace the reference adapter and local databases with authorized systems, then pilot a narrow case class. |

See the [value framework](../../docs/example-value.md) and the [customer domain adapter API](../../adapters/customer-domain/API.md).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them. Remove `.local-data/` only when you intentionally want to discard the demo data.
