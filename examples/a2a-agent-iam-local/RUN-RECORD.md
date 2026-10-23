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

## Limits

- This is a single-host local stack, not a production deployment.
- The live A2A call goes directly to the PRAXO-CORE A2A server. The LIMENORA
  A2A reverse-ingress route to PRAXO-CORE is not wired yet.
- AEGIVELA `serviceAgentApi` v2 still returns `400` on this local build; the
  verified path is `system_api`.
- External A2A peer interoperability, external gRPC, deployed TLS/identity, and
  deployed throughput/SLO validation remain open.
- Workload assertion and token values are credentials and are not recorded.
