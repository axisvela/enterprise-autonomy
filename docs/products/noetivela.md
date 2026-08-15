# Noetivela â€?Inference Fabric

## Public Role

Enterprise inference fabric for governed model and endpoint selection and routing, with policy, quality, latency, and cost evidence.

## Local Surface

| Item | Detail |
| --- | --- |
| Binaries | `noetivela-gateway`, `noetivela-controller`, CLI `noetivela` |
| Current ports | gateway `:8080`, controller `:8081` |
| Planned ports | `1826` gateway Â· `1827` controller |
| Database | none required; in-memory registry, optional JSON file store |
| Interfaces | OpenAI-compatible HTTP, governed endpoints, CLI, Go/Python/TS SDKs |
| Health | `GET /healthz` |

## Where It Fits

- Complements semantic and cognition fabrics (Gnosivela, Mnemovela) in scenario composition
- Governed model selection for agent runtimes such as Praxovela

## Authority

The [noetivela-open](https://github.com/axisrobo/noetivela-open) repository is authoritative for implementation, availability, and product documentation. See the [technical catalog](../technical-catalog.md) for operational details.
