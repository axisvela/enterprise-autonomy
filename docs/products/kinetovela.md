# Kinetovela — Robotics Fleet Control Plane

## Public Role

Physical-autonomy and robotics fleet control plane for bounded, observable, and recoverable missions.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `kinetovela-api` (source entrypoint; no local compiled `.exe`) |
| Current port | `:8080` (`KINETOVELA_LISTEN_ADDR`) |
| Planned port | `1946` API |
| Database | PostgreSQL documented as authoritative; not yet wired in shipped binary |
| Interfaces | HTTP API (health and version only in current binary); frontend planned but not implemented |
| Health | `GET /healthz` |

## Where It Fits

- [Mission-to-execution](../../vertical-slices/mission-to-execution.md) — physical execution
- [Facility inspection](../../reference-stacks/facility-inspection.md) — robot-fleet task execution
- [Fleet mission exception](../../vertical-slices/fleet-mission-exception.md) — exception handling for physical missions

## Authority

The [kinetovela-open](https://github.com/axisrobo/kinetovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details and maturity notes.
