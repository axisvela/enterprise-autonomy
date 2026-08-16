# Gnosivela — Semantic and Knowledge Fabric

## Public Role

Enterprise semantic and knowledge fabric for governed concepts, claims, evidence, conflicts, and scoped grounding views.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `gnosivela`, `gnosivela-gen` |
| Current port | `:8080` (`-addr`) |
| Planned port | `1836` API |
| Database | PostgreSQL optional (`-pg-dsn`); in-memory default |
| Interfaces | HTTP API, DSL compiler CLI, Go/Java/Python/TS SDKs |
| Health | `GET /healthz` |

## Where It Fits

- [Inference request to governed answer](../../vertical-slices/inference-request-to-governed-answer.md) — grounded claims and evidence
- [Inference governance](../../reference-stacks/inference-governance.md) — grounding contract and evidence
- Provides grounded concepts and claims for scenario reasoning
- Pairs with Noetivela (inference) and Mnemovela (memory) in composition

## Authority

The [gnosivela-open](https://github.com/axisrobo/gnosivela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
