# Deployment-Domain Adapter

Local reference service for simulated sequenced-autonomy views. Not a production release platform.

Base URL: `http://localhost:8102` (override with `--addr`).

See [API.md](API.md) for endpoints, and [main_test.go](main_test.go) for the governance gates covered by unit tests.

## Governance Pattern: Sequenced Autonomous Execution

The adapter demonstrates **sequenced autonomous execution**:

- Automation may execute a declared step sequence **strictly in order**; an out-of-sequence step is rejected (`409 step_out_of_sequence_next_is_<step>`).
- Each step **cites evidence** (`evidence_ref`) recorded by the executing agent; a step without evidence is rejected (`400`).
- A completed step is **immutable**; re-executing it is rejected (`409 step_already_executed_immutable`).
- Any **deviation** from the sequence (pause, skip, rollback) requires a **human approval** with an `approval_ref`; an unapproved deviation is rejected (`403 deviation_requires_human_approval`).
- A released deployment is **immutable**; no further steps or deviations are accepted (`409 deployment_already_released_immutable`).

## Build and Run

```powershell
cd adapters\deployment-domain
go build -o deployment-domain-adapter.exe .
.\deployment-domain-adapter.exe --addr :8102 --data-file deployment-domain-data.json
```

## Tests

```powershell
go vet ./...
go test ./...
```

See the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository for the full pattern taxonomy.
