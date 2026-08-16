# Reference Adapters

Reference adapters are local, illustrative integrations used by runnable examples. They are not production systems.

| Adapter | Role | API Reference |
| --- | --- | --- |
| [order-domain](order-domain/README.md) | Simulated order, inventory, payment, carrier, and customer-notification views with governed fulfillment actions. | [API.md](order-domain/API.md) |
| [inventory-domain](inventory-domain/README.md) | Simulated multi-warehouse inventory views with governed, approved stock adjustments. | [API.md](inventory-domain/API.md) |
| [procurement-domain](procurement-domain/README.md) | Simulated purchasing views: requests, budget, suppliers, purchase orders, and receipts with segregation of duties and role approvals. | [API.md](procurement-domain/API.md) |
| [customer-domain](customer-domain/README.md) | Simulated customer-service views: cases, verified facts, consent, resolutions, accounts, and notifications with consent + approval governance. | [API.md](customer-domain/API.md) |
| [recruitment-domain](recruitment-domain/README.md) | Simulated recruiting views: requisitions, candidates, human-only decisions, and offers with an automation-cannot-decide boundary. | [API.md](recruitment-domain/API.md) |
| [maintenance-domain](maintenance-domain/README.md) | Simulated predictive-maintenance views: signals, validation, decisions, safety reviews, and work orders with prediction-vs-fact and safety conjunctive gates. | [API.md](maintenance-domain/API.md) |
| [integration-domain](integration-domain/README.md) | Simulated integration-outage recovery views: preservation, reconnection verification, resume, and completion with no-silent-rerun. | [API.md](integration-domain/API.md) |
| [simulation-domain](simulation-domain/README.md) | Simulated possible-world validation: scenarios, immutable simulation evidence, review decisions, and release with evidence-gated governance. | [API.md](simulation-domain/API.md) |
| [compliance-domain](compliance-domain/README.md) | Simulated compliance-audit views: evidence collection, attestation, and immutable audit packages with completeness gates. | [API.md](compliance-domain/API.md) |
| [fleet-domain](fleet-domain/README.md) | Simulated physical-mission views: boundary enforcement, exceptions, and operator review with pause-and-review governance. | [API.md](fleet-domain/API.md) |
| [process-domain](process-domain/README.md) | Simulated durable long-running process views: stage-sequenced advances, terminal-state enforcement, and immutable completion. | [API.md](process-domain/API.md) |
| [sandbox-domain](sandbox-domain/README.md) | Simulated innovation-sandbox views: bounded experiments, evidence-based policy decisions, and immutable policy apply. | [API.md](sandbox-domain/API.md) |
| [deployment-domain](deployment-domain/README.md) | Simulated release-pipeline views: sequenced autonomous execution, evidence-cited steps, approval-required deviations, and immutable release. | [API.md](deployment-domain/API.md) |

Use these only for demos and development. Replace them with authorized production integrations before real business use.
