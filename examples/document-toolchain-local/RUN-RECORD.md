# RUN-RECORD — document-toolchain-local（按 case）

## 已执行（2026-10-16，本机）

| Case | 命令 | 结果 |
| --- | --- | --- |
| 01 解析与降级 | `go test ./internal/parser -run Test`（janus-gateway） | ✅ PASS（`ok … internal/parser 2.142s`） |
| 02 文档适配器 | `go test ./pkg/adapters -run TestDoc`（janus-gateway） | ✅ PASS（`ok … pkg/adapters 2.107s`） |

原始报告：`_reports/document-toolchain.json`（git-ignore，由 `verify.ps1` 生成）。

## 明确**未验证**（不是通过）

- **格式化工具可用性**（`internal/format`）：该包**没有测试文件**。首次运行 `verify.ps1` 时它返回
  `[no test files]`，而脚本会把它算作 PASS —— 这种"未验证却显示为绿"的情况已处理：
  case 文件被删除、该行从 `verify.ps1` 移除，并在脚本内留注释说明原因。
  形式化该能力需要先为 `internal/format` 补测试。

## 如何刷新

```powershell
. .\local.env.ps1
.\verify.ps1
```

## 未覆盖（不声称）

- 真实 Office 二进制往返保真（依赖已安装的 pandoc/LibreOffice 等）；
- 大文件与并发解析吞吐；渲染产物的视觉一致性。
