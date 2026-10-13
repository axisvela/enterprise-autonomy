# Inference-Domain Adapter

Local reference service for simulated governed-inference views. Not a production inference fabric.

Base URL: `http://localhost:8103` (override with `--addr`).

See [API.md](API.md) for endpoints, and [main_test.go](main_test.go) for the governance gates covered by unit tests.

## Governance Pattern: Governed Inference

The adapter demonstrates **governed inference**:

- A request must be **authorized** before any model or endpoint is selected (`403 authorization_required_before_route`).
- The model and endpoint are selected **under policy**; a model or endpoint outside the allowed catalog is rejected (`403 model_out_of_policy_<model>` / `403 endpoint_out_of_policy_<endpoint>`).
- An answer must be **grounded** in accepted claims and memory context before it is produced (`403 route_and_grounding_required_before_answer`).
- A **high-impact** request requires a **human review** before the answer is produced (`403 human_review_required_before_answer`); the review decision must be `approve`.
- The result is recorded as an **immutable audit record**; an audited inference accepts no further mutations (`409 inference_audited_immutable`).

## Build and Run

```powershell
cd adapters\inference-domain
go build -o inference-domain-adapter.exe .
.\inference-domain-adapter.exe --addr :8103 --data-file inference-domain-data.json
```

## Tests

```powershell
go vet ./...
go test ./...
```

See the governance-pattern catalog in the private **`enterprise-autonomy-ee`** repository for the full pattern taxonomy.
