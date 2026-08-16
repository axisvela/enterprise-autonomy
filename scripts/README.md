# Repository Scripts

Small validation and reporting utilities for the public examples.

| Script | Purpose | Exit codes |
| --- | --- | --- |
| [check-links.ps1](check-links.ps1) | Verifies every internal markdown link resolves. Run after content changes. | `0` pass, `1` broken links |
| [check-examples.ps1](check-examples.ps1) | Verifies a runnable demo's produced artifacts against expectations via its `verify.ps1`. | `0` pass, `1` failure |
| [report-value.ps1](report-value.ps1) | Aggregates value reports (`.local-data/*-value-report.json`) into a summary table. | `0` (also succeeds when no reports exist) |
| [run-demo-smoke.ps1](run-demo-smoke.ps1) | Smoke-tests the reference adapters end to end: order (governed fulfillment + denial), inventory (governed reservation), and procurement (segregation of duties, role approvals, purchase, receipt). | `0` pass, `1` failure |
| [version.ps1](version.ps1) | Reads, sets, or bumps the repository version in `VERSION`. | `0` success |
| [check-release.ps1](check-release.ps1) | Decides whether a new tag/version is warranted after commits. | `0` no change, `1` new tag needed, `2` prepared and ready to tag |
| [install-hooks.ps1](install-hooks.ps1) | Installs the pre-commit hook (`.githooks/pre-commit`) via `core.hooksPath`. | `0` success |
| [check-hooks.ps1](check-hooks.ps1) | Verifies the pre-commit hook is installed and active. | `0` active, `1` not installed |

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

**Commit-time check.** After committing (or in CI), run `check-release.ps1`. It compares `HEAD` against the latest tag and reports:

- `0` — no commits since the last tag; no new release needed.
- `1` — commits exist; bump `VERSION`, add a `CHANGELOG.md` entry, then tag.
- `2` — the new version is prepared; create and push the tag.

Release flow:

```powershell
.\scripts\version.ps1 bump minor   # e.g. 0.1.0 -> 0.2.0
# add a CHANGELOG.md entry for the new version
git add -A
git commit -m "..."
.\scripts\check-release.ps1        # expect exit 2
git tag -a "v$((.\scripts\version.ps1 get))" -m "Release v$((.\scripts\version.ps1 get))"
git push origin main --tags
```

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
2. `run-demo-smoke.ps1` — builds and smoke-tests all four reference adapters (order, inventory, procurement, customer).
3. `version.ps1 get` — reports the current version.
4. `check-release.ps1` — reports whether a new tag is warranted (informational; exit `1` does not fail the build).

`check-examples.ps1` verifies produced demo artifacts after a run; it is intended for post-run verification, not CI without a full demo environment.
