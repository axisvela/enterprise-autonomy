# AxisRobo Product Technical Catalog

This catalog summarizes the local runnable surfaces of the AxisRobo Enterprise Autonomy ecosystem. It reflects the currently available source trees and local build artifacts, and each product's own repository remains authoritative.

## Summary

| Product | Primary Service | Local Binary / Entrypoint | HTTP Port | Database | Interface |
| --- | --- | --- | --- | --- | --- |
| Moduregis | Capability control plane | `moduregis-api.exe`; worker + migrate CLIs | `:8080` (`LISTEN_ADDR`) | PostgreSQL (required) | HTTP API + React console + CLI |
| Orchadyn | Planning compiler | `orchadyn-api.exe`; migrate CLI | `:8080` (`ORCHADYN_LISTEN_ADDR`) | PostgreSQL (required) | HTTP API + MCP |
| Noetivela | Inference fabric | `noetivela-gateway`, `noetivela-controller`, `noetivela` CLI | gateway `:8080`, controller `:8081` | None (in-memory / JSON file) | HTTP API + CLI + SDKs |
| Gnosivela | Semantic and knowledge fabric | `gnosivela`; `gnosivela-gen` CLI | `:8080` (`-addr`) | PostgreSQL optional (in-memory default) | HTTP API + CLI + SDKs |
| Mnemovela | Cognition and memory runtime | `mneme-http`, `mneme-grpc`, `mneme-mcp-stdio` | HTTP `8080`, gRPC `9090`, web `4200` | Embedded (in-memory / Pebble / SQLite); PostgreSQL in EE | HTTP + gRPC + MCP + web console + CLI |
| Ontovela | Digital twin and world model | `ontovela.exe` | `:8080` (`-addr`) | PostgreSQL optional (in-memory default) | HTTP API + SDKs |
| Praxovela | Governed agent runtime | `axond.exe`; desktop app | `8420` (`AXON_PORT`) | SQLite local | HTTP API + desktop app + MCP |
| Rheovela | Durable workflow platform | `rheo.exe` | `:8080` (`--addr`) | SQLite default; PostgreSQL in EE | CLI + HTTP API + MCP + EE console |
| Aegivela | Identity and authorization fabric | `aegivela-api` (EE `aegivela-ee.exe`) | core `:8080`, EE `:8081` | PostgreSQL (required) | HTTP API + PEP SDK |
| Limenora | Governed integration gateway | `limenora-edge.exe`, `limenora-enterprise.exe`, `limenora-control.exe` | edge `10255`, enterprise `10256`, control `10257` | PostgreSQL/Valkey optional | HTTP gateway + CLI |
| Peiravela | Simulation and experiment control plane | `api-server.exe`, `control-plane.exe` | `:8080` (`PEIRAVELA_API_ADDR`) | PostgreSQL optional (in-memory fallback) | HTTP API + embedded Studio + CLI |
| Tekmovela | Engineering assurance | `tek.exe` | none (CLI) | PostgreSQL for migrations; local file store default | CLI only |
| Symbivela | Human–agent collaboration workspace | `symbivela.exe` | `:8080` | PostgreSQL (required) | HTTP API + React frontend + CLI tools |
| Harmovela | Coordination protocol runtime | `harmovelad`; `harmovela` CLI | WS `8787`, SSE `8788`, API `8790` | SQLite default; PostgreSQL optional | HTTP + WebSocket + SSE + stdio + CLI + MCP bridge |
| Kinetovela | Robotics fleet control plane | `kinetovela-api` | `:8080` (`KINETOVELA_LISTEN_ADDR`) | PostgreSQL documented, not yet wired in shipped binary | HTTP API (health only in current binary) |

## Per-Product Details

### Moduregis
- **Role:** Capability control plane for publishing, discovering, governing, authorizing, invoking, and auditing capabilities.
- **Binaries:** `moduregis-api`, `moduregis-worker`, `moduregis-migrate`, `moduregis-health`, `moduregis-import-skill`, `moduregis-recovery-verify`; Windows release archives under `dist/`.
- **Port:** `:8080` default, override `LISTEN_ADDR`.
- **Database:** PostgreSQL 16, `DATABASE_URL` required. Also `MODUREGIS_ENV`, `AEGIVELA_MODE`/`AEGIVELA_BASE_URL`.
- **Interfaces:** REST `v1alpha1` (`/v1/capabilities`, `/v1/resolve`, `/v1/invocations`, `/v1/health`); React management console at `frontend/console/`; CLI migrate/import tools.
- **Health:** `GET /healthz`, `/readyz`, `/v1/health`.

