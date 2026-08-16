# The Subtlety of Governed Autonomy

This page explains, with concrete artifacts from the [order-exception demo](../examples/order-fulfillment-local/README.md), why the ecosystem's design is subtle rather than simply "many services chained together." For a navigation-level view of the governance patterns, see the private **`enterprise-autonomy-ee`** repository's governance-pattern catalog.

## Contents

1. [No Product Can Change the Order Without a Case](#1-no-product-can-change-the-order-without-a-case)
2. [One Approval Reference, Three Products](#2-one-approval-reference-three-products)
3. [A Plan Is a Recommendation, Not an Authorization](#3-a-plan-is-a-recommendation-not-an-authorization)
4. [Deny-by-Default Runtime](#4-deny-by-default-runtime)
5. [The Audit Trail Is a Chain, Not a Log](#5-the-audit-trail-is-a-chain-not-a-log)
6. [Idempotency Makes Re-Runs Safe](#6-idempotency-makes-re-runs-safe)
7. [Segregation of Duties Is Structural (Procurement Demo)](#7-segregation-of-duties-is-structural-procurement-demo)
8. [Consent Is a First-Class Gate (Customer-Case Demo)](#8-consent-is-a-first-class-gate-customer-case-demo)
9. [Automation Cannot Decide (Recruitment Demo)](#9-automation-cannot-decide-recruitment-demo)
10. [A Prediction Is Not a Fault, and Safety Is Conjunctive (Maintenance Demo)](#10-a-prediction-is-not-a-fault-and-safety-is-conjunctive-maintenance-demo)
11. [Recovery Integrity: Preserve, Verify, Never Rerun (Integration Demo)](#11-recovery-integrity-preserve-verify-never-rerun-integration-demo)
12. [Evidence-Gated Release and Immutable Simulation (Simulation Demo)](#12-evidence-gated-release-and-immutable-simulation-simulation-demo)
13. [Completeness-Gated Attestation and Immutable Audit (Compliance Demo)](#13-completeness-gated-attestation-and-immutable-audit-compliance-demo)
14. [Autonomous Boundary and Pause-and-Review (Fleet Demo)](#14-autonomous-boundary-and-pause-and-review-fleet-demo)
15. [Durable Process Lifecycle Integrity (Process-To-Outcome Demo)](#15-durable-process-lifecycle-integrity-process-to-outcome-demo)
16. [Sandbox Boundary, Evidence-Based Policy, and Immutable Policy (Innovation Sandbox Demo)](#16-sandbox-boundary-evidence-based-policy-and-immutable-policy-innovation-sandbox-demo)

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

## 8. Consent Is a First-Class Gate (Customer-Case Demo)

The [customer-case demo](../examples/customer-case-local/README.md) introduces **customer consent** as a governance input distinct from internal approval:

```
POST /v1/cases/cs-0001/resolutions
{"type":"compensation","amount":40,"approved_by":"service-lead",
 "approval_ref":"approval://cs-0001","consent_ref":"consent://cs-0001", ...}
-> 403 {"error":"consent_required"}          (before consent is recorded)
-> 403 {"error":"approval_required_for_compensation"}  (consent yes, approval missing)
```

Three properties worth noticing:

1. **Consent and approval are separate, conjunctive records.** Money does not move until an approved consent (matching reference) AND a service-lead approval both exist.
2. **Consent is attributable.** The record carries the customer reference and a `consent_ref` that the resolution must cite exactly (`consent_ref_mismatch` otherwise).
3. **Facts gate the case.** Only verified facts can be recorded, so a remedy cannot be grounded in unverified claims.

## 9. Automation Cannot Decide (Recruitment Demo)

The [recruitment demo](../examples/recruitment-local/README.md) enforces **human-decision integrity**: screening, selection, and offer decisions are human-only.

```
POST /v1/requisitions/req-0001/decisions
{"stage":"shortlist","decision":"advance","candidate":"cand-a","decided_by":"recruiter-assistant",
 "actor_type":"automated","rationale":"keyword match", ...}
-> 403 {"error":"automation_cannot_make_hiring_decisions"}
```

Three properties worth noticing:

1. **The boundary is structural and first.** The `actor_type: automated` check runs before stage or candidate checks — automation cannot route around it.
2. **Every decision is attributed.** A human `decided_by`, a `rationale`, and a `decision_ref` are all required; there is no unattributed screening.
3. **The lifecycle is stage-gated.** `shortlist → selection → offer` must proceed in order, and an offer requires a matching offer-stage human decision for the same candidate.

## 10. A Prediction Is Not a Fault, and Safety Is Conjunctive (Maintenance Demo)

The [predictive-maintenance demo](../examples/predictive-maintenance-local/README.md) adds two coupled governance properties:

```
POST /v1/signals/signal-pm-0001/work-orders       (signal still pending)
-> 403 {"error":"signal_not_validated_prediction_is_not_a_fault"}

POST /v1/signals/signal-pm-0001/decisions         (decision = stop, unconfirmed)
-> 403 {"error":"unconfirmed_prediction_cannot_trigger_stop"}

POST /v1/signals/signal-pm-0001/work-orders       (repair decided, no safety review)
-> 403 {"error":"safety_review_required_for_intrusive_work"}
```

Three properties worth noticing:

1. **Prediction-vs-fact is structural.** A work order cannot exist on an unvalidated signal, and an unconfirmed prediction cannot escalate to a `stop` — a prediction is never treated as a confirmed fault.
2. **Safety is conjunctive.** Intrusive work (`repair`/`stop`) requires both a maintenance decision and an approved safety review by the safety authority; either missing factor denies the work order.
3. **Decisions scope the work.** `monitor`, `inspect`, and `defer` never produce a work order; only `repair`/`stop` do, and only after all gates pass.

## 11. Recovery Integrity: Preserve, Verify, Never Rerun (Integration Demo)

The [integration-outage-recovery demo](../examples/integration-recovery-local/README.md) shows recovery as a governed sequence rather than a "resume button":

```
POST /v1/work/work-0001/resume      (work still inflight)
-> 403 {"error":"work_not_preserved"}

POST /v1/work/work-0001/resume      (work preserved, integration still down)
-> 403 {"error":"integration_not_verified"}

POST /v1/work/work-0001/complete    (already completed, different key)
-> 409 {"error":"action_already_completed_no_silent_rerun"}
```

Three properties worth noticing:

1. **Preserve-before-resume.** In-flight work must be preserved under a durable reference before any resume is possible.
2. **Verify-before-resume.** Resume requires an integration-owner reconnection check that verified the integration — preservation alone is insufficient.
3. **No silent re-execution.** A completed action is final; a new completion is rejected (`409`), and only the same idempotency key replays. Recovery is durable, never duplicated.

## 12. Evidence-Gated Release and Immutable Simulation (Simulation Demo)

The [simulation-to-validation demo](../examples/simulation-validation-local/README.md) shows that going live is a governed decision grounded in evidence:

```
POST /v1/proposals/proposal-sim-0001/decisions     (no simulation run yet)
-> 403 {"error":"simulation_evidence_required_before_decision"}

POST /v1/proposals/proposal-sim-0001/runs          (evidence already recorded)
-> 409 {"error":"evidence_already_recorded_immutable"}

POST /v1/proposals/proposal-sim-0001/release       (wrong decision reference)
-> 403 {"error":"decision_ref_mismatch"}
```

Four properties worth noticing:

1. **Evidence-before-decision.** A review decision cannot exist before recorded simulation evidence — the review cannot precede the run.
2. **Immutable evidence.** Simulation runs are recorded once and cannot be replaced (`409`); the evidence set is final.
3. **Review-group authority.** Only designated reviewers may decide (`403 not_review_group_member`).
4. **Approval-gated release.** Release requires an `approve` decision citing the exact reference; a wrong reference is rejected.

## 13. Completeness-Gated Attestation and Immutable Audit (Compliance Demo)

The [compliance-audit demo](../examples/compliance-audit-local/README.md) shows that an audit record is a governed, complete artifact:

```
POST /v1/compliance/compliance-0001/attestations   (only 3 of 4 evidence items)
-> 403 {"error":"evidence_incomplete_attestation_requires_all_items"}

POST /v1/compliance/compliance-0001/attestations   (outsider)
-> 403 {"error":"not_designated_attestor"}

POST /v1/compliance/compliance-0001/packages       (released already)
-> 409 {"error":"package_already_released_immutable"}
```

Four properties worth noticing:

1. **Completeness gates attestation.** No attestation until every required evidence item is collected — partial evidence cannot be attested.
2. **Designated attestor.** Only the designated attestor may attest; attestation is conjunctive with completeness.
3. **Attestation-gated package.** The audit package releases only after an `attest` decision citing the exact reference.
4. **Immutable package.** A released audit package is final (`409`); the audit record cannot be replaced.

## 14. Autonomous Boundary and Pause-and-Review (Fleet Demo)

The [fleet-mission demo](../examples/fleet-mission-local/README.md) shows the two sides of physical autonomy — automated boundary enforcement and human exception review:

```
POST /v1/missions/mission-alpha-001/telemetry   (position = zone-omega)
-> 403 {"error":"boundary_deviation_mission_frozen"}        (autonomous, no human)

POST /v1/missions/mission-alpha-001/reviews     (mission not paused)
-> 403 {"error":"operator_review_required_mission_must_be_paused"}

POST /v1/missions/mission-alpha-001/reviews     (outsider)
-> 403 {"error":"not_mission_operator"}
```

Three properties worth noticing:

1. **Boundary enforcement is autonomous.** Out-of-bound telemetry is frozen with no human involvement — the boundary is hard-coded, not procedural.
2. **Pause-and-review is mandatory.** An exception always pauses; resume/adjust/cancel require an operator review carrying an `approval_ref`.
3. **Operator-gated.** Only the mission operator may start or review — physical actions are never unsupervised.

## 15. Durable Process Lifecycle Integrity (Process-To-Outcome Demo)

The [process-to-outcome demo](../examples/process-to-outcome-local/README.md) shows that a long-running process is a governed sequence, not a mutable to-do list:

```
POST /v1/processes/proc-0001/advance     (out-of-order: request -> approve)
-> 409 {"error":"stage_mismatch_next_is_review"}

POST /v1/processes/proc-0001/complete    (before the terminal stage)
-> 403 {"error":"outcome_not_reached_terminal_stage_required"}

POST /v1/processes/proc-0001/complete    (no advances recorded)
-> 403 {"error":"no_stage_advances_recorded"}
```

Three properties worth noticing:

1. **Stage-sequenced gating is structural.** An advance must name the exact current stage and the exact next stage; any jump is rejected with `409` — the stage order is encoded in the domain, not a procedure.
2. **Terminal-state enforcement.** The outcome completes only at the terminal stage (`complete`), and only after at least one recorded advance — a process cannot reach its outcome out of order.
3. **Completed-process immutability.** A completed process is final; any advance or completion after that is rejected (`409`), and only the same idempotency key replays. The outcome is durable, never reopened.

## 16. Sandbox Boundary, Evidence-Based Policy, and Immutable Policy (Innovation Sandbox Demo)

The [innovation-sandbox demo](../examples/innovation-sandbox-local/README.md) shows how a proposed capability earns policy through bounded, evidence-grounded exploration:

```
POST /v1/proposals/proposal-sandbox-0001/experiments   (outside sandbox scope)
-> 403 {"error":"sandbox_boundary_experiment_outside_scope"}

POST /v1/proposals/proposal-sandbox-0001/decisions     (no experiment evidence yet)
-> 403 {"error":"experiment_evidence_required_before_policy"}

POST /v1/proposals/proposal-sandbox-0001/decisions     (outsider)
-> 403 {"error":"not_designated_reviewer"}

POST /v1/proposals/proposal-sandbox-0001/apply         (wrong policy reference)
-> 403 {"error":"policy_ref_mismatch"}
```

Four properties worth noticing:

1. **Sandbox boundary is structural.** An experiment must stay within the proposal's declared `sandbox_scope`; anything outside is rejected before any other logic runs — exploration is bounded, not open-ended.
2. **Evidence-based policy.** A policy decision cannot exist before recorded experiment evidence — the review cannot precede the experiment.
3. **Designated reviewer.** Only review-group members may decide (`403 not_designated_reviewer`).
4. **Immutable policy.** A recorded policy decision is final (`409 policy_already_recorded_immutable`), and `apply` requires the exact `policy_ref`; a rejected proposal can never be applied. Policy is earned once, from evidence, and then fixed.

## Why This Matters

The subtlety is that **governance is distributed and structural**: each product enforces a piece of the policy in its own domain, the pieces reference each other through shared approval/evidence references, and none of them can be bypassed by calling another one. That is what "contract-governed" means in practice.
