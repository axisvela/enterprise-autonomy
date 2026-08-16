# AxisRobo Enterprise Autonomy

> Contract-Governed Infrastructure for Agents, Robots, Twins and Simulated Worlds

`enterprise-autonomy` is the public introduction and end-to-end examples repository for the AxisRobo Enterprise Autonomy ecosystem.

## Scope

This repository provides public material for understanding the ecosystem:

- Product introductions and repository links
- Public end-to-end scenarios and reference-stack overviews
- Adoption-oriented examples and supporting documentation

Product repositories retain authority for their own runtimes and domains.

## Publication Boundary

This is the public repository. It contains externally shareable product information, end-to-end examples, and adoption-oriented documentation.

Architecture, contracts, schemas, profiles, conformance, governance, internal planning, unreleased product direction, security-sensitive deployment details, customer or partner information, commercial material, and confidential operating documents belong in the private `enterprise-autonomy-ee` repository. Do not place credentials, secrets, internal endpoints, private incident evidence, or non-public roadmap information in this repository.

## Repository Map

| Path | Purpose |
| --- | --- |
| `docs/products.md` | Public overview of the ecosystem products. |
| `docs/products/` | Per-product public overview pages. |
| `examples/` | Public, illustrative end-to-end scenarios and local runnable demos. |
| `examples/run-all-demos.ps1` | Run every runnable demo end to end and stop the stack. |
| `examples/stop-demo.ps1` | Stop demo processes reliably (path-based). |
| `reference-stacks/` | Public reference-stack overviews. |
| `vertical-slices/` | End-to-end use cases spanning products. |
| `adapters/` | Local reference adapters used by runnable examples. |
| `docs/` | Supporting documentation for adopters and contributors. |
| `docs/governance-patterns.md` | Examples organized vertically by governance pattern. |
| `docs/governance-subtlety.md` | Deep dive into why the governance is structural. |
| `scripts/` | Validation, versioning, and release tooling (see [scripts/README.md](scripts/README.md)). |
| `.githooks/` | Commit-time checks (install with `scripts/install-hooks.ps1`). |

Placeholder indexes in `architecture/`, `contracts/`, `schemas/`, `profiles/`, `conformance/`, `governance/`, and `benchmarks/` mark domains whose authoritative content lives in the private repository.

## Getting Started

Start with the [getting-started guide](docs/getting-started.md), then explore a [public end-to-end scenario](vertical-slices/mission-to-execution.md). For product binaries, ports, databases, and interfaces, see the [technical catalog](docs/technical-catalog.md). Product-specific pages live under [docs/products/](docs/products.md).

## Public Examples

- [Facility inspection reference stack](reference-stacks/facility-inspection.md)
- [Order operations reference stack](reference-stacks/order-operations.md)
- [Customer service operations reference stack](reference-stacks/customer-service-operations.md)
- [Talent acquisition reference stack](reference-stacks/talent-acquisition.md)
- [Predictive maintenance reference stack](reference-stacks/predictive-maintenance.md)
- [Engineering assurance reference stack](reference-stacks/engineering-assurance.md)
- [Mission-to-execution](vertical-slices/mission-to-execution.md)
- [Simulation-to-validation](vertical-slices/simulation-to-validation.md)
- [Process-to-outcome](vertical-slices/process-to-outcome.md)
- [Order fulfillment exception management](vertical-slices/order-fulfillment-exception.md)
- [Procurement request to receipt](vertical-slices/procurement-request-to-receipt.md)
- [Recruitment requisition to offer](vertical-slices/recruitment-requisition-to-offer.md)
- [Fleet mission exception](vertical-slices/fleet-mission-exception.md)
- [Integration outage recovery](vertical-slices/integration-outage-recovery.md)
- [Compliance request to audit](vertical-slices/compliance-request-to-audit.md)
- [Innovation sandbox to policy](vertical-slices/innovation-sandbox-to-policy.md)
- [Business scenario catalog](docs/business-scenarios.md)
- [Public example design guide](docs/example-design-guide.md)
- [Glossary](docs/glossary.md)

## Status

Public product introductions and end-to-end examples are being expanded incrementally. See the [repository roadmap](ROADMAP.md) for the public content plan and [release status](docs/release-status.md) for the ecosystem release overview.
