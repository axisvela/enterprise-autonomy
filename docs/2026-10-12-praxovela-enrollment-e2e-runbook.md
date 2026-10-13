# PRAXOVELA Production Enrollment E2E Runbook

Date: 2026-10-13 (recorded) · Status: verified against real services
Applies to: PRAXOVELA `2.8.0` (axond), NOMIVELA, EIDOVELA, LIMENORA, PostgreSQL.

This runbook records the end-to-end acceptance of PRAXOVELA's **production
agent bootstrap**: axond registers its agent with NOMIVELA, enrolls it with
EIDOVELA (a registry consumer), and builds the LIMENORA egress with the
EIDOVELA-issued token as the agent credential (`AXON_LIMENORA_TOKEN_SOURCE=eidovela`).

Every command below was executed and its real output is quoted.

## 1. What it proves

```
axond boot
  └─ StartNomivelaRegistration  (manifest → NOMIVELA: workload, agent, identity,
  │   binding, lifecycle→active, instance; surfaces agentId + workloadRegistrationId)
  └─ StartEidovelaEnrollment    (registry coords + workloadAttributes + workloadId/
      artifactDigest → EIDOVELA CreateChallenge/Complete; EIDOVELA commits the
      instance back to NOMIVELA and returns the token-context identity)
  └─ LIMENORA egress            (AXON_LIMENORA_TOKEN_SOURCE=eidovela; ONE shared
      EIDOVELA client drives both enrollment and the egress token source)
```

Success signal (real output):

```
[runtime] NOMIVELA registration complete: 1 agent(s) registered (namespace=https://registry.fp1.test)
[runtime] EIDOVELA enrollment complete (client=f33fee87-2ae7-4ffb-9473-78c915df92e4 namespace=https://registry.fp1.test)
```

`client=` is the **registry agent UUID** returned by NOMIVELA (not the config
`CLIENT_ID`), proving the registry coordinates flowed through.

## 2. Topology and ports

| Component | Address | Notes |
| --- | --- | --- |
| PostgreSQL | `localhost:5433` (`postgres`/`postgres`) | example DBs created by the harness |
| NOMIVELA | `http://127.0.0.1:1956` | registry; `NOMIVELA_MIGRATE=true` |
| EIDOVELA | `http://127.0.0.1:1966` | `EIDOVELA_ISSUER=http://127.0.0.1:1966`; registry-consumer mode |
| LIMENORA | `http://127.0.0.1:1897` | server-gateway; federated presentation |
| axond | `http://127.0.0.1:1866` | the PRAXOVELA runtime under test |

> Use `127.0.0.1` (not `localhost`) for the EIDOVELA issuer: LIMENORA's
> introspector only permits plaintext HTTP against a literal loopback IP.

## 3. Prerequisites

