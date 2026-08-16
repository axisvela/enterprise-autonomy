# Rheovela — Durable Workflow Platform

## Public Role

Dynamic process and durable-workflow platform for recoverable, approvable, and auditable process instances.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `rheo` (local `rheo.exe`); EE `rheo-ee`; worker SDKs |
| Current ports | core `:8080` (`--addr`); EE `:8081` |
| Planned ports | `1876` serve · `1877` console |
| Database | SQLite default (`~/.proc/proc.db`); PostgreSQL backend for EE |
| Interfaces | CLI, HTTP Ops API, MCP gateway, EE Ops Cockpit |
| Health | `GET /api/v1/health` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) — durable exception process
- [Process-to-outcome](../../vertical-slices/process-to-outcome.md) — long-running process coordination
- [Release operations](../../reference-stacks/release-operations.md) — durable release process
- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) — runnable durable process instance

## Authority

The [rheovela-open](https://github.com/axisrobo/rheovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
