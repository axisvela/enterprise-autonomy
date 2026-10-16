# Case 02 — Workload 身份绑定与断言签发

**目的**：为 axond 的 workload 身份建立 binding，并能签发可被 Rheovela 校验的断言。
**前置**：[Case 01](01-aegivela-service.md) 已通过。

## 关键契约

AEGIVELA 的内部令牌解析器要求调用方在 `X-Aegivela-Internal-Token` **之外**再断言三个头：

```
X-Aegivela-Tenant-ID      = tenant-dev
X-Aegivela-Actor-ID       = axond-dev-subject
X-Aegivela-Authority-Root = did:axisrobo:dev
```

且 binding 请求体里的 `subject_ref` / `organization_root` 必须与这两个头**完全一致**。

## 步骤

```powershell
$h = @{
  'X-Aegivela-Internal-Token' = $env:AEGIVELA_INTERNAL_AUTH_TOKEN
  'X-Aegivela-Tenant-ID'      = 'tenant-dev'
  'X-Aegivela-Actor-ID'       = 'axond-dev-subject'
  'X-Aegivela-Authority-Root' = 'did:axisrobo:dev'
}

# 1. 建 binding
$binding = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:1886/v1/workload-bindings -Headers $h `
  -ContentType application/json -Body (@{
     api_version='aegivela.io/v1alpha1'
     subject_ref='axond-dev-subject'; organization_root='did:axisrobo:dev'
     client_id='axond-dev'; workload_ref='axond'
     evidence_ref='evidence:dev-bridge-local'
     trace_id='4bf92f3577b34da6a3ce929d0e0e4736'
  } | ConvertTo-Json -Compress)
$binding.BindingID

# 2. 签发断言（TTL 必须 ≤ 5 分钟）
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:1886/v1/workload-assertions/issue -Headers $h `
  -ContentType application/json -Body (@{
     api_version='aegivela.io/v1alpha1'
     subject_ref='axond-dev-subject'; organization_root='did:axisrobo:dev'
     binding_id=$binding.BindingID; client_id='axond-dev'; workload_ref='axond'
     audience='rheovela'
     expires_at=(Get-Date).ToUniversalTime().AddMinutes(4).ToString('o')
     trace_id='4bf92f3577b34da6a3ce929d0e0e4736'
  } | ConvertTo-Json -Compress) | Select-Object -ExpandProperty workload_assertion
```

## 预期可观测

| 检查 | 期望 |
| --- | --- |
| binding 创建 | `201`，返回 `BindingID`（形如 `UOpT1YupAHz-11BhsldMyg`）、`Lifecycle=active` |
| 断言签发（TTL 4–5 分钟） | `200`，返回 Ed25519 JWT（`iss=https://aegivela-dev.local`、`aud=rheovela`） |

## 本 case 暴露的坑（均为实测复现）

| 现象 | 根因 | 处理 |
| --- | --- | --- |
| `401 unauthenticated` | 只发内部令牌、缺三个权威头 | 补齐头（生产代码路径由 aegivela-open SDK 的 `WithTrustedAuthority` 承担） |
| `400 invalid_workload_binding_request` | `evidence_ref` 未带 `evidence:` 前缀；注意校验器把"规整的三段式"反而判为非法，用**单段**后缀如 `evidence:dev-bridge-local` | 修正取值 |
| `400 invalid_workload_assertion_request` | 请求的 `expires_at` 超过 `maxAssertionTTL = 5m`（10 分钟必失败，5 分钟成功） | TTL 收敛到 ≤5 分钟 |

## 与生产代码的对应

`AXON_WORKLOAD_{BINDING_ID,CLIENT_ID,REF,SUBJECT_REF,ORG_ROOT}` + `AXON_AEGIVELA_{URL,TOKEN,TENANT_ID}`
在 axond 侧装配成 `adapters/aegivelaassert`，它经 aegivela-open 的 identity SDK 签发断言。
