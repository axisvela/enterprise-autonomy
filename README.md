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
| `docs/demo-matrix.md` | Comparison of all twelve runnable demos. |
| `examples/` | Public, illustrative end-to-end scenarios and local runnable demos. |
| `examples/run-all-demos.ps1` | Run every runnable demo end to end and stop the stack. |
| `examples/stop-demo.ps1` | Stop demo processes reliably (path-based). |
| `reference-stacks/` | Public reference-stack overviews. |
| `vertical-slices/` | End-to-end use cases spanning products. |
| `adapters/` | Local reference adapters used by runnable examples. |
| `docs/` | Supporting documentation for adopters and contributors. |
| `docs/governance-patterns.md` | Pointer to the governance-pattern catalog (moved to the private EE repository). |
| `docs/governance-subtlety.md` | Deep dive into why the governance is structural. |
| `scripts/` | Validation, versioning, and release tooling (see [scripts/README.md](scripts/README.md)). |
| `.github/workflows/ci.yml` | Continuous integration: links, structure, JSON, go tests, smoke, version. |
| `.github/workflows/release.yml` | Automatic tag + GitHub Release when a version is prepared. |
| `.githooks/` | Commit-time checks (install with `scripts/install-hooks.ps1`). |

Placeholder indexes in `architecture/`, `contracts/`, `schemas/`, `profiles/`, `conformance/`, `governance/`, and `benchmarks/` mark domains whose authoritative content lives in the private repository.

## Getting Started

Start with the [getting-started guide](docs/getting-started.md), then explore a [public end-to-end scenario](vertical-slices/mission-to-execution.md). For product binaries, ports, databases, and interfaces, see the [technical catalog](docs/technical-catalog.md). Product-specific pages live under [docs/products/](docs/products.md).

## Runnable Demos

Twelve of the thirteen vertical slices have runnable local demos. Each demo drives real local product binaries plus a reference adapter and produces a machine-readable [value report](docs/value-dashboard.md). See the [demo matrix](docs/demo-matrix.md) for the full comparison.

| Demo | Adapter | Port | Governance flavor | Value report |
| --- | --- | --- | --- | --- |
| [Order fulfillment exception](examples/order-fulfillment-local/README.md) | order-domain | 8090 | Approval-cited deny-by-default | `order-value-report.json` |
| [Procurement request to receipt](examples/procurement-local/README.md) | procurement-domain | 8092 | Segregation of duties + conjunctive approval | `procurement-value-report.json` |
| [Customer case resolution](examples/customer-case-local/README.md) | customer-domain | 8093 | Consent as a first-class gate | `customer-value-report.json` |
| [Recruitment requisition to offer](examples/recruitment-local/README.md) | recruitment-domain | 8094 | Automation cannot decide | `recruitment-value-report.json` |
| [Predictive maintenance](examples/predictive-maintenance-local/README.md) | maintenance-domain | 8095 | Prediction-not-fault + safety conjunctive | `maintenance-value-report.json` |
| [Integration outage recovery](examples/integration-recovery-local/README.md) | integration-domain | 8096 | Preserve / verify / never rerun | `integration-value-report.json` |
| [Simulation to validation](examples/simulation-validation-local/README.md) | simulation-domain | 8097 | Evidence-gated release | `simulation-value-report.json` |
| [Compliance audit](examples/compliance-audit-local/README.md) | compliance-domain | 8098 | Completeness-gated attestation | `compliance-value-report.json` |
| [Fleet mission exception](examples/fleet-mission-local/README.md) | fleet-domain | 8099 | Autonomous boundary + pause-and-review | `fleet-value-report.json` |
| [Process to outcome](examples/process-to-outcome-local/README.md) | process-domain | 8100 | Stage-sequenced durable process | `process-value-report.json` |
| [Innovation sandbox](examples/innovation-sandbox-local/README.md) | sandbox-domain | 8101 | Sandbox boundary + evidence-based policy | `sandbox-value-report.json` |
| [Sequenced deployment](examples/deployment-local/README.md) | deployment-domain | 8102 | Sequenced autonomous execution + approval-required deviations | `deployment-value-report.json` |

## Quickstart

```powershell
# verify structure without a database
.\examples\run-all-demos.ps1 -CheckOnly

# run every demo end to end (requires a full local stack)
.\examples\run-all-demos.ps1

# stop all demo processes safely
.\examples\stop-demo.ps1

# aggregate value reports into the dashboard
.\scripts\report-value.ps1
```

## Public Examples

- [Facility inspection reference stack](reference-stacks/facility-inspection.md)
- [Order operations reference stack](reference-stacks/order-operations.md)
- [Customer service operations reference stack](reference-stacks/customer-service-operations.md)
- [Talent acquisition reference stack](reference-stacks/talent-acquisition.md)
- [Predictive maintenance reference stack](reference-stacks/predictive-maintenance.md)
- [Engineering assurance reference stack](reference-stacks/engineering-assurance.md)
- [Release operations reference stack](reference-stacks/release-operations.md)
- [Inference governance reference stack](reference-stacks/inference-governance.md)
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
- [Sequenced deployment](vertical-slices/sequenced-deployment.md)
- [Inference request to governed answer](vertical-slices/inference-request-to-governed-answer.md)
- [Business scenario catalog](docs/business-scenarios.md)
- [Public example design guide](docs/example-design-guide.md)
- [Glossary](docs/glossary.md)

## Status

**Stable 1.x release series** (current: 1.1.7). Thirteen vertical slices describe end-to-end scenarios; twelve have runnable local demos, backed by thirteen reference adapters with Go unit tests, continuous integration, structural validation, and an automated release workflow that publishes a tag and GitHub Release for every prepared version. Public content is maintained in this repository; governance-pattern knowledge and internal material live in the private `enterprise-autonomy-ee` repository. See the [repository roadmap](ROADMAP.md) and [release status](docs/release-status.md).

## Releases

Releases are tagged `vX.Y.Z` and published to GitHub Releases. The current version lives in `VERSION`; manage it with `.\scripts\version.ps1`, and the [release workflow](.github/workflows/release.yml) creates the tag and release automatically when a version is prepared. See [scripts/README.md](scripts/README.md).
