# Changelog

All notable changes to this repository are documented here. Public content is expanded incrementally; product runtimes track their own releases in their own repositories.

Versioning: the current version lives in `VERSION`. Manage it with `scripts/version.ps1` and decide on tags with `scripts/check-release.ps1`.

## 0.8.0 (2026-08-16)

- Added the integration-domain reference adapter (integration state, preservation, reconnection checks, resume, completion) with **preserve-before-resume**, **verify-before-resume**, and **no-silent-re-execution** recovery integrity.
- Added the runnable integration-outage-recovery local demo (`examples/integration-recovery-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all seven adapters (34 assertions) and wired the integration demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, and `validate-demos.ps1`.
- Extended the governance-subtlety guide with the recovery-integrity pattern (preserve, verify, never rerun).
- Cross-linked the integration demo from the integration-outage-recovery slice, example index, getting-started, run handbook, and roadmap.

## 0.7.0 (2026-08-16)

- Added the maintenance-domain reference adapter (signals, validation, decisions, safety reviews, work orders) with **prediction-vs-fact integrity** and a **safety conjunctive gate** for intrusive work.
- Added the runnable predictive-maintenance to work-order local demo (`examples/predictive-maintenance-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all six adapters (28 assertions) and wired the maintenance demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, and `validate-demos.ps1`.
- Extended the governance-subtlety guide with the prediction-vs-fact and safety-conjunctive patterns.
- Cross-linked the maintenance demo from the predictive-maintenance slice, example index, getting-started, run handbook, and roadmap.

## 0.6.0 (2026-08-16)

- Added demo orchestration: `examples/run-all-demos.ps1` runs all four demos end to end (`-Only`/`-Skip`/`-CheckOnly`), with per-demo summary and combined dashboard JSON.
- Added `examples/stop-demo.ps1` and `scripts/kill-adapters.ps1` — path-based, safe process stop for demo runs and CI hygiene.
- Added structural validators `scripts/validate-demos.ps1` (structure + PowerShell syntax) and `scripts/validate-json.ps1` (JSON validity), wired into CI.
- Enhanced `scripts/report-value.ps1` into a value dashboard aggregating all demo value reports, documented in `docs/value-dashboard.md`.
- Hardened `run-demo-smoke.ps1`: deletes stale binaries before build and fails on build errors.
- Updated demo READMEs, run handbook, getting-started, repository map, and roadmap for the orchestration tooling.

## 0.5.0 (2026-08-16)

- Added the recruitment-domain reference adapter (requisitions, candidates, human-only decisions, offers) with an **automation-cannot-decide** structural boundary and stage-gated lifecycle.
- Added the runnable recruitment requisition-to-offer local demo (`examples/recruitment-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all five adapters (23 assertions).
- Added commit-time checks via local git hooks: `.githooks/pre-commit` plus `install-hooks.ps1` and `check-hooks.ps1`, verifying internal links and reporting the version on every commit.
- Extended the governance-subtlety guide with the automation-cannot-decide pattern.
- Cross-linked the recruitment demo from the recruitment slice, example index, getting-started, run handbook, and roadmap.

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
