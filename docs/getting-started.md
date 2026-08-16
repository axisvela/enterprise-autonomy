# Getting Started

This guide orients new readers across the public AxisRobo Enterprise Autonomy material.

## 1. Understand the ecosystem

Read the [product overview](products.md) to learn what the fifteen products do. Each product has a [public overview page](products.md) and an authoritative repository.

## 2. Pick a scenario

Browse the [business scenario catalog](business-scenarios.md) and choose a [vertical slice](../vertical-slices/) close to your outcome. Each slice names a trigger, accountable owner, completion, evidence, human decision gates, and exceptions.

## 3. See product composition

Reference stacks, such as [facility inspection](../reference-stacks/facility-inspection.md), show which products can contribute to a class of outcomes and where human review points sit.

## 4. Understand example value

The [value framework](example-value.md) explains what makes an example valuable: outcome, accountable owner, decision gates, evidence, and effect. The [value metrics catalog](../examples/value-metrics.md) defines KPIs per example class.

## 5. Run a local demo

Five runnable local demos are available, each producing a value report:

- [Order exception demo](../examples/order-fulfillment-local/README.md) — stockout exception with approvals and value report.
- [Procurement demo](../examples/procurement-local/README.md) — governed purchasing with segregation of duties.
- [Customer case demo](../examples/customer-case-local/README.md) — governed customer remedy with consent and approval.
- [Recruitment demo](../examples/recruitment-local/README.md) — human-only hiring decisions with an automation boundary.
- [Predictive maintenance demo](../examples/predictive-maintenance-local/README.md) — safety-reviewed intervention with prediction-vs-fact integrity.
- [Integration recovery demo](../examples/integration-recovery-local/README.md) — preserved, verified recovery with no silent re-execution.
- [Simulation validation demo](../examples/simulation-validation-local/README.md) — evidence-gated release with immutable simulation evidence.
- [Compliance audit demo](../examples/compliance-audit-local/README.md) — completeness-gated attestation and immutable audit package.
- [Fleet mission demo](../examples/fleet-mission-local/README.md) — autonomous boundary enforcement and operator-reviewed pauses.

Run them all end to end with `.\examples\run-all-demos.ps1` (requires a full local stack; use `-CheckOnly` to verify structure without a database). Aggregate the results with `.\scripts\report-value.ps1` into the [value dashboard](value-dashboard.md). See the [local run handbook](../examples/local-run-handbook.md) for startup guidance.

## 6. Learn operational details

The [technical catalog](technical-catalog.md) lists binaries, current and planned ports, databases, and health endpoints. The [port migration guide](port-migration.md) explains the planned port allocation.

## 7. Check release status

The [release status](release-status.md) page summarizes public release maturity. Each product repository is authoritative for its own releases.

## Boundaries

This repository is public and adoption-oriented. Never expect to find internal architecture, contracts, schemas, profiles, conformance, governance, deployment topology, credentials, or customer data here; those live in the private repository.