### Orchadyn
- **Role:** Planning compiler that turns goals, state, capabilities, and constraints into verified, revisable plans.
- **Binaries:** `orchadyn-api`, `orchadyn-mcp`, `orchadyn-migrate` (releases under `ORCHADYN-open/releases/`).
- **Port:** `:8080` default, override `ORCHADYN_LISTEN_ADDR`.
- **Database:** PostgreSQL for the plan ledger; `DATABASE_URL` required; MCP uses in-memory ledger. `ORCHADYN_TENANT_ID` or `ORCHADYN_TRUSTED_PROXY_TOKEN` required.
- **Interfaces:** HTTP (`POST /plans:generate`, `/plans:verify`, `/plans:revise`, `GET /plans`); MCP stdio server (`generate`, `verify`, `explain`, `project`, `revise`); migrate CLI.
- **Health:** `GET /healthz`.

### Noetivela
- **Role:** Inference fabric that governs model and endpoint selection and routes requests with policy, quality, latency, and cost evidence.
- **Binaries:** `noetivela-gateway`, `noetivela-controller`, CLI `noetivela`.
- **Ports:** gateway `:8080` (`NOETIVELA_ADDR`); controller `:8081` (`NOETIVELA_CONTROLLER_ADDR`).
- **Database:** none required; in-memory registry with optional JSON file store (`NOETIVELA_STORE_FILE`).
- **Interfaces:** OpenAI-compatible HTTP (`/v1/chat/completions`, `/v1/embeddings`) plus governed endpoints; CLI (`contract validate`, `eligible`, `chat`, `decisions`); Go/Python/TS SDKs.
- **Health:** `GET /healthz`.

### Gnosivela
- **Role:** Semantic and knowledge fabric for concepts, entity references, claims, evidence, conflicts, and scoped grounding views.
- **Binaries:** `gnosivela`, `gnosivela-gen`.
- **Port:** `:8080` default via `-addr`.
- **Database:** PostgreSQL optional via `-pg-dsn`; in-memory default.
- **Interfaces:** HTTP API (`/ontologies`, `/assertions`, `/entities/resolve`); DSL compiler CLI; Go/Java/Python/TS SDKs.
- **Health:** `GET /healthz`.

### Mnemovela
- **Role:** Durable, auditable cognition memory with commit-like semantics and hybrid retrieval.
- **Binaries:** `mneme-http`, `mneme-grpc`, `mneme-jsonrpc-stdio`, `mneme-mcp-stdio`; Python REST and CLI.
- **Ports:** HTTP `127.0.0.1:8080` (`Mnemovela_HTTP_ADDR`); gRPC `:9090`; web console `4200`; Python REST `8000`.
- **Database:** embedded in-memory / Pebble (`Mnemovela_GO_PEBBLE_PATH`) / SQLite; PostgreSQL+PGVector in EE.
- **Interfaces:** REST (`/api/v1/query/*`, `/api/v1/jsonrpc`), gRPC, JSON-RPC stdio, MCP stdio, Angular web console, Python SDK/CLI.
- **Health:** `GET /api/v1/live`, `/ready`, `/health`.

### Ontovela
- **Role:** Bitemporal, evidence-bearing operational world-model and digital twin platform.
- **Binaries:** `ontovela` (local `ontovela.exe`; EE `ontovela-ee.exe`).
- **Port:** core `:8080` via `-addr`; EE `:8090`.
- **Database:** PostgreSQL optional via `ONTOVELA_PG_DSN`/`-pg-dsn`; in-memory default.
- **Interfaces:** tenant-scoped HTTP (`X-Tenant-ID`; `POST /v1/assertions`, `GET /v1/twins/{id}/state/{property}`, snapshots, changes); SDKs.
- **Health:** `GET /healthz`.

### Praxovela
- **Role:** Deny-by-default local agent runtime with effect ledger, checkpoint recovery, and sandboxed execution.
- **Binaries:** `axond.exe` (AXON Core); desktop app; `prax-bench`, `skig`.
- **Port:** `8420` default (`AXON_PORT`).
- **Database:** local SQLite (`axon.db`); optional `AXON_MEMORY_URL` (Mnemovela).
- **Interfaces:** HTTP API (`/v1/sessions`, `/v1/agent/tools/execute`, `/v1/runs/{id}/recover`); embedded MCP gateway; Tauri desktop app.
- **Health:** `GET /health`.

### Rheovela
- **Role:** Durable workflow platform that turns capability plans into recoverable, approvable process instances.
- **Binaries:** `rheo` (local `rheo.exe`); EE `rheo-ee`; worker SDKs.
- **Port:** core `:8080` via `--addr`; EE `:8081`.
- **Database:** SQLite default (`~/.proc/proc.db` or `--db`); PostgreSQL backend for EE.
- **Interfaces:** CLI (`rheo serve`, `rheo run open`, `rheo workflow define`); HTTP Ops API (`/api/v1/instances`, `/api/v1/workflows`); MCP gateway at `/mcp`; EE Ops Cockpit at `/console`.
- **Health:** `GET /api/v1/health`.

### Aegivela
- **Role:** Agent identity, authorization, delegation, approval, revocation, and security evidence fabric.
- **Binaries:** `aegivela-api` (core, no local `.exe`); EE `aegivela-ee.exe`.
- **Ports:** core `:8080`; EE `:8081`.
- **Database:** PostgreSQL required (`DATABASE_URL`); `AEGIVELA_INTERNAL_AUTH_TOKEN` required.
- **Interfaces:** HTTP API (`/v1/policies`, `/v1/attestations`, `/v1/risk/signals`, `/v1/agents`); PEP SDK library.
- **Health:** `GET /healthz`.

