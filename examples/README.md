# Public Examples

Public examples illustrate how AxisRobo products can be composed to achieve a measurable outcome. They are adoption-oriented, not deployment blueprints. Every example makes its value explicit through outcome, decision gates, evidence, and effect; see the [value framework](../docs/example-value.md).

| Example | Type | Description | Value & Effect |
| --- | --- | --- | --- |
| [Mission to execution](mission-to-execution.md) | Designed scenario | Bounded physical inspection with human review. | [Value & Effect](mission-to-execution.md#value--effect) |
| [Order fulfillment exception (local)](order-fulfillment-local/README.md) | Runnable local demo | End-to-end stockout exception across local binaries with a verified value report. | [Value & Effect](order-fulfillment-local/README.md#value--effect) |

## Supporting Material

- [Value framework](../docs/example-value.md) — how examples demonstrate value.
- [Value report template](value-report-template.md) — machine-readable outcome report.
- [Value metrics catalog](value-metrics.md) — KPIs by example class.
- [Input/output conventions](inputs-outputs.md) — shared shape for step I/O.
- [Local run handbook](local-run-handbook.md) — startup and troubleshooting guidance.
- [Detailed operations guide](order-fulfillment-local/operations-guide.md) — exact requests/responses for the runnable demo.
- [Governance subtlety](../docs/governance-subtlety.md) — why the design is structural, not just chained services.
- [Mission-to-execution walkthrough](mission-to-execution-walkthrough.md) — concrete artifacts for the designed example.

## Local Runnable Demos

Runnable demos execute against real local product binaries and produce observable business artifacts plus a machine-readable value report. See the [local run handbook](local-run-handbook.md) for common startup and troubleshooting guidance.

## Boundaries

Public examples must not include contracts, schemas, private profiles, security configuration, service endpoints, deployment topology, credentials, internal thresholds, customer data, or confidential operating procedures. Follow the [public example design guide](../docs/example-design-guide.md).
