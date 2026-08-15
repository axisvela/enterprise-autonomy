# Order Fulfillment Exception Management

## Business Scenario

An ordered item is unavailable at its assigned warehouse. Operations must choose an acceptable alternative, obtain the required approval when the customer promise changes, update connected systems, and retain evidence of the outcome.

| Item | Definition |
| --- | --- |
| Trigger | Inventory, warehouse, carrier, or payment event puts the original order promise at risk. |
| Accountable owner | Order operations lead. |
| Completion | Order is fulfilled, replaced, split, cancelled, or escalated with records and customer communication updated. |
| Evidence | Order reference, exception reason, alternatives, decision, executed action, and notification status. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Order, warehouse, carrier, and customer-system connectivity | Limenora |
| Current operational state | Ontovela |
| Alternative planning | Orchadyn |
| Capability control | Moduregis |
| Authorization and approvals | Aegivela |
| Durable exception process | Rheovela |
| Operator review | Symbivela |

## Design Steps

1. Define the exception classes: stockout, delivery delay, address failure, payment hold, and damaged goods.
2. Define permitted outcomes for each class: alternate location, split shipment, approved substitute, revised promise, refund, cancellation, or escalation.
3. Identify which outcomes require customer consent, finance review, or an operations-lead decision. A recommendation is never approval.
4. Require evidence for each alternative, including availability, delivery impact, price impact, and customer preference where available.
5. Pilot one exception class and reversible outcomes before expanding scope.

## Operating Steps

1. **Open the case.** An at-risk event creates a case with the order reference, affected items, reason, detection time, and accountable owner.
2. **Validate the signal.** The operator checks the current order, inventory, carrier, and payment context. Stale or conflicting data is recorded for correction, not used to change the order.
3. **Prepare alternatives.** The operator reviews allowed alternatives with their customer and operational impact.
4. **Make the decision.** The operator may select an approved, in-policy alternative. Promise changes, price changes, refunds, or cancellations wait for the required customer or human decision.
5. **Execute and confirm.** The approved action updates the connected systems. The case records acceptance or failure for each required update.
6. **Notify and close.** The operator verifies communication status and closes only after the final order state is evidenced. Unresolved cases go to the escalation queue with all prior evidence.

## Exceptions

- No acceptable alternative: escalate; do not silently cancel or substitute.
- Customer consent required: hold execution until consent or the approved fallback is recorded.
- External update failed: preserve the case and show the failure to the accountable operator.
- Conflicting data: resolve through human review before changing the customer promise.

## Public Boundary

This example omits pricing rules, allocation logic, communication templates, endpoints, and approval policy.
