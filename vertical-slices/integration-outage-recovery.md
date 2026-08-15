# Integration Outage Recovery

## Business Scenario

An external system or partner integration becomes unavailable. Governed processes must preserve in-flight work, surface the outage to the accountable operator, and resume only when the integration and its evidence are verified.

| Item | Definition |
| --- | --- |
| Trigger | Partner, API, event, or webhook outage threatens in-flight work. |
| Accountable owner | Integration operations lead. |
| Completion | Affected work is resumed, re-routed, or completed with verified integration status. |
| Evidence | Outage reference, affected work, reconnection status, and completed actions. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| API, MCP, event, and webhook connectivity | Limenora |
| Integration and operational state | Ontovela |
| Recovery planning | Orchadyn |
| Capability control | Moduregis |
| Authorization and approvals | Aegivela |
| Durable recovery process | Rheovela |
| Operator review | Symbivela |

## Design Steps

1. Define the integration classes and the accountable owner for each.
2. Define which work can wait, re-route, or must escalate during an outage.
3. Require verification of the integration and its state before resuming affected work.
4. Require evidence of the outage window and of each resumed action.
5. Pilot with a non-critical integration before expanding.

## Operating Steps

1. Detect the outage and open a case with the integration reference, affected work, and detection time.
2. Preserve in-flight work in durable processes so it survives the outage.
3. Verify the integration and its state before resuming any affected work.
4. Resume or re-route work according to the approved recovery plan.
5. Confirm each completed action and record the outage and recovery evidence.
6. Close the case only after affected work is evidenced as complete or escalated.

## Exceptions

- Partner outage persists: escalate with affected-work evidence.
- In-flight work lost: surface the loss for review; do not silently re-execute.
- Re-routing requires consent: hold until consent or an approved fallback is recorded.
- Conflicting state after reconnect: resolve through human review.

## Public Boundary

This example omits partner details, topology, endpoints, credentials, and outage policy.
