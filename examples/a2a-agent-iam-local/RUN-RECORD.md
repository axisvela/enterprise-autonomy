# A2A Agent IAM Local Run Record

**Date:** 2026-10-23
**Environment:** Windows, Go 1.26.10, PostgreSQL 18.1 on `127.0.0.1:5433`
**Repository:** `axisvela/enterprise-autonomy`

## Result

All four local services started and passed health checks:

| Service | Address | Status |
| --- | --- | --- |
| NOMIVELA | `127.0.0.1:1956` | ready |
| EIDOVELA | `127.0.0.1:1966` | ready |
| AEGIVELA | `127.0.0.1:1886` | ready |
| LIMENORA | `:1897` | ready |

The real IAM chain completed:

1. Google ADK checkout agent registered, approved, and activated in NOMIVELA.
2. Agent identity allocated, bound to `root:demo`, activated, and a local
   workload registration created.
3. EIDOVELA enrollment completed for the workload and a short-lived
   `praxo-a2a` PoP token was issued.
4. The token was verified locally against the EIDOVELA JWKS.
5. AEGIVELA policy `system-api-access` (`v1`) allowed `order:cancel`.
6. AEGIVELA workload binding was created and an AEGIVELA workload assertion was
   issued.
7. A real AEGIVELA decision returned `outcome=allow`, decision
   `3cd14aa4-6ece-4427-96db-913d5e12b3aa`, policy `v1`.

## Recorded Values

- Namespace: `https://registry.a2a-iam.test`
- Agent reference: `agent_google_adk_checkout`
- NOMIVELA Agent ID: `db18dbd9-65f1-470c-9539-93a394d242f5`
- EIDOVELA instance ID: `59e86bc2-2501-4097-a494-cddf9d5c065d`
- EIDOVELA token: verified, 800 bytes (the token value is not recorded)
- AEGIVELA binding ID: `MuA-uiLtANWocJ2aq_D8dg`
- AEGIVELA decision: `allow`

## Database Setup

The script created isolated databases:

- `a2a_iam_nomivela`
- `a2a_iam_eidovela`
- `a2a_iam_aegivela`
- `a2a_iam_limenora`

Migrations applied:

- NOMIVELA: auto-migrate on first boot; skipped on later boots.
- EIDOVELA: `0001` through `0009`; database default search path set to
  `eidovela, public` before `0007`.
- AEGIVELA: all `*.up.sql` migrations in lexical order.
- LIMENORA: started with its configured PostgreSQL URL.

## Commands

```powershell
cd examples/a2a-agent-iam-local
.\start-services.ps1

cd ..\a2a-agent-iam
GOWORK=off go run ./cmd/smoke
GOWORK=off go run ./cmd/decide -mode system -assertion <assertion> \
  -agent db18dbd9-65f1-470c-9539-93a394d242f5 \
  -instance 59e86bc2-2501-4097-a494-cddf9d5c065d

$env:A2A_IAM_AEGIVELA_TOKEN = "dev-aegivela-token"
$env:A2A_IAM_TENANT = "demo"
GOWORK=off go run ./cmd/live \
  -agent-id db18dbd9-65f1-470c-9539-93a394d242f5 \
  -workload-id 63e9f268-14b7-428f-85ff-659c2c07ca51 \
  -assertion <assertion>
```

Stop the stack with:

```powershell
cd examples/a2a-agent-iam-local
.\stop-services.ps1
```

## Live A2A Call

A Google ADK -> PRAXO-CORE A2A call was exercised with the real local IAM
services:

1. A fresh EIDOVELA enrollment produced instance
   `d36ec1a8-b15f-4955-b5a1-5a942a36d550` and an 804-byte PoP token.
2. The PRAXO-CORE A2A server verified the token, resolved NOMIVELA Registry
   Context, and evaluated the AEGIVELA workload assertion.
3. Google ADK received `approved: order-1001 can be cancelled before shipment`.

The server was the PRAXO-CORE A2A server listening directly on
`127.0.0.1:18086`; LIMENORA was not in this request path.

## Issues And Fixes

1. **EIDOVELA migration 0007 failed** with `identity_credentials` missing.
   Migrations `0007+` use unqualified names. Fixed by setting
   `ALTER DATABASE a2a_iam_eidovela SET search_path TO eidovela, public` before
   migration.
2. **NOMIVELA failed on restart** because auto-migrate re-ran a non-idempotent
   migration. Fixed by setting `NOMIVELA_MIGRATE=false` when
   `public.schema_migrations` already exists.
3. **AEGIVELA source build panicked** in protobuf descriptor initialization.
   The prebuilt `Aegivela/bin/aegivela-api.exe` was used instead.
4. **LIMENORA failed to start** with an AEGIVELA default-route error. Fixed by
   setting `GATEWAY_AEGIVELA_AUDIENCE=praxo-a2a`, tenant, action, and scope.
5. **AEGIVELA `serviceAgentApi` v2 returned `400 invalid_policy_request`** on
   this local build. The verified path is `system_api` with an AEGIVELA-issued
   workload assertion, which returned `allow`.
6. **A 30-minute assertion request returned `400
   invalid_workload_assertion_request`**. The same request with a 5-minute
   expiry succeeded, so the local issuer enforces a short maximum TTL.
7. **EIDOVELA enrollment rejected mismatched workload attributes** with
   `workload attributes do not match registered selector`. The live command
   sends `app=google-adk`, matching the registered workload selector.
