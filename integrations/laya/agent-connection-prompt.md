请使用这台 Mac 上 iTermate 提供的 {{MODEL_NAME}} 本地模型处理适合的决策。Laya/Vela 支持分类、评分或是非判断；Local LLM 仅提供固定的会话回复分类。此接口不是通用聊天接口，也不是云端 API。

## 当前真实连接信息

- API 地址：{{API_URL}}
- Bearer Token：{{API_TOKEN}}
- 认证请求头：Authorization: Bearer {{API_TOKEN}}

此提示词包含真实凭据，只能交给可信的本机 Agent 或客户端。不要将 Token 打印到日志、保存到仓库或公开分享。地址中的端口可能在服务重启后变化；连接失效时请用户从设置页重新复制提示词，不要扫描端口或无限重试。

## 使用方式

1. 只向上述本机地址发送请求，禁用代理和 HTTP 重定向，不把 Token 发往其他地址。
2. 先调用 `GET /health`，确认 `ready` 为 true，并查看 `provider`、`model` 与 `instance`；切换模型或服务重启后重新获取连接信息。
3. 根据任务选择接口：
   - `POST /v1/decide`：仅 Laya/Vela 支持，正文含 `state` 字符串和 `questions` 对象；支持 `choice`、`score`、`noul`，每个问题必须有 `type` 和非空 `instructions`。Local LLM 不支持此通用接口。
   - `POST /v1/session`：正文为 `{"state":"最后一条助手回复"}`，返回 `awaitingInput` 或 `idle`，不预测进程运行状态。
   - `POST /v1/question`：正文为 `{"state":"最后一条助手消息"}`，返回 `answers.question.choice`（`question` 或 `normal`）。识别当前是否请求或等待用户参与：回答、确认、选择、授权或提供信息。请求句和隐含确认也算 `question`，不要求有问号；完成报告、自主执行进度、引用和自问自答算 `normal`。
4. `choice` 的 `criteria` 为 2–10 个选项及描述组成的字典；`score` 为 2–10 个描述组成的数组（Laya 也兼容单级数组），分数从 0 开始；`noul` 不传 criteria。
5. 正文最多 16384 字节，state 最多 3000 字符，每次 1–8 个问题；instructions 最多 600 字符，选项名最多 64 字符、描述最多 200 字符。还有模型 token 预算，超限返回 413。401 表示认证失败，429 表示模型忙；请求超时不代表服务端推理已取消。
6. 结果在 `answers` 中。Local LLM 只返回合法标签和 `source: "local-llm"`，没有概率或 confidence；不要伪造概率。Laya/Vela 的概率和 confidence 也不是正确性保证，不要用推断覆盖明确的进程或 Agent 生命周期事件。
7. 服务随 iTermate 运行；无法连接时请用户检查设置，不要擅自启动、重启 App 或安装其他服务。

## Python 标准库调用示例

以下示例已填入真实地址和 Token，请在内存中使用，不要把含凭据的代码保存到仓库：

```python
import json
import urllib.error
import urllib.request

base = "{{API_URL}}"
token = "{{API_TOKEN}}"

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

def call(path, payload=None):
    request = urllib.request.Request(
        base + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    with opener.open(request, timeout=12) as response:
        return json.load(response)

try:
    health = call("/health")
    if health.get("ready") is not True:
        raise ValueError("Model not ready")
    if health.get("provider") == "local-llm":
        result = call("/v1/question", {"state": "请确认后我再继续。"})
    else:
        result = call("/v1/decide", {
            "state": "I was charged twice. Please refund the duplicate payment.",
            "questions": {
                "department": {
                    "type": "choice",
                    "instructions": "Which department should handle this message?",
                    "criteria": {
                        "billing": "Charges, payments, or refunds",
                        "technical_support": "Bugs or connection problems",
                        "account_management": "Passwords or login access",
                    },
                },
            },
        })
    print(json.dumps(result, ensure_ascii=False, indent=2))
except urllib.error.HTTPError as error:
    print(f"Local model HTTP error: {error.code}")
except (OSError, ValueError, urllib.error.URLError):
    print("Cannot access the local model. Ask the user to check iTermate and copy a fresh connection prompt.")
```
