# Reference Adapters

Reference adapters are local, illustrative integrations used by runnable examples. They are not production systems.

| Adapter | Role | API Reference |
| --- | --- | --- |
| [order-domain](order-domain/README.md) | Simulated order, inventory, payment, carrier, and customer-notification views with governed fulfillment actions. | [API.md](order-domain/API.md) |
| [inventory-domain](inventory-domain/README.md) | Simulated multi-warehouse inventory views with governed, approved stock adjustments. | [API.md](inventory-domain/API.md) |
| [procurement-domain](procurement-domain/README.md) | Simulated purchasing views: requests, budget, suppliers, purchase orders, and receipts with segregation of duties and role approvals. | [API.md](procurement-domain/API.md) |
| [customer-domain](customer-domain/README.md) | Simulated customer-service views: cases, verified facts, consent, resolutions, accounts, and notifications with consent + approval governance. | [API.md](customer-domain/API.md) |

Use these only for demos and development. Replace them with authorized production integrations before real business use.
