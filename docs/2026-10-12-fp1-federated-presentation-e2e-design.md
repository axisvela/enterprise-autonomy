# FP-1 Federated Presentation — End-to-End Example Design

Date: 2026-10-12
Status: approved for planning (AEGIVELA deferred to a follow-up)

## 1. Context

EIDOVELA issues a PoP-bound short-lived agent token whose `cnf.jkt` binds the
workload's Ed25519 key. The federated-presentation candidate **FP-1** (frozen in
`eidovela-open/contracts/v3.0/federated-presentation.md`) lets that token be
presented through an intermediate gateway:

- the workload signs **two** RFC 9449 proofs with the same token-bound key —
  a **resource proof** bound to the outbound resource request, and an
  **introspection proof** bound to `POST {EIDOVELA BaseIssuer}/v1/introspect`;
- **LIMENORA** independently verifies the resource proof, consumes a single-use
  replay ledger entry, relays the introspection proof unchanged, and maps the
  verified `TokenContext` to the binding identity it already feeds to policy;
- **EIDOVELA** verifies possession on the introspection call and returns the
  registry context with `tokenHash` and `presenterJkt`.

NOMIVELA owns the registered identity (namespace, agentId, agentRef, raw
`registryClass`, `identityType`, `subjectRef`, dual epochs). Every product is
consumed here only through its **public SDK and its core binary** — never its
source.

## 2. Goal

Add a public, reproducible end-to-end example under
`enterprise-autonomy/examples/agent-federated-presentation-local/` that:

1. boots the real core binaries (`nomivela`, `eidovelad`, `limenora`
   server-gateway) against a real PostgreSQL;
2. drives the FP-1 chain with an **SDK-only** client adapter;
3. asserts the happy path plus **deny**, **no-downgrade**, and **no-leak**.

## 3. Scope And Non-Goals

In scope:

- NOMIVELA (registry) and EIDOVELA (identity) as core binaries, each with its
  migration command; LIMENORA server-gateway as the presentation gateway.
- The token alignment: the EIDOVELA-issued token is presented as the LIMENORA
  agent credential.
- Real PostgreSQL; reproducible run script and a machine-readable value report.

Non-goals (first version):

- **AEGIVELA / PEP decision plane** — deferred. The first version runs LIMENORA
  with its local deny-by-default policy resolver and no external
  `DecisionService`.
- PRAXOVELA `axond` as a process (the SDK adapter is the client contract
  equivalent); Rust parity; EE-only features; broad negative-fixture coverage
  beyond the core set in §9.

## 4. Dependency Rule

The example's Go code MUST NOT import any product's core source. It may import
only public SDK modules and shell out to core binaries:

| Product | Public SDK (import) | Core binary |
| --- | --- | --- |
| NOMIVELA | `github.com/axisvela/nomivela-open/v2/sdk/go` | `nomivela`, `nomivela-migrate` |
| EIDOVELA | `github.com/axisvela/eidovela-open/sdk/go/eidovela/v3` | `eidovelad`, `eidovela-migrate` |
| LIMENORA | `github.com/axisvela/LIMENORA-open/sdk/go/network` | `server-gateway` |
| AEGIVELA (deferred) | `github.com/axisvela/aegivela-open/sdk/go/pepsdk` | `aegivela-api` |

During local development the three SDK modules resolve through `replace`
directives to sibling checkouts; for release they resolve to tagged modules. The
core binaries are built from sibling checkouts (or fetched from release
archives), exactly as the existing demos do.

## 5. Architecture

```
 presentation-client (SDK-only, adapters/presentation-client)
   ├─ NOMIVELA-open SDK  ── seed + registry reads
   ├─ EIDOVELA-open v3 SDK ── enroll, token, SignDPoP ×2, IntrospectContext
   └─ LIMENORA-open network SDK ── ProxyEgress (ProofCarrier + AgentTokenSource)
                 │  Proxy-Authorization: Bearer <EIDOVELA token>
                 ▼
     LIMENORA server-gateway ── verify resource proof, consume replay,
                 │  relay introspection proof, map context→binding
                 ▼                          │
         upstream (local httptest)          └──► EIDOVELA /v1/introspect (relayed proof)
                                                     │
                                                     ▼
                                            NOMIVELA registry-context (read)
```

