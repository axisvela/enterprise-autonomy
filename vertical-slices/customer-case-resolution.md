# Customer Case Resolution

## Business Scenario

A customer reports a service problem that spans account, order, delivery, and billing systems. The service team must establish the facts, coordinate the correct internal owners, obtain approval for compensation or account changes, keep the customer informed, and close the case with a reviewable resolution.

| Item | Definition |
| --- | --- |
| Trigger | Customer submits a complaint, service request, dispute, or escalation. |
| Accountable owner | Customer-service lead. |
| Completion | The case is resolved, customer communication is recorded, and any promised correction is confirmed or escalated. |
| Evidence | Customer request, verified facts, actions considered, approvals, communication status, and final outcome. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Customer, order, billing, and support-system connectivity | Limenora |
| Case context and evidence | Gnosivela, Mnemovela, and Ontovela |
| Resolution planning | Orchadyn |
| Authorized service actions | Moduregis and Aegivela |
| Durable case coordination | Rheovela |
| Agent workspace and human oversight | Symbivela and Praxovela |

## Design Steps

1. Define case classes, service-level expectations, accountable owners, and mandatory escalation paths.
2. Define the facts required for each class and distinguish verified system records from customer statements or agent notes.
3. Define permitted remedies, including correction, replacement, refund, credit, explanation, or escalation, with the approval required for each.
4. Define customer communication checkpoints: acknowledgement, investigation update, proposed resolution, and closure.
5. Pilot a narrow set of cases and require a human service owner for exceptions and customer-impacting commitments.

## Operating Steps

1. **Acknowledge and classify.** Create a case with the customer's request, contact channel, urgency, affected account or transaction, and accountable service owner.
2. **Verify facts.** The agent reviews the relevant records and distinguishes confirmed facts from unverified claims. Missing or conflicting information is requested or escalated.
3. **Coordinate investigation.** The case routes tasks to the responsible order, billing, delivery, or product teams. The service owner remains accountable for the customer outcome.
4. **Prepare a resolution.** The agent presents permitted options with customer impact, cost, and dependencies. An agent does not promise a remedy beyond their assigned authority.
5. **Approve and act.** Required reviewers approve compensation, account changes, refunds, or other customer commitments. The selected action is executed through the designated systems and recorded.
6. **Communicate and confirm.** The customer receives a clear status and next step. The agent verifies that any promised correction was accepted or completed.
7. **Close or escalate.** Close only after the outcome and communication are evidenced. Repeat contacts, regulatory concerns, threats, privacy issues, or unresolved disputes follow the escalation route.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Customer cases are resolved against verified facts with consent and approvals recorded, reducing repeat contacts and unmanaged commitments. |
| KPIs | First-resolution accuracy, consent compliance, communication completeness, case reconstructability. |
| Decision gates | Case assignment, remedy approval, customer consent for commitments, closure review. |
| Evidence produced | Case, verified facts, actions considered, approvals, communication status, final outcome. |
| Adoption path | Pilot a narrow case class with a human service owner; expand after measuring first-resolution accuracy. |

See the [value framework](../docs/example-value.md).

## Public Boundary

This example omits customer data, remedy limits, service-level targets, system endpoints, privacy controls, and internal escalation policy.
