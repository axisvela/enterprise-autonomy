# Run Records — what has actually been executed per example

`docs/demo-matrix.md` lists which examples are **runnable**. It does not say
which have been **run**. This page records observed executions found in the
checkouts on 2026-10-16, so "runnable" is never read as "verified".

## Executed and recorded

| Example | Artifact (git-ignored, under the example) | Date | Result | Record |
| --- | --- | --- | --- | --- |
| `agent-federated-presentation-local` | `.local-data/fp1-value-report.json` | 2026-10-13 20:44 | FP-1 4/4 passed | [RUN-RECORD.md](../examples/agent-federated-presentation-local/RUN-RECORD.md) |
| `agent-federated-presentation-local` | `.local-data/fp1-live-report.json` | 2026-10-14 09:08 | FP-1 4/4 passed (identical content) | [RUN-RECORD.md](../examples/agent-federated-presentation-local/RUN-RECORD.md) |
| `agent-workflow-bridge-local` (new) | case records + `.local-logs/*` | 2026-10-16 | bridge E2E passed (cases 01–04; failures F1–F7) | [cases/](../examples/agent-workflow-bridge-local/cases/) |

## Executed with no result — recorded as a gap

| Artifact | Date | Observation |
| --- | --- | --- |
| `examples/.stack/all-demos-report.json` | 2026-10-12 19:29 | **empty**: `{"generated_at": "...", "demos": []}`. The dashboard run (`scripts/report-value.ps1`, documented in [value-dashboard.md](value-dashboard.md)) recorded **no demos**, so it neither passed nor failed anything. A later dashboard run should replace it; until then it must not be cited as evidence. |

## Runnable but never run in these checkouts

The thirteen business demos in [demo-matrix.md](demo-matrix.md) each document a
`*-value-report.json`, but **no such report exists on disk** in this workspace
(the only report artifacts present are the FP-1 ones above and the empty
dashboard).

That means for those thirteen: the code, the adapters and the run scripts are
present, and the demo *design* is documented — but there is **no executed
evidence** in these checkouts. Producing their reports (`run-all.ps1` per
example, or `scripts/report-value.ps1` for the combined dashboard) is the way to
turn them from "runnable" into "recorded", and the results should land here.

## How to record a new run

1. Run the example (`run-all.ps1`) or the dashboard (`scripts/report-value.ps1`).
2. Copy the produced report into the example's own record file
   (`RUN-RECORD.md`, as the FP-1 example does) with: date, environment/ports,
   the verbatim report, what it proves and what it does not.
3. Add one row to the two tables above.

Rules: keep reports verbatim (no summarising away a skip or a failure), keep the
date and environment, and never cite a report that does not exist on disk.
