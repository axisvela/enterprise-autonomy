# Case 05 — 失败/负向场景（本次 bring-up 实际踩到并复现的）

每个 case 给出：触发方式、观测到的现象、根因、处理与状态。
这些都是"失败即关闭（fail-closed）"，除了两个**跨仓集成缺陷**（F1/F2）是真正需要修代码的。

## F1 — 断言签发 401：SDK 缺可信权威头 ✅ 已修

- **触发**：不带头（或只带 `X-Aegivela-Internal-Token`）调用 `POST /v1/workload-assertions/issue`。
- **现象**：`401 unauthenticated`；PRAXOVELA 侧表现为 axond 启动失败
  `[axond] Rheovela unreachable at http://127.0.0.1:1876: rheovela: credential: unauthenticated`。
- **根因**：`aegivela-open/sdk/go/identitysdk` 的 `internalHeader` 只设置内部令牌，而 AEGIVELA 的
  `InternalTokenResolver.Resolve` 要求 `X-Aegivela-Tenant-ID` / `-Actor-ID` / `-Authority-Root`。
- **证据**：同参数下原始 HTTP（带头）→ `200` 且返回断言；`identitysdk.IssueWorkloadAssertion(...)` → `unauthenticated`。
- **处理**：SDK 增加 `TrustedAuthority` + `WithTrustedAuthority`（`aegivela-open ecab950`），
  PRAXOVELA 由 workload 身份注入（core `3a1cbf5`）。
- **状态**：已修，有 SDK 单测（`TestTrustedAuthorityHeaders`）。

## F2 — 断言签发 400：TTL 超出服务端上限 ✅ 已修

- **触发**：`expires_at` 设为 10 分钟后。
- **现象**：`400 invalid_workload_assertion_request`；axond 侧
  `credential: invalid authorization input`。
- **根因**：AEGIVELA `maxAssertionTTL = 5m`；而 SDK 与 PRAXOVELA 适配器默认都是 10 分钟。
- **证据**：同一请求 5 分钟 → `200`；10 分钟 → `400`。
- **处理**：两侧默认值改为 5 分钟（`aegivela-open ace4c25`、core `3a1cbf5`）。
- **状态**：已修。

## F3 — Binding 创建 400：`evidence_ref` 形状 ⚠️ 绕行（服务端校验语义可疑）

- **触发**：`evidence_ref = "dev-r6-e2e"`（无前缀）。
- **现象**：`400 invalid_workload_binding_request`。
- **根因**：校验要求 `evidence:` 前缀；且当去掉前缀后恰好是**三段点分**时，若每段都是普通
  字母数字/-/_，校验反而判为**非法**（只有"含空段或含特殊字符"才通过）。
- **处理**：改用单段后缀 `evidence:dev-bridge-local`（已通过）。
- **状态**：绕行；建议 aegivela-open/AEGIVELA 复核该校验函数（疑似把合法形状判反）。

## F4 — axond 启动失败：缺 `AXON_AEGIVELA_TENANT_ID` ✅ 预期（fail-closed）

- **现象**：`[axond] AEGIVELA policy service: aegivela: tenant scope is required (AXON_AEGIVELA_TENANT_ID); the PDP rejects a missing X-Aegivela-Tenant-ID header`，进程退出。
- **含义**：正确行为——宁可不启动，也不在缺少租户作用域时以更弱身份运行。

## F5 — 误判：health 200 不等于认证通过 ⚠️ 排查陷阱

- **现象**：`GET /api/v1/health`（Rheovela）带/不带断言都返回 `200`。
- **含义**：健康端点是公开的；**判断认证链路必须用受保护端点**（如 `GET /api/v1/workflows`）。
  本次先为此误判付出过一轮排查。

## F6 — 误判：bridge 501 `rheovela_not_configured` ⚠️ 环境/进程问题

- **现象**：`POST /v1/instances` → `501 {"error":"rheovela_not_configured"}`。
- **根因**：启动 axond 的那次命令只设了 `AXON_PORT`/`AXON_API_KEY`，**漏了 `AXON_RHEOVELA_URL` 等 R6 变量**，
  于是 `rt.RheovelaOrch` 为 nil（启动日志里也没有 `Orchestrator: Rheovela` 行）。
- **含义**：不是代码缺陷。判据：启动日志是否出现 `Orchestrator: Rheovela`。

## F7 — 远程监听无凭证被拒 ✅ 预期（fail-closed）

- **触发**：`AXON_ALLOW_REMOTE=1` 且未配置 `AXON_API_KEY`/令牌存储。
- **现象**：axond 拒绝启动并报错提示需配置操作员认证。
- **含义**：正确行为（core `2111418`），本地回环不受影响。
