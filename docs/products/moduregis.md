# Moduregis — Capability Control Plane

## Public Role

Enterprise capability control plane for publishing, discovering, governing, authorizing, invoking, and auditing capabilities.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `moduregis-api`, `moduregis-worker`, `moduregis-migrate`, `moduregis-health`, `moduregis-import-skill`, `moduregis-recovery-verify`; Windows release archives under `dist/`. |
| Current port | `:8080` (`LISTEN_ADDR`) |
| Planned port | `1806` API · `1807` console |
| Database | PostgreSQL 16 required (`DATABASE_URL`) |
| Interfaces | HTTP API `v1alpha1`, React management console, CLI |
| Health | `GET /healthz`, `/readyz`, `/v1/health` |

## Where It Fits

- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — capability control for physical work
- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) — governed capability invocation
- [Release operations](../../reference-stacks/release-operations.md) — release and compliance notifications

## Authority

The [moduregis-open](https://github.com/axisrobo/moduregis-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
