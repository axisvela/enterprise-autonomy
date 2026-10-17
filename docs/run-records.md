# Run Records — 按 case 记录"哪些例子真的跑过"

`docs/demo-matrix.md` 说明哪些例子**可运行**；本页按 case 记录**实际执行过什么**——观测结果、证据位置与结论。规则：可运行 ≠ 已运行；报告逐字引用；不得引用磁盘上不存在的产物。

生成物统一放在 `examples/_reports/`（下划线前缀 = 本地产物，已 git-ignore）。此前的 `examples/.stack/` 是隐藏目录，且名字与实际内容不符，故改名。

---

## Case R1 — FP-1 联邦呈现（`agent-federated-presentation-local`）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（4/4） |
| 运行时间 | 2026-10-13 20:44（value report）／2026-10-14 09:08（live report），两次产物内容字节相同 |
| 环境 | 本地 PostgreSQL `5433`、NOMIVELA `1956`、EIDOVELA `1966`、LIMENORA `1897`；由 `adapters/presentation-client` 驱动 |
| 结果 | FP-01 `200, proofs stripped`；FP-02 `407`；FP-05 `407`（重放被拒）；FP-07 拒绝且上游未触达 |
| 证据 | 本地 `.local-data/fp1-{value,live}-report.json`（git-ignore） |
| 记录 | [examples/agent-federated-presentation-local/RUN-RECORD.md](../examples/agent-federated-presentation-local/RUN-RECORD.md)（按 case 分节） |
| 结论 | 证明"合法凭据 + 双证明 → 上游且剥离证据"与三条拒绝路径；不含吊销 SLO、外部 IdP、失败矩阵 |

## Case R2 — 业务 demo 汇总 dashboard（`scripts/report-value.ps1`）

| 项 | 内容 |
| --- | --- |
| 状态 | ⚠️ 已执行但**无结果**（不算通过） |
| 运行时间 | 2026-10-12 19:29 |
| 结果 | `examples/_reports/all-demos-report.json` 内容为 `{"generated_at":"…","demos":[]}` —— **demos 为空** |
| 记录 | 本页 |
| 结论 | 该次汇总既未通过也未失败任何 demo；必须由后续汇总运行替换，**不得作为证据引用** |

## Case R3 — 13 个业务 demo（**13/13 已跑通**，2026-10-16）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ **13/13 已跑通**（每个 `verify.ps1` 报 VERIFY OK） |
| 环境 | PostgreSQL 18.1 `5433`（库 symbivela/orchadyn/moduregis）+ 核心服务（limenora-edge/ontovela/rheo/symbivela/axond/orchadyn/moduregis）+ 各 demo 的 `*-domain` 适配器 |
| 逐例记录 | 每例 `examples/<demo>/RUN-RECORD.md`（共 13 个） |
| 关键修复（共享） | ① Rheovela workflow 须 `POST /api/v1/workflows`（`rheo workflow define` 只写 CLI 本地库，非服务端 `--db`）；② `verify.ps1` 的 PS 5.1 `(单对象管道).Count` 须包 `@()` |
| 结论 | 13 个业务 demo 全部有真实、可审计的执行记录（本地单机栈） |

## Case R4 — R6 bridge 本地 bring-up（`agent-workflow-bridge-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 5 场景通过；2026-10-17 Case 06 **重试策略部署验证通过**（cancel 在 Rheovela API，axond 桥未暴露） |
| 运行时间 | 2026-10-16 / 2026-10-17 |
| 结果 | axond 启动日志出现 `Orchestrator: Rheovela`（该行只在真实 AEGIVELA 断言认证成功后打印）；`POST /v1/instances` → 实例 `active`；`GET /v1/instances/{id}` → `active`/`definition_id=expense`；`POST .../steps` → `ok`；`GET .../audit` → 通 |
| 失败/负向 | F1 SDK 缺权威头→401（已修）、F2 断言 TTL 超限→400（已修）、F3 `evidence_ref` 形状（绕行）、F4 缺租约→fail-closed、F5 health 200≠认证通过、F6 漏设 env→401、F7 无凭据远程监听被拒 |
| 部署态 work-item（Case 06） | `claim→complete` → `done`；`claim→fail` → 回队 `ready`（attempts=1）→ 重领 → `complete` → `done`；`max_attempts=1` 时终态 `failed`、重领 409；Rheovela 侧 `cancel` → `cancelled`。报告 `.local-data/fault-injection-report.json`（`retry_supported=true`）。结论：**重试策略已实现并在部署态验证**；cancel 在 Rheovela API，axond 桥尚未暴露 |
| 记录 | [examples/agent-workflow-bridge-local/cases/](../examples/agent-workflow-bridge-local/cases/)（cases 01–06） |

