# Google ADK A2A Order Cancellation

This local, deterministic demo proves that a Google ADK Go consumer can discover
and call a PRAXO-CORE A2A server over HTTP JSON-RPC. It uses no model provider,
credentials, database, or product runtime.

## Scenario

An online-store checkout assistant built with Google ADK asks a remote
PRAXO-CORE order-eligibility agent whether cancellation can proceed:

| Request | PRAXO-CORE decision | Consumer behavior |
| --- | --- | --- |
| Cancel `order-1001` | Approved before shipment | Continue automated cancellation flow |
| Cancel `order-1002` | Denied because it shipped | Route to a human returns specialist |
| Remote eligibility failure | A2A error | Stop the automated flow and surface the failure |
| Eligibility timeout | A2A client deadline | Stop the automated flow and surface the timeout |

The PRAXO-CORE agent is exposed through `adapters/a2a.Executor`. Google ADK Go
uses `agent/remoteagent/v2.NewA2A` and `NewAgentCardProvider` to fetch
`/.well-known/agent-card.json` and call the advertised JSON-RPC interface.

## Run

```powershell
GOWORK=off go test ./...
```

The test starts the PRAXO-CORE server with `httptest`, then uses the published
Google ADK Go SDK as the external A2A client. It verifies discovery, successful
business handling, a policy-style denial, and remote error propagation.

## Boundaries

- This is protocol interoperability, not a production order-management system.
- The eligibility decisions are deterministic fixture rules; no order is changed.
- A2A agent cards are discovered from a loopback server only. Production callers
  must authenticate peers, validate card trust, and use HTTPS.
- A denial is a business result, not an A2A transport error. The caller owns the
  human handoff and any actual cancellation.
