# Release Operations Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed release-operations outcome for autonomous systems: an agent executes a declared step sequence in order, citing evidence, while any deviation from the sequence requires human approval. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Release case and operator workspace | Symbivela |
| Pipeline state and capability assertions | Ontovela |
| Durable release process | Rheovela |
| Planning under sequence constraints | Orchadyn |
| Release and compliance notifications | Moduregis |
| Integration of pipeline systems | Limenora |
| Bounded agent execution (boundary policy) | Praxovela |
| Identity, authorization, and approvals | Aegivela |

## Design Steps

1. Define the release pipeline steps and their strict execution order.
2. Define the evidence each step must produce and the shared evidence references that gate the next step.
3. Select the product roles needed for pipeline execution, durable process, planning, and notifications.
4. Identify the human decision points: deviation approvals (pause, skip, rollback) and release acceptance.
5. Start with a single low-risk pipeline and expand as sequence compliance and deviation reviews are measured.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm access.
2. Open the release as a governed case with a declared step sequence.
3. Let an autonomous executor advance the sequence one step at a time, each step citing the evidence it produced.
4. Reject out-of-sequence or evidence-less execution; keep completed steps immutable.
5. Apply a deviation (pause, skip, rollback) only after a human approval citing a shared approval reference.
6. Record the release and its attestations; a released deployment is final and immutable.

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
| Open release | release case, step sequence | Symbivela | case `dep-0001-release` (`open`) |
| Record context | pipeline assertion, evidence ref | Ontovela, deployment-domain | pipeline view (`initiated`) |
| Execute sequence | per-step evidence, executor | deployment-domain, Rheovela | step runs (`in-flight` → `released`) |
| Approve deviation | pause/skip/rollback with human approval | Aegivela, Symbivela | deviation record `deviation-0001` |
| Plan | goal, catalog, constraints, delegation | Orchadyn | verified plan |
| Notify | release and compliance notifications | Moduregis | notification records |
| Release | final step evidence | deployment-domain | deployment `released`, immutable |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local sequenced-deployment demo](../examples/deployment-local/README.md) and its [Detailed Operations Guide](../examples/deployment-local/operations-guide.md).

## Scope Boundary

Actual deployment topology, integrations, sequence definitions, and policy are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