---

## Case R5 — 插件滚动更新与回滚（`plugin-rolling-update-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（4 个场景/case，套件驱动） |
| 运行时间 | 2026-10-15 / 2026-10-16 |
| 结果 | promote+rollback（journal `SUCCESS` 事实）、`Assembly.RollbackPlugin`（恢复并原位可再次 invoke）、生产管理器发布失败回滚（共享套件对**两个**管理器断言）、Apply 受管同表、部署进程生命周期 E2E（step-01..13） |
| 为什么是套件驱动 | 治理 HTTP 面仅在装配控制面时挂载，且真实包需签名 + artifact + 信任根；能力本身在真实 host/journal 下已可完全覆盖 |
| 记录 | [examples/plugin-rolling-update-local/](../examples/plugin-rolling-update-local/)（cases 01–04 + RUN-RECORD） |

---

## Case R6 — 身份与角色判定（`identity-auth-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（3 个场景/case，套件驱动） |
| 运行时间 | 2026-10-16 |
| 结果 | 无/错凭据 `401`、本地回退只给最低角色、审批缺决策 `400`（不默认批准）、插件 toggle 畸形 body `400`、角色层级与空/未知角色拒绝、跨租户 `404`、**远程无凭据拒绝启动** |
| 记录 | [examples/identity-auth-local/](../examples/identity-auth-local/)（cases 01–03 + RUN-RECORD） |

---

## Case R7 — 负载矩阵（`praxovela-e2e`，**已执行 2026-10-16，PASS**）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（共享栈 + N 路并发驱动器；一次启动 AEGIVELA+LIMENORA+PG） |
| 运行时间 | 2026-10-16 |
| 结果 | 档 1/8/32 × 每档 20 回合（20/160/640 样本）：p99 **17.1 / 17.4 / 262.8 ms**、max 451 ms、0 错误/超时、continuation 覆盖 20/20·160/160·640/640；每档 **PASS（p99 < 5s）** |
| 门槛 | 1/8/32 并发档、每档 ≥20 回合、每档 p99 < 5s、报告 workload/load/sample count |
| 证据 | [报告](../../demo-repository/praxovela-e2e/_reports/c7-load-matrix-20261016-212009.json) · [门槛与跑法](../../demo-repository/praxovela-e2e/LOAD-MATRIX.md)（Case C7） |

---

## Case R9 — 业务 demo 实跑尝试：**中断，无结果**（2026-10-16）

| 项 | 内容 |
| --- | --- |
| 尝试 | `examples/order-fulfillment-local/run-all.ps1`（start-services → 场景 → verify） |
| 结果 | 未产生任何结果：启动阶段缺少预构建服务二进制（本次报 `<...>\ONTOVELA\backend\ontovela.exe` 不存在），随后被中断；**不得计入"已运行"** |
| 残留清理 | 已停止本次留下的 `limenora-edge` 进程（pid 24176），无残留监听 |
| 准备条件 | 按各 demo 的 `operations-guide.md` / `start-services.ps1` 先构建所需服务二进制（Ontovela、Rheovela、Symbivela、Moduregis、Praxovela AXON，可选 Orchadyn），并配好 `local.env.ps1` |
| 影响 | 13 个业务 demo 仍为"**可运行但无执行记录**"（见本页 Case R3） |
| 后续（2026-10-16） | 同日该 demo 已**跑通**（VERIFY OK 11/11）。根因：`$AxisRoboHome` 布局不匹配（仓库在 `axis-vela\` 下）+ 缺 PG 库 `symbivela`/`orchadyn`/`moduregis` + 两处脚本 bug（Rheovela workflow 发布到错误库、verify 的 PS5.1 `.Count`）。见 [examples/order-fulfillment-local/RUN-RECORD.md](../examples/order-fulfillment-local/RUN-RECORD.md) |

---

## 如何记录新运行（规范）

1. 运行例子（`run-all.ps1`）或汇总（`scripts/report-value.ps1`）。
2. 在该例子写/更新 `RUN-RECORD.md`，按 case 分节：日期、环境/端口、逐字报告、证明了什么、没证明什么。
3. 回到本页对应 case 补一行（状态/时间/结果/证据位置）。

报告不得总结掉 skip 或 fail；不得引用磁盘上不存在的报告；本地产物放 `examples/_reports/` 或各例子的 `.local-data/`。