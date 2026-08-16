# Governance Patterns

This catalog organizes the AxisRobo examples **vertically by governance pattern**, across the nine runnable demos and ten reference adapters. Each pattern is structural: it is enforced by a domain, not by a procedure. The [governance subtlety guide](governance-subtlety.md) is the deep-dive companion with concrete artifacts; this page is the navigation layer.

## Pattern Index

| # | Pattern | Category | Canonical Demo | Adapter Endpoints |
| --- | --- | --- | --- | --- |
| 1 | Deny-by-default, no bypass | Integrity | [order](../examples/order-fulfillment-local/README.md) | order-domain `fulfillment-actions` |
| 2 | Shared approval reference | Integrity | [order](../examples/order-fulfillment-local/README.md) | Symbivela case / Orchadyn delegation / order-domain |
| 3 | Plan is a recommendation, not authorization | Integrity | [order](../examples/order-fulfillment-local/README.md) | Orchadyn `plans:generate` |
| 4 | Deny-by-default runtime (effect ledger) | Integrity | [order](../examples/order-fulfillment-local/README.md) | Praxovela AXON |
| 5 | Audit trail is a chain | Integrity | [order](../examples/order-fulfillment-local/README.md) | all products |
| 6 | Idempotency makes reruns safe | Integrity | [order](../examples/order-fulfillment-local/README.md) | all adapters |
| 7 | Segregation of duties | Authority | [procurement](../examples/procurement-local/README.md) | procurement-domain `approvals` |
| 8 | Conjunctive authority | Authority | [procurement](../examples/procurement-local/README.md) | procurement-domain / customer-domain / maintenance-domain |
| 9 | Consent as a first-class gate | Authority | [customer](../examples/customer-case-local/README.md) | customer-domain `consent` |
| 10 | Automation cannot decide | Authority | [recruitment](../examples/recruitment-local/README.md) | recruitment-domain `decisions` |
| 11 | Prediction is not a fault; safety conjunctive | Evidence | [maintenance](../examples/predictive-maintenance-local/README.md) | maintenance-domain `validate`/`work-orders` |
| 12 | Recovery integrity: preserve, verify, never rerun | Recovery | [integration](../examples/integration-recovery-local/README.md) | integration-domain `resume`/`complete` |
| 13 | Evidence-gated release; immutable simulation | Evidence | [simulation](../examples/simulation-validation-local/README.md) | simulation-domain `runs`/`decisions` |
| 14 | Completeness-gated attestation; immutable audit | Evidence | [compliance](../examples/compliance-audit-local/README.md) | compliance-domain `attestations`/`packages` |
| 15 | Autonomous boundary; pause-and-review | Physical | [fleet](../examples/fleet-mission-local/README.md) | fleet-domain `telemetry`/`reviews` |

## Pattern-to-Example Matrix

| Pattern | order | procurement | customer | recruitment | maintenance | integration | simulation | compliance | fleet |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| 1 Deny-by-default | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 2 Shared approval ref | ● | ● | ● | ● | ● | ● | | ● | ● |
| 3 Plan-not-authorization | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 4 Deny-by-default runtime | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 5 Audit-chain | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 6 Idempotency | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 7 Segregation of duties | | ● | | | | | | | |
| 8 Conjunctive authority | | ● | ● | | ● | | | | |
| 9 Consent gate | | | ● | | | | | | |
| 10 Automation cannot decide | | | | ● | | | | | |
| 11 Prediction-not-fault | | | | | ● | | | | |
| 12 Recovery integrity | | | | | | ● | | | |
| 13 Evidence-gated release | | | | | | | ● | | |
| 14 Completeness attestation | | | | | | | | ● | |
| 15 Boundary + pause-review | | | | | | | | | ● |

● = demonstrated by the runnable demo. Patterns 1–6 are the cross-cutting integrity layer present in every demo; patterns 7–15 are the domain-specific governance flavors.

## How To Read This Catalog

- **By pattern** — pick a governance requirement (for example "requester must not approve their own request") and go to the pattern, which names the canonical demo and the exact denial behavior.
- **By example** — open any demo's README; its **Governance Patterns** section lists the patterns it demonstrates, linking back here.
- **By machine** — `examples/patterns.json` carries the same matrix in a consumable form.

## Integrity Patterns (Cross-Cutting)

These six patterns are structural in **every** demo and adapter. They are what "contract-governed" means in practice.

### 1. Deny-by-Default, No Bypass

The domain adapter rejects any action lacking the required approval evidence. An empty approval is **not** treated as "no approval required"; denial is the default.

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md), [Detailed Operations Guide](../examples/order-fulfillment-local/operations-guide.md).
- Concrete denial: `POST /v1/orders/order-123/fulfillment-actions` with empty `approved_by` → `400 action_approved_by_approval_ref_and_idempotency_key_are_required`.
- Present in: all nine demos, ten adapters.

### 2. Shared Approval Reference

One approval reference is cited by multiple independent products, so a state change is traceable to the human decision across product boundaries.

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md).
- Concrete: `approval://order-123-stockout` appears in the Symbivela case, the Orchadyn delegation's `evidenceDuty`, and the order-domain action.

### 3. Plan Is a Recommendation, Not an Authorization

A verified plan can only recommend what the authority structure permits; a human decision is still required before execution.

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md) (Orchadyn `plans:generate`).
- Concrete: the goal itself forbids an *unapproved* promise change.

### 4. Deny-by-Default Runtime (Effect Ledger)

