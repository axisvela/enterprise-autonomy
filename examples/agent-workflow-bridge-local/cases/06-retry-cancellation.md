# Case 06 — Work-item closure under injected failure (retry / cancel)

Run **2026-10-17** against the deployed stack (axond bridge → `adapters/rheovela`
→ real `rheo serve` on **1876** → AEGIVELA workload assertion). Script:
`fault-injection.ps1`; report: `.local-data/fault-injection-report.json`
(git-ignored).

> The runtime has no HTTP "create work item" surface (a producer owns creation),
> so the script seeds a `ready` row into the running Rheovela DB and drives the
> **deployed bridge**.

## Result — retry policy implemented 2026-10-17

| Path | Observation |
| --- | --- |
| `claim → complete` | item `done` |
| `claim → fail` (attempts < max) | item `ready`, `attempts=1`; **reclaim succeeds** → `complete` → `done` |
| `max_attempts=1`: `claim → fail` | item `failed`; reclaim = **409 not claimable** (terminal) |
| `POST /api/v1/work-items/{id}/cancel` (Rheovela) | item `cancelled` |

`fault-injection-report.json` records `retry_supported=true`.

## Semantics

- `FailWorkItem` now increments `attempts`, stores `last_error`, clears the
  lease/fencing token, and re-queues (`state='ready'`) while
  `attempts < max_attempts`; at the bound it becomes terminal `failed`
  (`max_attempts` defaults to 3; set per item).
- `CancelWorkItem` terminates a `ready`/`claimed`/`failed` item as `cancelled`
  and releases its lease.
- The axond bridge exposes `claim`/`heartbeat`/`complete`/`fail`. The **cancel**
  operation exists on Rheovela's API but is **not yet proxied by axond** — a
  small remaining exposure. Compensation stays a separate process concern.

## Reproduce

```powershell
# after .\start-services.ps1 (stack up on 1876)
$env:PATH = "<sqlite3 dir>;" + $env:PATH   # or set $env:SQLITE3
. .\local.env.ps1
.\fault-injection.ps1
```
