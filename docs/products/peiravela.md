# Peiravela â€?Simulation and Experiment Control Plane

## Public Role

Autonomous-system simulation, experimentation, and validation control plane with immutable simulation evidence.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `api-server`, `control-plane`, `gen-client` |
| Current port | `:8080` (`PEIRAVELA_API_ADDR`) |
| Planned port | `1906` API |
| Database | PostgreSQL optional; in-memory fallback |
| Interfaces | HTTP API, embedded Studio UI, control-plane CLI, client generator |
| Health | `GET /health` |

## Where It Fits

- [Simulation-to-validation](../../vertical-slices/simulation-to-validation.md) â€?review before live use
- [Facility inspection](../../reference-stacks/facility-inspection.md) â€?simulation before live operation
- [Innovation sandbox to policy](../../vertical-slices/innovation-sandbox-to-policy.md) â€?possible-world experimentation

## Authority

The [peiravela-open](https://github.com/axisrobo/peiravela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
