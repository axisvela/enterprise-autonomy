# Praxovela â€?Governed Agent Runtime

## Public Role

Local-first desktop agent runtime with governed, sandboxed capability use, a deny-by-default effect ledger, checkpoint recovery, and replayable execution traces.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `axond.exe` (AXON Core), desktop app, `prax-bench`, `skig` |
| Current port | `8420` (`AXON_PORT`) |
| Planned port | `1866` AXON |
| Database | local SQLite (`axon.db`); optional `AXON_MEMORY_URL` (Mnemovela) |
| Interfaces | HTTP API, embedded MCP gateway, Tauri desktop app |
| Health | `GET /health` |

## Where It Fits

- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) â€?runnable deny-by-default agent step with effect ledger
- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) â€?governed agent actions

## Authority

The [praxovela-open](https://github.com/axisrobo/praxovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
