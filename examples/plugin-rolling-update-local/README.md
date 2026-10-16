# plugin-rolling-update-local

Demonstrates the **plugin rolling-update and rollback** behaviour of the governed
plugin/runtime plane, recorded per case.

## Why this example is suite-driven

The governance HTTP surface (`/v1/governance/plugins/...`) is only mounted when a
control plane is assembled (`AXON_SYNDOVELA_URL` set), and a real bundle needs a
signed descriptor + artifact + trust root. That is a control-plane bring-up, not a
one-command local demo.

The behaviour itself is fully exercisable **hermetically**, against the product's
own binaries in-process (real WASM fixture hosts, real update journal, real
guarded registry), so this example drives those suites and records their output as
evidence. That is a deliberate scope choice, stated here rather than dressed up as
an HTTP demo.

## Run

```powershell
. .\local.env.ps1      # copy from local.env.ps1.example and edit PRAXOVELA_DIR
.\verify.ps1           # runs the pinned suites, writes _reports/plugin-rolling-update.json
```

`verify.ps1` runs, and records pass/fail per case:

| Case | Pinned suites |
| --- | --- |
| [01 promote and rollback](cases/01-promote-and-rollback.md) | `internal/pluginruntime -run TestSBRP` |
| [02 post-publish rollback](cases/02-post-publish-rollback.md) | `internal/pluginruntime -run TestRollbackPlugin`, `internal/governance -run TestRuntimeManagerConformance` |
| [03 apply unification](cases/03-apply-unification.md) | `internal/pluginruntime -run TestApply`, `internal/governance -run 'Rollback\|Update\|Promote'` |
| [04 deployed lifecycle E2E](cases/04-deployed-lifecycle-e2e.md) | `cmd/axond -run TestGovernanceProcessLifecycleE2E` (deployed process, no control plane needed) |

## Scope

Covers: candidate staging → health-gated promote → incumbent retained as rollback
target → rollback restores the incumbent **with its guarded adapter re-bound** →
publish-failure rollback in the production manager.

Not covered: a control-plane-driven install of a signed bundle over HTTP (needs
SYNDOVELA + trust root + artifact), and cross-host placement.
