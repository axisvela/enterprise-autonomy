# Compliance-Domain Adapter â€?API Reference

Local reference service for simulated compliance-audit views. Not a production compliance system.

Base URL: `http://localhost:8098` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"compliance-domain-adapter"}
```

### `GET /v1/compliance/{id}`

Seeded `compliance-0001`:

```json
{"id":"compliance-0001","requirement":"SOC2-1","status":"open","attestor":"compliance-lead",
 "required_items":["evidence-item-1","evidence-item-2","evidence-item-3","evidence-item-4"],
 "evidence":{},"actions":[]}
```

Errors: `404 compliance_case_not_found`.

### `POST /v1/compliance/{id}/evidence`

Collects a required evidence item. Requires `item_id`, `source`, `timestamp`, `evidence_ref`, `collected_by`, `idempotency_key`.

```json
{"item_id":"evidence-item-1","source":"governed-source-1","timestamp":"2026-08-16T14:01:00Z",
 "evidence_ref":"evidence://comp/item-1","collected_by":"compliance-lead","idempotency_key":"comp-ev-1"}
```

`case.status` â†?`evidence` once all items are collected.

Errors: `400` missing fields or `unknown_evidence_item`, `409 evidence_item_already_collected`.

### `POST /v1/compliance/{id}/attestations`

Designated attestor attests. Requires `attested_by`, `decision` (`attest`/`defer`), `attestation_ref`, `idempotency_key`.

```json
{"attested_by":"compliance-lead","decision":"attest","attestation_ref":"attestation://comp-0001","idempotency_key":"comp-att-v1"}
```

`case.status` â†?`attested` when attested. Errors: `400` missing/invalid fields, `403 evidence_incomplete_attestation_requires_all_items`, `403 not_designated_attestor`.

### `POST /v1/compliance/{id}/packages`

Assembles and releases the audit package. Requires `released_by`, `attestation_ref`, `idempotency_key`.

```json
{"released_by":"compliance-lead","attestation_ref":"attestation://comp-0001","idempotency_key":"comp-pkg-v1"}
```

Creates `package-comp-pkg-v1`; `case.status` â†?`released`. Gated on an `attest` decision citing the exact reference; released packages are immutable.

Errors: `400` missing fields, `403 attestation_required_before_package`, `403 attestation_ref_mismatch`, `409 package_already_released_immutable`.

### `GET /v1/notifications/{id}`

```json
{"case_id":"compliance-0001","notifications":["audit-package-notification-pending:package-comp-pkg-v1"]}
```

Errors: `404 compliance_case_not_found`.

## State Machine

```
open -> evidence -> attested -> released
```

`evidence` transitions to `open â†?evidence` when all items are collected; an `attest` decision moves to `attested`; the package release moves to `released` and is immutable.

## Compliance Integrity Model

- **Completeness-gated attestation.** No attestation without all required evidence items.
- **Designated attestor.** Only the designated attestor may attest.
- **Attestation-gated, immutable package.** The package releases only after an attest citing the exact reference, and can never be replaced.

**Governance pattern:** [Completeness-gated attestation and immutable audit](../../docs/governance-patterns.md#14-completeness-gated-attestation-immutable-audit) from the [governance patterns catalog](../../docs/governance-patterns.md).
