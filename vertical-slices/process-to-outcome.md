# Process-to-Outcome Vertical Slice

## Scenario

An enterprise coordinates a long-running operational process that requires planning, external integrations, human approvals, and recoverable execution.

## Design Steps

1. Define the business outcome, accountable owner, expected duration, and completion evidence.
2. Identify external participants, systems, human approvals, and exceptions that can affect the process.
3. Assign products to planning, durable process management, authorization, integration, operator collaboration, and contextual support.
4. Define the escalation path and the points where an operator can pause, revise, or cancel the work.

## Operating Steps

1. A user or business system initiates a governed operational objective.
2. Orchadyn develops a revisable plan using available context and constraints.
3. Rheovela manages the durable process lifecycle, including waiting, recovery, and escalation.
4. Aegivela supports the required identity, authorization, and approval steps.
5. Limenora connects the process to external systems, events, and partner interfaces.
6. Symbivela provides a workspace for operators to review progress, intervene, and inspect outcomes.

## Commonly Involved Products

Rheovela, Orchadyn, Aegivela, Limenora, Symbivela, Moduregis, Gnosivela, Mnemovela, and Noetivela can contribute to this outcome, depending on the process.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Long-running enterprise processes recover and complete with human oversight, so work survives failures and stays auditable. |
| KPIs | In-flight preservation, resume verification, gate compliance, audit reconstructability. |
| Decision gates | Initiation review, approvals within the process, pause/revise/cancel decisions, outcome acceptance. |
| Evidence produced | Objective, plan, process lifecycle record, approvals, integration events, outcome. |
| Adoption path | Start with a single governed process; expand after measuring recovery and gate compliance. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Initiate | governed operational objective | Symbivela, Rheovela | process instance `proc-0001` (`initiated`) |
| Plan | goals, context, constraints | Orchadyn | plan `plan-proc-0001` |
| Run process | durable lifecycle, waiting, recovery, escalation | Rheovela | instance state history |
| Authorize | identity, authorization, approvals | Aegivela | `approval://proc-0001` |
| Integrate | external systems, events, partner interfaces | Limenora | integration events |
| Review and intervene | progress, pauses, revisions, outcome inspection | Symbivela | review record `review-proc-0001` |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local process-to-outcome demo](../examples/process-to-outcome-local/README.md) and its [Detailed Operations Guide](../examples/process-to-outcome-local/operations-guide.md).

## Public Boundary

This example intentionally omits process definitions, approval policy, service endpoints, customer data, and operational runbooks.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
