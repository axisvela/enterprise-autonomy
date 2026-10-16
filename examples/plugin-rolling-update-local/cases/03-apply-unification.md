# Case 03 — Apply 与受治理生命周期同表

**目的**：验证 `Apply` 不再自建"未受治理"实例，而是与候选/升代**共用同一张受管表**
（否则 Disable/Enable/Quarantine 会拒绝它，或留下第二套状态机）。
**跑法**：`go test ./internal/pluginruntime -run TestApply`、`go test ./internal/governance -run 'Rollback|Update|Promote'`。

## 期望与观测

| 步骤 | 期望 | 观测（核心 `46bda96`，本会话复跑） |
| --- | --- | --- |
| `Apply` 后实例 | 进入**受管**表（非 unmanaged） | ✅ `lifecycle_api_test.go` 断言 Apply 产生受管实例 |
| Apply 后 `Disable` | 可正常禁用（不再报 "unknown contract"） | ✅ 同套件断言 |
| 单活跃约束 | 同一 `tool.provider` 契约同时只能有 1 个 ACTIVE（受 guarded registry 键约束） | ✅ 冲突即失败关闭 |
| Apply 二阶语义 | 已存在服务代时走**更新平面**（不再绕过） | ✅ `governance` 套件覆盖 promote/update/rollback |

## 要点（契约）

受治理生命周期只有**一个所有者**：装配（assembly）持有实例与 guarded 绑定，更新管理器持有代数与日志；
`Apply` 与 `PrepareCandidate/PromoteCandidate` 都是这一条路径的入口。

## 判据

`PASS` 表示"Apply 产生的实例可被生命周期 API 正常操作"成立；这也是 R5 中 S-05 的关闭证据。
