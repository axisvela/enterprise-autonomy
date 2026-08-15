# Limenora â€?Governed Integration Gateway

## Public Role

Governed integration gateway for APIs, MCP servers, events, webhooks, and partner systems.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `limenora-edge`, `limenora-enterprise`, `limenora-gateway`, `limenora-control`, `limenora-capability`; Rust reference gateway |
| Current ports | edge `10255`, enterprise `10256`, control `10257`; optional `GATEWAY_ADMIN_PORT` |
| Planned ports | `1896` edge Â· `1897` enterprise Â· `1898` control |
| Database | PostgreSQL optional (server role); Valkey/Redis optional |
| Interfaces | HTTP gateway (proxy, CONNECT, webhooks, event ingress, admin), control CLI, capability manifest CLI |
| Health | `GET /healthz`, `/v1/health`, `/v1/health/detailed` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) â€?order, warehouse, carrier, and customer-system connectivity
- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) â€?runnable governed edge gateway
- [Integration outage recovery](../../vertical-slices/integration-outage-recovery.md) â€?connectivity resilience

## Authority

The [limenora-open](https://github.com/axisrobo/limenora-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
