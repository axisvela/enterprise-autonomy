# Adoption Guide

How to approach adopting AxisRobo Enterprise Autonomy products for a governed autonomous outcome.

## Principles

- **Start with the outcome, not the products.** Define the measurable operational outcome and the accountable human role first.
- **Keep product authority.** Each product remains authoritative for its own domain; compose, do not merge.
- **Govern the boundaries.** Define human decision gates, evidence, and exception handling before enabling autonomy.
- **Start small.** Pilot a limited scope, reversible case before expanding.

## Process

1. **Define the outcome.** Use the [public example design guide](example-design-guide.md) to structure the goal, context, constraints, evidence, and review points.
2. **Select product roles.** Map needs to product roles using the [product overview](products.md) and relevant [reference stacks](../reference-stacks/).
3. **Plan the human gates.** Identify every decision that requires review, approval, consent, or escalation.
4. **Trial in a controlled environment.** Use simulation ([Peiravela](products/peiravela.md)) and engineering assurance ([Tekmovela](products/tekmovela.md)) before live operation.
5. **Run, review, and improve.** Execute the accepted plan, review evidence at each gate, and expand only after the organization accepts the result.
6. **Measure the effect.** Define KPIs using the [value metrics catalog](../examples/value-metrics.md), and verify the outcome with the [value framework](example-value.md).

## Scenario Guidance

- [Business scenario catalog](business-scenarios.md) — outcome-level scenarios
- [Reference stacks](../reference-stacks/) — product-composition overviews
- [Vertical slices](../vertical-slices/) — end-to-end use cases

## Operational Guidance

- [Technical catalog](technical-catalog.md) — binaries, ports, databases, health endpoints
- [Port migration](port-migration.md) — planned port allocation
- [Release status](release-status.md) — public release maturity
- [Ecosystem links](ecosystem-links.md) — product repositories

## Non-Goals

This guide does not cover internal architecture, contracts, schemas, profiles, conformance, governance, or security configuration. Those belong to the private repository and to each product's documentation.
