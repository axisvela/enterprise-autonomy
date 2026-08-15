# Mission-to-Execution Example

## Objective

Inspect a designated facility zone and present a reviewable result to an authorized operator.

## Design Steps

1. Define the inspection zone, the expected result, and the operator responsible for review.
2. Choose the product roles required to plan, authorize, execute, observe, and review the work.
3. Set a limited first-run scope and clear conditions for pausing or escalating to a human.

## Example Composition

| Need | Example Product Role |
| --- | --- |
| Operator collaboration and approval | Symbivela |
| Planning | Orchadyn |
| Capability control | Moduregis |
| Identity and authorization | Aegivela |
| Physical execution | Kinetovela |
| Operational context | Ontovela |
| External-system integration | Limenora |

## Outcome

The operator can initiate, supervise, and review a physical inspection without requiring the products to become a single runtime. Each product remains responsible for its own domain while contributing to the end-to-end outcome.

## Operating Steps

1. **Open the request.** Record the inspection zone, purpose, completion window, required evidence, restrictions, and accountable operator.
2. **Validate context.** Confirm the zone is available; delay, reduce scope, or escalate if an operating condition requires it.
3. **Review work.** Check planned scope, assigned resource, evidence, and stop conditions. Approve, revise, or cancel the run.
4. **Supervise.** Start the approved work, monitor status, and pause or escalate unexpected conditions.
5. **Review outcome.** Verify required evidence, record completion, and create follow-up work for findings.
6. **Close or repeat.** Close only after evidence review; partial or failed work remains visible for repeat or escalation.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | A facility inspection is completed under human authority with reviewable evidence, without merging products into a single runtime. |
| KPIs | Boundary compliance, pause-and-review rate, evidence completeness, human-approval rate. |
| Decision gates | Work review before start, pause/escalation on exceptions, evidence review at outcome. |
| Evidence produced | Inspection objective, zone context, approved plan, mission status, required evidence, completion record. |
| Adoption path | Start with a limited zone and a repeatable objective; expand coverage only after the organization accepts the result. |

See the [value framework](../docs/example-value.md) and [value metrics catalog](../examples/value-metrics.md).

## Detailed Operating Procedure

Each step lists its **input** (who provides what), the **products** involved, and the **output** artifact that evidence the step.

### Step 1 — Open the request

- **Input:** operator submits the inspection zone (`zone-alpha`), purpose, completion window (`2026-08-20T18:00:00Z`), required evidence (zone images, sensor log, exception report), restrictions (no entry after `17:00`), and accountable operator (`ops-lead`).
- **Products:** Symbivela (workspace + mission case), Ontovela (zone context).
- **Output:** a mission case `mission-alpha-001` in `open` state with `subject_ref = zone://zone-alpha`.

### Step 2 — Validate context

- **Input:** the operator confirms the zone availability and current restrictions.
- **Products:** Ontovela (resolved zone state), Limenora (facility-system query if needed).
- **Output:** a context assertion (`zone-alpha available`, `authority_rank` set); conflicting or stale data is recorded for correction, not used.

### Step 3 — Review work

- **Input:** the operator reviews the proposed plan, assigned resource, required evidence, and stop conditions.
- **Products:** Orchadyn (plan), Moduregis (capability availability), Aegivela (authorization), Symbivela (review).
- **Output:** an approved work record with `approval_ref`; the operator may approve, revise, or cancel.

### Step 4 — Supervise

- **Input:** the operator starts the approved work and monitors mission status.
- **Products:** Kinetovela (bounded execution), Ontovela (live state), Symbivela (monitoring).
- **Output:** mission status events; a pause request is raised on any exception for operator review.

### Step 5 — Review outcome

- **Input:** the operator verifies the required evidence against the mission objective.
- **Products:** Ontovela (evidence state), Tekmovela (assurance), Symbivela (review).
- **Output:** a completion record; follow-up work is created for findings.

### Step 6 — Close or repeat

- **Input:** the operator accepts or escalates the result.
- **Products:** Rheovela (durable close), Symbivela (outcome record).
- **Output:** a closed mission with evidence; partial or failed work stays visible for repeat or escalation.

See the [mission-to-execution walkthrough](mission-to-execution-walkthrough.md) for a concrete run with artifacts.

See the [public example design guide](../docs/example-design-guide.md) for common boundaries and adaptation guidance.
