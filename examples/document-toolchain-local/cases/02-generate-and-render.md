# Case 02 — 文档适配器（信息/文本/计数/差异/模板）

**跑法**：`go test ./pkg/adapters -run TestDoc`（模块 `packages/janus-gateway`）

| 检查 | 期望 |
| --- | --- |
| `doc.info` | 返回文档元信息；文件缺失时**报错**而不是返回空对象 |
| `doc.text` / `doc.count` | 抽取文本、计数（供上层做摘要/校验） |
| `doc.diff` | 两版差异可读 |
| `doc.template` | 模板渲染产出文件 |

**要点**：适配器只做"取用与呈现"，不做授权判断；失败必须显式返回错误（与本次会话在
`doc.open` 上修掉的 shell 元字符守卫一致——**路径来自数据时不得进入 shell 解析**）。
