# Release Status

This page summarizes the public maturity of each product's local surface. Product repositories are authoritative for their own release versions and availability.

> **This public repository is at 1.1.9** — a stable release series (1.x) of the introduction and examples content. Releases are tagged `vX.Y.Z` and published to GitHub Releases with their CHANGELOG body; every version tag has a matching release. See the [demo matrix](demo-matrix.md) for the full runnable-demo set and [CHANGELOG.md](../CHANGELOG.md) for the release history.

| Product | Local binary available | Maturity notes |
| --- | --- | --- |
| Moduregis | Yes (`moduregis-api.exe`, worker, migrate) | Windows release archives under `dist/`; local demo uses v1.0.1. |
| Orchadyn | Yes (`orchadyn-api`, MCP, migrate) | Release archives under `releases/`; local demo downloads v0.7.0. |
| Noetivela | Yes (gateway, controller, CLI) | No database required. |
| Gnosivela | Yes (`gnosivela`, `gnosivela-gen`) | In-memory default; optional PostgreSQL. |
| Mnemovela | Yes (`mneme-http`, `mneme-grpc`, MCP) | Embedded storage default; PostgreSQL + PGVector in EE. |
| Ontovela | Yes (`ontovela.exe`) | In-memory default; optional PostgreSQL. |
| Praxovela | Yes (`axond.exe`, desktop app) | Local SQLite. |
| Rheovela | Yes (`rheo.exe`) | SQLite default; PostgreSQL backend in EE. |
| Kinetovela | Yes (`kinetovela-api`, darwin/linux/windows amd64) | GitHub release v0.30.0 publishes multi-platform binaries plus adapter TCK/quickstart, multi-vendor-acceptance, and offline-autonomy tools. |
| Aegivela | Yes (`aegivela-api`) | GitHub release v0.5.0 (darwin/linux/windows); EE binary `aegivela-ee.exe`; PostgreSQL required. |
| Limenora | Yes (edge, enterprise, control) | Also Rust reference gateway. Edge default `1896` (`--port`). |
| Peiravela | Yes (`api-server`, `control-plane`) | Release builds under `bin/`. |
| Tekmovela | Yes (`tek.exe`) | CLI only; no listener. |
| Symbivela | Yes (`symbivela.exe`) | v1.1.1: core API on `1926` (`SYMBIVELA_ADDR`); frontend dev `1927`. PostgreSQL required. |
| Harmovela | Protocol-first; no compiled binary expected | Coordination protocol with `harmovelad` daemon, `harmovela` CLI, and TS/Python/Java equivalents; standalone `.exe` may not be required. |
| Nomivela | Yes (`nomivela`, `nomivela-migrate`) | Agent identity registry of record; PostgreSQL required; signed discovery (`/.well-known/agent-iam`) and Open SDKs (Go/Java/Python). |
| Eidovela | Yes (`eidovelad`, `eidovela-migrate`) | Agent identity provider; registry-consumer mode (requires NOMIVELA); PoP tokens and proof-bound introspection; PostgreSQL optional (in-memory reference store default). |

## Port-Migration Status

Tracking against the [planned port allocation](port-migration.md). Product repositories are authoritative for their actual listener addresses. "Default migrated" means the shipped binary's default listener is the planned port; "Demo-stack migrated" means the runnable local demos run that product on the planned port via its documented override.

| Product | Current ports | Planned ports | Status |
| --- | --- | --- | --- |
| Moduregis | `1806` (`LISTEN_ADDR` default) | `1806` API · `1807` console | Default migrated |
| Orchadyn | `1816` (`ORCHADYN_LISTEN_ADDR` default) | `1816` API | Default migrated |
| Noetivela | gateway `:8080`, controller `:8081` | `1826` gateway · `1827` controller | Not migrated |
| Gnosivela | `:8080` (`-addr`) | `1836` API | Not migrated |
| Mnemovela | HTTP `8080`, gRPC `9090`, web `4200` | `1846` HTTP · `1847` gRPC | Not migrated |
| Ontovela | default `:8080`; demos on `1856` | `1856` API | Demo-stack migrated |
| Praxovela | default `8420`; demos on `1866` | `1866` AXON | Demo-stack migrated |
| Rheovela | default `:8080`; demos on `1876` | `1876` serve · `1877` console | Demo-stack migrated |
| Aegivela | `1886` core · `1887` EE | `1886` core · `1887` EE | Migrated |
| Limenora | edge `1896` (`--port` default) | `1896` edge · `1897` enterprise · `1898` control | Default migrated |
| Peiravela | `:8080` (`PEIRAVELA_API_ADDR`) | `1906` API | Not migrated |
| Tekmovela | none (CLI only) | `1916` reserved | Not applicable |
| Symbivela | `1926` (`SYMBIVELA_ADDR` default since v1.1.1) | `1926` API | Default migrated (v1.1.1) |
| Harmovela | WS `8787`, SSE `8788`, API `8790` | `1936` WS · `1937` SSE · `1938` API | Not migrated |
| Kinetovela | `:8080` (`KINETOVELA_LISTEN_ADDR`) | `1946` API | Not migrated |
| Nomivela | `1956` (`NOMIVELA_HTTP_PORT` default) | `1956` API | Default migrated |
| Eidovela | `127.0.0.1:8080` (`EIDOVELA_LISTEN_ADDR`) | `1966` API | Not migrated |

## Notes

- Most HTTP services still default to `:8080`; new deployments should use the [planned port allocation](port-migration.md). Moduregis, Orchadyn, Limenora, Aegivela, Symbivela (v1.1.1), and Nomivela ship planned ports as defaults; the local demo stack runs Ontovela, Praxovela, and Rheovela on their planned ports via documented overrides.
- Health endpoints are `/healthz` or `/health` unless noted in the [technical catalog](technical-catalog.md).
- Posture varies from PostgreSQL-required to embedded/SQLite-default; see the [technical catalog](technical-catalog.md) for each product.
