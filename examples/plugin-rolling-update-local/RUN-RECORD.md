# RUN-RECORD — plugin-rolling-update-local（按 case）

## 已执行（2026-10-15 / 2026-10-16，PRAXOVELA core）

| Case | 命令 | 结果 |
| --- | --- | --- |
| 01 promote and rollback | `go test ./internal/pluginruntime -run TestSBRP` | ✅ 通过（含 `TestSBRPUpdatePromoteRollback`，journal 记录 `SUCCESS` 回滚事实） |
| 02 post-publish rollback | `go test ./internal/pluginruntime -run TestRollbackPlugin`、`go test ./internal/governance -run TestRuntimeManagerConformance` | ✅ 通过（`RollbackPlugin` 恢复 1.0.0 并可再次 invoke；共享套件对两个管理器断言"保留在位代"） |
| 03 apply unification | `go test ./internal/pluginruntime -run TestApply`、`go test ./internal/governance -run 'Rollback\|Update\|Promote'` | ✅ 通过（Apply 产生受管实例；Disable 可操作） |
| 04 deployed lifecycle E2E | `go test ./cmd/axond -run TestGovernanceProcessLifecycleE2E` | ✅ 通过（step-01..13，含更新/审批/隔离/卸载/重启不复活） |

## 相关独立证据（同会话）

- R5 官方 SBRP 一致性：官方 `syndovela-cli conform` 报告 **conformant**（10/12 executed 全过、2 wire-N/A、0 失败）
  —— 报告在 `PRAXOVELA-EE/docs/assessments/2026-10-16-sbrp-conformance-axond-inline.json`；
- 生产发布失败回滚：核心 `3dde504`（`Assembly.RollbackPlugin` + 生产管理器接线）；
- Apply 统一：核心 `46bda96`；生产 host 选择：核心 `44143e6`。

## 如何刷新本记录

```powershell
. .\local.env.ps1
.\verify.ps1        # 重新跑上表套件，写入 _reports/plugin-rolling-update.json
```

`_reports/` 为 git-ignore；数字与结论若变化，请更新本文件与
`enterprise-autonomy/docs/run-records.md` 的对应 case 行。

## 未覆盖（不声称）

- 通过治理 HTTP 面安装**已签名**包（需 SYNDOVELA + 信任根 + artifact）；
- 跨主机放置与节点面调度；
- 并发负载下的升代/回滚时延。
