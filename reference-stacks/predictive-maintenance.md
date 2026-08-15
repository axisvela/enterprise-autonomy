# Predictive Maintenance Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed predictive-maintenance outcome. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Maintenance review and approval workspace | Symbivela |
| Equipment and operational state | Ontovela |
| Risk-signal reasoning and knowledge | Gnosivela / Mnemovela |
| Maintenance planning and replanning | Orchadyn |
| Identity, authorization, and approval | Aegivela |
| Sensor, CMMS, and notification connectivity | Limenora |
| Durable maintenance process | Rheovela |
| Simulation of intervention impact | Peiravela |

## Design Steps

1. Define the equipment risk signals and the accountable maintenance manager.
2. Define which interventions require shutdown, safety, or cost review.
3. Select the product roles needed for state, knowledge, planning, authorization, connectivity, and process.
4. Identify the human decision points: risk confirmation, intervention approval, scheduling, and close-out.
5. Pilot on non-critical equipment and measure prediction and intervention quality before expanding.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm operator access.
2. Record the equipment risk signal with evidence when it fires.
3. Confirm the risk against current state and prior knowledge before recommending action.
4. Approve the intervention and schedule it with the required safety review.
5. Execute the maintenance process, confirm CMMS and notification updates, and close with evidence.
6. Escalate unexpected risk without silently deferring the intervention.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Equipment risk signals lead to approved interventions with safety review, not unvalidated action. |
| KPIs | Signal-to-intervention, gate compliance, evidence quality, false-alarm handling. |
| Decision gates | Risk confirmation, intervention approval, scheduling, close-out. |
| Evidence produced | Signal, asset state, assessment, approval, work order, execution result, post-work verification. |
| Adoption path | Pilot on non-critical equipment and measure prediction and intervention quality before expanding. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Detect signal | equipment risk signal with evidence | Ontovela, Gnosivela | signal record `pm-0001` |
| Confirm risk | current state, prior knowledge, signal quality | Ontovela, Mnemovela | confirmed risk `confirm-pm-0001` |
| Propose intervention | approved options with impact | Orchadyn, Moduregis | intervention options |
| Approve | safety/cost review, scheduling | Aegivela, Symbivela | `approval://pm-0001` + schedule |
| Execute | maintenance process, CMMS + notification updates | Rheovela, Limenora | work order + updates |
| Close | post-work verification, evidence | Symbivela, Ontovela | closed work order + follow-up |

## Scope Boundary

Actual deployment topology, integrations, prediction thresholds, and policy are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
