# Inference Governance Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed inference outcome for autonomous systems: a request is routed to an authorized model and endpoint under policy, grounded in claims and durable memory, and recorded as auditable evidence. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Governed model and endpoint selection and routing | Noetivela |
| Grounded concepts, claims, and evidence | Gnosivela |
| Durable, auditable memory and context | Mnemovela |
| Review and case workspace | Symbivela |
| Identity, authorization, and approvals | Aegivela |
| Capability and audit notifications | Moduregis |

## Design Steps

1. Define the bounded set of governed inference requests and who is accountable for each.
2. Define the model and endpoint selection policy and the evidence every selection decision must record.
3. Define the grounding contract: which claims and memory context may inform an answer.
4. Identify the human decision points: review-before-answer for high-impact requests and grounding acceptance.
5. Start with a single low-impact decision and expand after measuring policy compliance and review rate.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm access.
2. Open the request as a governed case with a declared use, constraints, and authorization.
3. Route to an authorized model and endpoint under policy, recording the selection evidence.
4. Ground the answer in accepted claims and durable memory context.
5. Apply human review where policy requires; keep completed requests immutable.
6. Record the request and its evidence for audit.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Inference stays governed end to end: selection under policy, grounded in claims and memory, with auditable evidence for every answer. |
| KPIs | Policy compliance, grounding coverage, review rate, evidence completeness, latency and cost within budget. |
| Decision gates | Selection, human-review points, grounding acceptance. |
| Evidence produced | Request, selection, grounding refs, answer, audit record. |
| Adoption path | Start with a single low-impact decision; expand after measuring compliance and review rate. |

See the [value framework](../docs/example-value.md).

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open request | request, intended use, constraints | Symbivela | case `inf-0001` (`open`) |
| Authorize | identity, policy, delegated authority | Aegivela | authorization record `authz-inf-0001` |
| Select route | selection policy, model/endpoint catalog | Noetivela | route `route-inf-0001` (`selected`) |
| Ground | accepted claims, memory context | Gnosivela, Mnemovela | grounding refs `grounding://inf-0001` |
| Answer | authorized endpoint, grounded context | Noetivela | answer `answer-inf-0001` with evidence refs |
| Review | policy-required human review | Symbivela | review record `review-inf-0001` |
| Notify | request and audit notifications | Moduregis | notification records |
| Record | final evidence | Symbivela, Aegivela | audit record `audit-inf-0001` |

## Runnable Local Demo

A runnable inference-governance demo is planned under [Phase 8 of the roadmap](../ROADMAP.md). Until it ships, run each product's own local binaries and follow the [detailed operating procedure](#detailed-operating-procedure) above.

## Scope Boundary

Actual model selection policy, endpoint configuration, grounding contracts, and review policy are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
