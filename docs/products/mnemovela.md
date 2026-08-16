# Mnemovela — Cognition and Memory Runtime

## Public Role

Local-first cognition runtime for durable, auditable memory, context, ontology, and knowledge retrieval with commit-like semantics.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `mneme-http`, `mneme-grpc`, `mneme-jsonrpc-stdio`, `mneme-mcp-stdio`; Python REST and CLI |
| Current ports | HTTP `127.0.0.1:8080`, gRPC `:9090`, web console `4200`, Python REST `8000` |
| Planned ports | `1846` HTTP · `1847` gRPC |
| Database | embedded in-memory / Pebble / SQLite; PostgreSQL + PGVector in EE |
| Interfaces | REST, gRPC, JSON-RPC stdio, MCP stdio, Angular web console, Python SDK/CLI |
| Health | `GET /api/v1/live`, `/ready`, `/health` |

## Where It Fits

- [Inference request to governed answer](../../vertical-slices/inference-request-to-governed-answer.md) — durable, auditable memory and context
- [Inference governance](../../reference-stacks/inference-governance.md) — memory context for grounded answers
- Optional memory and context backing for agent runtimes (for example Praxovela via `AXON_MEMORY_URL`)

## Authority

The [mnemovela-open](https://github.com/axisrobo/mnemovela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
