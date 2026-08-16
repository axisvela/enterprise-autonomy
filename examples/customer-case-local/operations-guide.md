# Customer-Case Demo — Detailed Operations Guide

Step-by-step walkthrough of the customer-case demo with the **exact requests and responses** each script issues. Read it alongside the [README](README.md).

## How To Read This Guide

Each step documents its **Purpose**, the exact **Request** (method, URL, headers, body), the **Response** fields the script reads, and **What to notice** — the governance behavior it demonstrates.

Values are concrete: customer `cust-1001`, service lead `service-lead`, consent reference `consent://cs-0001`, approval reference `approval://cs-0001`, compensation `40`.

## Service Map

| Service | Address | Health |
| --- | --- | --- |
| Limenora Edge | `http://localhost:10255` | `GET /healthz` |
| Ontovela | `http://localhost:8082` | `GET /healthz` |
| Rheovela | `http://localhost:8083` | `GET /api/v1/health` |
| Symbivela | `http://localhost:8080` | `GET /ready` |
| Praxovela AXON Core | `http://127.0.0.1:8420` | `GET /health` |
| Customer-domain adapter | `http://localhost:8093` | `GET /healthz` |
| Moduregis | `http://localhost:8084` | `GET /v1/health` |
| Orchadyn API (optional) | `http://localhost:1816` | `GET /healthz` |

## Seed Data

- **Case** (`cs-0001`): customer `cust-1001`, account `acct-2001`, issue `billing overcharge`, status `open`.
- **Account** (`acct-2001`): balance `120 USD`, status `active`.

## Setup

Copy `local.env.ps1.example` to `local.env.ps1`, set the checkout root and connection strings, then start the services:

```powershell
. .\local.env.ps1
.\start-services.ps1
```

Expected final line: `All local services are ready.`

## Step 1 — Open the case (Symbivela)

**Purpose.** Create the human authority that gates any customer commitment.

**Request 1a — workspace.**
```
POST http://localhost:8080/v1/workspaces
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: service-lead,
         Idempotency-Key: customer-service-workspace-v1
Body:
{"workspace_id":"customer-service","name":"Customer Service","owner_id":"service-lead"}
```

**Request 1b — case.**
```
POST http://localhost:8080/v1/exception-cases
Headers: X-SYMBIVELA-Tenant: tenant-a, X-SYMBIVELA-Actor: service-lead,
         Idempotency-Key: cs-0001-case-v1
Body:
{"workspace_id":"customer-service","case_id":"cs-0001-billing","subject_ref":"case://cs-0001",
 "problem":"Billing overcharge reported by the customer.","evidence_refs":"account://acct-2001",
 "candidate_actions":"explanation,correction,compensation,refund,credit,escalation",
 "deadline":"2026-08-22T12:00:00Z"}
```

**What to notice.** The case enumerates the permitted remedies. No remedy may be committed outside this case.

## Step 2 — Verify the facts (customer-domain adapter + Ontovela)

**Purpose.** Establish verified facts and assert the account context before any remedy.

**Request 2a — record a verified fact.**
```
POST http://localhost:8093/v1/cases/cs-0001/facts
Body:
{"claim":"billing overcharge confirmed against acct-2001","source":"billing-system",
 "verified":true,"idempotency_key":"cs-fact-v1"}
```
Response: `fact.id` (`fact-cs-fact-v1`). An `unverified` claim is rejected (`422 unverified_claim_requires_investigation`).

**Request 2b — account assertion.**
```
POST http://localhost:8082/v1/assertions
Headers: X-Tenant-ID: tenant-a, Idempotency-Key: cs-0001-account-v1
Body:
{"id":"assertion-acct-2001-overcharge","subject_id":"acct-2001","property":"billing_status",
 "value":"overcharge","state_kind":"observed","event_time":"2026-08-16T10:00:00Z",
 "system_time":"2026-08-16T10:00:01Z","source":"billing-system","evidence_ref":"evidence://billing/acct-2001"}
```

