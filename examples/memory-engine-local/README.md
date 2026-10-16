# memory-engine-local

展示**记忆引擎**这一层的契约与客户端行为：OSS 安全契约（含 `NoOpMemoryEngine` 降级）、
Mnemovela 客户端（记录/检索）、以及**服务间令牌源**（断言作为 S2S 凭证）。

## 为什么是套件驱动

记忆是被 ADR-006 拆出的独立契约模块（`packages/contracts/memory`）+ 适配器（`packages/adapters/mnemovela`），
两者都有自己的测试；契约的"降级"语义必须在**不接服务**时也能成立。本例子驱动这些套件并记录结果。

## 跑

```powershell
Copy-Item local.env.ps1.example local.env.ps1   # 改 PRAXOVELA_DIR
. .\local.env.ps1
.\verify.ps1          # 跑固定套件，写 _reports/memory-engine.json
```

| Case | 套件 |
| --- | --- |
| 01 契约与 NoOp 降级 | `packages/contracts/memory`（`NoOpMemoryEngine` 各方法 + 类型常量 + 引擎契约） |
| 02 Mnemovela 客户端 | `packages/adapters/mnemovela`（Record/Search/TokenSource） |

## 覆盖与不覆盖

**覆盖**：契约形状与常量；`NoOpMemoryEngine` 在无后端时的安全降级（不 panic、不返回伪造数据）；
客户端对后端的调用形状；**S2S 令牌源**（经 AEGIVELA 断言，而非静态密钥）。

**不覆盖**：真实 Mnemovela 服务的端到端检索质量/延迟；**scope 传播**（R7 待办：企业记忆的
租户/项目作用域必须端到端传递）；并发写入。
