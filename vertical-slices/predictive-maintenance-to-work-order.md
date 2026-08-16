# Predictive Maintenance To Work Order

## Business Scenario

An equipment signal indicates that an asset may require maintenance. Operations must validate the signal, assess safety and production impact, decide whether to inspect or intervene, schedule approved work, and record the maintenance outcome without treating a prediction as a confirmed fault.

| Item | Definition |
| --- | --- |
| Trigger | Monitoring, inspection, or analysis reports elevated equipment risk. |
| Accountable owner | Maintenance manager. |
| Completion | Risk is dismissed with evidence, inspected, repaired, deferred by authorized decision, or escalated as a safety event. |
| Evidence | Signal source, asset context, assessment, safety decision, work order, execution result, and post-work verification. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Asset and operational context | Ontovela |
| Simulation and scenario evaluation | Peiravela |
| Inspection and maintenance planning | Orchadyn |
| Maintenance capability control | Moduregis |
| Work-order process and recovery | Rheovela |
| Authorization and safety approvals | Aegivela |
| Robot or field execution | Kinetovela and Praxovela |
| Operator oversight and external-system connectivity | Symbivela and Limenora |

## Design Steps

1. Define which signals create a review, inspection, immediate stop, or emergency escalation; do not equate a prediction with a confirmed defect.
2. Identify the maintenance manager, safety authority, asset owner, and execution owner for each asset class.
3. Define evidence required to authorize intervention: signal quality, asset history, production impact, site conditions, and safety review.
4. Define allowable outcomes: monitor, inspect, repair, replace, defer with authorization, or stop operations.
5. Use a controlled asset class and review outcomes before expanding to broader autonomous or robotic work.

## Operating Steps

1. **Open the maintenance assessment.** Record the signal, affected asset, detection time, current operating state, and maintenance owner.
2. **Validate the signal.** Review recent inspections, operating context, and signal quality. If evidence is insufficient, schedule inspection rather than declaring a failure.
3. **Assess impact.** The maintenance and safety owners review production, safety, access, and outage implications. A safety concern follows the emergency process.
4. **Plan the response.** Prepare approved options such as monitoring, inspection, scheduled repair, or controlled shutdown. Each option states required approvals and expected evidence.
5. **Authorize and schedule.** The accountable owners approve the selected work. The work order identifies the asset, scope, assigned capability, site window, and stop conditions.
6. **Execute and observe.** The assigned team, robot, or agent performs only the approved scope. Exceptions, unsafe conditions, and incomplete work are reported to the maintenance owner.
7. **Verify and close.** Confirm the post-work asset state and attach the result to the work order. Close only when the maintenance manager accepts the evidence; otherwise create follow-up work.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Equipment risk is validated before action, so predictions do not become confirmed faults and interventions are approved with evidence. |
| KPIs | Signal-to-intervention, gate compliance, evidence quality, false-alarm handling. |
| Decision gates | Risk confirmation, safety impact review, intervention approval, close-out acceptance. |
| Evidence produced | Signal, asset context, assessment, safety decision, work order, execution result, post-work verification. |
| Adoption path | Pilot on non-critical assets; measure prediction and intervention quality before broader robotic or autonomous work. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open assessment | signal, affected asset, detection time, operating state | Ontovela | assessment `maint-assess-0001` (`open`) |
| Validate signal | recent inspections, operating context, signal quality | Ontovela, Gnosivela | validation record `valid-0001` |
| Assess impact | production, safety, access, outage implications | Symbivela, Aegivela | impact assessment `impact-0001` |
| Plan response | approved options + required approvals/evidence | Orchadyn, Moduregis | response plan `plan-maint-0001` |
| Authorize and schedule | owner approvals, work order fields | Aegivela, Rheovela | work order `wo-0001` + `approval://maint-assess-0001` |
| Execute and observe | assigned scope, stop conditions | Kinetovela, Praxovela | execution record `run-wo-0001` |
| Verify and close | post-work asset state, maintenance manager acceptance | Ontovela, Symbivela | closed work order + follow-up record |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local predictive-maintenance demo](../examples/predictive-maintenance-local/README.md) and its [Detailed Operations Guide](../examples/predictive-maintenance-local/operations-guide.md).

## Public Boundary

This example omits equipment thresholds, control logic, safety policy, site topology, maintenance records, and execution configuration.
