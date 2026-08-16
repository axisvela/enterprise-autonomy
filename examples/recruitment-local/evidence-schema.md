# Recruitment Demo Artifact Schema

The recruitment demo writes artifacts under `.local-data/`.

## `recruitment-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `requisition_id` | string | The requisition reference (`req-0001`). |
| `tenant` | string | The tenant used for the run. |
| `hiring_manager` | string | The accountable hiring manager. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `requisition_state` | object | The final requisition view (decisions, offer, status). |
| `notifications` | array | Pending offer/rejection notifications. |

## `recruitment-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `recruitment-requisition-to-offer`. |
| `outcome` | object | `subject`, `before`, `after`, `candidate`, `offer`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `shortlist-decision`, `selection-decision`, `offer-decision`. |
| `evidence` | array | Per-product artifacts including the `automated-decision-rejected` denial record. |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
