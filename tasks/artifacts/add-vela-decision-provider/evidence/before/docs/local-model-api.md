# Laya 本地模型与公共 API

## 安装与启用

在 iTermate Settings 的 **Local Model** 标签页点击 **Download Model**。App 不包含模型权重，也不会在首次启动时自动下载。

页面分别展示 **Installation status** 和 **Service status**。安装状态为 Not installed、Installing、Installed 或 Installation failed；安装阶段会显示运行时准备、依赖安装或模型下载进度。Installed 表示安装记录、关键模型文件及 Python/Laya 运行时文件存在，不代表服务已启动，也不是每次打开页面都重新做完整哈希校验。取消后按实际文件状态显示，并提示可以重试；停止服务不会把已安装模型显示为未安装。

- 需要 Apple Silicon、macOS 14+ 和 `uv`。未安装 `uv` 时，设置页会提示先运行 `brew install uv`。
- 下载动作使用 `uv` 准备独立 Python 3.12 环境，安装 `laya-mlx==0.2.0`，然后下载多语言 FP16 模型 `aac6fef/laya-multilingual-mlx`，固定 revision 为 `f2b4faf51023039425946074e2cf1361d2db11d5`。
- 模型下载到 Hugging Face 缓存；核对发布清单中的大小与 SHA256 后，才写入安装完成标记。模型约 650 MB，另需 Python、依赖与缓存空间。下载进度由 Hub 报告，不包含依赖安装及校验阶段。
- 启用 **Enable local API service** 后加载模型；启用 **Assist session state and reply detection** 后才分析 Session 文本。两项偏好独立持久化；错误不会自动关闭用户偏好。
- 取消下载或服务操作后可重试。App 退出会停止自己启动的服务；没有系统级 daemon 或独立登录项。下次打开 App 时，若用户此前启用了服务，则恢复服务，但不自动下载。
- Intel Mac 或 macOS 13 仍可使用原有功能，本地模型设置会说明不支持。

## 安全与生命周期

设置页的 **Copy Agent Connection Prompt** 按钮会在点击时填入当前真实 API 地址和 Bearer Token，复制完整连接说明与 Python 示例；只在服务就绪时可用，成功后显示已复制。该提示词包含凭据，只交给可信 Agent 或客户端；不要保存到仓库、日志或公开聊天。服务重启后应重新复制。App 内仅分发占位符模板，不内置或保存生成后的凭据提示词。

服务只监听 `127.0.0.1`，不允许远程连接；端口由系统分配，重新启动可能变化。所有接口都需要本机 Bearer Token。服务拒绝浏览器 Origin、非精确 loopback Host 和 HTTP 重定向式访问，不提供 CORS。Token 可在设置页复制；剪贴板属于敏感信息，请勿上传或分享。

服务工作目录位于当前用户 Application Support 的 `iTermate/Laya` 下，权限为 0700；其中：

- `endpoint.json`：当前服务地址与 PID；客户端应在连接失败后重新读取，不缓存端口。
- `api-token`：权限 0600 的本机调用凭据，与 Jev Token 无关。
- `model.json`：已校验的本地模型位置。
- `runtime`：独立 Python 环境。
- `analysis-enabled`：允许 iTermate 集成提交 Session 正文的标记，不影响公共决策 API。

服务不记录正文，不调用云端推理，也不会下载或执行来自 API 请求的模型、文件或命令。拥有当前用户文件读取权限的本地进程可以取得 Token；这不是隔离同一用户恶意程序的安全边界。

并发推理采用单实例非阻塞锁：模型忙时返回 429，不排无限队列；最多处理 8 个 HTTP 连接，读取超时 5 秒。外部客户端应自行设置超时，并按业务需要有限重试；超时不代表推理已经取消。

## 接口

### `GET /health`

返回 `ready` 和模型 ID。只有模型加载成功后才发布 endpoint。

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
- `score`：`criteria` 为 1–10 个描述组成的数组，得分从 0 开始。
- `noul`：是非判断，仅使用 `instructions`，不接受非空 `criteria`。
- 还会按模型 tokenizer 检查上下文预算；内容过长返回 413，请缩短输入。接口不是 OpenAI Chat Completions，也不接受动态模型路径或切换模型。

返回原生 Laya JSON：`model`、`answers`、`usage`，并附加 `elapsed_ms`（本次 predict 时间，不含 HTTP 网络和加载）。`choice` 包含选择、各项概率、`confidence` 和 `action`。概率与 confidence 不一定相等，均不保证正确性。

### `POST /v1/session`

正文只需 `{"state": "最后一条助手消息或终端文本"}`。返回固定的两个答案：

- `answers.state`：`running`、`awaitingInput`、`idle` 或 `unknown`。
- `answers.needs_reply.noul`：是否明确要求用户回答、选择、确认或授权的概率。

这是推断，不会直接修改任何 Session。客户端必须保留真实生命周期优先级；不要根据一条文本把正在运行的进程标成完成。

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
    "state": "Please confirm whether I should proceed. I will wait for your reply.",
}
request = urllib.request.Request(
    f"http://127.0.0.1:{address.port}/v1/session",
    data=json.dumps(body).encode(),
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
with opener.open(request, timeout=5) as response:
    print(json.load(response))
```

## iTermate 的判定边界

- Pi 交互集成仅在 Agent settled 后使用最后一条成功结束的助手文本；启用分析时优先请求模型，不因正则已命中而跳过模型。HTTP 请求最多等待 800 ms；关闭、失败、繁忙、超时或结果不确定时才回退既有正则。正在执行的 Agent、新一轮输入、切换分支和明确 UI 提问事件优先。
- 模型返回三态决策：`awaitingInput` 概率至少 0.85 且 `needs_reply` 至少 0.6，判定需要回复；`idle` 概率至少 0.85 且 `needs_reply` 不高于 0.4，判定不需要回复，可否定正则误判；其余情况不作决定，回退正则。非法类型、非有限数值或不在 0–1 内的概率也回退。阈值是保守工程选择，不是已验证的准确率保证。
- 模型的肯定和否定结果都观察分析开关；关闭后，在下一次约两秒的检查中恢复正则结果。模型判定已完成时只检查开关，不重复上报完成事件。等待模型期间暂停旧心跳，避免最终分类前先错误上报完成。
- iTerm2 对没有真实状态的 Session 轮流读取可见终端文本末尾（最多 1500 字符），每个周期最多分析一个，结果最长保存 8 秒。界面以带问号的模型辅助标签显示，不写回权威状态，不计入完成次数或完成通知。不是按 Session 名称推测，也不能保证可见屏幕等于最后一条助手消息。
- Ghostty 无法通过当前 AppleScript 接口读取正文；Pi 集成可以提供消息，其余没有集成的 Session 保持未知。
- 模型常驻占用内存并竞争 GPU；单例结果不能证明所有语言和终端 UI 都能准确判断。关闭模型分析可立即恢复原有判定路径。

## 验证限制

构建与隔离服务验证不等同于真实 App 界面验收。需要用户自行重新构建并启动 App，检查下载进度、取消与重试、设置持久化、服务启停和真实 Session 显示。既有运行中的 App、Bridge 与用户安装态集成不得由源码修改自动替换。
