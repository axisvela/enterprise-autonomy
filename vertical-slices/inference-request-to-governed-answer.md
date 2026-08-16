# Inference-Request-to-Governed-Answer Vertical Slice

## Business Scenario

An organization needs an inference result (a model answer or a routing decision) that is governed end to end: the model and endpoint are selected under policy, the answer can be grounded in claims and durable memory, and every result is recorded as auditable evidence rather than an ungoverned call.

| Item | Definition |
| --- | --- |
| Trigger | A governed inference request is submitted for a bounded decision or answer. |
| Accountable owner | The designated inference governance owner. |
| Completion | A governed answer is returned with endpoint, model, policy, and grounding references recorded. |
| Evidence | Request, selected endpoint/model, policy decision, grounding claims, memory context, answer, audit record. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Governed model and endpoint selection and routing | Noetivela |
| Grounded concepts, claims, and evidence | Gnosivela |
| Durable, auditable memory and context | Mnemovela |
| Review and case workspace | Symbivela |
| Identity, authorization, and approvals | Aegivela |
| Capability and audit notifications | Moduregis |

## Design Steps

1. Define the inference use case, the bounded set of answers the system may produce, and who is accountable.
2. Define the model and endpoint selection policy (quality, latency, cost) and which requests require human review.
3. Define the grounding contract: which claims and memory context may inform the answer, and what evidence is recorded.
4. Establish the audit boundary: what is recorded per request and how policy deviations are handled.

## Operating Steps

1. A governed request arrives with its intended use, constraints, and authorization.
2. Noetivela selects and routes to an authorized model and endpoint under policy.
3. Gnosivela supplies grounded claims and evidence; Mnemovela supplies durable memory context.
4. The answer is produced with endpoint, model, policy, and grounding references attached.
5. Human review occurs where policy requires, with authorization enforced by Aegivela.
6. The organization records the request and its evidence for audit and monitors policy compliance.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Inference is governed end to end: selection under policy, grounded in claims and memory, with auditable evidence for every answer. |
| KPIs | Policy compliance, grounding coverage, review rate, evidence completeness, latency and cost within budget. |
| Decision gates | Endpoint/model selection, human-review points, grounding acceptance. |
| Evidence produced | Request, selection decision, grounding claims, memory references, answer, audit record. |
| Adoption path | Start with one bounded decision; expand only after measuring policy compliance and review rate. |

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
| Record | request and answer evidence | Moduregis, Aegivela | audit record `audit-inf-0001` |

## Runnable Local Demo

No runnable demo ships for this slice yet. A governed inference-governance demo backed by a new inference-domain reference adapter is tracked in [Phase 8 of the roadmap](../ROADMAP.md). Until it lands, run the products' own local binaries and follow the [detailed operating procedure](#detailed-operating-procedure) above.

## Public Boundary

This scenario describes an outcome-level workflow only. It does not disclose model selection policy rules, endpoint configurations, grounding thresholds, or internal decision logic.

Use the [example design guide](../docs/example-design-guide.md) when adapting this scenario to a specific organization.
