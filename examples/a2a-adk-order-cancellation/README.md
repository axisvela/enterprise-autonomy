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

Run the in-process interoperability tests:

```powershell
GOWORK=off go test ./...
```

The test starts the PRAXO-CORE server with `httptest`, then uses the published
Google ADK Go SDK as the external A2A client. It verifies discovery, successful
business handling, a policy-style denial, remote failure, timeout, and authorized
versus unauthorized calls.

## Boundaries

- This is protocol interoperability, not a production order-management system.
- The eligibility decisions are deterministic fixture rules; no order is changed.
- The two-process demo still runs both peers on loopback. Production callers must
  authenticate deployed peers, validate card trust across origins, use HTTPS, and
  test load and failure behavior in their own environment.
- A denial is a business result, not an A2A transport error. The caller owns the
  human handoff and any actual cancellation.
