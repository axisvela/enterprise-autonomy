# Product Maturity and 3.0 Integration Assessment

**Date:** 2026-10-17

**Scope:** Core and enterprise repositories in the AxisVela ecosystem. This assessment is a planning snapshot, not a certification. Product repositories remain authoritative for their own versions, contracts, and release gates.

## Summary

PRAXOVELA 3.0 is a platform release. It does not require every product to publish a matching `3.0.0` tag.

The ecosystem currently has three different kinds of version state:

1. **Platform version:** PRAXOVELA, PRAXOVELA-open, and PRAXOVELA-EE are on `3.0.0`.
2. **Product version:** each product keeps its own version line (for example Aegivela `1.2.x`, LIMENORA `2.5.x`, ORCHADYN `1.59.x`).
3. **Go module API version:** all AxisVela Go modules use the `/v3` module path. This is an import-path major, not a claim that the product itself is at product version 3.0.

**Recommendation:** do not mass-tag every product as `3.0.0`. Align mature products through a Wave 1 integration gate. Improve early products against their own roadmaps before integrating them.

## Method and Evidence

The assessment uses repository evidence available on 2026-10-17:

- latest semantic tag and its date;
- commit count on the default branch;
- number of Go modules;
- number of Go test functions;
- presence of README, docs, and roadmap material.

These signals indicate maturity and maintenance activity. They do not replace product acceptance tests, security review, or release-gate evidence.

## Maturity Tiers

### Tier A: mature core, integration-ready

| Product | Core tag | Commits | Go tests | Notes |
| --- | --- | ---: | ---: | --- |
| Aegivela | `backend/v1.2.11` | 559 | 1209 | Strong test surface; identity and authorization fabric. |
| LIMENORA | `v2.5.0` | 622 | 968 | Strong test surface; integration gateway. |
| NOMIVELA | `v2.1.1` | 61 | 142 | Stable identity registry; active release line. |
| EIDOVELA | `v2.2.2` | 138 | 133 | Stable identity provider; registry-consumer mode. |
| Rheovela | `v1.1.0` | 209 | 412 | Workflow runtime; mature core. |
| MODUREGIS | `v1.6.0` | 309 | 412 | Capability control plane; mature core. |
| Mnemovela | `v1.2.0` | 713 | 345 | Memory runtime; mature core. |
| SYNDOVELA | `v1.10.0` | 35 | 155 | Small but released product line. |
| ORCHADYN | `v1.59.0` | 195 | 542 | Planning compiler; high release cadence. |
| TEKMOVELA | `v1.0.0` | 184 | 811 | Strong test surface; assurance platform. |
| KINETOVELA | `v1.0.0` | 234 | 597 | Fleet control plane; mature core. |
| PEIRAVELA | `v1.0.0` | 302 | 370 | Simulation and validation control plane. |
| SYMBIVELA | `v1.1.1` | 134 | 242 | Collaboration workspace; released core. |
| Harmovela | `v1.0.1` | 410 | 153 | Protocol-first product; reference daemon and CLIs. |

### Tier B: early core, improve before integration

| Product | Core tag | Commits | Go tests | Primary gap |
| --- | --- | ---: | ---: | --- |
| ONTOVELA | `v1.0.1` | 96 | 120 | Public contract and documentation depth; core/EE alignment. |
| GNOSIVELA | `v1.0.0` | 59 | 181 | Public documentation and port migration; integration evidence. |
| NOETIVELA | `v1.0.0` | 16 | 90 | Smallest public surface; documentation and integration scenarios. |

### Tier A: mature EE counterparts

These EE repositories have enough implementation and test evidence to follow the Wave 1 core products.

| EE repository | EE tag | Commits | Go tests | Notes |
| --- | --- | ---: | ---: | --- |
| aegivela-ee | `v1.2.4` | 43 | 154 | Mature EE counterpart to Aegivela. |
| NOMIVELA-ee | `v1.0.0` | 45 | 121 | Mature enough for Wave 1. |
| Mnemovela-EE | `v1.1.0` | 129 | 148 | Mature enough for Wave 1. |
| ONTOVELA-ee | `v1.0.0` | 199 | 118 | EE surface is stronger than the core Tier B rating; align with core first. |
| PEIRAVELA-ee | `v1.0.0` | 107 | 117 | Mature enough for Wave 1. |
| Rheovela-ee | `v1.1.0` | 31 | 51 | Small but released EE line. |
| SYNDOVELA-ee | `v1.4.0` | 40 | 58 | Small but released EE line. |

### Tier B: early EE counterparts

