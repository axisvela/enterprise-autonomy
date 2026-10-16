# document-toolchain-local

展示**文档工具�?*：解析（多格式→文本/结构）、生成（模板→文档）、渲染（Markdown/LaTeX/Mermaid�?及其**降级语义**（缺外部工具时如何表现，而不是假装可用）�?
## 为什么是套件驱动

工具链的行为高度依赖本机是否装了外部工具（pandoc 等）�?能不能用"必须�?*显式可用性判�?*表达�?而不是靠运行时报错。产品已把这些判定与降级路径写成测试，本例子驱动它们并按 case 记录�?
## �?
```powershell
. .\local.env.ps1     # copy from local.env.ps1.example，改 PRAXOVELA_DIR
.\verify.ps1          # 跑固定套件，�?_reports/document-toolchain.json
```

| Case | 套件 |
| --- | --- |
| [01 解析与降级](cases/01-parse-and-fallback.md) | `packages/janus-gateway/internal/parser -run Test` |
| [02 生成与渲染](cases/02-generate-and-render.md) | `packages/janus-gateway/pkg/adapters -run TestDoc` |
| [03 格式化可用性判定](cases/03-formatter-availability.md) | `packages/axon-core/internal/format -run Test` |

## 覆盖与不覆盖

**覆盖**：不支持/缺失输入�?*拒绝**（缺文件、无扩展名）；pandoc 缺失�?*显式标记不可�?*而不是崩溃或假成功；
Markdown/LaTeX 内容保真；docx 回退路径；文档信�?文本/计数/差异/模板适配器�?
**不覆�?*：真�?Office 套件的二进制往返保真（依赖已安装的 pandoc/LibreOffice 等）�?大文件与并发解析吞吐、渲染产物的视觉一致性�?