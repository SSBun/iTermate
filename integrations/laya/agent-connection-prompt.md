请使用这台 Mac 上 iTermate 提供的 Laya 本地模型，处理当前任务中适合分类、评分或是非判断的决策。它不是聊天模型，也不是 Jev 云端 API。

## 当前真实连接信息

- API 地址：{{API_URL}}
- Bearer Token：{{API_TOKEN}}
- 认证请求头：Authorization: Bearer {{API_TOKEN}}

此提示词包含真实凭据，只能交给可信的本机 Agent 或客户端。不要将 Token 打印到日志、保存到仓库或公开分享。地址中的端口可能在服务重启后变化；连接失效时请用户从设置页重新复制提示词，不要扫描端口或无限重试。

## 使用方式

1. 只向上述本机地址发送请求，禁用代理和 HTTP 重定向，不把 Token 发往其他地址。
2. 先调用 `GET /health`，确认 `ready` 为 true。
3. 根据任务选择接口：
   - `POST /v1/decide`：正文含 `state` 字符串和 `questions` 对象；支持 `choice`、`score`、`noul`，每个问题必须有 `type` 和非空 `instructions`。
   - `POST /v1/session`：正文为 `{"state":"最后一条助手消息或终端文本"}`，返回运行状态分类和需要回复的概率。
4. `choice` 的 `criteria` 为 2–10 个选项及描述组成的字典；`score` 为 1–10 个描述组成的数组，分数从 0 开始；`noul` 不传 criteria。
5. 正文最多 16384 字节，state 最多 3000 字符，每次 1–8 个问题；instructions 最多 600 字符，选项名最多 64 字符、描述最多 200 字符。还有模型 token 预算，超限返回 413。401 表示认证失败，429 表示模型忙；请求超时不代表服务端推理已取消。
6. 结果在 `answers` 中。概率和 confidence 不是正确性保证，不要用推断覆盖明确的进程或 Agent 生命周期事件。
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
    with opener.open(request, timeout=5) as response:
        return json.load(response)

try:
    if call("/health").get("ready") is not True:
        raise ValueError("Model not ready")
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
