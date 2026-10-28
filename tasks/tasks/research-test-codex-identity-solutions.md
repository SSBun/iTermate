# 搜索并实测Codex精准身份关联替代方案

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 18:19) |
| Artifacts | [Artifacts](../artifacts/research-test-codex-identity-solutions/) |
| Kind | Task |

## Target

- [ ] T1: 根据官方接口与固定版本源码筛选比no-daemon加文件推断更可靠的新Codex会话身份方案
- [ ] T2: 对可执行候选开展受控实测，覆盖新会话及当前对话切换，报告明确成功、失败和未验证项
- [ ] T3: 不改变全局配置、安装态或用户现有会话，不重启iTermate和Bridge，清理测试资源并给出证据支持的推荐

## Scope

本轮只搜索、原型验证与受控实测，不实施产品源码修复或改变用户启动方式。用户明确授权搜索与测试，可使用新建的合成Codex TUI及临时配置；不操作现有会话、不复制或输出凭据、不修改全局配置、不重启App/Bridge、不发布。对iTerm2传输验证只允许新建并清理自有测试终端，不在用户既有终端发送输入。

## Plan

1. 核对官方hooks、终端原生状态协议、当前thread标题与固定版本TUI代码，排除缺少客户端身份或只代表活动的信号。
2. 复用已成功的独立PTY驱动，在临时配置中启用TUI原生thread标题，结合生产Bridge前缀解析函数与原版Monitor验证首轮、/new及可执行的已加载对话切换，不更改用户配置。
3. 用自有新建iTerm2测试终端检验原生OSC身份能否穿过真实Kiro；权限不足时明确保留该缺口，不用模拟终端冒充。
4. 比较最小原生通道与hooks/独立模式/需改造TUI的方案；只推荐有来源和实际证据的部分，列清未验证边界及运行代价。
5. 检查原配置、生产源码及现有会话未被测试改变，清理自有资源，保存脱敏证据并交付结论。

## Decisions

- no-daemon单独依赖FD已经由前任务实测否定，不再重试同一假设或按最新文件猜当前thread。
- 官方hooks在server侧运行，session_id不等于TUI当前选择；共享daemon环境字段可能属于首个客户端，已加载thread选择切换也不保证触发hook，不能将搜索结果中的提案冒充已发布接口。
- Codex0.164原生OSC7501/21337提供活动状态但无thread UUID；原生thread标题来自TUI当前会话，值得做精确绑定实测。thread项仍可能截断为29字符前缀，必须唯一扩展与metadata校验。
- -c tui.terminal_title并不在当前daemon兼容白名单内，不能以这种启动方式的结果宣称共享daemon也已验证。临时实验可显式独立模式，之后真实终端转发单独验证；共享daemon本身仍列为独立验证边界。

- Current artifacts: 本任务evidence/sources的固定版本公开源码与URL/hash清单；前任务有效的no-daemon反例。
- Next action: 完成原生thread标题与当前Monitor组合的动态测试，然后验证Kiro转发。
- Required input: None
