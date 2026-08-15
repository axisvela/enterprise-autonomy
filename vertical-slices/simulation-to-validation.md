# Simulation-to-Validation Vertical Slice

## Scenario

An organization evaluates a proposed autonomous operation in simulation before allowing it to proceed in a live environment.

## Design Steps

1. Define the operation to be evaluated, its intended business outcome, and the accountable review group.
2. Identify the representative operational context and the scenarios that would make the operation unacceptable.
3. Define evidence that allows reviewers to compare candidate approaches and record a decision.
4. Establish a clear boundary between the simulation exercise and any later live operation.

## Operating Steps

1. A team defines an operational objective, constraints, and success criteria.
2. Planning and world-model products provide the candidate operation and relevant context.
3. Peiravela evaluates possible scenarios and produces reviewable simulation outcomes.
4. Symbivela enables human review of the proposed operation and its evidence.
5. Tekmovela supports repeatable validation and release-assurance activities before deployment.
6. The organization decides whether to revise, approve, or reject the proposed operation.

## Commonly Involved Products

Orchadyn, Ontovela, Peiravela, Symbivela, Tekmovela, Aegivela, and Limenora can participate in this outcome, depending on the deployment.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Autonomous operations are reviewed in simulation before live use, so the organization decides with evidence instead of by trial. |
| KPIs | Contract pass rate, re-verification coverage, waiver discipline, attestation completeness. |
| Decision gates | Scenario definition, evidence review, revise/approve/reject decision, release assurance. |
| Evidence produced | Candidate operation, simulation outcomes, review record, validation and release assurance evidence. |
| Adoption path | Evaluate one bounded operation; expand only after the review group accepts simulated evidence. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Define objective | operational objective, constraints, success criteria | Symbivela | proposal `eval-0001` |
| Prepare context | candidate operation + relevant context | Orchadyn, Ontovela | candidate spec `spec-eval-0001` |
| Run simulation | scenario definitions, boundary cases | Peiravela | simulation runs + immutable evidence `evidence://eval-0001` |
| Review | simulated outcomes against criteria | Symbivela | review record `review-eval-0001` |
| Validate | repeatable validation, release assurance | Tekmovela | validation report `assurance-eval-0001` |
| Decide | revise, approve, or reject | Symbivela, Aegivela | decision `decision-eval-0001` |

## Public Boundary

This scenario describes an outcome-level workflow only. It does not disclose simulation models, operational thresholds, policy rules, test fixtures, or internal decision logic.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
