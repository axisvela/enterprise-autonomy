# Innovation Sandbox Demo Artifact Schema

The innovation-sandbox demo writes artifacts under `.local-data/`.

## `sandbox-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `proposal_id` | string | The proposal reference (`proposal-sandbox-0001`). |
| `tenant` | string | The tenant used for the run. |
| `reviewer` | string | The review-group member who decided. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `proposal_state` | object | The final proposal view (experiments, decision, apply, status). |
| `notifications` | array | Pending policy-apply notifications. |

## `sandbox-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `innovation-sandbox-to-policy`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `sandbox-scoped`, `experiment-evidence`, `policy-decision`. |
| `evidence` | array | Per-product artifacts including the denial records (`sandbox-boundary-rejected`, `decision-without-evidence-rejected`, `non-reviewer-rejected`, `policy-immutability-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
