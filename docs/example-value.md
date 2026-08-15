# Example Value and Effect Framework

Public examples exist to demonstrate that the AxisRobo Enterprise Autonomy ecosystem can produce governed, measurable outcomes. This framework defines what makes an example valuable and how its effect is shown.

## The Value Chain

Every example must make the following chain explicit:

1. **Outcome** — the measurable business result the example produces.
2. **Accountable owner** — the human role responsible for the result.
3. **Decision gates** — the human reviews, approvals, and consents that keep control with people.
4. **Evidence** — the auditable artifacts that reconstruct the outcome.
5. **Effect** — the observable change in operational state and the KPIs that show it.

An example is valuable when each link of this chain is demonstrable.

## What "Effect" Means

Effect is the observable difference the example makes, shown through:

- **State change**: the operational state before and after (for example `stockout` to `replanned`).
- **Governance effect**: which gates were passed, who approved, and what evidence each product recorded.
- **Recoverability**: whether the outcome survives restarts and is auditable.
- **KPI movement**: measurable indicators such as time-to-resolve, gates passed, evidence completeness, and coverage.

## Required Example Sections

Each designed example, vertical slice, and reference stack includes a **Value & Effect** section with:

| Field | Definition |
| --- | --- |
| Outcome value | The business result and why it matters. |
| KPIs | 2–4 measurable indicators for this example class. |
| Decision gates | The human review points and what each unblocks. |
| Evidence produced | The artifacts that reconstruct the outcome. |
| Adoption path | How an organization could trial and expand it. |

## Value Report

Runnable examples produce a machine-readable **value report** in addition to their business report. The report records the outcome, each step's evidence, the gates passed, and the resulting KPI values, so the effect can be verified. See the [value report template](../examples/value-report-template.md) and the [value metrics catalog](../examples/value-metrics.md).

## Validation

The [scripts in the repository](../scripts/README.md) verify examples:

- [check-links.ps1](../scripts/check-links.ps1) — verifies internal documentation links.
- [check-examples.ps1](../scripts/check-examples.ps1) — verifies produced artifacts against expectations.
- [run-demo-smoke.ps1](../scripts/run-demo-smoke.ps1) — smoke-tests a runnable demo end to end.
