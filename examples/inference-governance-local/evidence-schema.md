# Inference-Governance Demo Artifact Schema

The inference-governance demo writes artifacts under `.local-data/`.

## `inference-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `inference_id` | string | The inference reference (`inf-0001`). |
| `tenant` | string | The tenant used for the run. |
| `operator` | string | The accountable operator. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `inference_state` | object | The final inference view (route, grounding, review, answer, audit, status). |
| `notifications` | array | Pending review/audit notifications. |

## `inference-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `inference-governance`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `authorized`, `route-selected`, `grounded`, `reviewed`, `answered`. |
| `evidence` | array | Per-product artifacts including the denial records (`unauthorized-route-rejected`, `out-of-policy-model-rejected`, `unreviewed-answer-rejected`, `audited-inference-immutable`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
