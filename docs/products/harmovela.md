# Harmovela — Coordination Protocol

## Public Role

Open asynchronous coordination protocol for autonomous-system events, tasks, state, delegation, recovery, and governance.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `harmovelad` (daemon), `harmovela` (CLI); TS/Python/Java equivalents; no local `.exe` |
| Current ports | WebSocket `8787`, SSE `8788`, HTTP API `8790` |
| Planned ports | `1936` WS · `1937` SSE · `1938` API |
| Database | SQLite default; PostgreSQL optional |
| Interfaces | HTTP API, WebSocket, SSE, stdio, gRPC, NATS/Kafka/Redis transports, CLI, MCP bridge |
| Health | `GET /harmovela/api/healthz` |

## Where It Fits

- Cross-runtime coordination between agents, robots, and process runtimes
- Open-protocol foundation for ecosystem interoperability

## Authority

The [harmovela](https://github.com/axisrobo/harmovela) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
