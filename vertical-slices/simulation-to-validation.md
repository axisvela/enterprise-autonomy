# Simulation-to-Validation Vertical Slice

## Business Scenario

An organization evaluates a proposed autonomous operation in simulation before allowing it to proceed in a live environment.

| Item | Definition |
| --- | --- |
| Trigger | A proposed autonomous operation is submitted for evaluation. |
| Accountable owner | The designated review group. |
| Completion | A decision to revise, approve, or reject the operation is recorded with simulation evidence. |
| Evidence | Candidate operation, simulation outcomes, review record, validation and release assurance evidence. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Human review and decision | Symbivela |
| Planning and world-model context | Orchadyn, Ontovela |
| Simulation and experiment control | Peiravela |
| Validation and release assurance | Tekmovela |
| Identity, authorization, and review evidence | Aegivela |
| External integration | Limenora |

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

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local simulation-validation demo](../examples/simulation-validation-local/README.md) and its [Detailed Operations Guide](../examples/simulation-validation-local/operations-guide.md).

## Public Boundary

This scenario describes an outcome-level workflow only. It does not disclose simulation models, operational thresholds, policy rules, test fixtures, or internal decision logic.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
