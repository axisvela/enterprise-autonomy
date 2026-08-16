# Compliance Audit Demo Artifact Schema

The compliance-audit demo writes artifacts under `.local-data/`.

## `compliance-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `case_id` | string | The compliance case reference (`compliance-0001`). |
| `tenant` | string | The tenant used for the run. |
| `compliance_lead` | string | The accountable compliance lead. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `case_state` | object | The final case view (evidence, attestation, package, status). |
| `notifications` | array | Pending audit-package notifications. |

## `compliance-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `compliance-request-to-audit`. |
| `outcome` | object | `subject`, `before`, `after`, `package`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `requirement-context`, `evidence-complete`, `attestation`. |
| `evidence` | array | Per-product artifacts including the denial records (`attestation-without-evidence-rejected`, `non-attestor-rejected`, `attestation-ref-mismatch-rejected`, `package-immutability-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