Components:

- `adapters/presentation-client/` — SDK-only Go client and the runnable
  scenario driver. Owns the ProofCarrier (signs the two proofs) and the
  EIDOVELA-token AgentTokenSource.
- `examples/agent-federated-presentation-local/` — product binaries launcher,
  configuration, scenario runner, verification, value report, docs.

## 6. Data Flow

1. **Migrate + boot NOMIVELA**: `NOMIVELA_MIGRATE=true` (or `nomivela-migrate`),
   then serve with an unrestricted seeder principal.
2. **Seed registry** via the NOMIVELA SDK, in dependency order: namespace →
   agent (+ lifecycle to `active`) → agent-identity (`identityType`/`subjectRef`)
   → authority binding → workload-registration (selector,
   `allowedProofMethods:["private_key_jwt"]`). The agent instance is committed by
   EIDOVELA, not seeded.
3. **Migrate + boot EIDOVELA**: run `eidovela-migrate` first (the daemon never
   creates tables), then `eidovelad` with `EIDOVELA_NOMIVELA_URL` +
   `EIDOVELA_NOMIVELA_NAMESPACE`.
4. **Boot LIMENORA server-gateway** with federated presentation enabled
   (`GATEWAY_EIDOVELA_URL`, `GATEWAY_EIDOVELA_AUDIENCE`,
   `GATEWAY_RESOURCE_PROOF_CARRIAGE=request_header`,
   `GATEWAY_AGENT_TUNNEL_POLICY=deny`), agent-egress required, and the
   PostgreSQL-backed replay ledger.
5. **Enroll + token** with the EIDOVELA-open v3 SDK; the token binds key K.
6. **Present** through the LIMENORA-open `ProxyEgress`:
   - `AgentTokenSource` returns the **EIDOVELA token** (the alignment);
   - the resource proof binds the intercepted inner request
     (`method` + `scheme://host/path`);
   - the introspection proof binds `{EIDOVELA_ISSUER}/v1/introspect`;
   - distinct `jti`s, both `ath = base64url(sha256(token))`.
7. **LIMENORA** verifies the resource proof, consumes `resource:{jti}` in the
   replay ledger, relays the introspection proof to EIDOVELA, checks
   `presenterJkt == resource-proof jkt`, and attaches the binding.
8. **Upstream** receives the forwarded request with proof headers stripped.

## 7. The Presentation Alignment (Crux)

For the chain to succeed the following must be identical:

```
token.claims.cnf.jkt  ==  Thumbprint(resource-proof.jwk)
                      ==  Thumbprint(introspection-proof.jwk)
                      ==  EIDOVELA context.presenterJkt

resource-proof.ath    ==  introspection-proof.ath
                      ==  base64url(sha256(exact presented token))
```

The single enabling decision is that the **EIDOVELA-issued token is the LIMENORA
agent credential**: it is what appears in `Proxy-Authorization`, what the
resource proof's `ath` covers, and what EIDOVELA re-verifies on the relayed
introspection proof. Presenting a separate LIMENORA-minted opaque token breaks
the chain (EIDOVELA cannot bind possession to it).

The introspection proof's `htu` MUST be the configured
`EIDOVELA_ISSUER + /v1/introspect`, not the actual `127.0.0.1:<port>` address.

## 8. Products And Configuration

| Product | Key configuration | Port |
| --- | --- | --- |
| NOMIVELA | `NOMIVELA_DATABASE_URL`, `NOMIVELA_HTTP_PORT`, `NOMIVELA_SERVICE_PRINCIPALS` | `1956` |
| EIDOVELA | `EIDOVELA_DATABASE_URL`, `EIDOVELA_ISSUER`, `EIDOVELA_LISTEN_ADDR`, `EIDOVELA_NOMIVELA_URL`, `EIDOVELA_NOMIVELA_NAMESPACE`, `EIDOVELA_REQUIRE_DPOP=1` | `1966` |
| LIMENORA | `DATABASE_URL`, `GATEWAY_EIDOVELA_URL`, `GATEWAY_EIDOVELA_AUDIENCE`, `GATEWAY_RESOURCE_PROOF_CARRIAGE`, `GATEWAY_AGENT_TUNNEL_POLICY`, agent-egress scenario | `1897` |
| PostgreSQL | `DATABASE_URL` | `5433` (supplied) |

