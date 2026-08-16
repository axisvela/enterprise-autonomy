# Customer-Case Demo Artifact Schema

The customer-case demo writes artifacts under `.local-data/`.

## `customer-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `case_id` | string | The case reference (`cs-0001`). |
| `tenant` | string | The tenant used for the run. |
| `customer` | string | The customer reference. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `case_state` | object | The final case view (facts, consent, resolutions, status). |
| `notifications` | array | Pending customer notification references. |

## `customer-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `customer-case-resolution`. |
| `outcome` | object | `subject`, `before`, `after`, `compensation`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `customer-consent`, `resolution-approved`. |
| `evidence` | array | Per-product artifacts including both denial records (`compensation-without-consent-rejected`, `compensation-without-approval-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
