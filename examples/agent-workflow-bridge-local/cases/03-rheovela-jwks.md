# Case 03 — Rheovela 用 AEGIVELA JWKS 校验断言并发布工作流

**目的**：让 `rheo serve` 用 AEGIVELA 的公钥校验调用方，并发布 E2E 需要的工作流定义。
**前置**：[Case 02](02-workload-binding-assertion.md) 可签发断言。

## 启动

```powershell
$env:RHEO_AUTH_JWKS     = 'http://127.0.0.1:1886/v1/workload-assertions/jwks'
$env:RHEO_AUTH_ISSUER   = 'https://aegivela-dev.local'   # 必须等于断言 iss
$env:RHEO_AUTH_AUDIENCE = 'rheovela'                     # 必须等于断言 aud
& "$env:RHEOVELA_DIR\dist\rheo-windows-amd64.exe" serve --addr :8080 --db .\.local-data\rheo.db
```

## 发布工作流（用刚签发的断言做 Bearer）

```powershell
Invoke-WebRequest -Method Post -Uri http://127.0.0.1:8080/api/v1/workflows `
  -Headers @{ Authorization = "Bearer $assertion" } -ContentType application/json `
  -InFile "$env:RHEOVELA_DIR\examples\expense.json" -UseBasicParsing
```

## 预期可观测

| 检查 | 期望 |
| --- | --- |
| `GET http://127.0.0.1:8080/api/v1/health` | `{"db":"ok","status":"ok"}`（**该端点无需认证**，不能作为认证验证） |
| `GET /api/v1/workflows` 带断言 | `200`（无断言或断言无效 → 拒绝） |
| `POST /api/v1/workflows` 带断言 | `201` |

## 本 case 的要点

- `RHEO_AUTH_ISSUER` / `RHEO_AUTH_AUDIENCE` 必须与断言中的 `iss` / `aud` 逐字一致，否则校验失败。
- 健康端点不需要认证：**"health 返回 200" 不能证明断言被接受**。判断认证是否打通，要用受保护端点（如 `/api/v1/workflows`）。
- 认证之外，Rheovela 侧无额外配置；工作流定义来自 Rheovela 仓库自带示例（`examples\expense.json`，`workflow_id=expense`）。
