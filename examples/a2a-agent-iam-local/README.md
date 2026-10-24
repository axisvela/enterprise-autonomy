# Local A2A Agent IAM Stack

This example starts the four local services used by the recommended Agent IAM
chain:

```text
NOMIVELA :1956  Agent / Agent ID / workload registry and lifecycle
EIDOVELA :1966  Agent IdP, enrollment, PoP token, JWKS/introspection
AEGIVELA :1886  policy decision, grants, revocation, evidence
LIMENORA :1897  governed gateway / egress boundary
```

## Prerequisites

- Windows PowerShell 5.1 or later
- PostgreSQL 18 client tools at `D:\app\PostgreSQL\18\bin` (override by editing
  the script if installed elsewhere)
- A reachable PostgreSQL on `127.0.0.1:5433` with `postgres/postgres`
- Sibling checkouts: `NOMIVELA`, `EIDOVELA`, `Aegivela`, `LIMENORA`
- Go 1.26.10
- `openssl` on `PATH`

The script creates isolated databases:

- `a2a_iam_nomivela`
- `a2a_iam_eidovela`
- `a2a_iam_aegivela`
- `a2a_iam_limenora`

## Start

```powershell
.\start-services.ps1
```

Use `-Rebuild` to rebuild the local binaries after changing sibling sources.
AEGIVELA is built from the current source; the protobuf descriptor regression is
fixed, so the old prebuilt binary is no longer required.

## Stop

```powershell
.\stop-services.ps1
```

## Configuration

`local.env.ps1.example` records the service URLs, namespace, tenant, audience,
tokens, and database connection. Copy it to `local.env.ps1` for consumer scripts;
do not commit `local.env.ps1`.

## Current State

- NOMIVELA, EIDOVELA, AEGIVELA, and LIMENORA start and pass health checks.
- EIDOVELA runs in NOMIVELA registry-consumer mode for namespace
  `https://registry.a2a-iam.test`.
- AEGIVELA uses EIDOVELA as its identity source and has signed decision, grant,
  and workload-assertion keys plus a `praxo-a2a` audience registry.
- LIMENORA runs the server gateway with EIDOVELA presentation and an AEGIVELA
  default route for audience `praxo-a2a`.
- A separate local LIMENORA instance was exercised as a real A2A reverse-ingress
  gateway with a static agent binding and backend bearer injection. Google ADK
  through the gateway returned `approved: order-1001 can be cancelled before
  shipment`; missing or wrong agent credentials returned HTTP 403.
- `run-limenora-a2a.ps1 -Authority` additionally uses a live AEGIVELA
  `service_agent_api` decision for the reverse-ingress request. An allow decision
  forwarded the call, and a deny policy produced HTTP 403 before the backend.
  The path enrolls a fresh EIDOVELA/NOMIVELA instance with a valid lease and
  rejects expired leases. It uses an AEGIVELA workload assertion as the agent
  credential, not a live EIDOVELA PoP token.

## Real IAM Smoke

The real chain has been exercised locally:

1. `examples/a2a-agent-iam/cmd/smoke` registers the Google ADK checkout agent in
   NOMIVELA, enrolls it with EIDOVELA, and verifies a short-lived PoP token.
2. AEGIVELA policy `system-api-access` allows `order:cancel`; a workload binding
   and assertion are issued through `/v1/workload-bindings` and
   `/v1/workload-assertions/issue`.
3. `examples/a2a-agent-iam/cmd/decide -mode system` evaluates the assertion and
   returned `outcome=allow`.
4. `examples/a2a-agent-iam/cmd/live` enrolls a fresh EIDOVELA instance, starts a
   PRAXO-CORE A2A server with real EIDOVELA verification, NOMIVELA context
   resolution, and AEGIVELA workload-assertion authorization, then calls it with
   Google ADK. The call returned `approved: order-1001 can be cancelled before
   shipment`.
5. `run-limenora-a2a.ps1 -Authority` issues a real AEGIVELA workload assertion,
   seeds a gateway-connect policy, forwards through LIMENORA, then switches the
   policy to deny and verifies the next reverse-ingress request is rejected with
   HTTP 403.

The current-source AEGIVELA on port `1886` returned a real `serviceAgentApi` v2
`allow` decision. The old prebuilt binary and the temporary `1888` workaround are
no longer used. Live AEGIVELA reverse-ingress decisions are now verified; a live
EIDOVELA PoP credential, instance leases, and the full v2 A2A path remain open.

## Run Record

See [RUN-RECORD.md](RUN-RECORD.md) for the exact local environment, commands,
observed results, issues, and fixes.

## Limits

This starts the local services; it does not claim production readiness. A live
Google ADK -> PRAXO-CORE A2A call with real NOMIVELA, EIDOVELA, and AEGIVELA is
verified and calls the PRAXO server directly. LIMENORA reverse-ingress is verified
with both a static binding and a live AEGIVELA `service_agent_api` decision. The
authority path uses an AEGIVELA workload assertion, not a live EIDOVELA PoP
token. Expired instance leases are rejected and a fresh enrolled instance is
required; lease renewal/termination propagation, external A2A peers, external
gRPC, deployed TLS/identity, and deployed throughput/SLO validation remain open.
