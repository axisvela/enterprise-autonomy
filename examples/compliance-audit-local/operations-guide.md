# Compliance Audit Demo — Detailed Operations Guide

Step-by-step walkthrough of the compliance-request-to-audit demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: compliance lead `compliance-lead`, case `compliance-0001`, requirement `SOC2-1`, attestation reference `attestation://comp-0001`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Compliance-domain adapter | `http://localhost:8098` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Compliance case** (`compliance-0001`): requirement `SOC2-1`, status `open`, designated attestor `compliance-lead`, four required evidence items.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the compliance case (Symbivela)

**Purpose.** Create the human authority that governs evidence collection and attestation.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: compliance-lead,
         Idempotency-Key: compliance-workspace-v1
Body:
{"workspace_id":"compliance","name":"Compliance Operations","owner_id":"compliance-lead"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: compliance-lead,
         Idempotency-Key: comp-0001-case-v1
Body:
{"workspace_id":"compliance","case_id":"comp-0001-audit","subject_ref":"compliance://compliance-0001",
 "problem":"Assemble the audit package for SOC2-1 with complete evidence and a designated attestation.",
 "evidence_refs":"requirement://SOC2-1",
 "candidate_actions":"collect,attest,defer,release","deadline":"2026-08-30T12:00:00Z"}
```

**What to notice.** The case frames the audit as completeness-gated.

## Step 2 — Record the requirement context (adapter + Ontovela)

**Purpose.** Assert the requirement and confirm the required evidence set.

**Request 2a — case view.**
```
GET http://localhost:8098/v1/compliance/compliance-0001
```
Response: `{"id":"compliance-0001","requirement":"SOC2-1","status":"open","attestor":"compliance-lead","required_items":["evidence-item-1",...],"evidence":{}}`.

**Request 2b — requirement assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: comp-0001-req-v1
Body:
{"id":"assertion-compliance-0001-req","subject_id":"compliance-0001","property":"requirement",
 "value":"SOC2-1","state_kind":"observed","event_time":"2026-08-16T15:00:00Z",
 "system_time":"2026-08-16T15:00:01Z","source":"compliance-system",
 "evidence_ref":"evidence://compliance/compliance-0001"}
```

**What to notice.** The required evidence set is fixed; completeness is measured against it.

## Step 3 — Show completeness gates attestation

**Purpose.** Prove attestation requires all evidence.

**Request — attestation before evidence (expect rejection).**
```
POST http://localhost:8098/v1/compliance/compliance-0001/attestations
Body:
{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://comp-0001",
 "idempotency_key":"comp-att-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"evidence_incomplete_attestation_requires_all_items"}`.

**What to notice.** Attestation cannot precede complete evidence — completeness is a hard gate.

## Step 4 — Collect the required evidence

**Purpose.** Collect all four items from governed sources.

**Request — one item (repeated for items 1-4).**
```
POST http://localhost:8098/v1/compliance/compliance-0001/evidence
Body:
{"item_id":"evidence-item-1","source":"governed-source-1","timestamp":"2026-08-16T14:01:00Z",
 "evidence_ref":"evidence://comp/item-1","collected_by":"compliance-lead","idempotency_key":"comp-ev-1"}
```

After all four, `case.status` → `evidence`. An unknown item is rejected (`400 unknown_evidence_item`); a duplicate is rejected (`409 evidence_item_already_collected`).

**What to notice.** Each item carries a governed source and timestamp — evidence is attributable, not asserted.

## Step 5 — Attest the evidence set (designated attestor)

**Purpose.** Prove only the designated attestor may attest, then record the attestation.

**Request 5a — non-attestor (expect rejection).**
```
POST http://localhost:8098/v1/compliance/compliance-0001/attestations
Body:
{"attested_by":"outsider","decision":"attest","attestation_ref":"attestation://comp-0001",
 "idempotency_key":"comp-att-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"not_designated_attestor"}`.

**Request 5b — attestation.**
```
POST http://localhost:8098/v1/compliance/compliance-0001/attestations
Body:
{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://comp-0001",
 "idempotency_key":"comp-att-v1"}
```
Response: `attestation.decision` (`attest`), `case.status` (`attested`).

**What to notice.** Attestation is conjunctive: complete evidence AND the designated attestor.

## Step 6 — Create the durable compliance process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `compliance-audit-workflow.json`.** Stages: `collect (compliance-lead) → attest (compliance-lead) → package (capability compliance.package.assemble) → release (capability compliance.package.release) → close (compliance-lead)`.

**CLI — validate and define.**
```powershell
rheo workflow validate compliance-audit-workflow.json
rheo workflow define --file compliance-audit-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"compliance-request-to-audit","project":"compliance-0001","actor":"compliance-lead"}
```

**What to notice.** The `package` and `release` stages are capability-gated; the workflow mirrors collect → attest → package ordering.

## Step 7 — Generate a compliance plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `compliance-audit-plan.json`.** Goal `goal-comp-0001-attested`; catalog `cap-attest` with `completenessRequired: true` and `attestorOnly: true`; `cap-package` with `attestationRequired: true` and `immutable: true`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of compliance-audit-plan.json)
```

**What to notice.** The plan encodes completeness and attestation requirements, so even the recommendation respects the gates.

## Step 8 — Release the audit package and emit the value report

**Purpose.** Release the immutable package after attestation citing the exact reference.

**Request 8a — wrong reference (expect rejection).**
```
POST http://localhost:8098/v1/compliance/compliance-0001/packages
Body:
{"released_by":"compliance-lead","attestation_ref":"attestation://wrong","idempotency_key":"comp-pkg-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"attestation_ref_mismatch"}`.

**Request 8b — release.**
```
POST http://localhost:8098/v1/compliance/compliance-0001/packages
Body:
{"released_by":"compliance-lead","attestation_ref":"attestation://comp-0001","idempotency_key":"comp-pkg-v1"}
```
Response: `package_id` (`package-comp-pkg-v1`), `case.status` (`released`).

**Request 8c — second package (expect rejection).**
```
POST http://localhost:8098/v1/compliance/compliance-0001/packages
Body:
{"released_by":"compliance-lead","attestation_ref":"attestation://comp-0001","idempotency_key":"comp-pkg2-v1"}
```
The adapter responds `409 Conflict` with `{"error":"package_already_released_immutable"}`.

**Outputs written to `.local-data/`:** `compliance-outcome.json` and `compliance-value-report.json`.

**What to notice.** The released package is immutable; the four denial records make the compliance gates measurable.

## Output Artifacts

### `compliance-outcome.json`

```json
{
  "case_id": "compliance-0001",
  "tenant": "tenant-a",
  "compliance_lead": "compliance-lead",
  "steps": [
    {"index": 1, "title": "Open the compliance case", "product": "symbivela", "artifact": "comp-0001-audit"},
    {"index": 2, "title": "Record the requirement context", "product": "ontovela", "artifact": "assertion-compliance-0001-req"},
    {"index": 3, "title": "Show completeness gates attestation", "product": "compliance-domain", "artifact": "attestation-without-evidence-rejected"},
    {"index": 4, "title": "Collect the required evidence", "product": "compliance-domain", "artifact": "evidence-complete"},
    {"index": 5, "title": "Attest the evidence set", "product": "compliance-domain", "artifact": "attestation-comp-att-v1"},
    {"index": 6, "title": "Create the durable compliance process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 7, "title": "Generate a compliance plan", "product": "orchadyn", "artifact": "plan-comp-0001"},
    {"index": 8, "title": "Release the audit package", "product": "compliance-domain", "artifact": "package-comp-pkg-v1"}
  ],
  "case_state": {
    "id": "compliance-0001", "requirement": "SOC2-1", "status": "released",
    "attestor": "compliance-lead",
    "required_items": ["evidence-item-1", "evidence-item-2", "evidence-item-3", "evidence-item-4"],
    "evidence": {
      "evidence-item-1": {"id": "evidence-comp-ev-1", "source": "governed-source-1", "evidence_ref": "evidence://comp/item-1"},
      "evidence-item-2": {"id": "evidence-comp-ev-2", "source": "governed-source-2", "evidence_ref": "evidence://comp/item-2"},
      "evidence-item-3": {"id": "evidence-comp-ev-3", "source": "governed-source-3", "evidence_ref": "evidence://comp/item-3"},
      "evidence-item-4": {"id": "evidence-comp-ev-4", "source": "governed-source-4", "evidence_ref": "evidence://comp/item-4"}
    },
    "attestation": {"id": "attestation-comp-att-v1", "attested_by": "compliance-lead", "decision": "attest", "attestation_ref": "attestation://comp-0001"},
    "package_id": "package-comp-pkg-v1"
  }
}
```

### `compliance-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 4, `evidence_artifacts` 12, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8098/healthz` | Adapter build failed or port busy | Check `.local-logs\compliance-domain.err.log`; confirm `go` on PATH. |
| `403 evidence_incomplete_attestation_requires_all_items` | Attestation before all evidence | Collect all four items first. |
| `403 not_designated_attestor` | Non-designated attestor | Attest with `compliance-lead`. |
| `403 attestation_ref_mismatch` | Package with wrong reference | Release with the exact attestation reference. |
| `409 package_already_released_immutable` | Second package | This is the *expected* denial; the released package is immutable. |
