# Repository Scripts

Small validation and reporting utilities for the public examples.

| Script | Purpose | Exit codes |
| --- | --- | --- |
| [check-links.ps1](check-links.ps1) | Verifies every internal markdown link resolves. Run after content changes. | `0` pass, `1` broken links |
| [check-examples.ps1](check-examples.ps1) | Verifies a runnable demo's produced artifacts against expectations via its `verify.ps1`. | `0` pass, `1` failure |
| [report-value.ps1](report-value.ps1) | Aggregates value reports (`.local-data/*-value-report.json`) into a summary table. | `0` (also succeeds when no reports exist) |
| [run-demo-smoke.ps1](run-demo-smoke.ps1) | Smoke-tests every reference adapter end to end, covering each adapter's governance gates, denial paths, and idempotency. | `0` pass, `1` failure |
| [version.ps1](version.ps1) | Reads, sets, or bumps the repository version in `VERSION`. | `0` success |
| [check-release.ps1](check-release.ps1) | Decides whether a new tag/version is warranted after commits. | `0` no change, `1` new tag needed, `2` prepared and ready to tag |
| [install-hooks.ps1](install-hooks.ps1) | Installs the pre-commit hook (`.githooks/pre-commit`) via `core.hooksPath`. | `0` success |
| [check-hooks.ps1](check-hooks.ps1) | Verifies the pre-commit hook is installed and active. | `0` active, `1` not installed |
| [validate-demos.ps1](validate-demos.ps1) | Verifies demo structure (required files) and PowerShell syntax of all scripts. | `0` pass, `1` failure |
| [validate-json.ps1](validate-json.ps1) | Verifies every JSON file under `examples/` and `adapters/` parses. | `0` pass, `1` failure |
| [kill-adapters.ps1](kill-adapters.ps1) | Kills any reference-adapter process built from this repository. | `0` (with or without matches) |
| [run-go-tests.ps1](run-go-tests.ps1) | Runs `go vet` and `go test` across every reference-adapter module. | `0` pass, `1` failure |
| [read-changelog-section.ps1](read-changelog-section.ps1) | Extracts a version's block from `CHANGELOG.md`. | `0` (prints block), `1` missing |
| [create-tag.ps1](create-tag.ps1) | Creates the annotated tag `v<VERSION>` (no-op if it exists). | `0` success, `1` invalid/missing |
| [create-release.ps1](create-release.ps1) | Creates a GitHub Release via `gh` with the changelog block as body (idempotent; `-NotLatest` for backfills). | `0` success, `1` failure |
| [verify-release.ps1](verify-release.ps1) | Full release checklist: VERSION, CHANGELOG, tag, clean tree, validators, prepared state. | `0` ready, `1` blocking issue(s) |
| [check-releases.ps1](check-releases.ps1) | Verifies every release tag has a matching GitHub Release (excludes the in-flight current version). | `0` aligned, `1` missing release(s) |
| [release-body-preview.ps1](release-body-preview.ps1) | Prints the CHANGELOG body that would be used for a release, without creating anything. | `0` (prints body), `1` missing section |

## Usage

```powershell
.\scripts\check-links.ps1
.\scripts\check-examples.ps1
.\scripts\run-demo-smoke.ps1
.\scripts\report-value.ps1
```

## Version Management

The repository version follows `major.minor.patch` and lives in the `VERSION` file.

| Action | Command |
| --- | --- |
| Show the current version | `.\scripts\version.ps1 get` |
| Set an explicit version | `.\scripts\version.ps1 set 0.2.0` |
| Bump the patch/minor/major | `.\scripts\version.ps1 bump patch` · `bump minor` · `bump major` |
| Decide whether a tag is needed | `.\scripts\check-release.ps1` |
| Preview the release body | `.\scripts\release-body-preview.ps1 <version>` |

**Commit-time check.** After committing (or in CI), run `check-release.ps1`. It compares `HEAD` against the latest tag and reports:

- `0` — no commits since the last tag; no new release needed.
- `1` — commits exist; bump `VERSION`, add a `CHANGELOG.md` entry, then tag.
- `2` — the new version is prepared; create and push the tag.

Release flow:

```powershell
.\scripts\version.ps1 bump minor   # e.g. 0.17.0 -> 0.18.0
# add a CHANGELOG.md entry for the new version
git add -A
git commit -m "..."
.\scripts\check-release.ps1        # expect exit 2
.\scripts\release-body-preview.ps1 (.\scripts\version.ps1 get)  # preview notes
.\scripts\verify-release.ps1       # full release checklist (expect exit 0)
.\scripts\create-tag.ps1           # creates v0.18.0 (no-op if it exists)
.\scripts\create-release.ps1       # gh release create with changelog body
git push origin main --tags
```

**Automation.** The [release workflow](../.github/workflows/release.yml) performs the tag + release automatically on every push to `main` when `check-release.ps1` reports the version is prepared (exit `2`), and skips idempotently when the tag already exists.

## Automation

These scripts are designed to run in CI or pre-commit checks. Run `check-links.ps1` and `run-demo-smoke.ps1` on every content change, and `check-release.ps1` after every commit.

## Commit-Time Checks (Git Hooks)

Run `.\scripts\install-hooks.ps1` once to activate the [pre-commit hook](../.githooks/pre-commit). On every commit it:

1. Runs `check-links.ps1` and **blocks the commit** if any internal link is broken.
2. Reports the current `VERSION`.

Verify the hook is active with `.\scripts\check-hooks.ps1`. The CI workflow performs the same checks on every push.

## Continuous Integration

The repository includes [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). On every push to `main` and on pull requests it runs on a Windows runner:

1. `check-links.ps1` — breaks the build on broken internal links.
2. `validate-demos.ps1` — verifies demo structure and script syntax.
3. `validate-json.ps1` — verifies every JSON plan/workflow parses.
4. `run-go-tests.ps1` — runs `go vet` and `go test` on all thirteen reference adapters.
5. `run-demo-smoke.ps1` — builds and smoke-tests all thirteen reference adapters (75 assertions).
6. `check-hooks.ps1` — verifies the pre-commit hook file is present (config check is local-only).
7. `version.ps1 get` — reports the current version.
8. `check-release.ps1` — reports whether a new tag is warranted (informational; exit `1` does not fail the build).
9. `release-body-preview.ps1` — previews the release notes for the current version (informational).
10. `check-releases.ps1` — verifies every release tag has a GitHub Release (uses `GH_TOKEN`).

`check-examples.ps1` verifies produced demo artifacts after a run; it is intended for post-run verification, not CI without a full demo environment.

The governance-pattern catalog and its machine-readable matrix (`patterns.json`) are maintained in the private **`enterprise-autonomy-ee`** repository.

The repository started with the **1.0.0** first stable release (see `CHANGELOG.md`); `VERSION` tracks the current version and the release workflow publishes a tag and GitHub Release for every prepared version.
