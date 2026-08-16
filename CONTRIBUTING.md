# Contributing to enterprise-autonomy

Thank you for helping improve the public AxisRobo Enterprise Autonomy material.

## Scope

This repository holds public product introductions, end-to-end scenarios, reference-stack overviews, and adoption-oriented documentation. Product repositories are authoritative for their own runtimes and domains.

## Publication Boundary

Do not place credentials, secrets, internal endpoints, private incident evidence, customer or partner information, commercial material, or non-public roadmap information in this repository. Architecture, contracts, schemas, profiles, conformance, governance, internal planning, and unreleased product direction belong in the private `enterprise-autonomy-ee` repository.

## Content Guidelines

- Follow the [public example design guide](docs/example-design-guide.md) for scenarios.
- Keep each product authoritative for its own domain; prefer links over restating product facts.
- Match the existing scenario and reference-stack formats.
- Verify every internal link and keep the planned port allocation consistent with the [technical catalog](docs/technical-catalog.md).
- Do not add comments or decorative material to code beyond what is needed to run the example.

## Working With Local Examples

Runnable examples must document prerequisites, startup, expected output, and shutdown in their own `README.md`. Reference adapters must be buildable with the documented toolchain.

- Run `.\examples\run-all-demos.ps1 -CheckOnly` to verify demo structure without a database.
- Run `.\scripts\validate-demos.ps1` and `.\scripts\validate-json.ps1` to verify structure, script syntax, and JSON validity.
- Use `.\examples\stop-demo.ps1` to stop demo processes (it matches by executable path, never unrelated processes).

## Process

1. Keep changes small and focused on one area.
2. Test local examples before describing them as runnable.
3. Update `docs/` indexes and `CHANGELOG.md` for user-visible content changes.
4. Install the pre-commit hook once with `.\scripts\install-hooks.ps1`; it verifies internal links and reports the version on every commit.
5. Open a pull request with a clear description of the public content being added or changed. CI runs the same link, smoke, and version checks.
