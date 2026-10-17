# Case 06 — Work-item closure under injected failure (retry / cancellation)

Run **2026-10-17** against the deployed stack (axond bridge → `adapters/rheovela`
→ real `rheo serve` → AEGIVELA workload assertion). Script: `fault-injection.ps1`;
report: `.local-data/fault-injection-report.json` (git-ignored).

## What was driven

Work items are **producer-owned**: the runtime has no HTTP "create work item"
surface, so the script seeds a `ready` row into the running Rheovela DB
(`work_items`) and then drives the **deployed bridge** endpoints
`/v1/work-items`, `.../claim`, `.../complete`, `.../fail`. The list is scoped per
instance (`?instance=<id>`).

## Result

| Path | Observation |
| --- | --- |
| `claim → complete` | item reaches `done`; the effect → outcome closure works |
| `claim → fail` (injected transient) | item reaches `failed`; a second `claim` returns **409 work item not claimable** |

`fault-injection-report.json` records `retry_supported=false`.

## Honest conclusion (gap, not a pass)

- **The deployed runtime does not retry a failed work item.** `FailWorkItem`
  runs `UPDATE work_items SET state='failed', fencing_token=NULL` — there is no
  re-queue and no attempt counter.
- **There is no work-item cancel route**; cancellation/lease-loss likewise ends
  the item `failed`.
- The Rheovela worker SDK can *consume* a re-queued store (its tests model
  `requeueOnFail`), but the shipped store never re-queues, so end-to-end
  retries are **not** demonstrated.
- Closing R6's retry residual needs a retry policy (attempts / max-attempts) in
  the Rheovela store plus a cancel/compensate path.

## Reproduce

```powershell
# after .\start-services.ps1 (stack up)
$env:PATH = "<sqlite3 dir>;" + $env:PATH   # or set $env:SQLITE3
. .\local.env.ps1
.\fault-injection.ps1
```
