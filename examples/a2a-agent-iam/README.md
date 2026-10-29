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

The declared Core baseline is `v2.5.1`, but the replacements below determine the
actual source executed. Record every sibling repository SHA and dirty state when
using the test results as integration evidence; this is not published-package
consumption or a live-service test.

- `../../../NOMIVELA-open`
- `../../../EIDOVELA-open`
- `../../../aegivela-open/sdk/go`
- `../../../praxo-core`

## Live IAM A2A

`cmd/live` runs the same PRAXO-CORE A2A server with real EIDOVELA token
verification, NOMIVELA Registry Context resolution, and AEGIVELA `system_api`
workload-assertion authorization. It enrolls a fresh EIDOVELA instance, starts
the A2A server, and calls it with the real Google ADK Go client.

Prerequisites: the local stack from
[`../a2a-agent-iam-local`](../a2a-agent-iam-local/README.md) is running, the
AEGIVELA policy and workload binding are seeded, and a short-lived workload
assertion has been issued.

```powershell
$env:A2A_IAM_AEGIVELA_TOKEN = "dev-aegivela-token"
$env:A2A_IAM_TENANT = "demo"
$env:A2A_IAM_AUDIENCE = "praxo-a2a"
$env:GOWORK = "off"
go run ./cmd/live `
  -agent-id <NOMIVELA agent id> `
  -workload-id <NOMIVELA workload registration id> `
  -assertion <AEGIVELA workload assertion>
```

The verified local run returned `approved: order-1001 can be cancelled before
shipment` through Google ADK and PRAXO-CORE, after a real AEGIVELA `allow`
decision. The assertion and token values are credentials and are not recorded.

## Evidence Level

The demo validators accept at most one minute of past or future clock skew for
DPoP and gateway timestamps, and reject missing/blank gateway signing keys.
Negative fixtures also check method, path, token/key, signature, and required
gateway subject fields. These checks do not supply a DPoP JTI replay cache or
bind the gateway HMAC to the request body; do not use this demo envelope as a
production operation-authorization or replay-protection protocol.

The `direct` and `limenora` tests are contract-level wiring evidence: they prove
the sequence, request/response shapes, token/key binding, DPoP proof checking,
Registry Context resolution, and policy call placement without PostgreSQL.

The `cmd/live` path additionally proves the real local NOMIVELA, EIDOVELA, and
AEGIVELA services authorize a live Google ADK -> PRAXO-CORE A2A call. It does
not prove production PKI, HSM custody, deployed load, external A2A peers, or a
LIMENORA A2A reverse-ingress route.

The LIMENORA example uses a gateway-shaped local reverse proxy to show the trust
split; it is not a claim that the current LIMENORA binary was deployed for A2A.
