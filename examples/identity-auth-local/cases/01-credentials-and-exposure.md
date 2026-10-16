# Case 01 — 凭证与暴露守卫

**目的**：无/错凭证必须被拒；审批与插件开关这类写操作不得因"请求读不懂"而静默执行。
**跑法**：`go test ./internal/bridge -run 'TestValidateExposure|TestApproval|TestTogglePlugin'`、`go test ./internal/config`

| 检查 | 期望 | 观测（2026-10-16） |
| --- | --- | --- |
| 配置了 API key 时无/错令牌 | `401` | ✅ 中间件分支 |
| 未配置任何凭证（本地回环） | 允许，但只授予**最低角色**（member），不是 admin | ✅ |
| 审批响应缺 `decision` / 未知决策 / 畸形 JSON | `400`，**不默认批准** | ✅ 核心 `93d23e5` |
| 插件 toggle 畸形 body | `400`（不得静默变 `enabled=false`） | ✅ 核心 `1c4fec8` |
| 配置解析 | `AXON_ALLOW_REMOTE` 等按 env 生效且可测 | ✅ `internal/config` |

**要点**：凭证缺失时的"本地回退"只在回环发生，且给的是最弱角色——这一层不做任何"默认管理员"假设。
