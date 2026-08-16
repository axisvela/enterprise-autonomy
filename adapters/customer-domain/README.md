# Customer-Domain Reference Adapter

This local reference service adapts simulated customer-service views for runnable examples. It is not a production CRM, billing, or compensation system.

## Build And Start

```powershell
go build -o customer-domain-adapter.exe .
.\customer-domain-adapter.exe --addr :8093 --data-file .\customer-domain-data.json
```

`GET http://localhost:8093/healthz` returns `{"status":"ok","service":"customer-domain-adapter"}`.

## Seeded State

- Case `cs-0001`: customer `cust-1001`, account `acct-2001`, issue `billing overcharge`, status `open`.
- Account `acct-2001`: balance `120 USD`, status `active`.

## Governance Model

- **Consent-required**: `compensation`, `refund`, and `credit` resolutions require a recorded customer consent (`POST /v1/cases/{id}/consent` with decision `approve`).
- **Approval-required**: those resolutions additionally require a service-lead `approved_by` and `approval_ref` (conjunctive authority).
- `explanation` and `correction` need no consent; `escalation` records without applying money.
- A case can only close after at least one resolution is applied.

## APIs

| Request | Result |
| --- | --- |
| `GET /v1/cases/{id}` | Case with facts, consent, resolutions, and action history. |
| `POST /v1/cases/{id}/facts` | Records a verified fact; unverified claims are rejected. |
| `POST /v1/cases/{id}/consent` | Records the customer's consent decision. |
| `POST /v1/cases/{id}/resolutions` | Applies a resolution (consent + approval for money movements). |
| `POST /v1/cases/{id}/close` | Closes the case after a resolution. |
| `GET /v1/accounts/{id}` | Account balance and credit history. |
| `GET /v1/notifications/{id}` | Pending customer notifications. |

See [API.md](API.md) for request bodies, the state machine, and error semantics.
