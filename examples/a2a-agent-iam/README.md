# A2A Agent IAM Examples

Two contract-level end-to-end examples for the recommended Agent IAM chain:

```text
NOMIVELA registration/lifecycle
  -> EIDOVELA authentication and short-lived PoP token
  -> Google ADK A2A client carries the credential
  -> A2A server or LIMENORA gateway validates the token and resolves the NOMIVELA Agent ID
  -> AEGIVELA authorization/delegation/approval
  -> PRAXO-CORE executor
```

The existing [`a2a-adk-order-cancellation`](../a2a-adk-order-cancellation/README.md)
example keeps its static bearer-token authentication unchanged.

## Examples

| Example | Path | Difference |
| --- | --- | --- |
| Direct | [`direct`](direct/README.md) | Google ADK calls the PRAXO-CORE A2A server; the server validates EIDOVELA, NOMIVELA, and AEGIVELA. |
| LIMENORA | [`limenora`](limenora/README.md) | Google ADK calls a LIMENORA-shaped gateway; the gateway performs the same identity and authorization checks and forwards a signed verified context to PRAXO-CORE. |

Both examples register the Google ADK agent as a NOMIVELA Agent Record, Agent
Identity, and Workload Registration, enroll it with EIDOVELA, obtain a
short-lived token bound to the workload key, and call the real Google ADK Go
`remoteagent/v2` client.

## Run

The examples use the real NOMIVELA, EIDOVELA, AEGIVELA, PRAXO-CORE, and Google
ADK Go SDK/API surfaces. The IAM service responses are local contract fakes so
the examples run without PostgreSQL or product binaries.

```powershell
$env:GOWORK = "off"
go test -count=1 ./...
```

The module uses local `replace` directives for sibling checkouts:

- `../../../NOMIVELA-open`
- `../../../EIDOVELA-open`
- `../../../aegivela-open/sdk/go`
- `../../../praxo-core`

## Evidence Level

This is contract-level wiring evidence, not a real-service deployment claim. It
proves the sequence, request/response shapes, token/key binding, DPoP proof
checking, Registry Context resolution, and policy call placement. It does not
prove live NOMIVELA/EIDOVELA/AEGIVELA/LIMENORA behavior, production PKI, HSM
custody, or deployed load.

The LIMENORA example uses a gateway-shaped local reverse proxy to show the trust
split; it is not a claim that the current LIMENORA binary was deployed for A2A.
