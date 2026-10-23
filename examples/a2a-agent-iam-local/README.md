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
The AEGIVELA prebuilt binary at `Aegivela/bin/aegivela-api.exe` is used because
the current source build panics in its generated protobuf descriptor init under
this toolchain.

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

## Real IAM Smoke

The real chain has been exercised locally:

1. `examples/a2a-agent-iam/cmd/smoke` registers the Google ADK checkout agent in
   NOMIVELA, enrolls it with EIDOVELA, and verifies a short-lived PoP token.
2. AEGIVELA policy `system-api-access` allows `order:cancel`; a workload binding
   and assertion are issued through `/v1/workload-bindings` and
   `/v1/workload-assertions/issue`.
3. `examples/a2a-agent-iam/cmd/decide -mode system` evaluates the assertion and
   returned `outcome=allow`.

The AEGIVELA `serviceAgentApi` v2 path is configured but currently returns
`400 invalid_policy_request` against this local build; the `system_api`
workload-assertion path is the verified allow path.

## Run Record

See [RUN-RECORD.md](RUN-RECORD.md) for the exact local environment, commands,
observed results, issues, and fixes.

## Limits

This starts the local services; it does not claim production readiness. The
A2A Agent IAM examples under `examples/a2a-agent-iam` remain contract-level and
use local fakes. A live end-to-end A2A call through this stack still requires a
seeded AEGIVELA policy, workload assertion/binding, and a PRAXO-CORE A2A
consumer wired to these endpoints. LIMENORA is running as a gateway, not as a
fully configured A2A reverse-ingress route.
