# Public Repository Roadmap

This roadmap tracks the public content plan for the `enterprise-autonomy` repository. It describes what will be published, documented, and maintained here. Product-direction, internal planning, and unreleased product information remain in the private `enterprise-autonomy-ee` repository.

## Phase 1 — Foundation (complete)

- [x] Initialize public repository
- [x] Publish product overview
- [x] Publish technical catalog with planned port allocation
- [x] Publish business scenarios and example design guide
- [x] Publish initial vertical slices and reference stacks

## Phase 2 — Navigation and guidance (complete)

- [x] Per-product overview pages
- [x] Getting-started and adoption guides
- [x] Glossary and ecosystem links
- [x] Port migration guidance

## Phase 3 — Reference stacks (complete)

- [x] Order operations
- [x] Customer service operations
- [x] Talent acquisition
- [x] Predictive maintenance
- [x] Engineering assurance

## Phase 4 — Vertical slices (complete)

- [x] Fleet mission exception
- [x] Integration outage recovery
- [x] Compliance request to audit
- [x] Innovation sandbox to policy

## Phase 5 — Runnable examples (complete)

- [x] Local run handbook
- [x] Example index
- [x] Additional domain reference adapters
- [x] Value & Effect reporting for runnable examples
- [x] Demo validation and smoke-test tooling
- [x] Detailed operations guide with exact request/response per step
- [x] Additional runnable local demos (procurement request-to-receipt)

## Phase 6 — Consistency and release tracking (in progress)

- [x] Release-status documentation
- [x] Example value framework and metrics
- [x] Cross-link and consistency pass
- [x] Continuous verification of public examples
- [x] Per-example value reports for all designed examples
- [x] Detailed operating procedures (input/products/output) for all slices and stacks
- [x] Adapter API references and error semantics
- [x] Version management harness and commit-time release check
- [x] Second runnable local demo (procurement) cross-linked from slices and indexes
- [x] Third runnable local demo (customer case) with consent governance
- [x] Fourth runnable local demo (recruitment) with human-only decisions
- [x] Fifth runnable local demo (predictive maintenance) with prediction-vs-fact and safety gates
- [x] Sixth runnable local demo (integration recovery) with preserve/verify/no-rerun integrity
- [x] Seventh runnable local demo (simulation validation) with evidence-gated release
- [x] Eighth runnable local demo (compliance audit) with completeness-gated attestation
- [x] Ninth runnable local demo (fleet mission) with autonomous boundary and pause-and-review
- [x] Unit tests (go test) for every reference adapter, wired into CI
- [x] Continuous integration running link, smoke, and version checks on push
- [x] Commit-time checks via local git hooks (links + version) and CI
- [x] Demo orchestration: run all demos with one command, reliable stop, and a value dashboard
- [x] Structural validation (demo structure, script syntax, JSON validity) in CI

## Guiding Principles

- Product repositories remain authoritative for their own runtimes and domains.
- Public content is adoption-oriented and non-deployment-specific.
- Sensitive material belongs in `enterprise-autonomy-ee`, never here.
