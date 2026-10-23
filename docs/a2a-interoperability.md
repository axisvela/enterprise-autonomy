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
  tokens return HTTP 401 and stop before any order decision.

The agent card declares bearer security when the server has a token. The
`run.ps1` path builds separate PRAXO-CORE server and Google ADK client
processes on loopback, while the Go tests use `httptest` for the same protocol
paths. Neither contacts a model provider or changes a real order. A business
denial is an agent result, while an unavailable, timed-out, or unauthorized peer
is a transport failure that stops automation.

## Evidence Level

This proves a cross-SDK JSON-RPC interoperability path with Google ADK Go
v2.6.0, including a two-process loopback run and bearer authentication. It does
not prove production interoperability with a deployed Google ADK service, gRPC
transport interoperability, TLS termination, cross-origin card trust, provider
identity, or operational behavior under load.

Production callers must authenticate the peer, pin or otherwise validate the
agent card origin and interface URL, use HTTPS outside loopback development,
enforce deadlines, and keep actual order cancellation behind the owning system's
approval and idempotency controls.
