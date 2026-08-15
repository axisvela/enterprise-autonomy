# Designing Public Examples

Public examples explain how products can be composed to achieve an outcome without revealing internal architecture or deployment-sensitive implementation.

## Design Steps

1. Define a measurable operational outcome and the accountable human role.
2. Identify the operational context, constraints, evidence, and review points needed for that outcome.
3. Assign product roles by published capability, while keeping each product authoritative for its own domain.
4. Describe the lifecycle from intent through review using observable business events.
5. State what the example intentionally excludes, including topology, policy logic, credentials, customer data, and internal interfaces.
6. Add a **Value & Effect** section covering outcome value, 2–4 KPIs, decision gates, evidence produced, and the adoption path. See the [value framework](example-value.md) and the [value metrics catalog](../examples/value-metrics.md).

## Scenario Format

Each scenario names a concrete trigger, accountable owner, completion evidence, human decision gates, exception paths, and the information intentionally excluded from the public workflow.

## Input / Output Detail

Examples must document the **input and output of every step** so readers can understand the value without running the system. Follow the shared [input/output conventions](../examples/inputs-outputs.md):

- **Runnable demos**: exact method, URL, headers (tenant + idempotency), JSON body, and the response fields read, per step. See the [detailed operations guide](../examples/order-fulfillment-local/operations-guide.md).
- **Designed examples**: per-step `Input` (who provides what), `Products` (contributing roles), and `Output` artifact with a concrete id (case, assertion, approval, status record).
- **Value report**: runnable examples emit a machine-readable [value report](../examples/value-report-template.md) recording outcome, KPIs, gates, and evidence.

Use concrete, stable identifiers (for example `order-123`, `approval://order-123-stockout`) and state the headers and idempotency keys so runs are reproducible.

## Operating Steps

1. Prepare the required product environments using their individual public documentation.
2. Confirm the responsible operator, intended outcome, and available resources.
3. Begin with a constrained trial or simulated scenario where appropriate.
4. Review progress and evidence at each defined human decision point.
5. Record the outcome, improve the scenario, and expand only after the organization accepts the result.

## Scope Boundary

Public examples must not include contracts, schemas, private profiles, security configuration, service endpoints, deployment topology, credentials, internal thresholds, customer data, or confidential operating procedures.