- Windows + PowerShell 5.1, `curl.exe`, `openssl`, Go 1.25.
- Sibling checkouts: `NOMIVELA`, `EIDOVELA`, `LIMENORA`, `PRAXOVELA`
  (all under `D:\profile\paper-code\axis-vela\`).
- A reachable PostgreSQL (the `enterprise-autonomy` FP-1 demo harness resets and
  provisions the databases).

The service stack is booted by the FP-1 demo launcher, which builds and starts
the three core binaries and prepares the databases:

```
D:\profile\paper-code\axis-vela\enterprise-autonomy\examples\agent-federated-presentation-local\
  ├─ local.env.ps1            (copy of local.env.ps1.example; gitignored)
  └─ start-services.ps1       (builds nomivela/eidovelad/limenora + DB init + boot)
```

## 4. Step by step

### Step 1 — Boot the service stack

Input:
```powershell
# from D:\profile\paper-code\axis-vela\enterprise-autonomy
. .\examples\agent-federated-presentation-local\local.env.ps1
& .\examples\agent-federated-presentation-local\start-services.ps1
```

Output (tail): builds `nomivela.exe`/`eidovelad.exe`/`limenora-server.exe`,
runs `eidovela-migrate`, then:
```
fp1 databases ready
applied D:\...\EIDOVELA\backend\migrations\0001_init.sql
...
applied D:\...\EIDOVELA\backend\migrations\0009_attestation_results.sql
FP-1 services ready.
```

Verify health:
```powershell
foreach($u in "http://127.0.0.1:1956/healthz","http://127.0.0.1:1966/healthz","http://127.0.0.1:1897/healthz"){ (Invoke-WebRequest -UseBasicParsing $u).StatusCode }
```
Output: `200 200 200`.

### Step 2 — Create the NOMIVELA authority namespace

The registrar registers *into* a namespace; it does not create one, so create it
first (operator/authority provisioning).

Input:
```powershell
curl.exe -sS -X POST http://127.0.0.1:1956/v1/namespaces `
  -H "Authorization: Bearer dev-token" `
  -H "Idempotency-Key: ns-fp1-1" -H "X-Actor: user:fp1" `
  -H "Content-Type: application/json" `
  -d '{"namespace":"https://registry.fp1.test","authorityRootRef":"root:fp1"}'
```

Output:
```json
{"namespace":"https://registry.fp1.test","authorityRootRef":"root:fp1","status":"active","namespaceEpoch":1}
```

### Step 3 — Generate the PoP key and the registration manifest

Input:
```powershell
$d = Join-Path $env:TEMP "fp1-axond"; New-Item -ItemType Directory -Force $d | Out-Null
openssl genpkey -algorithm ed25519 -out "$d\key.pem"
```

Registration manifest `$d\manifest.yaml` (PRAXOVELA `AXON_NOMIVELA_REGISTRATIONS`,
YAML/JSON — see `internal/nomivela/manifest.go`):
```yaml
namespace: https://registry.fp1.test
actor: praxovela-axond
agents:
  - agentRef: agent_fp1_axond
    name: PRAXOVELA AXON runtime
    purpose: governed desktop agent runtime
    sponsorRef: root:fp1
    ownerRef: team:fp1
    riskClass: low
    agentClass: service
    identities:
      - identityType: interactive
        subjectRef: user:operator
    authorityBinding:
      authorityRootRef: root:fp1
      authorityRootType: organization
workload:
  platform: windows/amd64
  selector: { app: praxovela-axond }
  trustDomain: fp1.test
  allowedProofMethods: ["private_key_jwt"]
```

> The workload `selector` is the exact attribute set EIDOVELA compares during
> enrollment; PRAXOVELA forwards it as `workloadAttributes`.

### Step 4 — Build axond

Input (from `PRAXOVELA/packages/axon-core`, via the root `go.work`):
```powershell
go build -o "$env:TEMP\fp1-axond\axond.exe" ./cmd/axond
```
Output: `BUILD=0`; `axond.exe` ~27 MB.

### Step 5 — Run axond with the E2E environment

Input:
```powershell
$d = Join-Path $env:TEMP "fp1-axond"
$env:AXON_PORT="1866"
$env:AXON_NOMIVELA_URL="http://127.0.0.1:1956"
$env:AXON_NOMIVELA_TOKEN="dev-token"
$env:AXON_NOMIVELA_NAMESPACE="https://registry.fp1.test"
$env:AXON_NOMIVELA_REGISTRATIONS="$d\manifest.yaml"
$env:AXON_NOMIVELA_WORKLOAD_ID="praxovela-axond"
$env:AXON_NOMIVELA_ARTIFACT_DIGEST="sha256:fp1demo"
$env:AXON_NOMIVELA_PLATFORM="kubernetes"
$env:AXON_NOMIVELA_TRUST_DOMAIN="fp1.test"
$env:AXON_EIDOVELA_URL="http://127.0.0.1:1966"
$env:AXON_EIDOVELA_KEY_FILE="$d\key.pem"
$env:AXON_EIDOVELA_NAMESPACE="https://registry.fp1.test"
$env:AXON_EIDOVELA_AUDIENCE="limenora"
$env:AXON_EIDOVELA_CLIENT_ID="agent_fp1_axond"
$env:AXON_LIMENORA_URL="http://127.0.0.1:1897"
$env:AXON_LIMENORA_TOKEN_SOURCE="eidovela"
Start-Process "$d\axond.exe"
```

Output (relevant lines):
```
[axond] EIDOVELA authority: http://127.0.0.1:1966
[axond] NOMIVELA authority: http://127.0.0.1:1956 (lifecycle cascade enabled)
[axond] NOMIVELA registration declared: ...\manifest.yaml
[runtime] NOMIVELA registration complete: 1 agent(s) registered (namespace=https://registry.fp1.test)
[runtime] EIDOVELA enrollment complete (client=f33fee87-... namespace=https://registry.fp1.test)
```
axond then serves on `:1866`.

### Step 6 — Observe the registry state (optional)

NOMIVELA now holds the workload, agent, identity, binding and a committed
instance; EIDOVELA holds the credential for the PoP key. Query the registry
context with the surfaced agent id:
```powershell
curl.exe -sS "http://127.0.0.1:1956/v1/registry-context?namespace=https://registry.fp1.test&agentId=<agentId>" -H "Authorization: Bearer dev-token"
```

## 5. Gaps found during acceptance (and their fixes)

Running against **real** services surfaced four gaps that the fake-provider
tests had masked. All are fixed in PRAXOVELA `2.8.0` (commit `4ccad27`).

| Symptom (real output) | Root cause | Fix |
| --- | --- | --- |
| `register workload: .../v1/workload-registrations: not found` | registrar does not create the authority namespace | provision the namespace first (Step 2); registrar assumes an operator-provisioned namespace |
| `enrollment: agent not in an enrollable state` | `CreateAgent` yields `draft`; registrar never advanced the lifecycle (the e2e fake returned `active`) | registrar drives agent `draft→registered→approved→active` and identity `→active` (`adapters/nomivela.TransitionAgent`/`TransitionIdentity`) |
| `enrollment: workload attributes do not match registered selector` | enrollment sent no `workloadAttributes` | forward the manifest workload `selector` as `workloadAttributes` |
| `invalid workload registration: workload id and artifact digest are required` | EIDOVELA's instance commit needs `workloadId` + `artifactDigest`; enrollment sent neither | forward `AXON_NOMIVELA_WORKLOAD_ID` + `AXON_NOMIVELA_ARTIFACT_DIGEST` into enrollment |

Known, still-open (tracked, not required for this acceptance):
- **Registrar 409-reuse is non-idempotent against real NOMIVELA**: `CreateAgent`
  on conflict returns an error envelope without the existing record, so a
  restart/re-run fails closed. Fix requires read-then-reuse. Workaround for now:
  run against a fresh database.

## 6. Environment variable reference (axond)

| Var | Purpose |
| --- | --- |
| `AXON_NOMIVELA_URL` / `AXON_NOMIVELA_TOKEN` / `AXON_NOMIVELA_NAMESPACE` | registry endpoint, bearer, authority namespace |
| `AXON_NOMIVELA_REGISTRATIONS` | path to the registration manifest (boot prerequisite) |
| `AXON_NOMIVELA_WORKLOAD_ID` / `AXON_NOMIVELA_ARTIFACT_DIGEST` | instance commit coordinates |
| `AXON_NOMIVELA_PLATFORM` / `AXON_NOMIVELA_TRUST_DOMAIN` | workload fallbacks |
| `AXON_EIDOVELA_URL` / `AXON_EIDOVELA_KEY_FILE` | EIDOVELA authority + PoP key |
| `AXON_EIDOVELA_NAMESPACE` / `AXON_EIDOVELA_AUDIENCE` / `AXON_EIDOVELA_CLIENT_ID` | enrollment identity + token audience |
| `AXON_EIDOVELA_AGENT_ID` / `AXON_EIDOVELA_WORKLOAD_REGISTRATION_ID` | optional explicit overrides when not using NOMIVELA registration |
| `AXON_LIMENORA_URL` | proxy egress |
| `AXON_LIMENORA_TOKEN_SOURCE` | `static` (default) or `eidovela` |

## 7. Cleanup

```powershell
Get-Process nomivela,eidovelad,limenora-server,axond -ErrorAction SilentlyContinue | Stop-Process -Force
```

## 8. Related

This runbook covers the enrollment chain. The full five-product acceptance
(enrollment + LIMENORA→AEGIVELA decision + AEGIVELA→EIDOVELA federated agent
resolution), with the cross-product fixes and contract conclusions, is recorded
in the PRAXOVELA-EE assessment:
`PRAXOVELA-EE/docs/assessments/2026-10-13-ecosystem-integration-e2e-report.md`.
