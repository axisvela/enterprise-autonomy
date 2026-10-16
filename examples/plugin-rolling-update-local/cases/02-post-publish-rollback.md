# Case 02 — 发布失败后的回滚（生产管理器 ↔ 装配）

**目的**：当"运行时已翻转、治理清单发布失败"时，运行时要能**回到在位代**，而不是留下分裂状态。
**跑法**：
- `go test ./internal/pluginruntime -run TestRollbackPlugin`
- `go test ./internal/governance -run TestRuntimeManagerConformance`（对 **两个** 管理器都跑 `PostPublishCommitFailure`）

## 期望与观测

| 步骤 | 期望 | 观测（2026-10-16，核心 `3dde504`） |
| --- | --- | --- |
| `Assembly.RollbackPlugin` | 从 digest 校验过的缓存**重建**上一代 → 翻转更新平面 → 退役被取代代 → **重绑 guarded adapter** → 可再次调用 | ✅ `TestRollbackPluginRestoresTheIncumbentGeneration`（恢复 1.0.0 并真实 invoke 成功） |
| 无回滚目标 / 身份不可用 | **在任何状态变更前** fail closed | ✅ 二次回滚报错且不影响在位代 |
| 重建失败 | 更新平面与在位代**不受影响** | ✅（先重建后翻转的顺序保证） |
| 生产管理器发布失败 | 调用回滚；成功 → 返回普通发布错误（两平面一致）；回滚也失败 → 暴露分裂 `ErrPostPublishCommitFailed` | ✅ 共享套件对 `AssemblyRuntimeManager` 断言"保留在位代" |

## 要点（契约）

- 顺序是"**先重建、后翻转**"：能失败的部分（拉取/校验/构造/启动）都发生在权限变更之前。
- 回滚成功 ≠ 发布成功：操作仍是失败事务，但**两平面重新一致**；只有回滚也失败才是分裂。

## 判据

`PASS` 表示两个管理器的 `PostPublishCommitFailure` 都走"保留在位代"分支（共享套件里显式断言，不外挂 skip）。
