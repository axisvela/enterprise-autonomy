# Aegivela — Identity and Authorization Fabric

## Public Role

Agent identity, authorization, and security fabric for delegated authority, approvals, revocation, attestations, and security evidence.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `aegivela-api` (core, no local `.exe`); EE `aegivela-ee.exe` |
| Current ports | core `:8080`; EE `:8081` |
| Planned ports | `1886` core · `1887` EE |
| Database | PostgreSQL required (`DATABASE_URL`) |
| Interfaces | HTTP API, PEP SDK library |
| Health | `GET /healthz` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) — authorization and approvals
- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — identity and authorization
- [Facility inspection](../../reference-stacks/facility-inspection.md) — delegated authority and approval
- [Release operations](../../reference-stacks/release-operations.md) — identity, authorization, and approvals

## Authority

The [aegivela-open](https://github.com/axisrobo/aegivela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
