# AI 模型与功能设置

AI 设置将提供商配置与功能设置分开。

| 区域 | 用途 |
| --- | --- |
| LLM models | 选择 Ollama、Codex integration、OpenAI API 或 DeepSeek API，并配置模型。 |
| Decision models | 内置 `gpt-6-luna`，只需配置独立 API Key，无需填写模型名称。 |
| Title generation | 控制缺失标题自动补全；生成标题始终使用选中的 LLM provider。 |
| Question checking | 选择使用 LLM models 或 Decision models 判断是否需要用户回应。 |

## 配置与认证

没有 AI 配置文件时，默认使用现有 Ollama 模型与普通 LLM 判断方式。原有本地模型选择和标题补全开关继续保存在 `LocalLLM/configuration.json`，无需迁移或重新选择。

新的提供商配置保存在用户 Application Support 下的 `iTermate/AI/configuration.json`。应用写入时加锁、重读并合并目标字段，再原子写回。配置损坏或不可读时不覆盖文件，也不自动切换提供商。每次推理读取配置，结果发布前再次核对，配置已改变则丢弃旧结果。

OpenAI、DeepSeek 与 Decision 的密钥分别保存在 macOS Keychain 的 `com.caishilin.iTermate.ai` 服务中，账户名为 `openai`、`deepseek` 和 `decision`。普通模型与决策模型可以使用不同密钥。密钥仅由 iTermate App 读取，Pi 不再启动 `security` 或接收密钥。Pi 的 OpenAI、DeepSeek 和 Decision 请求经本机 Unix socket 交给运行中的 App 代理，目标地址由 App 固定，不接受客户端提供的地址。socket 目录权限为 `0700`，socket 为 `0600`，仅供同一用户访问；客户端检查属主与权限。密钥不写进共享 JSON、日志或命令参数。

所有后台密钥读取都使用非交互模式：钥匙串锁定或当前 App 无权访问时，请求直接失败，不弹出授权窗口。需要恢复访问时，在 AI 设置中主动重新保存对应 API Key；保存操作仍可能要求系统授权。Pi 远程 AI 需要新版 App 正在运行；App 不可用、socket 权限异常或凭据不可访问时，不回退命令行读取、不切换提供商。单个请求最多接收 64 KiB，最多同时处理四个请求；取消客户端请求也会取消 App 所拥有的提供商任务。

- **OpenAI API**：填写可访问且支持 Responses API 的模型 ID，调用 `https://api.openai.com/v1/responses`，请求设置 `store: false`。
- **DeepSeek API**：填写支持聊天接口的模型 ID，调用 `https://api.deepseek.com/chat/completions`。
- **Codex integration**：应用自动检测本机 Codex CLI 并在设置中显示路径，无需手动填写；仍可输入绝对路径覆盖检测结果，清空后恢复自动检测。检测依次检查用户的 mise 稳定 shim、进程 PATH、常用本地与 Homebrew 目录及 Codex 应用资源目录，不启动登录 shell。已有手动路径即使失效也不会悄悄替换。可选填写模型。使用 CLI 已有登录；先通过 `codex login` 完成认证。要求 CLI 支持 `--ignore-user-config`、`--ephemeral` 等参数。生成在临时目录执行，不读取项目说明，不启用 shell、子 Agent、hooks 或网页搜索；不保留会话文件。不支持参数或认证失败时明确失败，不切换到其他提供商。
- **Ollama**：继续支持 Qwen3.5 · 2B 与 4B。`Deploy Selected Model…` 由用户主动触发下载，要求先安装 Ollama 运行时；应用不自动安装运行时。下载完成后使用 `Check & Warm Model` 核对库存身份并预热。

模型通过 **Choose Model** 菜单从本机 Codex 的 `models_cache.json` 读取，可继续手动填写 Model ID；`CODEX_HOME` 存在时使用对应目录，否则使用 `~/.codex`。目录可能过期，不代表当前账号一定可用；缺少缓存时仍可输入 ID 或使用 **Codex Default**。

**Thinking level** 根据选中模型的本地能力信息提供选项，也可保留 **Codex Default**。设置持久化为可选的 `codexThinkingLevel`，旧配置缺少该字段时保持默认。切换模型会重置思考等级，避免沿用前一模型的值。Swift 与 Pi 调用均将模型作为 `--model`、思考等级作为 `-c model_reasoning_effort="..."` 传给 CLI；默认选项不传对应覆盖值。此设置同时适用于标题和使用 Codex 的 LLM 问题判断。

每次生成或判断都启动独立的临时 CLI 会话；标题的再次概括也会重新调用。`--ephemeral` 不保留 CLI 会话文件，执行目录和输入输出文件在结束后清理，不复用用户当前交互会话。现有调用以 `--ignore-user-config` 忽略 CLI 配置文件，因此显式选择的模型和思考等级由 iTermate 传入。

远程模型 ID 不预填，避免把示例型号当作永久有效的默认值。填写模型 ID 并保存密钥后，应通过测试菜单确认账号访问能力。

## 远程模型列表与思考设置

