# Mission-to-Execution Vertical Slice

## Business Scenario

An authorized operator requests a facility inspection. The ecosystem coordinates planning, capability selection, execution, and result review while products retain authority over their own runtimes.

| Item | Definition |
| --- | --- |
| Trigger | An authorized operator submits an inspection objective. |
| Accountable owner | The requesting operator. |
| Completion | The inspection is performed and the outcome is available to the operator with the evidence needed for review and follow-up. |
| Evidence | Objective, plan, capability selection, execution records, outcome and result evidence. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Human collaboration and review | Symbivela |
| Planning and replanning | Orchadyn |
| Capability control | Moduregis |
| Identity, authorization, and approval | Aegivela |
| Physical or agent execution | Kinetovela, Praxovela |
| Operational context | Ontovela |
| External integration | Limenora |

## Design Steps

1. Define the requested outcome, the operator who owns it, and the evidence required to accept completion.
2. Select the products that will provide collaboration, planning, capability control, authorization, execution, operational context, and integration.
3. Define the human review points for authorization, unexpected conditions, and final acceptance.
4. Limit the first trial to a recoverable scope with clear stop conditions.

## Operating Steps

1. An operator defines the inspection objective in a human-agent collaboration workspace.
2. Planning products turn the objective and current operational context into a revisable plan.
3. Capability and security products help establish whether eligible execution resources can perform the work.
4. An execution or robotics product performs the accepted work within its own safety and operating boundaries.
5. The outcome is available to the operator with the evidence needed for review and follow-up.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Physical or agent missions are planned, authorized, executed within product boundaries, and reviewed by the operator, so work is observable, recoverable, and auditable. |
| KPIs | Authorization coverage, boundary compliance, plan revisability, outcome evidence. |
| Decision gates | Authorization, unexpected-condition review, final acceptance. |
| Evidence produced | Objective, plan, capability selection, execution records, outcome. |
| Adoption path | Start with a small, recoverable inspection scope and clear stop conditions. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Define objective | inspection request, accountable operator | Symbivela | objective `mission-0001` |
| Plan | objective, operational context, constraints | Orchadyn | plan `plan-mission-0001` |
| Select capability | eligible execution resources | Moduregis, Aegivela | capability selection + authorization |
| Execute | accepted work within safety/operating boundaries | Kinetovela, Praxovela | execution records |
| Review and follow up | outcome, result evidence | Symbivela, Ontovela | review record `review-mission-0001` |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the local demos for the [fleet mission](../examples/fleet-mission-local/README.md) and [order exception](../examples/order-fulfillment-local/README.md) scenarios, and their Detailed Operations Guides.

## Public Boundary

This example omits specific robotics, planning, approval policy, service endpoints, and operational runbooks.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