The agent runtime runs with network disabled and a policy permitting exactly the operations in scope; the effect ledger records what was touched and what was not exposed.

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md) (Praxovela handoff).

### 5. Audit Trail Is a Chain

No single artifact contains the story; each product owns one link, and together the links reconstruct the decision, the approval, and the effect.

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md).

### 6. Idempotency Makes Reruns Safe

Every mutating call carries a stable idempotency key; reruns replay without duplication (`"replayed": true`).

- Canonical demo: [order exception](../examples/order-fulfillment-local/README.md).
- Present in: all adapters.

## Authority Patterns (Who May Decide)

These patterns govern **who** may act, and on what basis.

### 7. Segregation of Duties

The requester cannot approve their own request; the domain refuses the requester-as-approver before any role logic runs.

- Canonical demo: [procurement](../examples/procurement-local/README.md), [operations guide](../examples/procurement-local/operations-guide.md).
- Concrete denial: `403 segregation_of_duties_requester_cannot_approve_own_request`.

### 8. Conjunctive Authority

Multiple independent approvals, consents, or reviews must **all** hold before money or work moves. A single approval is insufficient.

- Canonical demos: [procurement](../examples/procurement-local/README.md) (finance + procurement), [customer](../examples/customer-case-local/README.md) (consent + approval), [maintenance](../examples/predictive-maintenance-local/README.md) (decision + safety).
- Concrete: a repair decision alone is denied without an approved safety review.

### 9. Consent as a First-Class Gate

Customer consent is a governance input distinct from internal approval; money does not move until an approved consent citing the exact reference exists.

- Canonical demo: [customer case](../examples/customer-case-local/README.md), [operations guide](../examples/customer-case-local/operations-guide.md).
- Concrete denial: `403 consent_required`, then `403 approval_required_for_compensation`.

### 10. Automation Cannot Decide

Screening, selection, and offer decisions are human-only; an `actor_type: automated` decision is rejected before stage or candidate checks.

- Canonical demo: [recruitment](../examples/recruitment-local/README.md), [operations guide](../examples/recruitment-local/operations-guide.md).
- Concrete denial: `403 automation_cannot_make_hiring_decisions`.

## Evidence and Recovery Patterns

These patterns govern **what must be true** before an outcome is allowed.

### 11. Prediction Is Not a Fault; Safety Is Conjunctive

An unvalidated signal is never treated as a fault, an unconfirmed prediction cannot stop equipment, and intrusive work requires an approved safety review.

- Canonical demo: [predictive maintenance](../examples/predictive-maintenance-local/README.md), [operations guide](../examples/predictive-maintenance-local/operations-guide.md).
- Concrete denials: `403 signal_not_validated_prediction_is_not_a_fault`, `403 unconfirmed_prediction_cannot_trigger_stop`, `403 safety_review_required_for_intrusive_work`.

### 12. Recovery Integrity: Preserve, Verify, Never Rerun

In-flight work is preserved before resume; resume requires a verified reconnection; a completed action can never be re-executed.

- Canonical demo: [integration recovery](../examples/integration-recovery-local/README.md), [operations guide](../examples/integration-recovery-local/operations-guide.md).
- Concrete denials: `403 work_not_preserved`, `403 integration_not_verified`, `409 action_already_completed_no_silent_rerun`.

### 13. Evidence-Gated Release; Immutable Simulation

A review decision cannot precede recorded simulation evidence; evidence is immutable; release requires an approve decision citing the exact reference.

- Canonical demo: [simulation validation](../examples/simulation-validation-local/README.md), [operations guide](../examples/simulation-validation-local/operations-guide.md).
- Concrete denials: `403 simulation_evidence_required_before_decision`, `409 evidence_already_recorded_immutable`.

### 14. Completeness-Gated Attestation; Immutable Audit

An attestation requires every required evidence item; only the designated attestor may attest; the released audit package is immutable.

- Canonical demo: [compliance audit](../examples/compliance-audit-local/README.md), [operations guide](../examples/compliance-audit-local/operations-guide.md).
- Concrete denials: `403 evidence_incomplete_attestation_requires_all_items`, `403 not_designated_attestor`, `409 package_already_released_immutable`.

### 15. Autonomous Boundary; Pause-and-Review

Boundary enforcement is autonomous (out-of-bound telemetry is frozen with no human), while exceptions always pause for an operator review with an approval reference.

- Canonical demo: [fleet mission](../examples/fleet-mission-local/README.md), [operations guide](../examples/fleet-mission-local/operations-guide.md).
- Concrete denials: `403 boundary_deviation_mission_frozen`, `403 operator_review_required_mission_must_be_paused`.

## Adoption by Pattern

Approach adoption by the governance requirement you need to enforce, then reuse the matching pattern and its demo:

1. **Start with the integrity layer (patterns 1–6).** Every deployment should deny-by-default, cite approvals, treat plans as recommendations, run bounded runtimes, keep an audit chain, and be idempotent.
2. **Add authority patterns (7–10)** where human decision rights matter: segregation for purchasing, conjunctive approval for money, consent for customer commitments, human-only decisions for hiring.
3. **Add evidence/recovery patterns (11–15)** where the truth of an outcome must be provable: validate predictions, preserve and verify recovery, gate releases on evidence, attest completeness, and keep missions bounded with operator review.

See the [value framework](example-value.md) and the [adoption guide](adoption-guide.md) for how to combine patterns with KPIs.
