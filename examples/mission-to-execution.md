# Mission-to-Execution Example

## Objective

Inspect a designated facility zone and present a reviewable result to an authorized operator.

## Design Steps

1. Define the inspection zone, the expected result, and the operator responsible for review.
2. Choose the product roles required to plan, authorize, execute, observe, and review the work.
3. Set a limited first-run scope and clear conditions for pausing or escalating to a human.

## Example Composition

| Need | Example Product Role |
| --- | --- |
| Operator collaboration and approval | Symbivela |
| Planning | Orchadyn |
| Capability control | Moduregis |
| Identity and authorization | Aegivela |
| Physical execution | Kinetovela |
| Operational context | Ontovela |
| External-system integration | Limenora |

## Outcome

The operator can initiate, supervise, and review a physical inspection without requiring the products to become a single runtime. Each product remains responsible for its own domain while contributing to the end-to-end outcome.

## Operating Steps

1. **Open the request.** Record the inspection zone, purpose, completion window, required evidence, restrictions, and accountable operator.
2. **Validate context.** Confirm the zone is available; delay, reduce scope, or escalate if an operating condition requires it.
3. **Review work.** Check planned scope, assigned resource, evidence, and stop conditions. Approve, revise, or cancel the run.
4. **Supervise.** Start the approved work, monitor status, and pause or escalate unexpected conditions.
5. **Review outcome.** Verify required evidence, record completion, and create follow-up work for findings.
6. **Close or repeat.** Close only after evidence review; partial or failed work remains visible for repeat or escalation.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | A facility inspection is completed under human authority with reviewable evidence, without merging products into a single runtime. |
| KPIs | Boundary compliance, pause-and-review rate, evidence completeness, human-approval rate. |
| Decision gates | Work review before start, pause/escalation on exceptions, evidence review at outcome. |
| Evidence produced | Inspection objective, zone context, approved plan, mission status, required evidence, completion record. |
| Adoption path | Start with a limited zone and a repeatable objective; expand coverage only after the organization accepts the result. |

See the [value framework](../docs/example-value.md) and [value metrics catalog](../examples/value-metrics.md).

See the [public example design guide](../docs/example-design-guide.md) for common boundaries and adaptation guidance.
