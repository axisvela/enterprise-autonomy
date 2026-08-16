# Predictive Maintenance Demo Artifact Schema

The predictive-maintenance demo writes artifacts under `.local-data/`.

## `maintenance-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `signal_id` | string | The signal reference (`signal-pm-0001`). |
| `tenant` | string | The tenant used for the run. |
| `maintenance_manager` | string | The accountable maintenance manager. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `signal_state` | object | The final signal view (validation, decision, safety, work order, status). |
| `notifications` | array | Pending work-order notifications. |

## `maintenance-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `predictive-maintenance-to-work-order`. |
| `outcome` | object | `subject`, `before`, `after`, `work_order`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `signal-validated`, `maintenance-decision`, `safety-review`. |
| `evidence` | array | Per-product artifacts including the three denial records (`unvalidated-work-order-rejected`, `unconfirmed-stop-rejected`, `no-safety-review-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
