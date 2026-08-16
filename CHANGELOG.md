# Changelog

All notable changes to this repository are documented here. Public content is expanded incrementally; product runtimes track their own releases in their own repositories.

Versioning: the current version lives in `VERSION`. Manage it with `scripts/version.ps1` and decide on tags with `scripts/check-release.ps1`.

## 0.4.0 (2026-08-16)

- Added the customer-domain reference adapter (cases, verified facts, consent, resolutions, accounts, notifications) with consent-required and approval-required conjunctive governance.
- Added the runnable customer-case-resolution local demo (`examples/customer-case-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all four adapters (18 assertions) and hardened process cleanup for consecutive CI runs.
- Added continuous integration (`.github/workflows/ci.yml`) running link, smoke, version, and release checks on every push and pull request.
- Extended the governance-subtlety guide with the consent-as-first-class-gate pattern.
- Cross-linked the customer-case demo from the customer slice, example index, getting-started, run handbook, and roadmap.

## 0.3.0 (2026-08-16)

- Added the procurement-domain reference adapter (requests, budget, suppliers, purchase orders, receipts) with structural segregation of duties and conjunctive role approvals.
- Added the runnable procurement request-to-receipt local demo (`examples/procurement-local/`) with an 8-step governed lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to cover all three adapters (order, inventory, procurement) and fixed the build-lock issue by giving each adapter its own smoke binary.
- Extended the governance-subtlety guide with the segregation-of-duties and conjunctive-approval patterns.
- Cross-linked the procurement demo from the procurement slice, example index, getting-started, run handbook, and roadmap.

## 0.2.1 (2026-08-16)

- Added the detailed operations guide sections: output artifacts, seed data, idempotency table, verification, and troubleshooting.
- Added adapter API references with endpoints, action semantics and state transitions, and error responses (`adapters/order-domain/API.md`, `adapters/inventory-domain/API.md`).
- Added detailed operating procedures with per-step inputs/products/outputs to all 11 vertical slices and 6 reference stacks.
- Added the mission-to-execution worked walkthrough and shared input/output conventions.
- Added the governance-subtlety guide explaining the structural, distributed governance design with concrete artifacts.
- Enriched the value report template with a worked example and the example design guide with detailed I/O requirements.

## 0.2.0 (2026-08-16)

- Added the example value framework (`docs/example-value.md`), value report template, and value metrics catalog.
- Added **Value & Effect** sections to every vertical slice and reference stack.
- Upgraded the local order-exception demo: inventory-domain adapter wired in, inventory reservation step, governance-denial demonstration, evidence collection, and a machine-readable value report (`order-value-report.json`).
- Added demo validation tooling: `verify.ps1`, `run-all.ps1`, and repository scripts (`check-links.ps1`, `check-examples.ps1`, `report-value.ps1`, `run-demo-smoke.ps1`).
- Added the detailed operations guide (`examples/order-fulfillment-local/operations-guide.md`) with exact requests and responses for every demo step.
- Added the versioning harness: `VERSION`, `scripts/version.ps1`, and `scripts/check-release.ps1`.

## 0.1.0 (2026-08-15)

- Initialized public ecosystem repository.
- Added product overview (`docs/products.md`).
- Added business scenarios (`docs/business-scenarios.md`).
- Added public example design guide (`docs/example-design-guide.md`).
- Added initial public autonomy scenarios and vertical slices.
- Added facility-inspection reference stack.
- Added local order-exception demo, technical catalog, order-domain reference adapter, and planned port allocation from `1806`.
