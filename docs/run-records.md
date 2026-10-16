# Run Records — 按 case 记录"哪些例子真的跑过"

`docs/demo-matrix.md` 说明哪些例子**可运行**；本页按 case 记录**实际执行过什么**、
观测结果、证据位置与结论。规则：可运行 ≠ 已运行；报告逐字引用；不得引用磁盘上不存在的产物。

生成物统一放在 `examples/_reports/`（下划线前缀 = 本地产物，已 git-ignore；
此前叫 `examples/.stack/`，隐藏目录 + 名字与实际内容不符，故改名）。

---

## Case R1 — FP-1 联邦呈现（`agent-federated-presentation-local`）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（4/4） |
| 运行时间 | 2026-10-13 20:44（value report）／2026-10-14 09:08（live report），内容字节相同 |
| 环境 | 本地 PostgreSQL `5433`、NOMIVELA `1956`、EIDOVELA `1966`、LIMENORA `1897`；由 `adapters/presentation-client` 驱动 |
| 结果 | FP-01 `200, proofs stripped`；FP-02 `407`；FP-05 `407`（重放被拒）；FP-07 拒绝且上游未触达 |
| 证据 | 本地 `.local-data/fp1-{value,live}-report.json`（git-ignore） |
| 记录 | [examples/agent-federated-presentation-local/RUN-RECORD.md](../examples/agent-federated-presentation-local/RUN-RECORD.md)（按 case 分节） |
| 结论 | 证明"合法凭据+双证明→上游且剥离证明"与三条拒绝路径；不含吊销 SLO、外部 IdP、失败矩阵 |

## Case R2 — 业务 demo 汇总 dashboard（`scripts/report-value.ps1`）

| 项 | 内容 |
| --- | --- |
| 状态 | ⚠️ 已执行但**无结果**（不算通过） |
| 运行时间 | 2026-10-12 19:29 |
| 结果 | `examples/_reports/all-demos-report.json` 内容为 `{"generated_at":"…","demos":[]}` —— **demos 为空** |
| 记录 | 本页 |
| 结论 | 该次汇总既未通过也未失败任何 demo；必须由后续汇总运行替换，**不得作为证据引用** |

## Case R3 — 13 个业务 demo（可运行，但无执行记录）

| 项 | 内容 |
| --- | --- |
| 状态 | ❌ 本工作区**无执行证据** |
| 依据 | [demo-matrix.md](demo-matrix.md) 中每个 demo 声称产出 `*-value-report.json`，但磁盘上不存在这些报告（仅存在 Case R1 的 FP-1 报告与 Case R2 的空 dashboard） |
| 如何变成"有记录" | 逐个运行 `run-all.ps1`（或整体 `scripts/report-value.ps1`），把产出的报告按 Case R1 的格式落成各例子自己的 `RUN-RECORD.md`，并回到本页加一行 |
| 结论 | 代码/适配器/脚本与设计文档齐备，但"跑过"这件事目前只是**声称** |

## Case R4 — R6 bridge 本地 bring-up（`agent-workflow-bridge-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（4 个场景 case） |
| 运行时间 | 2026-10-16 |
| 结果 | axond 启动日志出现 `Orchestrator: Rheovela`（该行只在真实 AEGIVELA 断言认证成功后打印）；`POST /v1/instances` → 实例 `active`；`GET /v1/instances/{id}` → `active`/`definition_id=expense`；`POST .../steps` → `ok`；`GET .../audit` → 通 |
| 失败/负向 | F1 SDK 缺权威头→401（已修）、F2 断言 TTL 超限→400（已修）、F3 `evidence_ref` 形状（绕行）、F4 缺租户→fail-closed、F5 health 200≠认证通过、F6 漏设 env→501、F7 无凭证远程监听被拒 |
| 记录 | [examples/agent-workflow-bridge-local/cases/](../examples/agent-workflow-bridge-local/cases/)（cases 01–05） |

---

## Case R5 — 插件滚动更新与回滚（`plugin-rolling-update-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（4 个场景 case，套件驱动） |
| 运行时间 | 2026-10-15 / 2026-10-16 |
| 结果 | promote+rollback（journal `SUCCESS` 事实）、`Assembly.RollbackPlugin`（恢复并在位代可再次 invoke）、生产管理器发布失败回滚（共享套件对**两个**管理器断言）、Apply 受管同表、部署进程生命周期 E2E（step-01..13） |
| 为什么是套件驱动 | 治理 HTTP 面仅在装配控制面时挂载，且真实包需签名+artifact+信任根；能力本身在真实 host/journal 下已可完全覆盖 |
| 记录 | [examples/plugin-rolling-update-local/](../examples/plugin-rolling-update-local/)（cases 01–04 + RUN-RECORD） |

---

## Case R6 — 身份与角色判定（`identity-auth-local`，新增）

| 项 | 内容 |
| --- | --- |
| 状态 | ✅ 已执行并通过（3 个场景 case，套件驱动） |
| 运行时间 | 2026-10-16 |
| 结果 | 无/错凭证 `401`、本地回退只给最低角色、审批缺决策 `400`（不默认批准）、插件 toggle 畸形 body `400`、角色层级与空/未知角色拒绝、跨租户 `404`、**远程无凭证拒绝启动** |
| 记录 | [examples/identity-auth-local/](../examples/identity-auth-local/)（cases 01–03 + RUN-RECORD） |

---

## Case R7 — 负载矩阵（`praxovela-e2e`，**未执行**）

| 项 | 内容 |
| --- | --- |
| 状态 | ❌ 未执行（门槛与跑法已定义） |
| 门槛 | 1/8/32 并发档、每档 ≥20 样本、每档 p99 < 5s、报告 workload/load/sample count |
| 记录 | [demo-repository/praxovela-e2e/LOAD-MATRIX.md](../../demo-repository/praxovela-e2e/LOAD-MATRIX.md)（Case C7） |

---

## 如何记录新运行（规范）

1. 运行例子（`run-all.ps1`）或汇总（`scripts/report-value.ps1`）。
2. 在该例子写/更新 `RUN-RECORD.md`，**按 case 分节**：日期、环境/端口、逐字报告、
   证明了什么、没证明什么。
3. 回到本页对应 case 补一行（状态/时间/结果/证据位置）。

报告不得总结掉 skip 或 fail；不得引用磁盘上不存在的报告；本地产物放 `examples/_reports/` 或各例子的 `.local-data/`。
