# Talent Acquisition Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed talent-acquisition outcome. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Hiring-goal and review workspace | Symbivela |
| Candidate and role context | Ontovela |
| Job-family and skills knowledge | Gnosivela |
| Sourcing and evaluation planning | Orchadyn |
| Identity, authorization, and consent | Aegivela |
| ATS, HR, and notification connectivity | Limenora |
| Durable requisition process | Rheovela |
| Governed assistant actions | Praxovela |

## Design Steps

1. Define the requisition lifecycle and the accountable owner at each stage.
2. Define which decisions require hiring-manager, talent-acquisition, or compliance review.
3. Select the product roles needed for context, knowledge, planning, authorization, connectivity, and process.
4. Identify the human decision points: requisition approval, shortlist review, offer approval, and acceptance.
5. Pilot one role family and review outcome quality before expanding.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm operator access.
2. Open a requisition with the role, location, budget envelope, and accountable owner.
3. Ground the process in current role and candidate context before proposing steps.
4. Review shortlists and approve each decision point with evidence.
5. Extend an approved offer, record acceptance or decline, and close the requisition with evidence.
6. Escalate or hold any stage that requires consent or compliance review.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Hiring decisions remain with accountable humans while administration and evidence organization are automated. |
| KPIs | Human-decision integrity, evidence completeness, cycle time, automation scope. |
| Decision gates | Requisition approval, shortlist review, offer approval, acceptance. |
| Evidence produced | Requisition, role context, candidate evidence, approvals, offer, communication status. |
| Adoption path | Pilot one role family and review outcome quality before expanding. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open requisition | role, location, budget envelope, owner | Symbivela | requisition `ta-0001` (`open`) |
| Ground process | current role and candidate context | Ontovela, Gnosivela | context record |
| Propose steps | sourcing and evaluation plan | Orchadyn | plan `plan-ta-0001` |
| Review shortlist | candidate evidence, structured feedback | Symbivela, Mnemovela | shortlist review `shortlist-ta-0001` |
| Approve | requisition, shortlist, offer decisions | Aegivela, Symbivela | `approval://ta-0001` |
| Extend and record | offer, acceptance/decline, closure | Limenora, Rheovela | `offer-ta-0001` + closure record |

## Scope Boundary

Actual deployment topology, integrations, sourcing policy, templates, and data handling are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
