# Changelog

All notable changes to this repository are documented here. Public content is expanded incrementally; product runtimes track their own releases in their own repositories.

Versioning: the current version lives in `VERSION`. Manage it with `scripts/version.ps1` and decide on tags with `scripts/check-release.ps1`. `1.0.0` is the first stable release of the public introduction and examples repository.

## 1.0.1 (2026-08-16)

- Backfilled GitHub Releases for every pre-0.14.0 version (v0.1.0 through v0.13.0), so each of the 19 tags now has a matching release with its CHANGELOG body. Kept v1.0.0 as the Latest release.
- Hardened `scripts/create-release.ps1`: idempotent (skips existing releases) and added `-NotLatest` for historical backfills so the newest version stays "Latest".
- Delegated `.github/workflows/release.yml` to the shared release scripts (`create-tag.ps1` + `create-release.ps1`) so local and CI behavior stay identical.
- Fixed the automated release path: the runner had no git committer identity and `gh` lacked `GH_TOKEN`; the workflow now sets `github-actions[bot]` identity and passes `github.token` to `gh`. These failures were latent because every earlier release ran the workflow while `check-release` reported nothing to release.
- Added a Phase 7 (post-1.0 additive work) backlog to the roadmap and updated the status note.

## 1.0.0 (2026-08-16)

First stable release of the public repository. All eleven vertical slices have runnable local demos backed by twelve reference adapters, with unit tests, continuous integration, structural validation, value reporting, and an automated release workflow.

- **11 runnable demos** covering every vertical slice, each with a detailed operations guide and a machine-readable value report.
- **12 reference adapters**, each with Go unit tests covering its governance gates.
- **Tooling**: version harness, commit-time hooks, CI (links, structure, JSON, go tests, smoke, version), release automation, demo orchestration, value dashboard, structural validators.
- **Governance knowledge** (pattern catalog) maintained in the private `enterprise-autonomy-ee` repository.

## 0.17.0 (2026-08-16)

- Consolidated the public repository: rewrote the top-level README as the project front door with a demo matrix and quickstart.
- Added `docs/demo-matrix.md` comparing all eleven runnable demos (adapter, port, governance flavor, value report, operations guide).
- Updated navigation (getting-started, adoption guide, examples index, value dashboard, ecosystem links) for the completed demo set.
- Status: all eleven vertical slices now have runnable demos, backed by twelve reference adapters with unit tests, CI, and automated releases.

## 0.16.0 (2026-08-16)

- Added the sandbox-domain reference adapter (innovation proposals, bounded experiments, evidence-based policy decisions, immutable apply) with **sandbox boundary**, **evidence-based policy**, **designated reviewer**, and **immutable policy** governance.
- Added the runnable innovation-sandbox-to-policy local demo (`examples/innovation-sandbox-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all twelve adapters (70 assertions) and wired the sandbox demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, `validate-demos.ps1`, and `run-go-tests.ps1`.
- Cross-linked the sandbox demo from the innovation-sandbox-to-policy slice, example index, getting-started, run handbook, and roadmap. **All eleven vertical slices now have runnable demos.**

## 0.15.0 (2026-08-16)

- Added the process-domain reference adapter (durable process, stage-sequenced advances, terminal-state enforcement, immutable completion) with **durable process lifecycle integrity** governance.
- Added the runnable process-to-outcome local demo (`examples/process-to-outcome-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all eleven adapters (62 assertions) and wired the process demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, `validate-demos.ps1`, and `run-go-tests.ps1`.
- Cross-linked the process demo from the process-to-outcome slice, example index, getting-started, run handbook, and roadmap. Ten of the eleven vertical slices now have runnable demos.

## 0.14.0 (2026-08-16)

- Added release automation completing the versioning harness: `scripts/read-changelog-section.ps1` (extracts a version's changelog block), `scripts/create-tag.ps1` (annotated tag from `VERSION`, idempotent), and `scripts/create-release.ps1` (`gh release create` with changelog body).
- Added `.github/workflows/release.yml`, which creates the tag and a GitHub Release automatically on every push to `main` when `check-release.ps1` reports the version is prepared, and skips idempotently when the tag exists.
- Moved the governance-pattern catalog and its machine-readable matrix (`governance-patterns.md`, `patterns.json`) to the private `enterprise-autonomy-ee` repository; the public files now carry pointers and references were updated.
- Restored em-dashes corrupted by earlier bulk text edits across product pages and example/API docs.
- Updated contributing, getting-started, scripts README, repository map, and roadmap for the automated release flow.

## 0.13.0 (2026-08-16)

- Added the governance patterns catalog (`docs/governance-patterns.md`) organizing the nine runnable demos **vertically by governance pattern** (15 patterns across integrity, authority, evidence, recovery, and physical categories), with a pattern-to-example matrix.
- Added **Governance Patterns** sections to every demo README and pattern cross-references to every adapter API reference.
- Added `examples/patterns.json`, a machine-readable pattern-to-example matrix.
- Updated navigation (getting-started, repository map, ecosystem links, value framework, adoption guide) and added a table of contents to the governance-subtlety deep dive.
- Updated the repository About (GitHub) with a project description and topics.

## 0.12.0 (2026-08-16)

- Added Go unit tests (`main_test.go`) for all ten reference adapters, covering each governance gate, denial path, and idempotency behavior.
- Refactored every adapter to expose `newMux` for direct handler testing.
- Added `scripts/run-go-tests.ps1` to run `go vet` and `go test` across all adapter modules, wired into CI.
- Updated the repository About (GitHub) with a project description and topics.

## 0.11.0 (2026-08-16)

- Added the fleet-domain reference adapter (missions, boundary enforcement, exceptions, operator reviews) with **autonomous boundary enforcement** and **pause-and-review** governance.
- Added the runnable fleet-mission-exception local demo (`examples/fleet-mission-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all ten adapters (55 assertions) and wired the fleet demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, and `validate-demos.ps1`.
- Extended the governance-subtlety guide with the autonomous-boundary and pause-and-review pattern.
- Cross-linked the fleet demo from the fleet-mission-exception slice, example index, getting-started, run handbook, and roadmap.

## 0.10.0 (2026-08-16)

- Added the compliance-domain reference adapter (compliance cases, evidence collection, attestation, audit packages) with **completeness-gated attestation**, **designated-attestor**, and **immutable package** governance.
- Added the runnable compliance-request-to-audit local demo (`examples/compliance-audit-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all nine adapters (48 assertions) and wired the compliance demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, and `validate-demos.ps1`.
- Extended the governance-subtlety guide with the completeness-gated attestation and immutable-package pattern.
- Cross-linked the compliance demo from the compliance-request-to-audit slice, example index, getting-started, run handbook, and roadmap.

## 0.9.0 (2026-08-16)

- Added the simulation-domain reference adapter (proposals, scenarios, immutable simulation runs, review decisions, release) with **evidence-before-decision**, **immutable evidence**, and **approval-gated release**.
- Added the runnable simulation-to-validation local demo (`examples/simulation-validation-local/`) with an 8-step lifecycle, `verify.ps1`, `run-all.ps1`, value report, and a detailed operations guide.
- Extended `run-demo-smoke.ps1` to all eight adapters (41 assertions) and wired the simulation demo into `run-all-demos.ps1`, `report-value.ps1`, `check-examples.ps1`, and `validate-demos.ps1`.
- Extended the governance-subtlety guide with the evidence-gated release and immutable-evidence pattern.
- Cross-linked the simulation demo from the simulation-to-validation slice, example index, getting-started, run handbook, and roadmap.

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