**Request 2c — account view.**
```
GET http://localhost:8093/v1/accounts/acct-2001
```
Response: `{"id":"acct-2001","customer":"cust-1001","balance":120,"currency":"USD","status":"active","credits":[]}`.

**What to notice.** The adapter refuses unverified claims; the world model asserts the account fact with evidence. A remedy can only be grounded in verified facts.

## Step 3 — Capture customer consent (customer-domain adapter)

**Purpose.** Prove compensation requires consent, then record it.

**Request 3a — compensation without consent (expect rejection).**
```
POST http://localhost:8093/v1/cases/cs-0001/resolutions
Body:
{"type":"compensation","amount":40,"approved_by":"service-lead",
 "approval_ref":"approval://cs-0001","consent_ref":"consent://cs-0001",
 "idempotency_key":"cs-comp-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"consent_required"}`.

**Request 3b — record consent.**
```
POST http://localhost:8093/v1/cases/cs-0001/consent
Body:
{"customer":"cust-1001","decision":"approve","consent_ref":"consent://cs-0001",
 "idempotency_key":"cs-consent-v1"}
```
Response: `case.status` (`consented`). A wrong customer is rejected (`403 customer_mismatch`).

**What to notice.** Consent is a first-class, idempotent record tied to a reference the resolution must cite. Money cannot move before it exists.

## Step 4 — Approve the resolution (service-lead authority)

**Purpose.** Prove the second conjunctive requirement — service-lead approval — then confirm the gate.

**Request 4a — compensation without approval (expect rejection).**
```
POST http://localhost:8093/v1/cases/cs-0001/resolutions
Body:
{"type":"compensation","amount":40,"approved_by":"","approval_ref":"",
 "consent_ref":"consent://cs-0001","idempotency_key":"cs-comp-v1"}
```
The adapter responds `403 Forbidden` with `{"error":"approval_required_for_compensation"}`.

**What to notice.** Consent alone is insufficient; the resolution requires **both** a matching consent reference and a service-lead approval. This is conjunctive authority: either missing factor denies the money movement.

## Step 5 — Create the durable case process (Rheovela)

**Purpose.** Wrap the lifecycle in a recoverable, capability-gated process.

**Input file — `customer-case-workflow.json`.** Stages: `verify-facts (service-agent) → consent (customer) → approve (service-lead) → resolve (capability customer.resolution.execute) → close (service-lead)`.

**CLI — validate and define.**
```powershell
rheo workflow validate customer-case-workflow.json
rheo workflow define --file customer-case-workflow.json
```

**Request — open an instance.**
```
POST http://localhost:8083/api/v1/instances
Body:
{"workflow":"customer-case-resolution","project":"cs-0001","actor":"service-lead"}
```

**What to notice.** The `resolve` stage is capability-gated (`customer.resolution.execute`); the workflow models consent and approval as explicit stages, mirroring the adapter's conjunctive enforcement.

## Step 6 — Generate a resolution plan (Orchadyn, optional)

**Purpose.** Produce a verified recommendation. A plan is not an authorization.

**Input file — `customer-case-plan.json`.** Goal `goal-cs-0001-resolved` owned by `service-lead`; catalog `cap-compensation` with `consentRequired: true` and `approvalRequired: true`; hard constraints for consent, approval, and a compensation ceiling of 100; delegation with `evidenceDuty: ["consent://cs-0001", "approval://cs-0001"]`.

**Request.**
```
POST http://localhost:1816/plans:generate
Body: (contents of customer-case-plan.json)
```

**What to notice.** The plan itself encodes the consent and approval constraints, so even the recommendation is bounded by the governance model.

## Step 7 — Apply the resolution (customer-domain adapter)

**Purpose.** Apply the consented, approved compensation.

**Request.**
```
POST http://localhost:8093/v1/cases/cs-0001/resolutions
Body:
{"type":"compensation","amount":40,"approved_by":"service-lead",
 "approval_ref":"approval://cs-0001","consent_ref":"consent://cs-0001",
 "idempotency_key":"cs-comp-v1"}
```

