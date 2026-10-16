# Case 01 — 候选升代与回滚（更新平面）

**目的**：验证"暂存候选 → 健康门 → 翻转 → 保留在位代作为回滚目标 → 回滚"这条更新平面语义。
**跑法**：`go test ./internal/pluginruntime -run TestSBRP`（真实 host + 真实更新日志）。

## 期望与观测

| 步骤 | 期望 | 观测（2026-10-15/16） |
| --- | --- | --- |
| Prepare 候选 | 候选 LOADED 且**不可调用**（未绑定 guarded registry） | ✅ |
| Promote（健康） | 新代 ACTIVE，旧代降为 rollback 目标（drained，未物理停止） | ✅ |
| Promote（不健康） | 候选 FAILED，**在位代继续服务**（隐式回滚） | ✅ |
| Rollback | 目标重新 ACTIVE；日志记录 `SUCCESS` 回滚事实（含 `From`/`To`） | ✅ `TestSBRPUpdatePromoteRollback` |
| Revoke/卸载 | 目标版本不再可服务；终态被诚实上报 | ✅ |

## 要点（契约）

- 回滚目标必须**先探活**再回到服务：探活失败则记录 `FAILED`，不会"声称 ACTIVE"。
- 回滚是**更新平面**的能力，不是 SBRP 操作；`/sbrp` 只暴露 describe/apply/report/revoke。

## 判据

`PASS` 表示上述断言在真实 host + 真实 journal 下成立；报告写入 `_reports/plugin-rolling-update.json`。
