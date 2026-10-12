# Agent Federated Presentation (local)

End-to-end FP-1 federated-presentation demo: an SDK-only client presents an
EIDOVELA-issued PoP token as the LIMENORA agent credential together with a
resource proof and an introspection proof. LIMENORA verifies the resource proof,
consumes the replay ledger, relays the introspection proof to EIDOVELA, maps the
verified context to a binding, and forwards to the upstream — fail-closed.

## Prerequisites
- Windows PowerShell 5.1, `curl.exe`, Go 1.25
- A reachable PostgreSQL (default `localhost:5433`, user `postgres`)
- Sibling checkouts of NOMIVELA, EIDOVELA, LIMENORA (+ their open SDKs)

## Run
```powershell
Copy-Item local.env.ps1.example local.env.ps1
. .\local.env.ps1
.\run-all.ps1
```
`run-all.ps1` builds the binaries, creates the databases, starts the services,
runs the scenarios, verifies the value report, and stops the stack.

## Ports
PostgreSQL `5433` · NOMIVELA `1956` · EIDOVELA `1966` · LIMENORA `1897`.
