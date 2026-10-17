# Case 04 — axond bridge 部署态 E2E（R6 主场景）

**目的**：验证 `axond bridge → adapters/rheovela → Rheovela`，且认证走**真实 AEGIVELA 断言**。
**前置**：[Case 03](03-rheovela-jwks.md) 通过（Rheovela 健康且已发布 `expense`）。

## 启动 axond

```
AXON_PORT=1867, AXON_API_KEY=dev-key                 # bridge 路由是 Admin 级，需管理员凭证
AXON_RHEOVELA_URL=http://127.0.0.1:1876
AXON_RHEOVELA_AUDIENCE=rheovela
AXON_AEGIVELA_URL=http://127.0.0.1:1886
AXON_AEGIVELA_TOKEN=<内部令牌>
AXON_AEGIVELA_TENANT_ID=tenant-dev                   # 缺此项 axond 启动即 fail-closed
AXON_WORKLOAD_BINDING_ID=<Case 02 的 BindingID>
AXON_WORKLOAD_CLIENT_ID=axond-dev
AXON_WORKLOAD_REF=axond
AXON_WORKLOAD_SUBJECT_REF=axond-dev-subject
AXON_WORKLOAD_ORG_ROOT=did:axisrobo:dev
```

## 预期可观测（启动即证明断言链路）

```
[axond] AEGIVELA policy service: http://127.0.0.1:1886 (audience=praxovela)
[axond] Orchestrator: Rheovela (http://127.0.0.1:1876, audience=rheovela)
[axond] HTTP/SSE listening on http://127.0.0.1:1867
```

**关键判据**：`Orchestrator: Rheovela` 只在 `orch.Health()` 成功后打印，而该健康调用要用刚签发的 AEGIVELA 断言完成认证——所以**这一行出现即代表断言链路打通**。失败时 axond 直接退出（fail-closed，不会"无编排器继续跑"）。

## bridge 调用（`Authorization: Bearer dev-key`）

```powershell
$H = @{ Authorization='Bearer dev-key'; 'Content-Type'='application/json' }
$inst = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:1867/v1/instances -Headers $H `
  -Body '{"workflow":"expense","project":"e2e-proj","actor":"e2e-operator"}'
Invoke-RestMethod -Method Get  -Uri "http://127.0.0.1:1867/v1/instances/$($inst.instance_id)" -Headers $H
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:1867/v1/instances/$($inst.instance_id)/steps" -Headers $H `
  -Body '{"action":"enter","stage":"validate","actor":"e2e-operator"}'
Invoke-RestMethod -Method Get  -Uri "http://127.0.0.1:1867/v1/instances/$($inst.instance_id)/audit" -Headers $H
```

## 实测结果（2026-10-16，通过）

| 调用 | 结果 |
| --- | --- |
| `POST /v1/instances` | 实例 `be8b0967-52bf-4fbb-8889-91013d3c30e1`，`status=active` |
| `GET /v1/instances/{id}` | `status=active`，`definition_id=expense` |
| `POST /v1/instances/{id}/steps` | `{"status":"ok"}` |
| `GET /v1/instances/{id}/audit` | 审计链接口可用 |

## 本 case 暴露的缺陷（已修，见 [Case 05](05-failure-cases.md)）

1. aegivela-open identity SDK 未发可信权威头 → 断言签发 401 → axond 报 `credential: unauthenticated`。
2. 断言 TTL 默认 10 分钟 > 服务端上限 5 分钟 → `credential: invalid authorization input`。

## 边界（本 case 未覆盖）

- 业务 work-item → effect → outcome 闭环（含重试/取消），以及 Rheovela worker 循环；
- 未配置 Rheovela 时的 501（`rheovela_not_configured`）属于**预期行为**，只有把 `AXON_RHEOVELA_URL` 真正设进 axond 进程才会走本 case。
