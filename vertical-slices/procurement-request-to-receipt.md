# Procurement Request To Receipt

## Business Scenario

An employee requests a business item or service. Procurement validates the request, obtains approvals, selects an eligible supplier, issues the purchase action, tracks receipt, and reconciles exceptions without bypassing procurement authority.

| Item | Definition |
| --- | --- |
| Trigger | Employee or business system submits a purchase request. |
| Accountable owner | Procurement owner for the request category. |
| Completion | Request is received, rejected, cancelled, or escalated with a recorded reason. |
| Evidence | Justification, budget context, approvals, supplier decision, purchase reference, receipt, and exceptions. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Requester workspace | Symbivela |
| ERP, supplier, and receiving-system connectivity | Limenora |
| Supplier and item context | Gnosivela and Ontovela |
| Sourcing alternatives | Orchadyn |
| Purchasing capabilities | Moduregis |
| Authority and approvals | Aegivela |
| Durable request-to-receipt process | Rheovela |

## Design Steps

1. Define categories, required justification, supplier restrictions, spend bands, and authorized approvers.
2. Identify the authoritative budget, supplier, purchase-order, receipt, and invoice systems.
3. Define permitted routes: catalog, preferred supplier, competitive sourcing, emergency exception, rejection, and cancellation.
4. Enforce segregation of duties: requesters cannot approve their own request or independently select a supplier where review is required.
5. Define closure evidence for goods and services.

## Operating Steps

1. **Submit.** The requester supplies need, description, quantity, delivery need, cost center, and justification.
2. **Validate.** Procurement checks completeness, duplicates, cost-center validity, and restricted categories; incomplete requests return with the missing information.
3. **Route.** The procurement owner confirms the category, approval chain, and sourcing path.
4. **Select.** Reviewers compare eligible options and record why the selected option meets the need.
5. **Approve.** Budget, procurement, security, or legal reviewers decide only within their assigned responsibility; every decision includes a responsible person and rationale.
6. **Purchase.** After approval, issue the purchase action and record the purchase reference and supplier acknowledgement.
7. **Receive and close.** The receiving owner confirms delivery or service acceptance. Discrepancies remain open for review; the owner closes only when purchase and receipt evidence agree.

## Exceptions

- Emergency: route to emergency authority and record why the normal path was unavailable.
- Ineligible supplier: do not purchase; request an approved alternative or supplier review.
- Overdue approval: notify and escalate through the procurement process.
- Receipt mismatch: keep open and record the discrepancy.

## Public Boundary

This example omits supplier data, thresholds, approval matrices, ERP configuration, and integration details.
