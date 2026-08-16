# Local-Binary Compliance Request To Audit Demo

`compliance-0001` for requirement `SOC2-1` runs a governed audit lifecycle: case, requirement context, **completeness-gated attestation**, **designated attestor**, durable process, compliance plan, and **immutable audit package release**. The demo runs against real local binaries plus the compliance-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/compliance-outcome.json` and `.local-data/compliance-value-report.json`. You can see:

- **The audit lifecycle**: how `compliance-0001` moves from `open` to `released` through evidence collection, attestation, and packaging.
- **Completeness gates attestation**: attestation before all evidence is rejected.
- **Designated attestor**: only the designated attestor may attest.
- **Immutable package**: a released audit package cannot be replaced.
- **The division of authority**: no single product releases the audit package; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** — the compliance lead opens a governed case.
2. **Context** — the requirement and its four required evidence items are asserted.
3. **Completeness gate** — attestation before all evidence is rejected.
4. **Collect** — all four evidence items are collected from governed sources.
5. **Attest** — the designated attestor attests; a non-attestor is rejected.
6. **Process** — a durable compliance process is opened.
7. **Plan** — a verified compliance plan is generated (recommendation only).
8. **Release** — the audit package releases after attestation citing the exact reference; released packages are immutable.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Compliance workspace, requirement fields | Symbivela case `comp-0001-audit` in `open` state |
| Record context | Requirement assertion, evidence ref | Ontovela requirement assertion + case view |
| Completeness gate | Attestation before all evidence | Adapter rejects with HTTP 403 |
| Collect evidence | 4 required items from governed sources | Case `evidence` |
| Non-attestor gate | Non-designated attestor attempt | Adapter rejects with HTTP 403 |
| Attest | Designated attestor, attestation ref | Case `attested` |
| Start process | Workflow definition, actor | Rheovela `compliance-request-to-audit` instance |
| Generate plan (optional) | Goal, catalog, constraints, delegation | Verified Orchadyn plan |
| Release package | Released by, exact attestation ref | Package `package-comp-pkg-v1`, case `released` |
| Ref-mismatch gate | Wrong attestation reference | Adapter rejects with HTTP 403 |
| Immutability gate | Second package attempt | Adapter rejects with HTTP 409 |
| Emit value report | Evidence and gates from all steps | `.local-data/compliance-value-report.json` |

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
| Compliance-domain adapter | `http://localhost:8098` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-compliance-audit.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8098/v1/compliance/compliance-0001"
curl.exe "http://localhost:8098/v1/notifications/compliance-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | An auditable record is produced only when evidence is complete, attested by a designated authority, and packaged immutably. |
| KPIs | Evidence completeness, attestation accuracy, package immutability, audit reconstructability. |
| Decision gates | Case opened, requirement scoped, evidence complete, attestation. |
| Evidence produced | Case, requirement assertion, four evidence items, attestation, package, denial records. |
| Adoption path | Pilot with one requirement class; expand as evidence completeness improves. |

See the [value framework](../../docs/example-value.md) and the [compliance domain adapter API](../../adapters/compliance-domain/API.md).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
