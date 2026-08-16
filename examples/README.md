# Public Examples

Public examples illustrate how AxisRobo products can be composed to achieve a measurable outcome. They are adoption-oriented, not deployment blueprints. Every example makes its value explicit through outcome, decision gates, evidence, and effect; see the [value framework](../docs/example-value.md).

| Example | Type | Description | Value & Effect |
| --- | --- | --- | --- |
| [Mission to execution](mission-to-execution.md) | Designed scenario | Bounded physical inspection with human review. | [Value & Effect](mission-to-execution.md#value--effect) |
| [Order fulfillment exception (local)](order-fulfillment-local/README.md) | Runnable local demo | End-to-end stockout exception across local binaries with a verified value report. | [Value & Effect](order-fulfillment-local/README.md#value--effect) |
| [Procurement request to receipt (local)](procurement-local/README.md) | Runnable local demo | Governed purchasing lifecycle with segregation of duties and a verified value report. | [Value & Effect](procurement-local/README.md#value--effect) |
| [Customer case resolution (local)](customer-case-local/README.md) | Runnable local demo | Governed customer remedy with consent and approval, and a verified value report. | [Value & Effect](customer-case-local/README.md#value--effect) |
| [Recruitment requisition to offer (local)](recruitment-local/README.md) | Runnable local demo | Human-only hiring decisions with an automation boundary, and a verified value report. | [Value & Effect](recruitment-local/README.md#value--effect) |
| [Predictive maintenance (local)](predictive-maintenance-local/README.md) | Runnable local demo | Safety-reviewed intervention with prediction-vs-fact integrity, and a verified value report. | [Value & Effect](predictive-maintenance-local/README.md#value--effect) |
| [Integration outage recovery (local)](integration-recovery-local/README.md) | Runnable local demo | Preserved, verified recovery with no silent re-execution, and a verified value report. | [Value & Effect](integration-recovery-local/README.md#value--effect) |
| [Simulation to validation (local)](simulation-validation-local/README.md) | Runnable local demo | Evidence-gated release with immutable simulation evidence, and a verified value report. | [Value & Effect](simulation-validation-local/README.md#value--effect) |
| [Compliance request to audit (local)](compliance-audit-local/README.md) | Runnable local demo | Completeness-gated attestation and immutable audit package, with a verified value report. | [Value & Effect](compliance-audit-local/README.md#value--effect) |
| [Fleet mission exception (local)](fleet-mission-local/README.md) | Runnable local demo | Autonomous boundary enforcement and operator-reviewed pauses, with a verified value report. | [Value & Effect](fleet-mission-local/README.md#value--effect) |
| [Process to outcome (local)](process-to-outcome-local/README.md) | Runnable local demo | Stage-sequenced durable process with terminal-state enforcement, and a verified value report. | [Value & Effect](process-to-outcome-local/README.md#value--effect) |
| [Innovation sandbox (local)](innovation-sandbox-local/README.md) | Runnable local demo | Bounded sandbox experiments and evidence-based policy, with a verified value report. | [Value & Effect](innovation-sandbox-local/README.md#value--effect) |

## Supporting Material

- [Value framework](../docs/example-value.md) — how examples demonstrate value.
- [Value dashboard](../docs/value-dashboard.md) — aggregated view of all demo value reports.
- [Governance patterns](../docs/governance-patterns.md) — examples organized vertically by governance pattern.
- [Governance subtlety](../docs/governance-subtlety.md) — why the design is structural, not just chained services.
- [Value report template](value-report-template.md) — machine-readable outcome report.
- [Value metrics catalog](value-metrics.md) — KPIs by example class.
- [Input/output conventions](inputs-outputs.md) — shared shape for step I/O.
- [Local run handbook](local-run-handbook.md) — startup and troubleshooting guidance.
- [Detailed operations guide](order-fulfillment-local/operations-guide.md) — exact requests/responses for the runnable demo.
- [Governance subtlety](../docs/governance-subtlety.md) — why the design is structural, not just chained services.
- [Mission-to-execution walkthrough](mission-to-execution-walkthrough.md) — concrete artifacts for the designed example.

## Local Runnable Demos

Runnable demos execute against real local product binaries and produce observable business artifacts plus a machine-readable value report. Run them individually (`<demo-dir>\run-all.ps1`) or all together:

```powershell
.\run-all-demos.ps1                # all four demos, end to end
.\run-all-demos.ps1 -CheckOnly     # verify structure without a database
.\stop-demo.ps1                    # stop all demo processes (path-based, safe)
```

Then aggregate the value reports:

```powershell
..\scripts\report-value.ps1        # dashboard -> .stack\all-demos-report.json
```

See the [local run handbook](local-run-handbook.md) for startup and troubleshooting guidance.

## Boundaries

Public examples must not include contracts, schemas, private profiles, security configuration, service endpoints, deployment topology, credentials, internal thresholds, customer data, or confidential operating procedures. Follow the [public example design guide](../docs/example-design-guide.md).
