# Ontovela — Digital Twin and World Model

## Public Role

Digital enterprise twin and operational world-model platform with evidence-bearing temporal (bitemporal) state.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `ontovela` (local `ontovela.exe`); EE `ontovela-ee.exe` |
| Current ports | core `:8080` (`-addr`); EE `:8090` |
| Planned port | `1856` API |
| Database | PostgreSQL optional (`-pg-dsn`); in-memory default |
| Interfaces | tenant-scoped HTTP API, SDKs |
| Health | `GET /healthz` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) — operational state such as stockout assertions
- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — operational context
- [Facility inspection](../../reference-stacks/facility-inspection.md) — facility state
- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) — runnable assertion and state resolution

## Authority

The [ontovela-open](https://github.com/axisrobo/ontovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
