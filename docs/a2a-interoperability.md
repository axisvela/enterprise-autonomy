# A2A Interoperability Evidence

## Google ADK Go Consumer

[`examples/a2a-adk-order-cancellation`](../examples/a2a-adk-order-cancellation/README.md)
is a deterministic external-peer interoperability test. It starts a
PRAXO-CORE order-cancellation eligibility agent over A2A JSON-RPC and consumes
it through the published Google ADK Go `remoteagent/v2` SDK.

The Google ADK consumer fetches `/.well-known/agent-card.json`, validates the
advertised loopback JSON-RPC interface, and sends a user message through its
normal A2A remote-agent path. No PRAXO-CORE A2A client is used by the consumer.

The scenario demonstrates:

- approval of an order that has not shipped;
- a business denial that routes to a human returns specialist;
- remote agent failure propagation;
- caller-side deadline expiry; and
- bearer authentication: a correct token succeeds, while missing or wrong
  tokens return HTTP 401 and stop before any order decision; and
- concurrent consumers with mixed approval and denial requests, each receiving
  the result for its own order;
- loopback TLS termination with a bearer-authenticated A2A endpoint; and
- rejection of an agent card whose advertised interface URL has a different
  origin from the card source.

The agent card declares bearer security when the server has a token. The
`run.ps1` path builds separate PRAXO-CORE server and Google ADK client
processes on loopback, while the Go tests use `httptest` for the same protocol
paths. Neither contacts a model provider or changes a real order. A business
denial is an agent result, while an unavailable, timed-out, or unauthorized peer
is a transport failure that stops automation.

## Agent IAM Contract Examples

Two additional contract-level examples apply the recommended Agent IAM chain:

- [`examples/a2a-agent-iam/direct`](../examples/a2a-agent-iam/direct/README.md):
  Google ADK calls PRAXO-CORE directly; the server verifies EIDOVELA, resolves
  NOMIVELA, calls AEGIVELA, and executes.
- [`examples/a2a-agent-iam/limenora`](../examples/a2a-agent-iam/limenora/README.md):
  Google ADK calls a LIMENORA-shaped gateway; the gateway performs the identity
  and authorization checks and forwards a signed verified context to PRAXO-CORE.

Both register the Google ADK agent in NOMIVELA, enroll it with EIDOVELA, send a
token-bound DPoP proof, and use AEGIVELA for the `order:cancel` decision. They
are contract-level examples: the IAM services are local fakes driven through
their real SDKs. They do not prove a live NOMIVELA/EIDOVELA/AEGIVELA/LIMENORA
deployment.

## Local IAM Stack

[`examples/a2a-agent-iam-local`](../examples/a2a-agent-iam-local/README.md)
starts the four services locally on isolated PostgreSQL databases:

- NOMIVELA `:1956`
- EIDOVELA `:1966`
- AEGIVELA `:1886`
- LIMENORA `:1897`

The `cmd/smoke` command in `examples/a2a-agent-iam` registers the Google ADK
checkout agent in NOMIVELA, completes EIDOVELA enrollment for its workload, and
issues and verifies a PoP-bound token for audience `praxo-a2a`. A local
AEGIVELA policy, workload binding, and workload assertion produced a real
`outcome=allow` decision. The `cmd/live` command starts a PRAXO-CORE A2A server
with real EIDOVELA verification, NOMIVELA context resolution, and AEGIVELA
workload-assertion authorization, then calls it with Google ADK and receives
`approved: order-1001 can be cancelled before shipment`. This is a real local
service chain, not a fake. See the
[run record](../examples/a2a-agent-iam-local/RUN-RECORD.md) for commands,
results, issues, and fixes.

A separate real LIMENORA reverse-ingress route has also been exercised: Google
ADK fetched the gateway-advertised card and invoked the PRAXO-CORE A2A backend
through LIMENORA with `X-LIMENORA-Agent-Credential`; LIMENORA injected the
backend bearer credential and returned `approved: order-1001 can be cancelled
before shipment`. Missing or wrong agent credentials were rejected with HTTP 403
before the backend. This route uses a static file agent binding and static
backend credential, not live EIDOVELA/AEGIVELA gateway decisions. Instance
leases, a fully IAM-governed gateway route, deployed peers, external gRPC, and
deployed TLS/SLO remain open.

## Evidence Level

This proves a cross-SDK JSON-RPC interoperability path with Google ADK Go
v2.6.0, including a two-process loopback run, bearer authentication, concurrent
loopback consumers, loopback TLS termination, and cross-origin agent-card
rejection. It does not prove production interoperability with a deployed Google
ADK service, gRPC transport interoperability, deployed TLS/identity, provider
identity, or deployed throughput, SLOs, and operational behavior under load.

Production callers must authenticate the peer, pin or otherwise validate the
agent card origin and interface URL, use HTTPS outside loopback development,
enforce deadlines, and keep actual order cancellation behind the owning system's
approval and idempotency controls.
