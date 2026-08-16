# Innovation Sandbox to Policy

## Business Scenario

A proposed autonomous capability is explored in a controlled simulation before it is allowed under policy. The organization runs possible-world experiments, reviews evidence, and either releases, restricts, or rejects the capability.

| Item | Definition |
| --- | --- |
| Trigger | A proposed capability or operating change is submitted for exploration. |
| Accountable owner | Designated review group. |
| Completion | A policy decision is recorded with simulation evidence for release, restriction, or rejection. |
| Evidence | Proposal, simulation runs, exception handling, review decisions, and the final policy record. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Simulation and experiment control | Peiravela |
| Review and policy decision | Symbivela |
| Policy and claims knowledge | Gnosivela |
| Experiment planning | Orchadyn |
| Identity, authorization, and review evidence | Aegivela |
| Capability control | Moduregis |
| Operational context | Ontovela |
| Durable review process | Rheovela |

## Design Steps

1. Define the proposal scope and the designated review group.
2. Define the experiments that must complete before a policy decision.
3. Require immutable simulation evidence and exception handling for each run.
4. Identify the human decision points: experiment approval, evidence review, and policy decision.
5. Pilot with a low-impact capability before expanding.

## Operating Steps

1. Open a proposal with the capability, scope, and accountable review group.
2. Compile and run the required simulation experiments in a controlled environment.
3. Review evidence, including exceptions and edge cases, against the proposal claims.
4. Decide to release, restrict, or reject the capability with recorded reasons.
5. Record the policy decision and any follow-up experiments.
6. Update the capability's availability according to the recorded decision.

## Exceptions

- Evidence incomplete: hold the decision; do not release on partial evidence.
- Unexpected behavior in simulation: review and re-run before deciding.
- Review group unavailable: hold the decision until the required authority is available.

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open proposal | capability, scope, review group | Symbivela | proposal `proposal-0001` (`open`) |
| Compile experiments | scenarios, boundary cases | Peiravela, Orchadyn | experiment set `exp-proposal-0001` |
| Run simulation | possible-world runs, immutable evidence | Peiravela | simulation evidence `evidence://proposal-0001` |
| Review | exceptions, edge cases, proposal claims | Gnosivela, Symbivela | review record `review-proposal-0001` |
| Decide | release, restrict, or reject | Symbivela, Aegivela | policy decision `decision-proposal-0001` |
| Apply | capability availability update | Moduregis | capability record updated |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local innovation-sandbox demo](../examples/innovation-sandbox-local/README.md) and its [Detailed Operations Guide](../examples/innovation-sandbox-local/operations-guide.md).

## Public Boundary

This example omits specific simulation models, thresholds, endpoints, and policy rules.
