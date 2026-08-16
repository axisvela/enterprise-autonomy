# Demo Matrix

All eleven vertical slices have runnable local demos. Each demo drives real local product binaries plus one reference adapter, and produces a machine-readable value report.

## Full Matrix

| # | Demo | Slice | Adapter (port) | Governance flavor | Value report | Operations guide |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | [Order fulfillment exception](../examples/order-fulfillment-local/README.md) | [order-fulfillment-exception](../vertical-slices/order-fulfillment-exception.md) | order-domain (8090) | Approval-cited deny-by-default; shared approval reference; plan-not-authorization; effect-ledger runtime; audit chain; idempotency | `order-value-report.json` | [guide](../examples/order-fulfillment-local/operations-guide.md) |
| 2 | [Procurement request to receipt](../examples/procurement-local/README.md) | [procurement-request-to-receipt](../vertical-slices/procurement-request-to-receipt.md) | procurement-domain (8092) | Segregation of duties; conjunctive approval | `procurement-value-report.json` | [guide](../examples/procurement-local/operations-guide.md) |
| 3 | [Customer case resolution](../examples/customer-case-local/README.md) | [customer-case-resolution](../vertical-slices/customer-case-resolution.md) | customer-domain (8093) | Consent as a first-class gate; conjunctive approval | `customer-value-report.json` | [guide](../examples/customer-case-local/operations-guide.md) |
| 4 | [Recruitment requisition to offer](../examples/recruitment-local/README.md) | [recruitment-requisition-to-offer](../vertical-slices/recruitment-requisition-to-offer.md) | recruitment-domain (8094) | Automation cannot decide | `recruitment-value-report.json` | [guide](../examples/recruitment-local/operations-guide.md) |
| 5 | [Predictive maintenance](../examples/predictive-maintenance-local/README.md) | [predictive-maintenance-to-work-order](../vertical-slices/predictive-maintenance-to-work-order.md) | maintenance-domain (8095) | Prediction-not-fault; safety conjunctive | `maintenance-value-report.json` | [guide](../examples/predictive-maintenance-local/operations-guide.md) |
| 6 | [Integration outage recovery](../examples/integration-recovery-local/README.md) | [integration-outage-recovery](../vertical-slices/integration-outage-recovery.md) | integration-domain (8096) | Preserve / verify / never rerun | `integration-value-report.json` | [guide](../examples/integration-recovery-local/operations-guide.md) |
| 7 | [Simulation to validation](../examples/simulation-validation-local/README.md) | [simulation-to-validation](../vertical-slices/simulation-to-validation.md) | simulation-domain (8097) | Evidence-gated release; immutable evidence | `simulation-value-report.json` | [guide](../examples/simulation-validation-local/operations-guide.md) |
| 8 | [Compliance audit](../examples/compliance-audit-local/README.md) | [compliance-request-to-audit](../vertical-slices/compliance-request-to-audit.md) | compliance-domain (8098) | Completeness-gated attestation; immutable audit | `compliance-value-report.json` | [guide](../examples/compliance-audit-local/operations-guide.md) |
| 9 | [Fleet mission exception](../examples/fleet-mission-local/README.md) | [fleet-mission-exception](../vertical-slices/fleet-mission-exception.md) | fleet-domain (8099) | Autonomous boundary; pause-and-review | `fleet-value-report.json` | [guide](../examples/fleet-mission-local/operations-guide.md) |
| 10 | [Process to outcome](../examples/process-to-outcome-local/README.md) | [process-to-outcome](../vertical-slices/process-to-outcome.md) | process-domain (8100) | Stage-sequenced durable process; terminal-state enforcement | `process-value-report.json` | [guide](../examples/process-to-outcome-local/operations-guide.md) |
| 11 | [Innovation sandbox](../examples/innovation-sandbox-local/README.md) | [innovation-sandbox-to-policy](../vertical-slices/innovation-sandbox-to-policy.md) | sandbox-domain (8101) | Sandbox boundary; evidence-based policy; immutable policy | `sandbox-value-report.json` | [guide](../examples/innovation-sandbox-local/operations-guide.md) |

## Common Stack

Every demo reuses the same local product stack: Limenora edge, Ontovela, Rheovela, Symbivela, Praxovela AXON, Moduregis, and optionally Orchadyn. See the [technical catalog](technical-catalog.md) for ports and health endpoints.

## Value Reports

Each demo writes its value report to `.local-data/`. Aggregate them with `.\scripts\report-value.ps1` into the [value dashboard](value-dashboard.md), which compares products involved, gates passed, evidence artifacts, and time-to-resolve across all eleven demos.

## Governance

The governance-pattern catalog organizing these demos vertically by governance behavior is maintained in the private `enterprise-autonomy-ee` repository; each demo's README and the [governance subtlety guide](governance-subtlety.md) summarize the behaviors it demonstrates.

## Version

This demo set is part of the public repository's **1.0.x** stable release series (current: 1.0.3). See [release status](release-status.md) and [CHANGELOG.md](../CHANGELOG.md).
