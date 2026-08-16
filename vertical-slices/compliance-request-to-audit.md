# Compliance Request to Audit

## Business Scenario

A governed operation must demonstrate compliance with a defined requirement. The organization assembles evidence, obtains the required reviews, and produces an auditable record ready for inspection.

| Item | Definition |
| --- | --- |
| Trigger | A compliance request or scheduled audit requirement. |
| Accountable owner | Compliance lead. |
| Completion | Required evidence is assembled, reviewed, and packaged into an auditable record. |
| Evidence | Requirement reference, collected evidence, review decisions, and the final audit package. |

## Product Roles

| Need | Example Product Role |
| --- | --- |
| Compliance review and approval | Symbivela |
| Evidence and claims management | Gnosivela |
| Operational state and change history | Ontovela |
| Evidence-collection planning | Orchadyn |
| Identity, authorization, and attestation | Aegivela |
| System and evidence connectivity | Limenora |
| Durable compliance process | Rheovela |

## Design Steps

1. Define the compliance requirements and the accountable compliance lead.
2. Define which evidence each requirement needs and who may attest to it.
3. Require that evidence is collected from governed sources with timestamps.
4. Identify the human decision points: evidence review, attestation, and package approval.
5. Pilot with one requirement class before expanding.

## Operating Steps

1. Open a compliance case with the requirement reference and accountable lead.
2. Collect evidence from governed sources for each requirement item.
3. Review the evidence against each requirement; flag gaps or conflicts for resolution.
4. Obtain the required attestations and approvals.
5. Assemble the audit package with the requirement reference and evidence.
6. Record the package for inspection and keep change history for follow-up.

## Exceptions

- Missing evidence: escalate the gap; do not mark the requirement complete.
- Conflicting claims: resolve through review before packaging.
- Attestation authority unavailable: hold packaging until the authority is available or an approved deputy records the decision.

## Detailed Operating Procedure

| Step | Input | Products | Output artifact |
| --- | --- | --- | --- |
| Open case | requirement reference, accountable lead | Symbivela | case `compliance-0001` (`open`) |
| Collect evidence | governed source artifacts with timestamps | Ontovela, Gnosivela | evidence set `evidence-compliance-0001` |
| Review | evidence against each requirement item | Symbivela | review record `review-compliance-0001` |
| Attest | required attestations | Aegivela | attestations `attestation-0001` |
| Package | requirement reference + evidence + decisions | Gnosivela, Rheovela | audit package `audit-compliance-0001` |
| Record | package for inspection, change history | Ontovela | inspection-ready record |

## Runnable Local Demo

For verified local-binary startup commands, configuration, API requests, request bodies, and expected operational outputs, see the [local compliance-audit demo](../examples/compliance-audit-local/README.md) and its [Detailed Operations Guide](../examples/compliance-audit-local/operations-guide.md).

## Public Boundary

This example omits specific regulations, endpoints, templates, and attestation policy.
