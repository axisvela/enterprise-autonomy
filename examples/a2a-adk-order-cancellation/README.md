# Google ADK A2A Order Cancellation

This local, deterministic demo proves that a Google ADK Go consumer can discover
and call a PRAXO-CORE A2A server over HTTP JSON-RPC. It uses no model provider,
database, or product runtime.

## Scenario

An online-store checkout assistant built with Google ADK asks a remote
PRAXO-CORE order-eligibility agent whether cancellation can proceed:

| Request | PRAXO-CORE decision | Consumer behavior |
| --- | --- | --- |
| Cancel `order-1001` | Approved before shipment | Continue automated cancellation flow |
| Cancel `order-1002` | Denied because it shipped | Route to a human returns specialist |
| Remote eligibility failure | A2A error | Stop the automated flow and surface the failure |
| Eligibility timeout | A2A client deadline | Stop the automated flow and surface the timeout |
| Missing or wrong bearer token | HTTP 401 | Stop before any order decision |

The PRAXO-CORE agent is exposed through `adapters/a2a.Executor`. Google ADK Go
uses `agent/remoteagent/v2.NewA2A` and `NewAgentCardProvider` to fetch
`/.well-known/agent-card.json` and call the advertised JSON-RPC interface. The
agent card declares bearer security when the server is configured with a token.

## Run

Run the two-process demo, including bearer authentication and the denial path:

```powershell
.\run.ps1
```

Use another loopback port when the default `8091` is busy:

```powershell
.\run.ps1 -Port 18091
```

The PRAXO-CORE peer listens on that port; the Google ADK consumer uses an
outbound connection and does not need a listening port of its own.

Run the in-process interoperability tests:

```powershell
GOWORK=off go test ./...
```

The test starts the PRAXO-CORE server with `httptest`, then uses the published
Google ADK Go SDK as the external A2A client. It verifies discovery, successful
business handling, a policy-style denial, remote failure, timeout, authorized
versus unauthorized calls, concurrent consumers with mixed approval/denial
requests, loopback TLS termination, and rejection of a cross-origin agent card.

## Gateway Mode

The client and server can also run through a LIMENORA reverse-ingress route.
The server advertises a gateway URL with `PRAXO_A2A_CARD_BASE`; the client sends
`X-LIMENORA-Agent-Credential` and fetches the card/invokes through the gateway.

```powershell
$env:PRAXO_A2A_TOKEN = "order-token"
$env:PRAXO_A2A_CARD_BASE = "http://127.0.0.1:1898/a2a"
.\praxo-server.exe -addr 127.0.0.1:18091

go run ./cmd/adk-client `
  -card http://127.0.0.1:1898/a2a `
  -agent-credential limenora-a2a-demo `
  -prompt "Cancel order-1001"
```

LIMENORA must have a matching agent binding and a route that forwards the path
prefix to the backend and injects the backend bearer credential. The verified
local path returned `approved: order-1001 can be cancelled before shipment`;
missing or wrong agent credentials were rejected with HTTP 403 before any order
decision. This uses a static file binding and static backend credential, not a
live EIDOVELA/AEGIVELA gateway decision.

## Boundaries

- This is protocol interoperability, not a production order-management system.
- The eligibility decisions are deterministic fixture rules; no order is changed.
- The two-process demo still runs both peers on loopback. Concurrent loopback
  calls are tested, but deployed throughput, SLOs, and failure behavior must be
  measured in the caller's own environment. Loopback TLS and cross-origin card
  rejection are tested here; deployed TLS, remote peers, and production card
  trust still require the caller's own environment.
- A denial is a business result, not an A2A transport error. The caller owns the
  human handoff and any actual cancellation.
