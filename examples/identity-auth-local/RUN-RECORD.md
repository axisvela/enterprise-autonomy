# RUN-RECORD — identity-auth-local（按 case）

## 已执行（2026-10-16，PRAXOVELA core）

| Case | 命令 | 结果 |
| --- | --- | --- |
| 01 凭证与暴露守卫 | `go test ./internal/bridge -run 'TestValidateExposure\|TestApproval\|TestTogglePlugin'`、`go test ./internal/config` | ✅ 通过 |
| 02 角色与作用域 | `go test ./internal/bridge -run 'Role\|Scope\|Tenant'`、`go test ./internal/identity` | ✅ 通过 |
| 03 远程监听拒绝启动 | `go test ./internal/bridge -run TestValidateExposure` | ✅ 通过（远程无凭证报错拒绝启动） |

同批证据（同会话，EE 侧）：EE `executions` 的 RBAC 用例（viewer 不能创建、缺角色不能变更、未知角色拒绝、
跨租户保持 `404`、operator 不能 revoke）在 `packages/axon-core-ee/executions` 套件中全绿。

## 如何刷新

```powershell
. .\local.env.ps1
.\verify.ps1      # 重跑上表套件，写入 _reports/identity-auth.json
```

## 未覆盖（不声称）

- 真实 IdP/OIDC 登录与会话（需外部身份提供方；本例子只覆盖令牌服务与边界判定）；
- 组织级委托/职责分离（EE 管理面）；
- 并发下的令牌校验吞吐。
