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

## Worked Example

The [order-exception demo](order-fulfillment-local/README.md) emits a report matching this shape after a successful `alternate_location`:

```json
{
  "example": "order-fulfillment-exception",
  "version": "1.0",
  "tenant": "tenant-a",
  "operator": "operations-lead",
  "outcome": {"subject": "order-123", "before": "stockout", "after": "replanned",
              "warehouse": "warehouse-b", "completed": true, "escalated": false},
  "kpis": {"products_involved": 7, "gates_passed": 2, "evidence_artifacts": 8,
           "steps_completed": 8, "time_to_resolve": "1.4"},
  "gates": [
    {"gate": "case-opened", "owner": "operations-lead", "decision": "open"},
    {"gate": "action-approved", "owner": "operations-lead", "decision": "alternate_location",
     "approval_ref": "approval://order-123-stockout"}
  ],
  "evidence": [
    {"product": "ontovela", "artifact": "assertion-order-123-stockout", "state": "observed"},
    {"product": "symbivela", "artifact": "order-123-stockout", "state": "open"},
    {"product": "rheovela", "artifact": "<instance-id>", "state": "open"},
    {"product": "inventory-domain", "artifact": "adjustment-inventory-order-123-reserve-v1", "state": "reserved"},
    {"product": "praxovela", "artifact": "order-123-stockout-handoff-v1", "state": "effect-ledgered"},
    {"product": "order-domain", "artifact": "unapproved-action-rejected", "state": "denied"},
    {"product": "order-domain", "artifact": "action-order-123-alternate_location-v1", "state": "replanned"},
    {"product": "order-domain", "artifact": "notification-order-123", "state": "pending"}
  ],
  "steps": [
    {"index": 1, "title": "Detect the stockout", "product": "ontovela", "artifact": "assertion-order-123-stockout"}
  ]
}
```

The console summary prints the order transition, the approval used, the gate and evidence counts, and the per-product audit chain. See the [detailed operations guide](order-fulfillment-local/operations-guide.md) for the request/response that produces each entry.

