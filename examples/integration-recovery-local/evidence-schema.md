# Integration Recovery Demo Artifact Schema

The integration-recovery demo writes artifacts under `.local-data/`.

## `integration-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `work_id` | string | The in-flight work reference (`work-0001`). |
| `tenant` | string | The tenant used for the run. |
| `integration_owner` | string | The accountable integration owner. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `work_state` | object | The final work view (preservation, resume, completion, status). |
| `notifications` | array | Pending recovery notifications. |

## `integration-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `integration-outage-recovery`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `work-preserved`, `reconnect-verified`, `work-resumed`. |
| `evidence` | array | Per-product artifacts including the three denial records (`resume-before-preserve-rejected`, `resume-before-verify-rejected`, `silent-rerun-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
