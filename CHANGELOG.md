# Changelog

All notable changes to this repository are documented here. Public content is expanded incrementally; product runtimes track their own releases in their own repositories.

Versioning: the current version lives in `VERSION`. Manage it with `scripts/version.ps1` and decide on tags with `scripts/check-release.ps1`.

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
