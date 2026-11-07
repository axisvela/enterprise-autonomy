# Executable Evidence for Vertical Slices

Each domain adapter under `adapters/` is a local reference service with a Go test suite.
The table records the public, reproducible check for each runnable vertical slice:

```powershell
cd adapters/<adapter>
go test . -count=1
```

All adapters below passed (`go test . -count=1`, 2026-11-07).

| Vertical slice | Reference adapter | Check |
| --- | --- | --- |
| [Order fulfillment exception](order-fulfillment-exception.md) | `order-domain` / `inventory-domain` | Order action requires approval and idempotency; replay does not duplicate the action. |
| [Procurement request to receipt](procurement-request-to-receipt.md) | `procurement-domain` | Segregation of duties and conjunctive approval gates. |
| [Customer case resolution](customer-case-resolution.md) | `customer-domain` | Consent is a first-class gate before resolution. |
| [Recruitment requisition to offer](recruitment-requisition-to-offer.md) | `recruitment-domain` | Automation cannot make the final hiring decision. |
| [Predictive maintenance to work order](predictive-maintenance-to-work-order.md) | `maintenance-domain` | Prediction-not-fault and safety conjunctive gates. |
| [Integration outage recovery](integration-outage-recovery.md) | `integration-domain` | Preserve, verify and never silently rerun failed integration work. |
| [Simulation to validation](simulation-to-validation.md) | `simulation-domain` | Immutable simulation evidence is required before a decision. |
| [Compliance request to audit](compliance-request-to-audit.md) | `compliance-domain` | Completeness-gated attestation and audit package. |
| [Fleet mission exception](fleet-mission-exception.md) | `fleet-domain` | Autonomous boundary plus pause-and-review. |
| [Process to outcome](process-to-outcome.md) | `process-domain` | Stage-sequenced durable process with recorded advances. |
| [Innovation sandbox to policy](innovation-sandbox-to-policy.md) | `sandbox-domain` | Sandbox boundary plus evidence-based policy decision. |
| [Sequenced deployment](sequenced-deployment.md) | `deployment-domain` | Sequenced autonomous execution; deviations require approval. |
| [Inference request to governed answer](inference-request-to-governed-answer.md) | `inference-domain` | Governed inference, high-impact review and immutable audit. |

## Boundary

These adapters are local reference services, not production order, procurement, CRM,
maintenance, integration, simulation, compliance, fleet, process, sandbox, deployment
or inference systems. The tests prove adapter behavior over HTTP with local persistence;
they do not prove production endpoints, network partitions, multi-tenant isolation or
provider-side status authority.

The separate `demo-repository/praxovela-e2e` Case C9 records local PostgreSQL
effect/outbox/reconcile checks. It is not production execution-authority evidence.
