# Laya / Vela / Local LLM 本地模型与公共 API

## 安装与启用

在 iTermate Settings 的 **Local Model** 标签页选择 **Decision model**（Laya、Vela 或 Qwen3.5 · 2B）。Laya/Vela 使用 **Download Model**；2B 在 **Local LLM** 区域使用 **Deploy / Repair 2B**。选择持久化；未保存选择时默认使用 Vela，已有明确选择（包括 Laya）保持不变，仍可手动切换。App 不包含模型权重，也不会自动下载未安装的模型。

模型切换会停止本 App 拥有的旧 worker，等待其释放单实例锁，然后按服务开关加载所选模型。若新模型未安装或启动失败，显示原因并保持该选择，不悄悄切回另一模型。安装或启动中暂时禁用切换。三种提供方使用各自的运行时和安装标记，不需要卸载旧模型。

页面分别展示 **Installation status** 和 **Service status**。安装状态为 Not installed、Installing、Installed 或 Installation failed；安装阶段会显示运行时准备、依赖安装或模型下载进度。Installed 表示安装记录、关键模型文件及 所选模型的 Python 运行时文件存在，不代表服务已启动，也不是每次打开页面都重新做完整哈希校验。取消后按实际文件状态显示，并提示可以重试；停止服务不会把已安装模型显示为未安装。

