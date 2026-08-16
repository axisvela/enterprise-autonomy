# Sequenced-Deployment Demo Artifact Schema

The sequenced-deployment demo writes artifacts under `.local-data/`.

## `deployment-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `deployment_id` | string | The deployment reference (`dep-0001`). |
| `tenant` | string | The tenant used for the run. |
| `operator` | string | The accountable operator. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `deployment_state` | object | The final deployment view (current step, steps run, status). |
| `notifications` | array | Pending release notifications. |

## `deployment-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `sequenced-deployment`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `step-checkout`, `step-build`, `step-test`, `step-approve`, `step-production`. |
| `evidence` | array | Per-product artifacts including the denial records (`out-of-sequence-step-rejected`, `unapproved-pause-rejected`, `released-step-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
