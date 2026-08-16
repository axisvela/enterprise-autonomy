# Recruitment-Domain Adapter â€?API Reference

Local reference service for simulated recruiting views. Not a production ATS or HR system.

Base URL: `http://localhost:8094` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"recruitment-domain-adapter"}
```

### `GET /v1/requisitions/{id}`

Returns the requisition with criteria, candidates, decisions, offer, and action history.

Seeded `req-0001`:

```json
{"id":"req-0001","role":"Senior Platform Engineer","location":"Remote",
 "hiring_manager":"hiring-manager-1","ta_lead":"ta-lead-1","budget_ref":"budget-rec-0001",
 "status":"draft","criteria":[],"candidates":["cand-a","cand-b","cand-c"],"decisions":[]}
```

Errors: `404 requisition_not_found`.

### `POST /v1/requisitions/{id}/validate`

TA lead validates the requisition and records criteria. Requires `validated_by`, `criteria`, `idempotency_key`.

```json
{"validated_by":"ta-lead-1","criteria":["platform-expertise","systems-ownership"],"idempotency_key":"rec-val-v1"}
```

`requisition.status` â†?`validated`. Errors: `400` missing fields, `403 only_ta_lead_can_validate`, `409 requisition_not_draft`.

### `POST /v1/requisitions/{id}/decisions`

Records a human decision. Requires `stage`, `decision`, `candidate`, `decided_by`, `actor_type`, `rationale`, `decision_ref`, `idempotency_key`.

```json
{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"panel-1",
 "actor_type":"human","rationale":"meets criteria","decision_ref":"decision://rec-0001",
 "idempotency_key":"rec-sl-v1"}
```

- `stage` must be `shortlist`, `selection`, or `offer`.
- **`actor_type: automated` is rejected** with `403 automation_cannot_make_hiring_decisions`.
- The lifecycle is stage-gated: `shortlist` requires `validated`/`shortlisting`; `selection` requires `shortlisting`; `offer` requires `selection`.

Errors: `400` missing/invalid fields, `403 automation_cannot_make_hiring_decisions`, `400 candidate_not_in_requisition`, `409 <stage>_required_first`.

### `POST /v1/requisitions/{id}/offers`

Issues an offer. Requires `candidate`, `offered_by`, `offer_ref`, `idempotency_key`.

```json
{"candidate":"cand-a","offered_by":"ta-lead-1","offer_ref":"offer://rec-0001","idempotency_key":"rec-offer-v1"}
```

Creates `offer-rec-offer-v1` (status `issued`) and sets `requisition.status` â†?`closed`.

Errors: `400` missing fields, `409 offer_decision_required_first`, `403 no_offer_decision_for_candidate`.

### `GET /v1/candidates/{id}`

```json
{"id":"cand-a","evaluation":[]}
```

Errors: `404 candidate_not_found`.

### `GET /v1/notifications/{id}`

```json
{"requisition_id":"req-0001","notifications":["offer-notification-pending:offer-rec-offer-v1"]}
```

Errors: `404 requisition_not_found`.

## State Machine

```
draft -> validated -> shortlisting -> selection -> offer -> closed
```

`validate` moves `draft â†?validated`; the first `shortlist` decision moves to `shortlisting`; the first `selection` decision to `selection`; the first `offer` decision to `offer`; the `offers` endpoint moves to `closed`.

## Automation Boundary

The adapter's central constraint is **human-decision integrity**: only humans (`actor_type: human`) may record screening, selection, or offer decisions. Automation can administer and organize, but any attempt to record a decision as an automated actor is denied before stage or candidate checks run.

**Governance pattern:** [Automation cannot decide](../../docs/governance-patterns.md#10-automation-cannot-decide) from the [governance patterns catalog](../../docs/governance-patterns.md).
