# Kinetovela — Robotics Fleet Control Plane

## Public Role

Physical-autonomy and robotics fleet control plane for bounded, observable, and recoverable missions.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `kinetovela-api` (darwin/linux/windows amd64, GitHub release v0.30.0); adapter-quickstart, adapter-tck, multi-vendor-acceptance, offline-autonomy tools |
| Current port | `:8080` (`KINETOVELA_LISTEN_ADDR`) |
| Planned port | `1946` API |
| Database | PostgreSQL documented as authoritative |
| Interfaces | HTTP API; frontend Operations Center planned but not implemented |
| Health | `GET /healthz` |

## Where It Fits

- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — physical execution
- [Facility inspection](../../reference-stacks/facility-inspection.md) — robot-fleet task execution
- [Fleet mission exception](../../vertical-slices/fleet-mission-exception.md) — exception handling for physical missions

## Authority

The [kinetovela-open](https://github.com/axisvela/kinetovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details and maturity notes.
