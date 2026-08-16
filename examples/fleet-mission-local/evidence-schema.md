# Fleet Mission Demo Artifact Schema

The fleet-mission demo writes artifacts under `.local-data/`.

## `fleet-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `mission_id` | string | The mission reference (`mission-alpha-001`). |
| `tenant` | string | The tenant used for the run. |
| `operator` | string | The accountable mission operator. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `mission_state` | object | The final mission view (boundary, exception, review, status). |
| `notifications` | array | Pending operator-review and completion notifications. |

## `fleet-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `fleet-mission-exception`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `mission-bounded`, `mission-started`, `exception-paused`, `operator-review`. |
| `evidence` | array | Per-product artifacts including the denial records (`boundary-deviation-frozen`, `review-without-pause-rejected`, `non-operator-review-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
