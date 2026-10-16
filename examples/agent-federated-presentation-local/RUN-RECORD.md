# FP-1 Run Record — federated presentation, local stack（按 case 记录）

`README.md` 说明怎么跑；本文件按 case 记录**实际观测到**的结果、时间与证据位置，
使 "passed" 可审计，而不是被推断。

两次运行的产物内容**字节相同**，以较晚的 2026-10-14 为当前记录，10-13 保留为历史。

---

## Case FP-01 — 合法凭据 + 双证明到达上游

| 项 | 内容 |
| --- | --- |
| 期望 | `200` |
| 观测 | `200, proofs stripped` |
| 结论 | ✅ 通过 —— 资源证明与内省证明在转发前被剥离，上游未见到证明材料 |
| 时间 | 2026-10-13 20:44 / 2026-10-14 09:08 |

## Case FP-02 — 缺资源证明被拒

| 项 | 内容 |
| --- | --- |
| 期望 | `407` |
| 观测 | `status 407` |
| 结论 | ✅ 通过 —— 缺证明不会降级为无证明转发 |

## Case FP-05 — 重放的资源证明 jti 被拒

| 项 | 内容 |
| --- | --- |
| 期望 | `407` |
| 观测 | `second use denied 407` |
| 结论 | ✅ 通过 —— 重放检测生效（同一 jti 第二次使用被拒） |

## Case FP-07 — 被禁用的 agent：拒绝且不降级、上游不受影响

| 项 | 内容 |
| --- | --- |
| 期望 | `deny, 0 upstream hits` |
| 观测 | `denied 407, upstream hits unchanged` |
| 结论 | ✅ 通过 —— provider 拒绝禁用 agent；无降级；上游命中数不变 |

---

## 环境

按本例子 `local.env.ps1` / FP-1 plan：本地 PostgreSQL `5433`、NOMIVELA `1956`、
EIDOVELA `1966`、LIMENORA `1897`，由 `adapters/presentation-client`（参考 PEP 客户端）
驱动，配合本目录的 start/verify 脚本。

## 证据与出处

| 产物 | 性质 |
| --- | --- |
| `.local-data/fp1-live-report.json` | 2026-10-14 运行产物（当前） |
| `.local-data/fp1-value-report.json` | 2026-10-13 运行产物（历史，内容相同） |

两者均在本例子目录内、**未提交**（`.gitignore`）。更广的同期证据见
`PRAXOVELA-EE/docs/assessments/2026-10-13-*`、`2026-10-14-*`。

## 未覆盖（不声称）

- 吊销时延/SLO 上界（另行测量）；外部 IdP / 联邦呈现；CA 失败、错误 issuer 等负向；
- 部署拓扑：这是单机本地开发栈，密钥材料本地生成。
