# RUN-RECORD — compliance-audit-local（按 case）

## 已执行（2026-10-16，本地全栈）

| 项 | 内容 |
| --- | --- |
| 命令 | `. .\local.env.ps1` → `.\start-services.ps1` → `.\run-*.ps1` → `.\verify.ps1`（即 `.\run-all.ps1`） |
| 环境 | PostgreSQL 18.1 `localhost:5433`（库 symbivela/orchadyn/moduregis）；核心服务 limenora-edge 1896 · ontovela 1856 · rheo 1876 · symbivela 1926 · axond 1866 · orchadyn 1816 · moduregis 1806 + 本 demo 的 `*-domain` 适配器 |
| 结果 | **VERIFY OK**（10/10） |
| 关键观测 | evidence_artifacts=15 · steps_completed=8 · gates_passed=4 · time_to_resolve=0.4 · products_involved=5 |
| 证据 | `.local-data/compliance-domain-data.json`、`.local-data/compliance-outcome.json`、`.local-data/compliance-value-report.json`（本地产物，git-ignore） |

## 为跑通所做的最小修复（共享，已提交）

- Rheovela workflow 发布：`rheo workflow define` 只写 CLI 本地库（非运行中服务端的 `--db`），已在 run 脚本追加一次 `POST /api/v1/workflows`。
- `verify.ps1`：Windows PowerShell 5.1 下 `(单对象管道).Count` 为 ` $null `（PS7 为 1），已包 `@(...)`。

## 未覆盖（不声称）

- 部署拓扑：单机本地开发栈；
- 本 demo 的 verify 门通过；断言前已 `POST /v1/twins` 注册主体（未注册会 fail-closed）；Orchadyn 计划生成为空的告警在部分环境可能出现，不阻断门，详见 `.local-data` 报告。
