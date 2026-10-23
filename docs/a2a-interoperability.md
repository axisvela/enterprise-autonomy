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
  the result for its own order.

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

## Evidence Level

This proves a cross-SDK JSON-RPC interoperability path with Google ADK Go
v2.6.0, including a two-process loopback run, bearer authentication, and
concurrent loopback consumers. It does not prove production interoperability
with a deployed Google ADK service, gRPC transport interoperability, TLS
termination, cross-origin card trust, provider identity, or deployed throughput,
SLOs, and operational behavior under load.

Production callers must authenticate the peer, pin or otherwise validate the
agent card origin and interface URL, use HTTPS outside loopback development,
enforce deadlines, and keep actual order cancellation behind the owning system's
approval and idempotency controls.
