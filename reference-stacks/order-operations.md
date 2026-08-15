# Order Operations Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed order-operations outcome. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Operator review, case authority, and approvals | Symbivela |
| Order, warehouse, carrier, and payment state | Ontovela |
| Alternative planning and replanning | Orchadyn |
| Capability discovery and control | Moduregis |
| Identity, authorization, and approval | Aegivela |
| Order-system and partner connectivity | Limenora |
| Durable exception process | Rheovela |
| Governed agent actions | Praxovela |

## Design Steps

1. Define the order exceptions that matter: stockout, delivery delay, address failure, payment hold, and damaged goods.
2. Define permitted outcomes per exception class and which outcomes require customer consent or finance review.
3. Select the product roles needed for state, planning, authorization, connectivity, process, and review.
4. Identify the human decision points: case open, alternative selection, approval, and outcome acceptance.
5. Pilot one exception class with reversible outcomes before expanding scope.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm operator access.
2. Record the at-risk order, exception reason, and accountable owner when an event fires.
3. Review current order, inventory, carrier, and payment context before proposing alternatives.
4. Select an approved alternative and obtain the required approval before any promise change.
5. Execute the approved action, confirm each connected-system update, and close the case with evidence.
6. Escalate unresolved cases with all prior evidence rather than silently cancelling or substituting.

## Runnable Local Demo

For verified local-binary startup commands, configuration, and expected outputs, see the [local order-exception demo](../examples/order-fulfillment-local/README.md).

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Order exceptions resolve with evidence and required approvals; no product silently changes the customer promise. |
| KPIs | Time-to-resolve, gate compliance, evidence completeness, audit reconstructability. |
| Decision gates | Case open, alternative selection, approval before promise changes, outcome acceptance. |
| Evidence produced | Case, state, plan, process, applied action, notification status. |
| Adoption path | Pilot one exception class with reversible outcomes; the local order-exception demo is the runnable starting point. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Detect exception | order/inventory/carrier/payment event, owner | Ontovela, Limenora | exception signal + case `exc-0001` |
| Review context | current order, inventory, carrier, payment | Ontovela, Gnosivela | verified context |
| Prepare alternatives | permitted outcomes per exception class | Orchadyn, Moduregis | alternatives list |
| Approve | required consent or finance review | Aegivela, Symbivela | `approval://exc-0001` |
| Execute | approved action, connected-system updates | Limenora, Rheovela | applied action + update results |
| Close | notification status, final state evidence | Symbivela | closed case or escalation |

See the runnable [order-exception demo](../examples/order-fulfillment-local/README.md) and its [Detailed Operations Guide](../examples/order-fulfillment-local/operations-guide.md).

## Scope Boundary

Actual deployment topology, integrations, pricing, allocation logic, communication templates, and policy are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
