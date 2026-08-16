# Symbivela — Human-Agent Collaboration Workspace

## Public Role

Human sovereignty control surface for goals, plan review, approvals, intervention, evidence inspection, and outcomes.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `symbivela` (local `symbivela.exe`), plus `symbivela-audit`, `symbivela-bench`, `symbivela-migrate` |
| Current port | `:8080` (fixed) |
| Planned port | `1926` API |
| Database | PostgreSQL required (`DATABASE_URL`) |
| Interfaces | HTTP API, React/Vite frontend, CLI tools |
| Health | `GET /health`, `/ready`, `/metrics` |

## Where It Fits

- [Order fulfillment exception](../../vertical-slices/order-fulfillment-exception.md) — operator review and case authority
- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — operator collaboration and approval
- [Release operations](../../reference-stacks/release-operations.md) — release case and operator workspace
- [Local order-exception demo](../../examples/order-fulfillment-local/README.md) — runnable workspace and exception cases

## Authority

The [symbivela-open](https://github.com/axisrobo/symbivela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
