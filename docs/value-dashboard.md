# Example Value Dashboard

The value dashboard aggregates the machine-readable value reports from all runnable demos into a single view, so the effect of the examples can be compared and verified at a glance.

## Generate The Dashboard

After running the demos (`. \examples\run-all-demos.ps1`), run:

```powershell
.\scripts\report-value.ps1
```

This prints a table per demo and writes the combined dashboard to `examples\.stack\all-demos-report.json`:

| Column | Meaning |
| --- | --- |
| Demo | The runnable demo directory. |
| Example | The value-report example identifier. |
| Outcome | The before → after state transition. |
| Products | Number of distinct products involved. |
| Gates | Human decision gates passed. |
| Evidence | Evidence artifacts recorded. |
| Steps | Business steps completed. |
| TimeSeconds | Time-to-resolve for the run. |
| Completed | Whether the outcome completed. |

## Reading The Dashboard

Each row is the **effect** of one demo: how many products composed the outcome, how many human gates governed it, and how much evidence reconstructs it. Together they show that every one of the [twelve runnable demos](demo-matrix.md) delivers a governed, measurable outcome rather than a chained service call.

## CI And Automation

The dashboard file is gitignored (`.stack/`). CI runs the same checks as the [local tooling](../scripts/README.md) without requiring a database; the full dashboards are produced by running the demos locally.

See the [value framework](example-value.md) and the [value report template](../examples/value-report-template.md).
