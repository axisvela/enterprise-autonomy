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
- remote agent failure propagation; and
- caller-side deadline expiry.

It uses deterministic fixture rules and `httptest`; it does not contact a model
provider or change a real order. A business denial is an agent result, while an
unavailable or timed-out peer is a transport failure that stops automation.

## Evidence Level

This proves an in-process, cross-SDK JSON-RPC interoperability path with Google
ADK Go v2.6.0. It does not prove production interoperability with a deployed
Google ADK service, gRPC transport interoperability, authentication, card trust
across origins, or operational behavior under load.

Production callers must authenticate the peer, pin or otherwise validate the
agent card origin and interface URL, use HTTPS outside loopback development,
enforce deadlines, and keep actual order cancellation behind the owning system's
approval and idempotency controls.
