# Local-Binary Inference-Governance Demo

`inf-0001` for the `customer-facing-summary` use runs a governed inference lifecycle: case, request context, **authorization gate**, **selection-policy gate**, **grounding gate**, **human-review gate**, governed answer, and **immutable audit**. The demo runs against real local binaries plus the inference-domain reference adapter.

> **Detailed walkthrough:** for the exact request bodies, headers, expected responses, and per-step governance behavior, see the [Detailed Operations Guide](operations-guide.md).

## What You Get From Running It

The run script prints a **step-by-step business report** and a **Value & Effect summary**, and writes `.local-data/inference-outcome.json` and `.local-data/inference-value-report.json`. You can see:

- **The governed inference lifecycle**: how `inf-0001` moves from `submitted` through `authorized â†?routed â†?grounded â†?reviewed â†?answered` to `audited`.
- **Authorization first**: a model route cannot be selected before the request is authorized.
- **Selection under policy**: a model outside the allowed catalog is rejected.
- **Grounding-cited answers**: an answer cannot be produced without accepted claims and memory context.
- **Human review for high impact**: the high-impact answer is rejected until an operator approves it.
- **Immutable audit**: an audited inference accepts no further mutations.
- **The division of authority**: no single product produces the answer; each contributes one governed step.

## The Scenario In Business Terms

1. **Open** â€?the inference owner opens a governed inference case.
2. **Context** â€?the request state is asserted with evidence.
3. **Authorization gate** â€?a route attempted before authorization is rejected.
4. **Authorize** â€?the request is authorized under delegated authority.
5. **Selection gate** â€?an out-of-policy model is rejected.
6. **Select** â€?an in-policy model and endpoint are selected under policy.
7. **Ground** â€?the answer is grounded in accepted claims and durable memory.
8. **Review gate** â€?a high-impact answer before human review is rejected.
9. **Review & answer** â€?an operator approves, and the governed answer is produced with its evidence refs attached.
10. **Audit** â€?the result is recorded as an immutable audit record.

## What This Demo Does

| Step | Input | Output |
| --- | --- | --- |
| Start services | Local binaries and PostgreSQL connection | All listed local services reachable and healthy |
| Open case | Inference workspace, request fields | Symbivela case `inf-0001-governed-answer` in `open` state |
| Record context | Request assertion, evidence ref | Ontovela assertion + inference view (`submitted`) |
| Authorization gate | Route before authorization | Adapter rejects with HTTP 403 |
| Authorize | Identity, delegated authority | Adapter request `authorized` |
| Selection gate | Out-of-policy model attempt | Adapter rejects with HTTP 403 |
| Select route | Selection policy, model/endpoint catalog | Adapter route `model-alpha` @ `endpoint-production` |
| Ground | Accepted claims, memory context | Adapter grounding refs attached |
| Review gate | Answer before human review | Adapter rejects with HTTP 403 |
| Review & answer | Operator approval, grounded context | Adapter `reviewed` â†?`answered` with evidence refs |
| Audit | Final evidence | Adapter `audited`, immutable |
| Emit value report | Evidence and gates from all steps | `.local-data/inference-value-report.json` |

## Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`
- Local checkout directories for `LIMENORA-open`, `ONTOVELA`, `RHEOVELA`, `SYMBIVELA`, and `PRAXOVELA`
- A running PostgreSQL 18 instance with databases `symbivela` and `moduregis`
- The verified binaries: `limenora-edge.exe`, `ontovela.exe`, `rheo.exe`, and `symbivela.exe`
- Optional: Moduregis v1.0.1 downloads on demand

Copy `local.env.ps1.example` to `local.env.ps1` and set your checkout root and connection strings. Do not commit `local.env.ps1`.

## Start The Services

```powershell
. .\local.env.ps1
.\start-services.ps1
```

| Service | Local address | Health check |
| --- | --- | --- |
| Limenora Edge | `http://localhost:1896` | `GET /healthz` |
| Ontovela | `http://localhost:1856` | `GET /healthz` |
| Rheovela | `http://localhost:1876` | `GET /api/v1/health` |
| Symbivela | `http://localhost:1926` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:1866` | `GET /health` |
| Inference-domain adapter | `http://localhost:8103` | `GET /healthz` |
| Moduregis | `http://localhost:1806` | `GET /v1/health` |

## Run The Scenario

```powershell
. .\local.env.ps1
.\run-inference-governance.ps1
```

Then verify the outcome:

```powershell
.\verify.ps1
```

Or run the whole flow in one step with `.\run-all.ps1`.

To inspect live state yourself:

```powershell
curl.exe "http://localhost:8103/v1/inferences/inf-0001"
curl.exe "http://localhost:8103/v1/notifications/inf-0001"
```

## Value & Effect

| Field | Value this demo demonstrates |
| --- | --- |
| Outcome value | A governed inference request is authorized, routed to an in-policy model and endpoint, grounded in accepted claims and durable memory, reviewed by a human for high impact, and recorded as an immutable audit record. |
| KPIs | Policy compliance, grounding coverage, review rate, evidence completeness, audit immutability. |
| Decision gates | Case opened, authorization, selection, grounding, human review, audit. |
| Evidence produced | Case, authorization, route selection, grounding refs, review, answer, audit record. |
| Adoption path | Start with a single bounded decision; expand only after measuring policy compliance and review rate. |

See the [value framework](../../docs/example-value.md) and the [inference domain adapter API](../../adapters/inference-domain/API.md).

## Governance Patterns

This demo demonstrates the integrity layer plus **governed inference** (selection under policy, grounding-cited answers, human review for high impact, immutable audit) of the governance-pattern catalog (maintained in the private **`enterprise-autonomy-ee`** repository).

## Stop The Demo

Stop the processes shown in `.local-logs/` or close the PowerShell sessions that started them, or run `..\stop-demo.ps1` from the `examples/` directory. Remove `.local-data/` only when you intentionally want to discard the demo data.
