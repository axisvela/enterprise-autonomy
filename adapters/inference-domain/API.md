# Inference-Domain Adapter — API Reference

Local reference service for simulated governed-inference views. Not a production inference fabric.

Base URL: `http://localhost:8103` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"inference-domain-adapter"}
```

### `GET /v1/inferences/{id}`

Seeded `inf-0001` (high-impact customer-facing summary):

```json
{"id":"inf-0001","use":"customer-facing-summary","impact":"high","status":"submitted"}
```

Errors: `404 inference_not_found`.

### `POST /v1/inferences/{id}/authorize`

Authorizes the request. Requires `authorized_by`, `authorization_ref`, `idempotency_key`.

```json
{"authorized_by":"inference-owner","authorization_ref":"authorization://inf/0001",
 "idempotency_key":"i-auth-v1"}
```

`status` → `authorized`. Errors: `400` missing fields, `409` immutable.

### `POST /v1/inferences/{id}/route`

Selects the model and endpoint under policy. Requires `model`, `endpoint`, `policy_ref`, `idempotency_key`.

```json
{"model":"model-alpha","endpoint":"endpoint-production","policy_ref":"policy://inf/selection",
 "idempotency_key":"i-route-v1"}
```

`status` → `routed`. Only `model-alpha`/`model-beta` and `endpoint-production` are in the allowed catalog.

Errors:
- `400` missing fields
- `403 authorization_required_before_route` (no authorization yet)
- `403 model_out_of_policy_<model>` (model not in the allowed catalog)
- `403 endpoint_out_of_policy_<endpoint>` (endpoint not in the allowed catalog)
- `409` immutable

### `POST /v1/inferences/{id}/ground`

Attaches grounding claims and memory context. Requires `claim_refs` (non-empty array), `memory_ref`, `idempotency_key`.

```json
{"claim_refs":["claim://inf/0001/service-level"],"memory_ref":"memory://inf/0001",
 "idempotency_key":"i-ground-v1"}
```

`status` → `grounded`. Errors: `400` missing fields, `403 route_required_before_grounding`, `409` immutable.

### `POST /v1/inferences/{id}/reviews`

Records the human review required for high-impact requests. Requires `reviewed_by`, `decision` (`approve`), `review_ref`, `idempotency_key`.

```json
{"reviewed_by":"inference-owner","decision":"approve","review_ref":"review://inf/0001",
 "idempotency_key":"i-review-v1"}
```

`status` → `reviewed`. Errors: `400` missing fields, `403 review_not_required_for_low_impact`, `403 review_decision_must_be_approve`, `409` immutable.

### `POST /v1/inferences/{id}/answers`

Produces the governed answer. Requires `answer_ref`, `produced_by`, `idempotency_key`.

```json
{"answer_ref":"answer://inf/0001","produced_by":"inference-runtime",
 "idempotency_key":"i-answer-v1"}
```

`status` → `answered`. High-impact requests require a review first.

Errors:
- `400` missing fields
- `403 route_and_grounding_required_before_answer` (no route or grounding)
- `403 human_review_required_before_answer` (high-impact request without a review)
- `409` immutable

### `POST /v1/inferences/{id}/audit`

Records the final auditable evidence. Requires `audited_by`, `audit_ref`, `idempotency_key`.

```json
{"audited_by":"inference-owner","audit_ref":"audit://inf/0001",
 "idempotency_key":"i-audit-v1"}
```

`status` → `audited`; the inference is immutable afterwards.

Errors: `400` missing fields, `403 answer_required_before_audit`.

### `GET /v1/notifications/{id}`

```json
{"inference_id":"inf-0001","notifications":["review-required-notification-pending:inf-0001"]}
```

Errors: `404 inference_not_found`.

## State Machine

```
submitted -> authorized -> routed -> grounded -> [reviewed] -> answered -> audited
                                                   (required for high-impact)
```

`route` requires an authorization and an in-policy model/endpoint; `ground` requires a route; a high-impact `answer` requires a human review; `audit` requires an answer; an audited inference is immutable.

**Governance pattern:** governed inference (selection under policy, grounding-cited answers, human review for high impact, immutable audit); see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
