# Case 01 — AEGIVELA 服务可用（PostgreSQL + AGE + 开发密钥）

**目的**：让 `aegivela-api` 在本机可启动、`/healthz` 可用、workload JWKS 可用。
**前置**：PostgreSQL 可达；本机 PostgreSQL 必须**具备 Apache AGE 扩展**。

## 步骤

```powershell
# 1. 数据库 + AGE 扩展（迁移 0014+ 引用 ag_catalog，缺扩展必然失败）
psql "postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable" -c "CREATE DATABASE aegivela_dev"
psql "postgres://postgres:postgres@localhost:5432/aegivela_dev?sslmode=disable" -c "CREATE EXTENSION IF NOT EXISTS age"

# 2. 迁移（22 个）
$env:DATABASE_URL = "postgres://postgres:postgres@localhost:5432/aegivela_dev?sslmode=disable"
migrate -path "$env:AEGIVELA_DIR\backend\deploy\postgres\migrations" -database $env:DATABASE_URL up

# 3. 开发密钥（Ed25519 PKCS#8 PEM）+ audience 注册表
go run .\tools\genkeys .\.local-data\keys
```

启动所需环境变量（缺任一项 AEGIVELA 启动即 fail-closed）：

```
DATABASE_URL, AEGIVELA_INTERNAL_AUTH_TOKEN, AEGIVELA_LISTEN_ADDR=:1886
AEGIVELA_POLICY_DECISION_SIGNING_KEY_FILE/_KEY_ID/AEGIVELA_POLICY_DECISION_ISSUER
AEGIVELA_EXECUTION_GRANT_SIGNING_KEY_FILE/_KEY_ID/AEGIVELA_EXECUTION_GRANT_ISSUER
AEGIVELA_GRANT_AUDIENCE_REGISTRY_FILE      # {"audiences":[{"audience":"rheovela","max_ttl_seconds":600}]}
AEGIVELA_WORKLOAD_ASSERTION_SIGNING_KEY_FILE/AEGIVELA_WORKLOAD_ASSERTION_KEY_ID/_ISSUER
```

## 预期可观测

| 检查 | 期望 |
| --- | --- |
| `GET http://127.0.0.1:1886/healthz` | `{"status":"ok"}`（注意是 `/healthz`，不是 `/health`） |
| `GET http://127.0.0.1:1886/v1/workload-assertions/jwks` | 含开发 workload 断言公钥（`kid` 与配置一致） |

## 本 case 暴露的坑

- **Apache AGE 是硬前置**：`aegivela_dev` 未建 AGE 时，迁移在 `0014_tenant_scope_web_resources` 处以 `schema "ag_catalog" does not exist` 失败；扩展是**按库**安装的，装在 `postgres` 库无效。
- audience 注册表的 `max_ttl_seconds` 有上界（grant TTL 上限 15 分钟），超界启动失败：`audience max TTL out of range`。
