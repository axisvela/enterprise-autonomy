# Demo Artifact Schema

The local order-exception demo writes artifacts under `.local-data/`. This page documents their structure so consumers and validators can rely on them.

## `order-outcome.json`

The business outcome of the run.

| Field | Type | Meaning |
| --- | --- | --- |
| `order_id` | string | The order reference (`order-123`). |
| `tenant` | string | The tenant used for the run. |
| `operator` | string | The accountable operator. |
| `steps` | array | Each step's index, title, product, and artifact. |
| `order_state` | object | The final order view from the order-domain adapter. |
| `notifications` | array | Pending customer notification references. |

## `order-value-report.json`

The machine-readable value report defined by the [value report template](../value-report-template.md).

| Field | Type | Meaning |
| --- | --- | --- |
| `example` | string | Example identifier (`order-fulfillment-exception`). |
| `version` | string | Report schema version (`1.0`). |
| `outcome` | object | `subject`, `before`, `after`, `warehouse`, `completed`, `escalated`. |
| `kpis` | object | `products_involved`, `gates_passed`, `evidence_artifacts`, `steps_completed`, `time_to_resolve`. |
| `gates` | array | Human decisions: `gate`, `owner`, `decision`, optional `approval_ref`. |
| `evidence` | array | Per-product artifacts: `product`, `artifact`, `state`. |
| `steps` | array | Business steps: `index`, `title`, `product`, `artifact`. |

## Validation

[`verify.ps1`](verify.ps1) enforces these structures and the minimum value thresholds (products, gates, evidence, steps, governance-denial evidence).
