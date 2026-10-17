# agent-workflow-bridge-local

Local (non-container) bring-up of the **PRAXOVELA R6 bridge path**, recorded as
**scenario cases** so each step can be run, reproduced and audited on its own.

```
axond bridge (/v1/instances, /v1/work-items)
  -> adapters/rheovela (official Rheovela Go SDK) -> Rheovela `rheo serve`
        verifies the caller with an AEGIVELA workload assertion (JWKS)
  <- AEGIVELA `aegivela-api` mints that assertion for axond's workload identity
```

## Cases

| Case | 场景 | 状态 |
| --- | --- | --- |
| [01](cases/01-aegivela-service.md) | AEGIVELA 服务可用（PostgreSQL + Apache AGE + 开发密钥 + 迁移） | ✅ 通过 |
| [02](cases/02-workload-binding-assertion.md) | Workload 身份绑定与断言签发（内部令牌 + 三个权威头） | ✅ 通过 |
| [03](cases/03-rheovela-jwks.md) | Rheovela 用 AEGIVELA JWKS 校验断言并发布工作流 | ✅ 通过 |
| [04](cases/04-bridge-e2e.md) | axond bridge 部署态 E2E（open/get/step/audit） | ✅ 通过 |
| [05](cases/05-failure-cases.md) | 失败/负向场景 F1–F7（含 2 个跨仓缺陷、2 个排查陷阱） | 见各条 |
| [06](cases/06-retry-cancellation.md) | 部署态 work-item 闭环 + 注入失败（claim→complete 通过；fail→failed，不可重领 ⇒ **无重试/取消**，缺口） | ⚠️ 缺口已证 |

结果摘要：axond 启动日志出现 `Orchestrator: Rheovela (...)`（该行只在真实断言认证成功后打印）；
`POST /v1/instances` → 实例 `active`；`GET /v1/instances/{id}` → `active`/`definition_id=expense`；
`POST .../steps` → `ok`；`GET .../audit` → 通。

## Quick start

```powershell
Copy-Item local.env.ps1.example local.env.ps1   # 改成你的 checkout 路径
. .\local.env.ps1
.\start-services.ps1          # 建库/迁移/密钥 -> AEGIVELA -> binding -> Rheovela -> axond
.\verify.ps1                  # 跑 Case 04 的 bridge 调用并打印证据
.\stop-services.ps1
```

`start-services.ps1` 按 Case 01→04 顺序执行；任何一步失败都会抛错并提示看
`.local-logs\`，不会留下"半启动但看起来正常"的状态（axond 缺编排器时是 fail-closed）。

## Layout

```
start-services.ps1 / stop-services.ps1 / verify.ps1
fault-injection.ps1          # Case 06：种子 work item + 经部署桥 claim/fail/complete
local.env.ps1.example        # 路径、端口、dev 凭证、workload 身份
tools/genkeys/               # 生成 AEGIVELA 需要的 Ed25519 PKCS#8 密钥 + audience 注册表（stdlib-only）
cases/01..06                 # 场景化记录
.local-data/ .local-logs/    # 运行期产物（git-ignored）
```

## Scope / 诚实边界

覆盖：bridge → SDK 适配器 → Rheovela，认证走**真实 AEGIVELA 断言**，含 open/get/step/audit；
部署态 work-item 的 **claim→complete 闭环**（Case 06）。

未覆盖 / 已证缺口：**部署态运行时不做失败重试**——`FailWorkItem` 置 `state='failed'` 且清空
fencing token，无回队、无尝试计数；也没有 work-item cancel 路由。worker SDK 能消费"会回队"的
store，但实际 store 不会回队，因此端到端重试未成立（见 Case 06）。Rheovela worker 循环的
单元测试（`rheovela-open/sdk/go/worker`）只覆盖 SDK 语义。

本目录只含**本机开发**配置；密钥、数据库、工作流都是本地产物，保存在 `.local-data/`（已 git-ignore）。