**Response fields read by the script:** `resolution.id`, `case.status` (`resolving`). The account is credited: balance `120 → 80`.

**What to notice.** The resolution carries both references (`consent_ref` and `approval_ref`), so the money movement is traceable to both the customer's consent and the service-lead's approval.

## Step 8 — Close and emit the value report

**Purpose.** Close the case only after a resolution, then reconstruct the lifecycle from evidence.

**Request.**
```
POST http://localhost:8093/v1/cases/cs-0001/close
Body:
{"closed_by":"service-lead","idempotency_key":"cs-close-v1"}
```

**Response fields read by the script:** `case.status` (`resolved`). A close with no resolution is rejected (`403 no_resolution_applied`); an escalated case cannot be closed directly.

**Outputs written to `.local-data/`:** `customer-outcome.json` and `customer-value-report.json`.

**What to notice.** The value report's denial entries (`compensation-without-consent-rejected`, `compensation-without-approval-rejected`) make the conjunctive governance effect measurable.

## Output Artifacts

### `customer-outcome.json`

```json
{
  "case_id": "cs-0001",
  "tenant": "tenant-a",
  "customer": "cust-1001",
  "steps": [
    {"index": 1, "title": "Open the case", "product": "symbivela", "artifact": "cs-0001-billing"},
    {"index": 2, "title": "Verify the facts", "product": "customer-domain", "artifact": "fact-cs-fact-v1"},
    {"index": 3, "title": "Capture customer consent", "product": "customer-domain", "artifact": "consent-cs-consent-v1"},
    {"index": 4, "title": "Approve the resolution", "product": "customer-domain", "artifact": "approval-cs-0001"},
    {"index": 5, "title": "Create the durable case process", "product": "rheovela", "artifact": "<instance-id>"},
    {"index": 6, "title": "Generate a resolution plan", "product": "orchadyn", "artifact": "plan-cs-0001"},
    {"index": 7, "title": "Apply the resolution", "product": "customer-domain", "artifact": "resolution-cs-comp-v1"},
    {"index": 8, "title": "Close the case", "product": "customer-domain", "artifact": "close-cs-0001"}
  ],
  "case_state": {
    "id": "cs-0001", "customer": "cust-1001", "account": "acct-2001",
    "issue": "billing overcharge", "status": "resolved",
    "facts": [{"id": "fact-cs-fact-v1", "claim": "billing overcharge confirmed against acct-2001", "verified": true}],
    "consent": {"id": "consent-cs-consent-v1", "customer": "cust-1001", "decision": "approve", "consent_ref": "consent://cs-0001"},
    "resolutions": [{"id": "resolution-cs-comp-v1", "type": "compensation", "amount": 40,
                     "consent_ref": "consent://cs-0001", "approval_ref": "approval://cs-0001", "status": "applied"}]
  }
}
```

### `customer-value-report.json`

Example KPIs: `products_involved` 5, `gates_passed` 3, `evidence_artifacts` 10, `steps_completed` 8.

## Troubleshooting

| Symptom | Likely cause | Expected fix |
| --- | --- | --- |
| `Load local.env.ps1 before running this script.` | Env not sourced | `. .\local.env.ps1` first. |
| `Service did not become ready: http://localhost:8093/healthz` | Adapter build failed or port busy | Check `.local-logs\customer-domain.err.log`; confirm `go` on PATH. |
| `403 consent_required` | Compensation before consent | Capture consent first (Step 3). |
| `403 approval_required_for_compensation` | Missing service-lead approval | Provide `approved_by` and `approval_ref` (Step 4). |
| `422 unverified_claim_requires_investigation` | Fact not verified | Record verified facts only. |
| `403 no_resolution_applied` | Close before any resolution | Apply a resolution before closing. |
| `409 escalated_case_requires_escalation_queue` | Closing an escalated case | Route through the escalation queue. |
