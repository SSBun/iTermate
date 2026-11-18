# Review round 01

- Schema: task-review-report/v1
- Task: split-ai-model-providers
- Round: 01
- Snapshot: snapshot:tasks/artifacts/split-ai-model-providers/evidence/d4601c4c50ad9773fd7b88a8b8bf313d6f5a361f8dd777db54400f17c2fb7a55.json#d4601c4c50ad9773fd7b88a8b8bf313d6f5a361f8dd777db54400f17c2fb7a55
- Task fingerprint: ef09a7c10af79a32cd9a3801286d0b4c6f78f51bccbd9978f45f6db7486d38c9
- Outcome: findings
- Mode: independent subagent
- Run: 87faca77-6b4a-4836-b11d-d2ae84ca6509

## Reviewer feedback

Review mode: independent subagent。独立只读审查；未编辑文件、改变任务状态、委派、运行 CLI 或测试。

Reviewed scope / snapshot: 已检查指定的 Swift 服务与设置页、Pi 集成、工程登记及四份文档，并追踪未改动的标题调用方和 Pi settled 生命周期。快照标识为 d4601c4c50ad9773fd7b88a8b8bf313d6f5a361f8dd777db54400f17c2fb7a55。Manifest 包含 12 个文件，其中一个是构建日志。当前工具未提供内容哈希校验能力，因此该标识仍属于作者提供的身份声明，不能视为本 Reviewer 已验证全部文件字节一致。

Findings:

**TR-1 — Severity: P1；Swift 远程标题请求缺少实际总截止**

- **Location**：/Users/caishilin/Desktop/personal/iTermate/iTermate/AIModelService.swift，第 128、252、256 行。
- **Issue**：生成方法计算六十秒 deadline，但网络请求只设置 `URLRequest.timeoutInterval`，随后直接等待 `session.data(for:)`。没有独立的总截止取消机制。
- **Evidence**：Foundation 的请求等待超时会在收到数据时重置，不能代替整个请求的持续时间上限。当前实现只在发起第一轮或重写请求前计算剩余时间，没有在请求进行期间强制执行该 deadline。相比之下，Pi 标题路径设置了独立计时器并取消请求。
- **Impact**：远程服务持续缓慢返回数据时，Swift 的 Codex 会话标题生成可能超过六十秒，长期占用在途标题任务；设置中的示例标题测试也可能一直显示 Testing。源码中的 deadline 无法保证声明的总预算。
- **Suggested next step**：为 Swift 标题操作增加覆盖两轮请求的总截止，在到期时取消实际网络任务，并保留现有外部取消传播。不能只在请求返回后检查时间。

**TR-2 — Severity: P2；标题操作文档仍包含错误的“仅本地”说明**

- **Location**：/Users/caishilin/Desktop/personal/iTermate/docs/pi-session-archives.md，第 19、29、35 行。
- **Issue**：文档仍分别称自动更新使用本机 Qwen、手动刷新“仅调用本地小模型”、生产路径固定使用本地模型。这与本次新增的提供商路由及同文件第 21 行冲突。
- **Evidence**：Pi `summarizeTask` 默认使用所选提供商，并在非 Ollama 配置下进入远程或 Codex 路径；自动和手动标题操作均复用该生成能力。
- **Impact**：用户按手动刷新说明操作时，可能误以为对话摘录只在本机处理。这影响远程内容发送说明的准确性。
- **Suggested next step**：将上述说明统一为“使用当前选中的 LLM provider”，明确远程提供商会接收摘录；本地专属行为应附上 Ollama 条件。

两项均为首次发现，没有旧 ledger 或已修复项。TR-1 需要修正实现，TR-2 需要修正文档。

Unverified risks:

- **外部服务与认证**：未验证真实 OpenAI、DeepSeek、Decision API、Codex 登录和 Keychain 跨进程首次授权。影响 T2–T5 的实际连通性。当前能确认请求结构、路由和错误处理，不能确认账号权限及端到端成功。鉴于本轮明确限制真实调用，这些限制本身不作为要求运行测试套件的阻断理由。
- **GUI 与模型部署**：未实际操作菜单、下载 Ollama 模型或检查运行中的设置页面。影响 T1、T2、T5 的运行态验收；静态实现和编译证据不能替代这些观察。
- **快照身份**：未独立重算 manifest 与所列文件哈希。它不妨碍上述源码发现成立，但 owner 在采用本报告作为当前快照证据前，应完成一致性核验；不匹配时需重新审查受影响内容。

Checks performed:

- 先按原始要求及最新双判断方式修订核对源码，再读取作者 Result 和构建记录。
- 确认四个设置分区、四种 LLM provider、独立 Decision 配置与两类测试菜单存在。
- 确认缺少新配置时仍默认 Ollama 与普通 LLM；旧本地模型配置继续使用。
- 追踪 Swift 与 Pi 标题调用、Pi 实际 settled 分类入口、配置身份复核及取消路径。
- 核对严格 JSON 标签解析、Decision 单答案及有限概率校验；旧 Decision 开关固定关闭，不绕过新增路由。
- 核对固定 HTTPS 地址、禁止重定向、Keychain 分账户、错误不包含远程响应正文，以及 Codex CLI 登录说明。
- 未运行任何测试、构建或类型检查。

Author evidence examined:

- 已阅读任务记录的 Result、Review Assessment 和作者列出的验证限制。
- 已读取 Debug 构建日志，观察到禁用签名的构建命令及 `BUILD SUCCEEDED`。
- `tsc` 严格检查与 `git diff --check` 通过属于作者记录；本 Reviewer 未重跑，也未看到独立原始输出。

Coverage limits: 审查限于本次指定范围和必要调用方；忽略预先存在的 memory 与 investigate-status-reset 改动。未审查发布或安装结果，未替换安装态，也未发送真实会话内容。