# Input / Output Conventions

A shared convention for describing examples so every step's **input** and **output** is explicit and consistent across the repository.

## For Runnable Demos

Runnable demos document real HTTP calls. Use this shape per step:

| Field | Content |
| --- | --- |
| Purpose | Why the step exists and what it proves. |
| Request | Method, URL, headers (tenant + idempotency), and the exact JSON body. |
| Response | The fields the script reads and what they mean. |
| Artifact | The `product`, `artifact`, and `state` recorded in the value report. |

See the [order-exception operations guide](../examples/order-fulfillment-local/operations-guide.md) as the reference implementation.

## For Designed Examples (not runnable)

Designed examples describe business-level artifacts. Use this shape per step:

| Field | Content |
| --- | --- |
| Input | Who provides what (subject reference, fields, window, evidence required). |
| Products | Which products contribute and in what role. |
| Output | The artifact produced (case, assertion, approval, status record) with a concrete id. |

## Naming Conventions

- **IDs** are stable and human-readable: `assertion-<subject>-<property>`, `case-<subject>-<issue>`, `mission-<zone>-<seq>`, `plan-<subject>`.
- **Evidence references** follow `evidence://<source>/<id>`; approval references follow `approval://<case-id>`.
- **Tenants and actors** are explicit (`tenant-a`, `operations-lead`) so runs are reproducible.
- **Idempotency keys** end with `-v1` and identify the call, not the outcome: `order-123-stockout-v1`.

## Headers

- Ontovela: `X-Tenant-ID`.
- Symbivela: `X-SYMBIVELA-Tenant`, `X-SYMBIVELA-Actor`.
- Mutating calls: `Idempotency-Key`.

## Boundaries

Public examples omit topology, credentials, internal thresholds, and customer data. Document only the input/output shape that illustrates the governed behavior.
