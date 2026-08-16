# Compliance-Domain Reference Adapter

This local reference service adapts simulated compliance-audit views for runnable examples. It is not a production compliance or audit system.

## Build And Start

```powershell
go build -o compliance-domain-adapter.exe .
.\compliance-domain-adapter.exe --addr :8098 --data-file .\compliance-domain-data.json
```

`GET http://localhost:8098/healthz` returns `{"status":"ok","service":"compliance-domain-adapter"}`.

## Seeded State

- Compliance case `compliance-0001`: requirement `SOC2-1`, status `open`, designated attestor `compliance-lead`, four required evidence items (`evidence-item-1` … `evidence-item-4`).

## Governance Model

- **Evidence completeness.** An attestation cannot be recorded until every required evidence item is collected (`403 evidence_incomplete_attestation_requires_all_items`).
- **Designated attestor.** Only the designated attestor may attest (`403 not_designated_attestor`).
- **Attestation-gated package.** The audit package is released only after an `attest` decision citing the exact attestation reference (`403 attestation_required_before_package`, `403 attestation_ref_mismatch`).
- **Package immutability.** Once released, the audit package cannot be replaced (`409 package_already_released_immutable`).

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/compliance/{id}` | Compliance case with collected evidence, attestation, and package state. |
| `POST /v1/compliance/{id}/evidence` | Collects a required evidence item from a governed source. |
| `POST /v1/compliance/{id}/attestations` | Designated attestor attests or defers (completeness-gated). |
| `POST /v1/compliance/{id}/packages` | Assembles and releases the audit package (attestation-gated, immutable). |
| `GET /v1/notifications/{id}` | Pending audit-package notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