### Limenora
- **Role:** Governed integration gateway for APIs, MCP, events, and webhooks.
- **Binaries:** `limenora-edge` (client gateway), `limenora-enterprise` (server gateway), `limenora-gateway`, `limenora-control`, `limenora-capability`; Rust reference gateway.
- **Ports:** edge `10255`, enterprise `10256`, control `10257`; optional `GATEWAY_ADMIN_PORT`.
- **Database:** PostgreSQL optional (`DATABASE_URL`, server role); Valkey/Redis optional (`GATEWAY_VALKEY_URL`).
- **Interfaces:** HTTP gateway (proxy, CONNECT, webhooks, event ingress, admin); `limenora-control` CLI/HTTP control plane; capability manifest CLI.
- **Health:** `GET /healthz`, `/v1/health`, `/v1/health/detailed`.

### Peiravela
- **Role:** Possible-world simulation and experiment control plane with immutable simulation evidence.
- **Binaries:** `api-server`, `control-plane`, `gen-client` (release builds under `PEIRAVELA-open/bin/`).
- **Port:** `:8080` default (`PEIRAVELA_API_ADDR`).
- **Database:** PostgreSQL optional (`PEIRAVELA_DATABASE_URL`); in-memory fallback.
- **Interfaces:** HTTP API (`/worlds`, `/scenarios/compile`, `/runs/suite`, `/evidence`); embedded Studio UI at `/`; control-plane CLI (~40 subcommands); client generator.
- **Health:** `GET /health`.

### Tekmovela
- **Role:** Engineering assurance with verification contracts, closed-loop tests, and release gating.
- **Binaries:** `tek` (local `tek.exe`).
- **Port:** none (CLI only).
- **Database:** PostgreSQL for migrations (`tek migrate --dsn`); local file store default (`.tek/store.json`).
- **Interfaces:** CLI (`verify`, `harness`, `test`, `explain`, `gate`, `attest`, `coverage`, `reverify`, `migrate`).
- **Health:** none.

### Symbivela
- **Role:** Human sovereignty control surface for goals, plan review, approvals, intervention, and evidence inspection.
- **Binaries:** `symbivela` (local `symbivela.exe`), plus `symbivela-audit`, `symbivela-bench`, `symbivela-migrate`.
- **Port:** `:8080` (fixed).
- **Database:** PostgreSQL required (`DATABASE_URL`).
- **Interfaces:** HTTP API (workspaces, goals, exception cases, approvals, interventions, outcomes); React/Vite frontend; CLI tools.
- **Health:** `GET /health`, `/ready`, `/metrics`.

### Harmovela
- **Role:** Open coordination protocol runtime for events, tasks, state, delegation, and recovery across agents and runtimes.
- **Binaries:** `harmovelad` (daemon), `harmovela` (CLI); TS/Python/Java equivalents; no local `.exe`.
- **Ports:** WebSocket `8787`, SSE `8788`, HTTP API `8790` (override `AEPD_*_PORT`).
- **Database:** SQLite default (`.harmovela/harmovela.sqlite`); PostgreSQL optional (`AEP_POSTGRES_URL`).
- **Interfaces:** HTTP API (`/harmovela/api`), WebSocket, SSE, stdio, gRPC, NATS/Kafka/Redis transports, CLI, MCP bridge.
- **Health:** `GET /harmovela/api/healthz`.

### Kinetovela
- **Role:** Robotics fleet control plane for bounded, observable, recoverable physical missions.
- **Binaries:** `kinetovela-api` (source entrypoint; no local compiled `.exe`).
- **Port:** `:8080` default (`KINETOVELA_LISTEN_ADDR`).
- **Database:** PostgreSQL documented as authoritative; the currently shipped binary has no database wiring and serves health/version only.
- **Interfaces:** HTTP API (`GET /healthz`, `GET /version`); frontend Operations Center planned but not implemented.
- **Health:** `GET /healthz`.

## Conventions

- Most HTTP services default to `:8080`; multi-plane products split control and data planes (Noetivela `8080/8081`, Limenora `10255-10257`, Harmovela `8787-8790`).
- Health endpoints are `/healthz` or `/health`; Symbivela additionally exposes `/ready` and `/metrics`.
- Database posture varies: PostgreSQL-required (Moduregis, Orchadyn, Aegivela, Symbivela), PostgreSQL-optional with in-memory default (Gnosivela, Ontovela, Peiravela), and embedded/SQLite-default (Mnemovela, Praxovela, Rheovela, Harmovela).
- Interfaces range from HTTP-only, CLI-only (Tekmovela), and desktop (Praxovela) to web consoles (Moduregis, Symbivela, Peiravela, Mnemovela, Rheovela-EE).
