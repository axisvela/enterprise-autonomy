# Local Run Handbook

This handbook covers common steps for running public local demos against real product binaries. Each demo's own `README.md` is authoritative for its prerequisites and scripts.

## Shared Prerequisites

- Windows PowerShell 5.1 or later and `curl.exe`
- Local checkouts of the product repositories referenced by the demo
- A reachable PostgreSQL instance with the databases the demo requires
- The verified local binaries or network access to download releases on demand

## Typical Flow

1. Copy the demo's `local.env.ps1.example` to `local.env.ps1` and set your checkout root and database connection strings.
2. Do not commit `local.env.ps1`; it contains environment-specific paths and connection strings.
3. Load the environment and start the services.
4. Run the scenario script and inspect the printed business report and `.local-data/` artifacts.
5. Review live state with the documented `curl.exe` requests before closing the case.
6. Verify the outcome with the demo's `verify.ps1`, which checks the produced artifacts against the [value framework](../docs/example-value.md) thresholds.
7. Stop the processes shown in `.local-logs/` and remove `.local-data/` only when you intentionally discard the demo data.

## One-Command Run

All runnable demos provide a `run-all.ps1` wrapper that loads the environment, starts the services, runs the scenario, and verifies the outcome in one step:

```powershell
# order-fulfillment-local, procurement-local, customer-case-local, recruitment-local, predictive-maintenance-local, integration-recovery-local
.\run-all.ps1
```

## Run All Demos

Run every demo end to end with a single command from `examples/`:

```powershell
.\run-all-demos.ps1                # all six demos
.\run-all-demos.ps1 -CheckOnly     # verify structure only, no database needed
.\run-all-demos.ps1 -Only procurement-local,recruitment-local
.\run-all-demos.ps1 -Skip customer-case-local
```

The runner starts each demo, executes its scenario, verifies the outcome, stops the processes, and reports a summary table. It fails (exit 1) if any selected demo fails, and continues past a failed demo.

## Stop The Stack

Stop all demo processes reliably with:

```powershell
.\stop-demo.ps1
```

`stop-demo.ps1` matches processes by executable path (repo adapters and the demo product stack), so it never touches unrelated processes. `scripts\kill-adapters.ps1` kills only reference-adapter processes.

## Value Reports

Runnable demos emit a machine-readable value report alongside the business outcome:

- Order demo: `.local-data/order-value-report.json` (see [evidence schema](order-fulfillment-local/evidence-schema.md)).
- Procurement demo: `.local-data/procurement-value-report.json` (see [evidence schema](procurement-local/evidence-schema.md)).
- Customer-case demo: `.local-data/customer-value-report.json` (see [evidence schema](customer-case-local/evidence-schema.md)).
- Recruitment demo: `.local-data/recruitment-value-report.json` (see [evidence schema](recruitment-local/evidence-schema.md)).
- Predictive-maintenance demo: `.local-data/maintenance-value-report.json` (see [evidence schema](predictive-maintenance-local/evidence-schema.md)).
- Integration-recovery demo: `.local-data/integration-value-report.json` (see [evidence schema](integration-recovery-local/evidence-schema.md)).

Aggregate all reports with `.\scripts\report-value.ps1` into the [value dashboard](../docs/value-dashboard.md).

The report records the outcome, KPIs, human gates, and per-product evidence so the effect can be verified. See the [value report template](value-report-template.md).

## Common Checks

| Symptom | Check |
| --- | --- |
| Script requires `local.env.ps1` | Ensure you dot-source it first: `. .\local.env.ps1` |
| Binary not found | Confirm the product checkout path and that the required binary exists at the documented location. |
| Service never becomes ready | Confirm the required databases exist and the PostgreSQL instance is reachable; check `.local-logs/`. |
| `GET /ready` not ready | Symbivela reports PostgreSQL connectivity; confirm the `DATABASE_URL` is correct. |
| Orchadyn plan skipped | `$OrchadynBinary` is `$null`; the demo runs without plan generation. |

## Reference Adapters

Local demos may use reference adapters under `../adapters/`. These are illustrative integrations, not production systems. Replace them with authorized production integrations before real business use.

## Health Endpoints by Product

See the [technical catalog](../docs/technical-catalog.md) for the authoritative health-endpoint and port list per product.
