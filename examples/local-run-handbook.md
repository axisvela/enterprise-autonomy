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
6. Stop the processes shown in `.local-logs/` and remove `.local-data/` only when you intentionally discard the demo data.

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
