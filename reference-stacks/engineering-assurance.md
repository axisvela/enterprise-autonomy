# Engineering Assurance Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed engineering-assurance outcome for autonomous systems. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Assurance review and release decision | Symbivela |
| Capability and system state | Ontovela |
| Verification contracts and release gating | Tekmovela |
| Simulation and experimentation | Peiravela |
| Planning under verification constraints | Orchadyn |
| Identity, authorization, and attestation | Aegivela |
| Integration of test and CI systems | Limenora |
| Durable release process | Rheovela |

## Design Steps

1. Define the verification contracts that must pass before a release is considered.
2. Define the review authority and the evidence required for a release decision.
3. Select the product roles needed for testing, simulation, planning, authorization, and process.
4. Identify the human decision points: test design review, exception waiver, and release approval.
5. Start with a small, bounded system and expand as assurance evidence accumulates.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and confirm access.
2. Define or update the verification contracts for the change under consideration.
3. Run the closed-loop tests and any required simulation in a controlled environment.
4. Review failures and diagnostics; waivers require explicit human approval with evidence.
5. Gate the release only when all required contracts pass and the review authority approves.
6. Record attestations and re-verify after any change that invalidates prior evidence.

## Value & Effect

| Field | Detail |
| --- | --- |
| Outcome value | Releases are gated on verified contracts and explicit human approval, so autonomous systems ship with reproducible assurance. |
| KPIs | Contract pass rate, waiver discipline, re-verification coverage, attestation completeness. |
| Decision gates | Test design review, exception waiver, release approval. |
| Evidence produced | Verification contracts, test and simulation results, diagnostics, waivers, attestations. |
| Adoption path | Start with a small, bounded system and expand as assurance evidence accumulates. |

See the [value framework](../docs/example-value.md).

## Scope Boundary

Actual deployment topology, integrations, verification thresholds, and policy are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
