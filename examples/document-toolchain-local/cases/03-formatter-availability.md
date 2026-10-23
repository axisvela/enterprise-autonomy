# Case 03 — 格式化可用性判定

**跑法**：`go test ./internal/format -run Test`（模块 `packages/axon-core`）

| 检查 | 期望 |
| --- | --- |
| 已注册但未安装的 formatter | `Detect` 返回不可用，不误报成功 |
| 已安装的 formatter | 按扩展名命中并返回可用 formatter |
| 未知扩展名或文件 | 返回“无 formatter”，不视为错误 |
| `AllAvailable` | 只列出实际可执行文件存在的 formatter |
| `List` | 保留完整注册表，不受本机安装状态影响 |
| 命令模板 | 按字段拆分，`$FILE` 作为参数替换，不经过 shell 解析 |
| 路径含 shell 元字符 | 不触发命令注入，路径作为单个参数传递 |

**要点**：可用性必须可查询，并与本机实际安装状态一致；缺少工具是可表达的状态，
不是异常，更不能把“未找到 formatter”伪装成格式化成功。