- 需要 Apple Silicon、macOS 14+ 和 `uv`。未安装 `uv` 时，设置页会提示先运行 `brew install uv`。
- 下载动作使用 `uv` 准备独立 Python 3.12 环境，安装 `laya-mlx==0.2.0`，然后下载多语言 FP16 模型 `aac6fef/laya-multilingual-mlx`，固定 revision 为 `f2b4faf51023039425946074e2cf1361d2db11d5`。
- 模型下载到 Hugging Face 缓存；核对发布清单中的大小与 SHA256 后，才写入安装完成标记。模型约 650 MB，另需 Python、依赖与缓存空间。下载进度由 Hub 报告，不包含依赖安装及校验阶段。
- Vela 使用独立 Python 3.12 环境、`torch==2.14.1`、`transformers==5.19.0`，运行 CPU/FP32、4 线程；模型为 `vllm-sr/Vela-2.0-0.3B`，固定 revision `d6f03aa9baca4f9017fa8f8e9c2764d3bed3f409`。下载和启动前核对固定 SHA256（含模型代码），启动不联网下载；权重约1.24 GB，另需tokenizer和运行时。短输入建议预留2–3 GiB内存，不是长上下文或并发保证。
- Vela 权重与代码使用 Apache-2.0，但 tokenizer 另受 [Gemma 条款](https://huggingface.co/vllm-sr/Vela-2.0-0.3B/blob/main/DISTRIBUTION_TERMS.md)约束。相关许可随下载保留。
- 启用 **Enable local API service** 后加载模型；启用 **Assist session state and reply detection** 后才分析 Session 文本。两项偏好独立持久化；错误不会自动关闭用户偏好。
- 取消下载或服务操作后可重试。App 退出会停止自己启动的服务；没有系统级 daemon 或独立登录项。下次打开 App 时，若用户此前启用了服务，则恢复服务，但不自动下载。
- Intel Mac 或 macOS 13 仍可使用原有功能，本地模型设置会说明不支持。

## Local LLM：Qwen3.5-2B

**Local LLM** 区域显示本机 Ollama 的 2B 可用性，支持 **Refresh Ollama Status**、**Use 2B for Reply Detection** 和选中后的 **Deploy / Repair 2B**。选用按钮持久选择 2B 并启用现有 API 与回复分析开关；首次使用需先部署分类桥接运行时，再启动服务。原有 Laya/Vela 不删除，未保存选择时仍默认 Vela。

- 需要本机 Ollama 正在 `127.0.0.1:11434` 运行，以及用于独立 Python 3.12 桥接环境的 `uv`。iTermate 不通过 Homebrew 自动安装依赖，不启动、关闭或接管 Ollama。
- 模型为 `qwen3.5:2b`，固定支持的 Ollama digest 为 `dfaf2605162e689c8cac330dc4a190c4c50ad30aa47814a8fe9b79fa5127e97e`。部署先核对 `/api/tags`，已安装匹配模型时直接复用；缺失时请求 Ollama 下载并重新核对身份。权重约 3.12 GB，存储由 Ollama 管理，不复制到 App bundle；桥接自身只依赖 Python 标准库。
- 部署标记与独立运行时位于控制目录下的 `LocalLLM`。安装状态结合标记、运行时和最近的 Ollama 模型库存查询；**Refresh Ollama Status** 可重新核验，服务启动与每次分类也核对模型身份。库存可用与鉴权桥接服务 Ready 是不同状态。
- 服务启动先预热模型，成功才发布鉴权端点和分析许可。生成关闭思考，固定 JSON label、32 输出 token、16384 上下文；输入仍限制 3000 字符。不截断超长回复后猜测，也不执行回复中的指令。
- Ollama 模型库存查询有 2 秒截止，推理请求有 6 秒截止；Pi 对此 provider 使用总计 10 秒的有界请求截止，Laya/Vela 仍为 800 毫秒。模型不可用、忙、超时、身份不符或无效 JSON 时保留明确生命周期状态，不换模型或调用云端。
- Local LLM 的 `elapsed_ms` 包含桥接到 Ollama 的库存查询、生成和可能发生的冷加载；不能与 Laya/Vela 的直接算子时间等同。
- Local LLM 只支持 `/v1/question`、`/v1/session` 和 `/health`，不支持通用 `/v1/decide`。生成式输出仅提供标签及 `source: "local-llm"`，**没有类别概率或 confidence**，不伪造 one-hot 概率。
- App 只停止自己拥有的分类桥接。Ollama 及其共享模型缓存仍由 Ollama 管理，请求使用 10 分钟 keep-alive；不会为清理本 App 而卸载其他客户端可能使用的模型。
- 本轮只改变回复分类，不改变标题生成；自动标题与右键刷新仍使用当前 Pi 会话模型。模型分类不保证正确，也不构成安全授权。

源码更新后，需用户自行运行新版 App，再通过既有 Agents 安装入口更新 Pi 集成并在会话中 `/reload`，然后在 Local Model 中部署、选用并启用 2B。仅编译或隔离 API 验证不等于当前 App 已切换，也不等于界面验收。

## 安全与生命周期

设置页的 **Copy Agent Connection Prompt** 按钮会在点击时填入当前真实 API 地址和 Bearer Token，复制完整连接说明与 Python 示例；只在服务就绪时可用，成功后显示已复制。该提示词包含凭据，只交给可信 Agent 或客户端；不要保存到仓库、日志或公开聊天。服务重启后应重新复制。App 内仅分发占位符模板，不内置或保存生成后的凭据提示词。

服务只监听 `127.0.0.1`，不允许远程连接；端口由系统分配，重新启动可能变化。所有接口都需要本机 Bearer Token。服务拒绝浏览器 Origin、非精确 loopback Host 和 HTTP 重定向式访问，不提供 CORS。Token 可在设置页复制；剪贴板属于敏感信息，请勿上传或分享。

服务工作目录位于当前用户 Application Support 的 `iTermate/Laya` 下，权限为 0700；其中：

- `endpoint.json`：当前服务地址、PID、`provider`、`model` 和随机 `instance`；客户端应重新读取，不永久缓存端口或模型身份。
- `configuration.json`：用户选择的 `provider`、`analysisEnabled`、`serviceEnabled` 及配置 `revision`；切换/启动/偏好变化生成新revision。
- `api-token`：权限 0600 的本机调用凭据，与 Jev Token 无关。
- `model.json`：已校验的本地模型位置。
- `runtime`：独立 Python 环境。
- `Vela`：Vela专用安装目录，包含自己的 `model.json` 与 `runtime`；外层控制目录沿用旧名称以兼容连接位置。
- `analysis-enabled`：服务ready后发布的分析许可，内容为当前配置revision，不影响公共决策 API。客户端同时核对配置、许可、端点provider/instance；响应后重读身份，拒绝切换或禁用期间的迟到结果。

服务不记录正文，不调用云端推理，也不会下载或执行来自 API 请求的模型、文件或命令。拥有当前用户文件读取权限的本地进程可以取得 Token；这不是隔离同一用户恶意程序的安全边界。

并发推理采用单实例非阻塞锁：模型忙时返回 429，不排无限队列；最多处理 8 个 HTTP 连接，读取超时 5 秒。外部客户端应自行设置超时，并按业务需要有限重试；超时不代表推理已经取消。

## 接口

### `GET /health`

返回 `ready`、`model`、`provider` 和 `instance`。模型完成加载及短输入预热后才发布 endpoint。

### `POST /v1/decide`

请求头：`Authorization: Bearer <token>`、`Content-Type: application/json`、`Content-Length`。不接受 chunked 请求。正文最多 16384 字节：

```json
{
  "state": "I was charged twice for the same order. Please help me get a refund.",
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Which support department should handle this message?",
      "criteria": {
        "technical_support": "Software bugs, crashes, or connection problems.",
        "billing": "Charges, payments, invoices, or refunds.",
        "account_management": "Account profiles, passwords, or login access."
      }
    }
  }
}
```

约束：

- `state`：非空字符串，最多 3000 字符。
- `questions`：1–8 个问题，问题名最多 64 字符。
- `instructions`：必填非空字符串，最多 600 字符。
- `choice`：`criteria` 为 2–10 个选项的字典；名称最多 64 字符，描述最多 200 字符。
- `score`：`criteria` 为描述数组；Laya为1–10项，Vela为2–10项，得分从0开始。
- `noul`：是非判断，仅使用 `instructions`，不接受非空 `criteria`。
- 还会按模型 tokenizer 检查上下文预算；内容过长返回 413，请缩短输入。接口不是 OpenAI Chat Completions，也不接受动态模型路径或切换模型。

Laya/Vela 返回 `model`、`provider`、`instance`、`answers`、`usage`，并附加 `elapsed_ms`（本次predict时间，不含HTTP网络和加载）。`choice` 包含选择、各项概率及模型提供的confidence；Laya可能另带action。概率与confidence不一定相等，均不保证正确性。

### `POST /v1/session`

正文只需 `{"state": "最后一条助手消息或终端文本"}`。返回固定的两个答案：

- `answers.state`：仅 `awaitingInput` 或 `idle`，判断最新回复是否需要用户继续参与，不预测执行过程。
- 与 `/v1/question` 共享用户参与语义；不再返回 `needs_reply`，不再使用0.85状态概率与0.6回复概率的双重过滤。
- 原生运行状态优先。`awaitingInput` 显示问号，点击不清除；`idle` 回复先高亮，点击后灰显。原生协议中的 `finished` 保留为未读回复标记，不再显示 Agent 成功/失败图标。此兼容接口仅供显式 API 调用；iTermate 不再调用它轮询屏幕。产品只通过已接入的回答结束 hook 调用 `/v1/question`。

这是推断，不会直接修改任何 Session。客户端必须保留真实生命周期优先级；不要根据一条文本把正在运行的进程标成完成。

### `POST /v1/question`

正文为 `{"state":"确认后我再继续。"}`。返回 `answers.question`，类型为choice，选项为 `question` / `normal`。Laya/Vela 附带两类概率；Local LLM 返回 `source: "local-llm"` 而不包含概率。这里的 `question` 是产品状态，不是语法疑问句：判断整条最后回答是否请求或等待用户继续参与，包括回答、确认、选择、授权或提供信息。

- `question`：“确认后我再继续”“请确认范围”“请选择方案”“请提供路径”“已完成，还需要更新示例吗？”。
- `normal`：单纯完成报告、无需用户介入的自动执行进度、引用/代码中的请求、自问自答、已经得到确认并完成的叙述。任务未完成不等于需要用户参与。

三种 provider 使用同一固定参与判定定义。此前speech-kind语法问句提示词及其77.5%留出成绩属于历史语义，不能当作当前效果。模型概率不保证正确，不能用作安全授权。

### 错误

| 状态码 | 含义 |
| --- | --- |
| 400 | JSON、字段、Content-Type 或传输格式不符合要求 |
| 401 | Token 缺失或错误 |
| 403 | Origin 或 Host 不允许 |
| 404 | 不存在的接口 |
| 413 | 正文或模型 token 预算超限 |
| 429 | 模型正在处理另一个请求 |
| 500 | 本地推理失败；不会回显输入正文 |

连接数超过上限时直接关闭连接；服务启动失败或未启用时无法连接。

## Python 客户端示例

仅使用标准库，动态读取地址，不把 Token 放在命令参数或代码中：

```python
import json
from pathlib import Path
import urllib.request

root = Path.home() / "Library/Application Support/iTermate/Laya"
endpoint = json.loads((root / "endpoint.json").read_text())["url"]
from urllib.parse import urlparse
address = urlparse(endpoint)
if address.scheme != "http" or address.hostname != "127.0.0.1" or not address.port:
    raise ValueError("Not a local iTermate endpoint")
token = (root / "api-token").read_text().strip()
body = {
    "state": "May I proceed with these changes?",
}
request = urllib.request.Request(
    f"http://127.0.0.1:{address.port}/v1/question",
    data=json.dumps(body).encode(),
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
with opener.open(request, timeout=12) as response:
    print(json.load(response))
```

## iTermate 的判定边界

- Pi 交互集成仅在Agent settled后使用最后一条成功结束的助手文本。启用模型分析时调用 `/v1/question`，由所选模型判断用户参与需求，不将旧规则与模型结果做OR合并；关闭分析时保留既有规则行为。新一轮输入、切换分支、子代理活动和明确UI提问事件仍优先。
- Laya/Vela 用户参与决策取合法二分类的最大概率选项，不套用旧终端状态0.85门槛；Local LLM 只接受来源匹配且无伪造概率的合法生成式标签。均校验provider/instance，响应后再次比对配置revision、许可与端点。配置改变或过期响应被丢弃，不切换到其他模型。
- 请求超时（Laya/Vela 800ms、Local LLM 10秒）、不可用、忙、非法结果或完整消息超过3000字符时，不截断后猜测、不换模型，也不把错误当作normal分类；本轮仅保留明确生命周期状态（已结束而非模型确认无需用户参与）。已确认的等待仍由心跳保持直到下一轮或导航，切换模型只作用于后续判定。安装旧版本集成的Pi需通过应用安装入口更新并重新加载，不能只替换源码。
- 只在 Pi 的 `agent_settled` hook（回答结束且会话空闲）触发模型分析，输入为本轮最后一条助手回复，不抓取终端屏幕、不轮询分类、不设置8秒模型结果过期。等待状态由生命周期心跳续租，心跳不调用模型；新一轮或会话导航清理旧状态。新一轮 generation 及模型身份校验拒绝迟到结果。
- 没有接入回答结束 hook 的会话不做模型猜测，仍可显示已接入的真实运行/完成事件。Bridge 快照刷新与 Agent 心跳不是模型轮询，保留断开连接时的租约失效机制。
- Ghostty 无法通过当前 AppleScript 接口读取正文；Pi 集成可以提供消息，其余没有集成的 Session 保持未知。
- Laya常驻占用内存/GPU，Vela占用内存/CPU，2B 由 Ollama 管理内存/GPU与缓存；同一App只保持所选分类 worker。模型样例不能证明所有语言和终端UI都能准确判断；未执行真实用户会话的切换验收时不得把编译通过当作视觉验收。

## 验证限制

构建与隔离服务验证不等同于真实 App 界面验收。需要用户自行重新构建并启动 App，检查下载进度、取消与重试、设置持久化、服务启停和真实 Session 显示。既有运行中的 App、Bridge 与用户安装态集成不得由源码修改自动替换。
