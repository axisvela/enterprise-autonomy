# FP-1 Value Report Schema

`fp1-value-report.json`:

| Field | Type | Meaning |
| --- | --- | --- |
| `passed` | bool | every scenario passed |
| `scenarios[]` | array | one entry per assertion |
| `scenarios[].id` | string | `FP-01`..`FP-09` |
| `scenarios[].expected` | string | expected outcome |
| `scenarios[].actual` | string | observed outcome |
| `scenarios[].passed` | bool | assertion result |
