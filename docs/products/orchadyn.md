# Orchadyn â€?Planning Compiler

## Public Role

Enterprise planning compiler that turns governed goals, state, capabilities, and constraints into verified, revisable plans.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `orchadyn-api`, `orchadyn-mcp`, `orchadyn-migrate` |
| Current port | `:8080` (`ORCHADYN_LISTEN_ADDR`) |
| Planned port | `1816` API |
| Database | PostgreSQL for the plan ledger (`DATABASE_URL`); MCP uses in-memory ledger |
| Interfaces | HTTP API, MCP stdio server, migrate CLI |
| Health | `GET /healthz` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) â€?alternate-fulfillment plan generation
- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) â€?planning and replanning
- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) â€?runnable verified planning

## Authority

The [orchadyn-open](https://github.com/axisrobo/orchadyn-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