| EE repository | EE tag | Commits | Go tests | Primary gap |
| --- | --- | ---: | ---: | --- |
| EIDOVELA-ee | `v0.6.0` | 68 | 18 | EE parity and test depth. |
| LIMENORA-ee | `v0.1.0` | 32 | 4 | First baseline tag; EE parity and tests. |
| MODUREGIS-ee | `v0.1.0` | 25 | 35 | First baseline tag; EE parity and tests. |
| ORCHADYN-ee | `v1.0.0` | 46 | 98 | First baseline tag; parity evidence. |
| TEKMOVELA-ee | `v1.0.0` | 84 | 114 | First baseline tag; parity evidence. |
| SYMBIVELA-ee | `v0.1.0` | 79 | 58 | First baseline tag; parity and test depth. |
| GNOSIVELA-ee | `v1.0.0` | 5 | 6 | EE implementation is still thin. |
| enterprise-autonomy-ee | `v0.1.0` | 4 | 0 | Documentation-only companion repository; no runtime surface. |

### Tier C: packaging or placeholder

| Repository | Tag | Notes |
| --- | --- | --- |
| KINETOVELA-ee | `v1.0.0` | No Go module or tests in the EE repository; treat the tag as packaging metadata, not maturity evidence. |

## Versioning Policy

1. **Keep product versions independent.** A product may consume PRAXOVELA 3.0 while remaining on its own `1.x` or `2.x` line.
2. **Use `/v3` for Go imports.** The module path major is an API compatibility boundary. It does not imply that a product has completed its 3.0 product release.
3. **Tag mature products at their next product major when the integration gate closes.** Do not assign `3.0.0` to a product solely because its modules moved to `/v3`.
4. **Do not use tags as maturity claims.** A repository with few tests or no runtime surface must not be presented as production-ready because it has a tag.
5. **Document compatibility explicitly.** The platform-to-product compatibility matrix remains the source of truth for supported combinations.

## Integration Sequence

### Wave 1: mature products

Core: Aegivela, LIMENORA, NOMIVELA, EIDOVELA, Rheovela, MODUREGIS, Mnemovela, SYNDOVELA, ORCHADYN, TEKMOVELA, KINETOVELA, PEIRAVELA, SYMBIVELA, Harmovela.

EE: aegivela-ee, NOMIVELA-ee, Mnemovela-EE, PEIRAVELA-ee, Rheovela-ee, SYNDOVELA-ee.

Entry criteria for each product:

- a documented integration contract and supported platform range;
- an end-to-end scenario that exercises the product through the platform boundary;
- release-gate evidence for the exact tag being integrated;
- no open blocker that invalidates the scenario;
- known limitations recorded in the compatibility matrix.

Wave 1 outcomes:

- integrate against PRAXOVELA 3.0;
- record per-product evidence;
- decide whether the product's next release is a new major or stays on its current line;
- only then create product `3.0.0` tags where the product owner decides that the product major should change.

### Wave 2: early products

Core: ONTOVELA, GNOSIVELA, NOETIVELA.

EE: EIDOVELA-ee, LIMENORA-ee, MODUREGIS-ee, ORCHADYN-ee, TEKMOVELA-ee, SYMBIVELA-ee, GNOSIVELA-ee, ONTOVELA-ee.

These products should first close their own roadmap gaps. Integration before that only proves skeleton wiring and creates a misleading maturity signal.

## B-Class Improvement Queue

Priority order for the next improvement cycle:

1. **NOETIVELA** — publish the product contract and integration scenario; increase public documentation coverage.
2. **GNOSIVELA** — complete public documentation, port migration, and integration evidence.
3. **ONTOVELA** — align core and EE contracts, complete public documentation, and keep the demo-stack port as the supported default.
4. **EIDOVELA-ee** — close EE parity gaps and raise test depth.
5. **LIMENORA-ee, MODUREGIS-ee, ORCHADYN-ee, TEKMOVELA-ee, SYMBIVELA-ee** — establish EE parity checklists, add missing tests, and produce release-gate evidence.
6. **GNOSIVELA-ee, enterprise-autonomy-ee** — define the EE implementation scope before claiming parity. The companion repository is documentation-only today.

## EE Baseline Tags

The following EE repositories had no semantic tag before this assessment. They now carry a baseline tag so that future EE work has a traceable starting point:

| Repository | Baseline tag | Rationale |
| --- | --- | --- |
| LIMENORA-ee | `v0.1.0` | First tracked EE baseline; early implementation. |
| MODUREGIS-ee | `v0.1.0` | First tracked EE baseline; early implementation. |
| ORCHADYN-ee | `v1.0.0` | Matches the version declared in `backend/internal/version/version.go`. |
| TEKMOVELA-ee | `v1.0.0` | Matches the repository `VERSION` file. |
| SYMBIVELA-ee | `v0.1.0` | First tracked EE baseline; features are still under development. |
| enterprise-autonomy-ee | `v0.1.0` | First tracked baseline for the documentation-only companion repository. |

These tags are baselines, not production-readiness statements.

## Next Actions

1. Run the Wave 1 readiness review for each mature product and record the result.
2. Start the B-class queue with NOETIVELA, GNOSIVELA, and ONTOVELA.
3. Keep the compatibility matrix current as products move through Wave 1 and Wave 2.
4. Reassess remaining Tier B products after the first improvement cycle.
