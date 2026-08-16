# Release Status

This page summarizes the public maturity of each product's local surface. Product repositories are authoritative for their own release versions and availability.

> **This public repository is at 1.1.0** — a stable release series (1.x) of the introduction and examples content. Releases are tagged `vX.Y.Z` and published to GitHub Releases with their CHANGELOG body; every version tag has a matching release. See the [demo matrix](demo-matrix.md) for the full runnable-demo set and [CHANGELOG.md](../CHANGELOG.md) for the release history.

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
| Kinetovela | No compiled `.exe` | Source entrypoint only; health/version only; database not yet wired; frontend planned. |
| Aegivela | No local `.exe` (core) | EE binary `aegivela-ee.exe`; PostgreSQL required. |
| Limenora | Yes (edge, enterprise, control) | Also Rust reference gateway. |
| Peiravela | Yes (`api-server`, `control-plane`) | Release builds under `bin/`. |
| Tekmovela | Yes (`tek.exe`) | CLI only; no listener. |
| Symbivela | Yes (`symbivela.exe`) | PostgreSQL required. |
| Harmovela | No local `.exe` | Daemon + CLI; TS/Python/Java equivalents. |

## Notes

- Most HTTP services still default to `:8080`; new deployments should use the [planned port allocation](port-migration.md).
- Health endpoints are `/healthz` or `/health` unless noted in the [technical catalog](technical-catalog.md).
- Posture varies from PostgreSQL-required to embedded/SQLite-default; see the [technical catalog](technical-catalog.md) for each product.