NOMIVELA and EIDOVELA are newly allocated blocks (`1956–1965` and `1966–1975`)
in the ecosystem port plan, recorded in `docs/port-migration.md`,
`docs/technical-catalog.md`, and `docs/release-status.md`.

## 9. Fail-Closed And Assertion Matrix

Every scenario asserts a specific outcome; none may fall back to native or
application authority.

| # | Scenario | Expected |
| --- | --- | --- |
| FP-01 | Valid token + both proofs, agent-selected route | 200; upstream reached; evidence carries `agent_ref`/`agent_class` binding |
| FP-02 | Missing resource proof | 407; no upstream request |
| FP-03 | Resource proof bound to a different `htu`/`htm` | 407 |
| FP-04 | Resource proof signed by a key != context `presenterJkt` | 407 |
| FP-05 | Replayed resource-proof `jti` (second use) | 407 |
| FP-06 | Introspection proof `ath` != token | 407; EIDOVELA never returns active |
| FP-07 | EIDOVELA unavailable / `active:false` | deny; **no downgrade**, no native fallback |
| FP-08 | `agent_tunnel_policy=deny` with a raw CONNECT (no interception) | deny |
| FP-09 | Proof headers / token / key after forwarding | never present upstream; never in evidence or logs |

The value report records the outcome per scenario and the leaked-material
checks.

## 10. Harness Layout

```
enterprise-autonomy/
  adapters/presentation-client/         # SDK-only Go module
    go.mod                              # replace → sibling SDK checkouts
    main.go                             # scenario driver (flags: seed, run, etc.)
    carrier.go                          # ProofCarrier: signs the two proofs
    token_source.go                     # AgentTokenSource returning the EIDOVELA token
    seed.go                             # NOMIVELA registry seeding via SDK
    main_test.go                        # unit tests (no services)
  examples/agent-federated-presentation-local/
    README.md
    local.env.ps1.example
    start-services.ps1                  # migrate + boot binaries + health checks
    run-all.ps1                         # seed → scenario → verify
    verify.ps1                          # assertions → value report
    evidence-schema.md                  # value-report contract
```

## 11. PRAXOVELA Production Wiring

Independent of the example, PRAXOVELA (same repository group) gains the
production counterpart so a real deployment presents the aligned token:

- an EIDOVELA-driven `AgentTokenSource` (enroll + `Token`) that yields the
  EIDOVELA PoP token, with unit tests;
- configuration selecting it, wired into `daemon.SelectLimenoraEgress` so the
  egress presents the EIDOVELA token instead of the static
  `AXON_LIMENORA_AGENT_TOKEN` when EIDOVELA is configured.

The example validates the contract this wiring must satisfy; it does not import
PRAXOVELA.

## 12. Verification

- `adapters/presentation-client`: `go test ./...` (SDK-only units; no services).
- Full chain: `examples/agent-federated-presentation-local/run-all.ps1` with
  `DATABASE_URL` set, then `verify.ps1` producing the value report.
- Structural checks: `examples/run-all-demos.ps1 -CheckOnly` and
  `scripts/validate-demos.ps1` (extended for the new example).

## 13. Public-Repository Boundaries

Only publicly shareable material is committed: no internal endpoints,
credentials, tokens, private keys, or confidential thresholds. Runtime material
(`local.env.ps1`, `.local-data/`, `.local-logs/`, generated proofs and keys)
stays uncommitted.

## 14. Follow-Ups

- **AEGIVELA decision plane** as a first-class participant (start `aegivela-api`,
  configure LIMENORA's `DecisionService`, assert deny/approval propagation).
- Cross-replica replay (shared PostgreSQL ledger across gateway replicas).
- Broader FP negative fixtures and dependency-outage/restart coverage.
