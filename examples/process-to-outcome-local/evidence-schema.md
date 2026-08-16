# Process-To-Outcome Demo Artifact Schema

The process-to-outcome demo writes artifacts under `.local-data/`.

## `process-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `process_id` | string | The process reference (`proc-0001`). |
| `tenant` | string | The tenant used for the run. |
| `operator` | string | The accountable operator. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `process_state` | object | The final process view (current stage, advances, status). |
| `notifications` | array | Pending outcome notifications. |

## `process-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `process-to-outcome`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `stage-request`, `stage-review`, `stage-approve`. |
| `evidence` | array | Per-product artifacts including the denial records (`out-of-order-advance-rejected`, `complete-before-terminal-rejected`, `reopen-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
