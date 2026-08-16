# The Subtlety of Governed Autonomy

This page explains, with concrete artifacts from the [order-exception demo](../examples/order-fulfillment-local/README.md), why the ecosystem's design is subtle rather than simply "many services chained together."

## 1. No Product Can Change the Order Without a Case

The order-domain adapter has **no bypass path**. It rejects any action without `approved_by` and `approval_ref`:

```
POST /v1/orders/order-123/fulfillment-actions
{"action":"alternate_location","approved_by":"","approval_ref":"", ...}
-> 400 {"error":"action_approved_by_approval_ref_and_idempotency_key_are_required"}
```

An empty approval is **not** treated as "no approval required". Denial is the default; approval is a hard requirement encoded in the domain, not in a sidecar.

## 2. One Approval Reference, Three Products

The same reference `approval://order-123-stockout` is cited by three independent products:

| Product | Where it appears |
| --- | --- |
| Symbivela | the exception case `order-123-stockout` that gates the order |
| Orchadyn | the delegation's `evidenceDuty: ["approval://order-123-stockout"]` |
| order-domain adapter | the `approval_ref` on the applied action |

Because the reference is shared, the state change is **traceable to the human decision** across product boundaries — no single product owns the whole story.

## 3. A Plan Is a Recommendation, Not an Authorization

Orchadyn produces a verified plan under hard constraints (region, budget) and a delegation chain with an evidence duty. But the goal itself is *"order-123 fulfilled without an unapproved customer promise change"*. So even a correct plan still waits for a human. Planning and authorization are separated by design.

## 4. Deny-by-Default Runtime

Praxovela runs with `network: {allow: false}` and a policy that permits exactly two operations on a single handoff file:

```yaml
rules:
  - capability_id: file.write
    resource: ...\.praxovela\order-123-stockout-handoff.json
    action: allow
  - capability_id: file.read
    resource: ...\.praxovela\order-123-stockout-handoff.json
    action: allow
```

The effect ledger records what was touched **and what was not exposed**. The agent could not have reached anything else, even if asked.

## 5. The Audit Trail Is a Chain, Not a Log

No single artifact contains the story. The chain is:

```
Ontovela assertion (fact)
  + Symbivela case (human authority)
  + Orchadyn plan (verified recommendation)
  + Rheovela instance (durable process)
  + inventory reservation (supporting system under same approval)
  + Praxovela effect ledger (bounded action)
  + order action (state change, approval-cited)
  + notification record (customer impact)
```

Removing any link breaks the reconstruction: the fact has no owner, the change has no approval, or the process has no evidence.

## 6. Idempotency Makes Re-Runs Safe

Every mutating call carries a stable idempotency key. Re-running the demo does not duplicate artifacts; the order adapter returns `"replayed": true`. Governance works on reruns too.

## 7. Segregation of Duties Is Structural (Procurement Demo)

The [procurement demo](../examples/procurement-local/README.md) adds a distinct governance subtlety: the requester cannot approve their own request.

```
POST /v1/requests/preq-0001/approvals
{"role":"finance","approver":"e-1001", ...}
-> 403 {"error":"segregation_of_duties_requester_cannot_approve_own_request"}
```

And both roles must approve before a purchase is possible:

```
finance  approves  -> request stays "submitted"
procurement approves -> request becomes "approved"
unapproved purchase -> 400 / 403, no PO is created
```

Two properties worth noticing:

1. **Segregation is enforced by the domain, not by a procedure.** The adapter refuses the requester-as-approver regardless of role, before any role logic runs.
2. **Approval is conjunctive.** A single role's approval is insufficient; the purchase is only reachable after both finance and procurement approvals under the same reference. The purchase and receipt steps are also capability/state-gated (`request_not_approved`, `no_purchase_order`).

## Why This Matters

The subtlety is that **governance is distributed and structural**: each product enforces a piece of the policy in its own domain, the pieces reference each other through shared approval/evidence references, and none of them can be bypassed by calling another one. That is what "contract-governed" means in practice.
