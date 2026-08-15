# Example Value Report Template

Runnable examples should emit a value report as a machine-readable JSON file and print a human-readable summary. The report reconstructs the outcome from each product's evidence so the effect can be verified.

## Structure

```json
{
  "example": "order-fulfillment-exception",
  "version": "1.0",
  "tenant": "tenant-a",
  "operator": "operations-lead",
  "outcome": {
    "subject": "order-123",
    "before": "stockout",
    "after": "replanned",
    "warehouse": "warehouse-b",
    "completed": true,
    "escalated": false
  },
  "kpis": {
    "products_involved": 7,
    "gates_passed": 3,
    "evidence_artifacts": 8,
    "steps_completed": 8
  },
  "gates": [
    {
      "gate": "case-opened",
      "owner": "operations-lead",
      "decision": "open"
    },
    {
      "gate": "action-approved",
      "owner": "operations-lead",
      "decision": "alternate_location",
      "approval_ref": "approval://order-123-stockout"
    }
  ],
  "evidence": [
    {
      "product": "ontovela",
      "artifact": "assertion-order-123-stockout",
      "state": "observed"
    },
    {
      "product": "symbivela",
      "artifact": "order-123-stockout",
      "state": "resolved"
    }
  ],
  "steps": [
    {
      "index": 1,
      "title": "Detect the stockout",
      "product": "ontovela",
      "artifact": "assertion-order-123-stockout"
    }
  ]
}
```

## Required Fields

- `example` and `version` identify the report.
- `outcome` records the before/after state and completion status.
- `kpis` carries the measurable effect.
- `gates` lists every human decision with its owner and decision.
- `evidence` lists the auditable artifacts per product.
- `steps` maps each business step to its product and artifact.

## Printing

Print a console summary that mirrors the JSON: order transition, approval used, gate count, evidence count, and the audit trail per product.
