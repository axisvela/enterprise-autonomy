# Simulation Validation Demo Artifact Schema

The simulation-validation demo writes artifacts under `.local-data/`.

## `simulation-outcome.json`

| Field | Type | Meaning |
| --- | --- | --- |
| `proposal_id` | string | The proposal reference (`proposal-sim-0001`). |
| `tenant` | string | The tenant used for the run. |
| `reviewer` | string | The review-group member who decided. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `proposal_state` | object | The final proposal view (scenarios, runs, decision, status). |
| `notifications` | array | Pending release notifications. |

## `simulation-value-report.json`

Follows the shared [value report template](../value-report-template.md) shape:

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | `simulation-to-validation`. |
| `outcome` | object | `subject`, `before`, `after`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | `case-opened`, `scenarios-compiled`, `simulation-evidence`, `review-decision`. |
| `evidence` | array | Per-product artifacts including the denial records (`decision-without-evidence-rejected`, `evidence-immutability-rejected`, `non-member-decision-rejected`, `release-ref-mismatch-rejected`). |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum thresholds.
