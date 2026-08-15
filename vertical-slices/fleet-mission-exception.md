# Fleet Mission Exception Management

## Business Scenario

A bounded physical mission encounters an exception, such as an obstacle, safety concern, or unexpected condition. The fleet must pause, surface the exception to the accountable operator, and resume or escalate only with human review.

| Item | Definition |
| --- | --- |
| Trigger | Mission status, sensor, or safety signal puts the bounded mission at risk. |
| Accountable owner | Operations owner responsible for the mission. |
| Completion | Mission resumes, adjusts, or is cancelled with operator-approved evidence. |
| Evidence | Mission reference, exception reason, paused status, reviewed decision, and completion state. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Bounded fleet mission execution | Kinetovela |
| Mission review and approval | Symbivela |
| Replanning under constraints | Orchadyn |
| Capability control | Moduregis |
| Authorization and approvals | Aegivela |
| Physical and mission state | Ontovela |
| Durable mission process | Rheovela |
| Simulation of adjusted missions | Peiravela |

## Design Steps

1. Define mission boundaries, stop conditions, and the accountable operator.
2. Define the exception classes: obstacle, safety concern, resource loss, and boundary violation.
3. Define which exceptions allow autonomous adjustment and which always require human review.
4. Require evidence for each pause or resume decision, including state at the time of the exception.
5. Pilot with a limited zone and a repeatable mission objective before expanding coverage.

## Operating Steps

1. Open the mission with the zone, objective, required evidence, restrictions, and accountable operator.
2. Start the approved mission and monitor status through the operator workspace.
3. Pause when an exception fires; do not adjust the mission without review.
4. Review the exception against current state and proposed alternatives.
5. Approve a resume, adjustment, or cancellation with evidence.
6. Record the outcome and use the result to improve the next mission cycle.

## Exceptions

- Safety concern: pause immediately; do not continue without operator review.
- Boundary violation: hold the mission and escalate.
- Resource loss: surface alternatives for review; do not silently swap resources.
- Conflicting state: resolve through human review before any adjustment.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Physical missions stay bounded and recoverable: exceptions pause for human review instead of continuing unobserved. |
| KPIs | Boundary compliance, pause-and-review rate, evidence completeness, human-approval rate. |
| Decision gates | Mission approval, exception pause and review, resume/adjust/cancel decision. |
| Evidence produced | Mission objective, paused status, exception reason, reviewed decision, completion state. |
| Adoption path | Pilot with a limited zone and a repeatable objective before expanding coverage. |

See the [value framework](../docs/example-value.md).

## Public Boundary

This example omits mission-control details, safety thresholds, topology, endpoints, and approval policy.