在 **LLM models** 选择 OpenAI API 或 DeepSeek API 后，先保存密钥，再点击 **Fetch Models**。应用用对应 Keychain 账户请求官方模型目录：OpenAI 为 `GET https://api.openai.com/v1/models`，DeepSeek 为 `GET https://api.deepseek.com/models`。请求不包含会话，不发起文本生成。获取有十五秒总截止；状态、数量和错误显示在按钮旁，失败不改选中的模型。目录请求不等待 Keychain 交互授权：若已有密钥需要额外权限，会提示在当前应用重新保存并允许访问后重试。

获取成功后，**Choose Model** 提供 API 可见的文本模型候选，也可继续手动输入 **Model ID**。列表过滤声明不支持文本输入或输出的模型及已知图像、音频、向量等专用型号；目录可见不保证所有端点都兼容。列表只在本次应用运行期间缓存。重新保存密钥会清空该提供商的旧列表，切换提供商会取消旧请求；迟到响应不能覆盖新状态。

**Thinking level** 随所选模型变化，**Provider Default** 不传任何思考覆盖参数。换模型重置为默认，避免把上一模型的配置带入新模型。能力与选择按提供商、模型绑定保存在可选的 `remoteThinking` 字段；旧配置缺少此字段时继续使用默认。

- **OpenAI**：`/models` 只提供基本模型信息，不包含完整 reasoning 能力。应用根据已核对的官方型号说明提供选项，例如 `gpt-6.1-sol` 和 `gpt-6-astra` 使用 `low/medium/high/xhigh/max`，`gpt-5.6-sol` 还支持 Off（`none`）。未知型号只保留默认，不借用 Codex 的能力信息。请求使用 `reasoning: {"effort": "..."}`。
- **DeepSeek**：优先读取目录中的 `effort.supported_levels`。目录未提供时，仅对已核对的 `deepseek-flash`、`deepseek-v4-pro` 使用官方等级；未知型号只保留默认。Off 发送 `thinking: {"type": "disabled"}`，其他选项发送 `thinking: {"type": "enabled"}` 和 `reasoning_effort`。不把 OpenAI 的字段直接用于 DeepSeek。

OpenAI 当前已核对的选项如下；对应日期快照沿用同一基础型号说明，未知变体不猜测。

| 型号 | 可选 effort（另有 Provider Default） |
| --- | --- |
| `gpt-6-astra`、`gpt-6.1-sol` | low、medium、high、xhigh、max |
| `gpt-6-sol`、`gpt-6-luna`、`gpt-6.1-terra`、`gpt-5.6`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna` | none、low、medium、high、xhigh、max |
| `gpt-5.5` | none、low、medium、high、xhigh |
| `gpt-5` | minimal、low、medium、high |

标题生成、LLM 问题判断和对应固定示例测试使用相同的思考设置。高等级可能增加延迟及用量，尤其可能超过问题判断原有的十秒预算；失败处理不因此改变。只有最终可见文本被用于标题或分类，不把推理内容展示或传入后续请求。

能力说明核对日期：2026-11-13。官方接口和型号能力可能变化，模型列表本身不等于运行验证。

参考：[OpenAI 模型列表](https://developers.openai.com/api/reference/resources/models/methods/list)、[OpenAI reasoning](https://developers.openai.com/api/docs/guides/reasoning)、[GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)、[GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)、[GPT-5.6 Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol)、[DeepSeek 模型列表](https://api-docs.deepseek.com/api/list-models)、[DeepSeek thinking](https://api-docs.deepseek.com/guides/thinking_mode)。

## 标题与问题判断

标题生成覆盖 Pi 会话与应用监控的 Codex 会话。输入仍限于已提取的用户和助手可见文本，不新增隐藏思考或工具输出。标题须非空、单行且不超过 80 个 Unicode 标量；不合格时最多再概括一次。失败保留已有标题，不调用其他提供商。

问题判断的默认方式为 **LLM models**：使用选中的 LLM provider，严格解析仅含 `label` 字段的 `question` 或 `normal` JSON。原有判断提示词继续用于 Pi 实际回复分类。

选择 **Decision models** 后，固定使用 `gpt-6-luna`（旧配置中的模型名称不再影响请求），调用 `https://api.openai.com/v1/decisions`，使用单个 `predicate` 问题判断回复是否要求用户回答、选择、确认、授权或提供必要信息。仅接受一个合法答案和有限的 `[0, 1]` 数值概率，布尔值不作为概率。概率大于等于 `0.5` 表示需要回应。概率是模型输出，不代表已验证的准确率。

两条判断路径沿用同一个十秒总截止与生命周期取消机制。超时、不可用或无效结果保留原有 `normal` 默认值，不启用其他模型作为后备。明确的 UI 等待、运行、中止和失败仍按原有生命周期处理。

## 测试与内容发送

LLM 提供商测试菜单可生成示例标题，或判断“要求回应”和“完成报告”两类固定示例。Decision 测试菜单提供相同两类判断示例，显示判断结果、概率、耗时或失败原因。测试只在点击后发送固定内容，不读取真实会话；LLM 连通性示例不替代实际分类提示词的业务准确率验收。

选择远程提供商后，真实标题生成会发送对话摘录，真实问题判断会发送助手回复。API 测试与真实调用均可能产生提供商用量。HTTP 失败仅报告状态与必要诊断，不展示完整响应体。HTTP 客户端不跟随重定向。

源码更新不会替换已安装应用或集成。使用时需要运行新版应用，并更新 Pi 集成、在现有 Pi 会话执行 `/reload`。