8. **The first live A2A call returned `403`** because the `system_api` client
   did not send AEGIVELA internal headers. The live path now sends the internal
   token, tenant, actor, and authority root.

## V2 Verification Update

The current-source AEGIVELA on `127.0.0.1:1886` returned `outcome=allow`,
decision `168f966f-eea0-4435-82a9-6c0279996456`, policy `v1`, for a real
`serviceAgentApi` v2 request. The start script now builds AEGIVELA from source;
the old prebuilt binary and temporary `1888` workaround are no longer used.
Earlier failures describe that old binary and the debugging history.

After rebuilding the stack from current source, the `system_api` path also
returned `outcome=allow`, decision `128ea12b-6ed8-4d53-8458-cb94e62b070c`,
policy `v1`, and `run-limenora-a2a.ps1` still returned
`approved: order-1001 can be cancelled before shipment`.

The local fixes cover camelCase authentication state and nested instance fields,
`credentialed` state with active credential-generation verification, Agent ID as
the principal actor, and production PDP resource digests required for v2 signing.
Temporary principal diagnostic logging was removed.

Backend fixes are recorded in AEGIVELA commit
`3ceb44c` (`fix: align EIDOVELA authentication and v2 policy signing`).

Targeted identity, principal, policy, HTTP API, and production PDP regression tests
pass, as does backend `go vet ./...`. The generated protobuf descriptors were
regenerated in `c14b781`; backend `go test ./...`, `go vet ./...`, and
`go build ./...` pass.

This decision does not establish instance-lease enforcement or a fully live
EIDOVELA PoP credential on the reverse path. No credentials are recorded here.

## Authority Reverse Ingress

`run-limenora-a2a.ps1 -Authority` issued a real AEGIVELA workload assertion with
audience `praxo-a2a`, created an `aegivela-gateway-connect` policy rule allowing
`connection:open`, and started LIMENORA with mode `service_agent_api` and
federated assertion source.

Observed:

```text
approved: order-1001 can be cancelled before shipment
authority deny enforced
```

After the first call, the script created a deny policy version. The next
reverse-ingress request was rejected with HTTP 403 before reaching the backend.
The script then restored an allow policy. The static path
(`.\run-limenora-a2a.ps1`) still returned
`approved: order-1001 can be cancelled before shipment`.

A direct AEGIVELA `/v1/gateway/connect` check returned `outcome=allow`, decision
`c3b7c9e8-192a-4cc3-be7d-d57bbc55797f`, policy `v1` for the same assertion and
`connection:open` scope. The reverse path uses an AEGIVELA workload assertion as
the agent credential, not a live EIDOVELA PoP token. Instance leases, external
peers, deployed TLS/identity, and SLO remain open.

## Protobuf Blocker Follow-Up

The identity descriptor panic was reproduced and resolved locally by running
the existing root `buf generate` configuration with its pinned Go plugin
`v1.36.11`. Regeneration repaired descriptor-length encodings in 27 generated
files; no `.proto` definitions or wire baselines changed. A second generation
produced identical output.

The repair and all-version initialization regression test are recorded in
AEGIVELA commit `c14b781` (`fix: regenerate contract descriptors after module rename`).

The contract-drift suite now initializes all 31 legacy and v2 contract
descriptors. `buf lint`, uncached backend `go test -count=1 ./...`,
`go vet ./...`, and `go build ./...` pass. Database-dependent tests may skip
without a configured test database; this is not a production deployment claim.

## LIMENORA A2A Reverse Ingress

A separate LIMENORA server instance on `127.0.0.1:1898` was configured with:

- a file agent binding (`GATEWAY_AGENT_BINDINGS`) for a service agent with
  audience `a2a-demo`, and
- a reverse route `/a2a` to `http://127.0.0.1:18091`, with `require_agent: true`
  and a header injection of the backend bearer credential.

The PRAXO-CORE order agent ran on `127.0.0.1:18091` and advertised
`PRAXO_A2A_CARD_BASE=http://127.0.0.1:1898/a2a`, so its card interface pointed
at the gateway rather than the backend.

The Google ADK client fetched the card through the gateway with
`X-LIMENORA-Agent-Credential` and invoked through the advertised gateway URL.
Results:

- correct agent credential: `approved: order-1001 can be cancelled before shipment`
- missing agent credential: HTTP 403 from LIMENORA
- wrong agent credential: HTTP 403 from LIMENORA before any order decision

The temporary `1898` and `18091` processes were stopped after verification. The
original four-service stack remains on its normal ports.

This proves the LIMENORA reverse-ingress forwarding, agent-binding lookup, card
rewriting through the advertised URL, and backend credential injection. It uses
a static file agent binding and static backend bearer credential; it is not a
live EIDOVELA/AEGIVELA gateway decision, instance-lease test, deployed peer, or
TLS/SLO test. No agent credential or backend token value is recorded.

## Limits

- This is a single-host local stack, not a production deployment.
- LIMENORA reverse ingress is now exercised with a static agent binding, but not
  with live EIDOVELA presentation or AEGIVELA authorization at the gateway.
- AEGIVELA is built from current source on `1886`; v2 `serviceAgentApi` has a
  verified `allow` decision. The live A2A call was verified separately with
  `system_api`; complete v2 A2A/instance-lease/gateway behavior remains open.
- External A2A peer interoperability, external gRPC, deployed TLS/identity, and
  deployed throughput/SLO validation remain open.
- Workload assertion and token values are credentials and are not recorded.
