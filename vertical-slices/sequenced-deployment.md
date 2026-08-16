# Sequenced Deployment Vertical Slice

## Business Scenario

An enterprise releases a service through a governed, sequenced pipeline in which an autonomous agent executes each step strictly in order, citing evidence, while any deviation from the sequence (pause, skip, rollback) requires human approval.

| Item | Definition |
| --- | --- |
| Trigger | A release is opened for the pipeline. |
| Accountable owner | The release lead who accepts the release and approves deviations. |
| Completion | The pipeline reaches the terminal step and the deployment is released, immutable. |
| Evidence | Case, pipeline assertion, per-step evidence, deviations, release record. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Release case and operator workspace | Symbivela |
| Pipeline state and capability assertions | Ontovela |
| Durable release process | Rheovela |
| Planning under sequence constraints | Orchadyn |
| Release and compliance notifications | Moduregis |
| Integration of pipeline systems | Limenora |
| Bounded agent execution | Praxovela |
| Identity, authorization, and approvals | Aegivela |

## Design Steps

1. Define the deployment pipeline steps and their strict execution order.
2. Identify the evidence each step must produce and the shared evidence references that gate the next step.
3. Assign products to pipeline execution, durable process management, authorization, and operator collaboration.
4. Define the deviation path: which sequence deviations are allowed, and which human roles must approve them.

## Operating Steps

1. The release pipeline is opened as a governed case with a declared step sequence.
2. An autonomous executor advances the sequence one step at a time; each step cites the evidence it produced.
3. Out-of-sequence or evidence-less execution is rejected; completed steps are immutable.
4. A deviation (pause, skip, rollback) is applied only after a human approval citing a shared approval reference.
5. Operators inspect progress in a collaboration workspace; the released deployment is final and immutable.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Automation advances the release sequence while sequence integrity and human control over deviations keep the pipeline safe and auditable. |
| KPIs | Sequence compliance, evidence coverage, deviation approvals, release immutability. |
| Decision gates | Deviation approvals (pause, skip, rollback), release acceptance. |
| Evidence produced | Case, pipeline assertion, per-step evidence, deviations, release record. |
| Adoption path | Start with a single low-risk pipeline; expand after measuring sequence compliance and deviation reviews. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open | pipeline case, step sequence | Symbivela | case `dep-0001-release` (`open`) |
| Record context | pipeline assertion, evidence ref | Ontovela, deployment-domain | pipeline view (`initiated`) |
| Sequence gate | out-of-order step | deployment-domain | `step_out_of_sequence_next_is_<step>` |
| Execute | per-step evidence, executor | deployment-domain | step run (`in-flight` → `released`) |
| Deviation gate | pause/skip/rollback without approval | deployment-domain | `deviation_requires_human_approval` |
| Wrap durably | workflow definition, actor | Rheovela | `sequenced-deployment` instance |
| Plan (optional) | goal, catalog, constraints, delegation | Orchadyn | verified plan |
| Release | final step evidence | deployment-domain | deployment `released`, immutable |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local deployment demo](../examples/deployment-local/README.md) and its [Detailed Operations Guide](../examples/deployment-local/operations-guide.md).

For the product-composition overview, see the [release operations reference stack](../reference-stacks/release-operations.md).

## Public Boundary

This example intentionally omits pipeline definitions, approval policy, service endpoints, customer data, and operational runbooks.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
