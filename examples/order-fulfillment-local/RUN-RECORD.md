# RUN-RECORD — order-fulfillment-local（按 case）

## 已执行（2026-10-16，本地全栈）

| 项 | 内容 |
| --- | --- |
| 命令 | `. .\local.env.ps1` → `.\start-services.ps1` → `.\run-order-exception.ps1` → `.\verify.ps1`（即 `.\run-all.ps1`） |
| 环境 | PostgreSQL **18.1** `localhost:5433`（库 `symbivela`/`orchadyn`/`moduregis`）；limenora-edge `1896`、ontovela `1856`、rheo `1876`、symbivela `1926`、axond `1866`、orchadyn `1816`、moduregis `1806`、order-domain `8090`、inventory-domain `8091` |
| 结果 | `All local services are ready.` → 8 步业务场景完成 → **`VERIFY OK`（11/11 全通过）** |
| 关键观测 | 订单 `stockout → replanned`；`warehouse-a → warehouse-b`；审批 `operations-lead / approval://order-123-stockout`；7 产品 · 2 gate · 9 evidence · 8 步 · 0.5s |
| 证据 | `.local-data/order-outcome.json`、`.local-data/order-value-report.json`（本地产物，git-ignore） |

## 为跑通所做的最小修复（本目录，已提交）

- `run-order-exception.ps1`：`rheo workflow define` 只写入 **CLI 自己的本地库**（`~/.proc/proc.db`），并非运行中服务端的 `--db`（`.local-data/rheovela.db`）。因此第 4 步报 `workflow not found: order-exception`。修复：在第 57 行之后追加一次 HTTP 发布 `POST http://localhost:1876/api/v1/workflows`（引擎的文档化管理调用）。
- `verify.ps1`：两条断言写成 `($report.evidence | Where-Object {…}).Count`；**Windows PowerShell 5.1** 下单对象管道结果的 `.Count` 为 `$null`（PS7 为 1），导致误报 FAIL。修复：改为 `@(…).Count`。

## 环境准备（本机，仓外）

- 建 PG 角色与库：`symbivela`/`orchadyn`/`moduregis`（登录名=库名，密码同名）。
- `$AxisRoboHome` 指向 `D:\profile\paper-code`，但仓库实际在 `D:\profile\paper-code\axis-vela\`：在 `paper-code\` 下建 junction `ONTOVELA`/`RHEOVELA`/`SYMBIVELA`/`PRAXOVELA` → `axis-vela\` 对应目录（`local.env.ps1` 无需改）。
- PG 18 客户端用 `D:\app\pgAdmin 4\runtime\psql.exe`（`pgsql17-mingw` 的 psql 缺入口点，报 0xC0000139）。

## 非致命错误（保留、不声称已消除）

- Step 1：断言前已 `POST /v1/twins` 注册 `order-123`（2026-10-16 修复）；未注册时 Ontovela 会 fail-closed（`not found: subject twin`）。
- Step 6：axond `POST /v1/agent/tools/execute` → `not found` / `bad request: session_id and call are required`（agent 会话未建立）；场景仍记录 `effect-ledgered` 并继续。
- `start-services.ps1:108` moduregis-migrate 的进度输出以 stderr 呈现（PowerShell 记为错误），迁移实际成功。

## 未覆盖（不声称）

- 其余 12 个业务 demo 的运行记录维护在私有仓 `enterprise-autonomy-ee/operations/run-records.md` Case R3；
- 部署拓扑：本记录是单机本地开发栈。
