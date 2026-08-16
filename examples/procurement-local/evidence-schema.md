# Procurement Demo Artifact Schema

The procurement demo writes artifacts under `.local-data/`.

## `procurement-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `request_id` | string | The request reference (`preq-0001`). |
| `tenant` | string | The tenant used for the run. |
| `requester` | string | The submitting employee. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `request_state` | object | The final request view (approvals, PO, receipt, status). |

## `procurement-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `procurement-request-to-receipt`. |
| `outcome` | object | `subject`, `before`, `after`, `po`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `budget-approved`, `supplier-approved`, `purchase-executed`. |
| `evidence` | array | Per-product artifacts including both denial records (`self-approval-rejected`, `unapproved-purchase-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
