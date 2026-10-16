# identity-auth-local

展示**身份与角色判定**这一层：操作员凭证 → 作用域（租户/工作区）→ 角色 → 拒绝语义，
以及"没有凭证就不能暴露到网络"的启动守卫。

## 为什么是套件驱动

身份链路的关键行为是**拒绝语义**（`401` / `403` / `404` / 拒绝启动），这些在 HTTP 边界上最容易被
"看起来能用"掩盖；产品自身已把它们写成测试。本例子驱动这些套件并把结果按 case 记录，
而不是再造一个需要控制面的 HTTP demo。

## 跑

```powershell
. .\local.env.ps1     # copy from local.env.ps1.example，改 PRAXOVELA_DIR
.\verify.ps1          # 跑固定套件，写 _reports/identity-auth.json
```

| Case | 套件 |
| --- | --- |
| [01 凭证与暴露守卫](cases/01-credentials-and-exposure.md) | `internal/bridge -run 'TestValidateExposure\|TestApproval\|TestTogglePlugin'`、`internal/config` |
| [02 角色与作用域](cases/02-role-and-scope.md) | `internal/bridge -run 'Role\|Scope\|Tenant'`、`internal/identity` |
| [03 远程监听拒绝启动](cases/03-remote-listen-refused.md) | `internal/bridge -run TestValidateExposure`（反向：远程无凭证必须报错） |

## 覆盖与不覆盖

**覆盖**：无/错凭证 `401`；空角色与未知角色拒绝；跨租户按"不存在"处理；审批响应必须带显式决策；
非回环监听在无凭证时**拒绝启动**；令牌服务（JWT 签发/校验/过期）。

**不覆盖**：真实 IdP/OIDC 登录（需外部身份提供方）、组织级委托与 SoD（EE 管理面）、
并发下的令牌校验吞吐。角色矩阵的产品归属见
`PRAXOVELA-EE/docs/editions/README.md`，安全前提见 `threat-model.md`。
