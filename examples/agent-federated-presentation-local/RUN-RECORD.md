# FP-1 Run Record — federated presentation, local stack

Records the **actual runs** of this example. The `README.md` describes how to run
it; this file records what was observed, when, and with what provenance — so a
pass/fail claim is auditable rather than implied.

## Runs

| Date (local) | Artifact | Result |
| --- | --- | --- |
| 2026-10-13 20:44 | `.local-data/fp1-value-report.json` | 4/4 scenarios passed |
| 2026-10-14 09:08 | `.local-data/fp1-live-report.json` | 4/4 scenarios passed (content identical to the 10-13 report) |

Both artifacts are byte-identical:

```json
{ "scenarios": [
  { "id": "FP-01", "description": "valid token + both proofs reach upstream", "expected": "200", "actual": "200, proofs stripped", "passed": true },
  { "id": "FP-02", "description": "missing resource proof denied",            "expected": "407", "actual": "status 407",              "passed": true },
  { "id": "FP-05", "description": "replayed resource-proof jti denied",      "expected": "407", "actual": "second use denied 407",   "passed": true },
  { "id": "FP-07", "description": "provider denies a disabled agent; no downgrade, upstream untouched",
    "expected": "deny, 0 upstream hits", "actual": "denied 407, upstream hits unchanged", "passed": true } ],
  "passed": true }
```

Treat the 2026-10-14 file as the current one (same result, later run); the 10-13
file is retained as history.

## Environment

Per this example's `local.env.ps1` / the FP-1 plan: local PostgreSQL on `5433`,
NOMIVELA `1956`, EIDOVELA `1966`, LIMENORA `1897`, driven by
`adapters/presentation-client` (the reference PEP client) with the example's
start/verify scripts.

## What this proves — and what it does not

Proves (wire-observable, at the time of the run):

- FP-01 a valid token plus both DPoP proofs reaches the upstream; the proofs are
  **stripped** before forwarding.
- FP-02 a missing resource proof is denied `407`.
- FP-05 a replayed resource-proof `jti` is denied `407`.
- FP-07 a disabled agent is denied and the upstream is not touched (no
  downgrade).

Does **not** prove, and is not claimed here:

- Any revocation timing/SLO bound (measured separately — see the PRAXOVELA-EE
  records, e.g. `2026-10-14-r2-r3-federated-reverification.md`).
- External-IdP/federated presentation, CA-failure or wrong-issuer negatives.
- Anything about the deployment topology: this is a single-host local dev stack
  with locally generated material.

## Related records

- Wider R2/R3 real-service evidence (same period): `PRAXOVELA-EE`
  `docs/assessments/2026-10-13-*` and `2026-10-14-*`.
- Example usage: [README.md](README.md); evidence shape:
  [evidence-schema.md](evidence-schema.md).
