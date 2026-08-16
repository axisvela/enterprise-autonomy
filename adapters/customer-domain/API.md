# Customer-Domain Adapter — API Reference

Local reference service for simulated customer-service views: cases, facts, consent, resolutions, accounts, and notifications. Not a production CRM, billing, or compensation system.

Base URL: `http://localhost:8093` (override with `--addr`).

## Endpoints

### `GET /healthz`

```json
{"status":"ok","service":"customer-domain-adapter"}
```

### `GET /v1/cases/{id}`

Returns the case with facts, consent, resolutions, and action history.

Seeded `cs-0001`:

```json
{"id":"cs-0001","customer":"cust-1001","account":"acct-2001","issue":"billing overcharge","status":"open","facts":[],"resolutions":[]}
```

Errors: `404 {"error":"case_not_found"}`.

### `POST /v1/cases/{id}/facts`

Records a verified fact. Requires `claim`, `source`, `verified`, `idempotency_key`.

```json
{"claim":"billing overcharge confirmed against acct-2001","source":"billing-system","verified":true,"idempotency_key":"cs-fact-v1"}
```

Errors: `400` missing fields, `422 unverified_claim_requires_investigation`.

### `POST /v1/cases/{id}/consent`

Records the customer's consent decision. Requires `customer`, `decision` (`approve`/`decline`), `consent_ref`, `idempotency_key`.

```json
{"customer":"cust-1001","decision":"approve","consent_ref":"consent://cs-0001","idempotency_key":"cs-consent-v1"}
```

`case.status` → `consented` when approved. Errors: `400` missing fields or invalid decision, `403 customer_mismatch`.

### `POST /v1/cases/{id}/resolutions`

Applies a resolution. Requires `type` and `idempotency_key`; money movements (`compensation`, `refund`, `credit`) additionally require consent + approval:

```json
{"type":"compensation","amount":40,"approved_by":"service-lead","approval_ref":"approval://cs-0001","consent_ref":"consent://cs-0001","idempotency_key":"cs-comp-v1"}
```

- `explanation`/`correction`: no consent or approval.
- `compensation`/`refund`/`credit`: require an approved consent and a service-lead approval; apply the credit to the account.
- `escalation`: records without moving money; sets `case.status` → `escalated`.
- Otherwise `case.status` → `resolving`.

Errors: `400` missing/invalid fields, `403 consent_required`, `403 consent_ref_mismatch`, `403 approval_required_for_compensation`, `400 amount_must_be_positive`.

### `POST /v1/cases/{id}/close`

Closes the case. Requires `closed_by`, `idempotency_key`.

```json
{"closed_by":"service-lead","idempotency_key":"cs-close-v1"}
```

`case.status` → `resolved`. Errors: `400` missing fields, `403 no_resolution_applied`, `409 escalated_case_requires_escalation_queue`.

### `GET /v1/accounts/{id}`

```json
{"id":"acct-2001","customer":"cust-1001","balance":120,"currency":"USD","status":"active","credits":[]}
```

Errors: `404 account_not_found`.

### `GET /v1/notifications/{id}`

```json
{"case_id":"cs-0001","notifications":["customer-notification-pending:resolution-cs-comp-v1"]}
```

Errors: `404 case_not_found`.

## State Machine

```
open -> consented -> resolving -> resolved
   \-> escalated (cannot close directly)
```

`open` becomes `consented` after an approved consent; `consenting`/`open` become `resolving` after a non-escalating resolution; `close` requires at least one resolution. Every mutating call is idempotent (`"replayed": true` on repeat keys).

## Governance Model

- **Consent-required**: money movements are denied without an approved consent whose reference matches the resolution.
- **Approval-required**: the same movements are denied without a service-lead `approved_by`/`approval_ref`.
- **Verified-facts-only**: unverified claims cannot be recorded.
- **Close-after-resolution**: a case cannot close with no applied resolution.

**Governance patterns:** consent as a first-class gate and conjunctive authority; see the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository.
