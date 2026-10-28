# Codex 精准会话绑定实施计划

## 目标与约束

未来新开的 Codex 使用当前终端原生标题前缀，由共享服务补全唯一完整 thread ID 后读取状态；覆盖首次提问前、`/new`、`/resume` 和同目录多终端。无法唯一确认就保持未绑定，不按目录或启动时间猜测。

前置研究：研究任务 `research-test-codex-identity-solutions` 及其 evidence。原生标题切换、共享后台双终端和 Kiro → iTerm2 → Bridge 传输已获历史证据；只读 API 扩展尚未实测，不能视为通过。

## 实施顺序

1. 核对生产 Bridge 标题解析、Monitor 匹配、AppServerClient 只读连接及固定版本 `thread/loaded/list` 分页、`thread/read` 结构。
2. 复用共享服务只读连接完整读取 loaded 列表，仅唯一前缀匹配可接受；失败、零匹配、歧义及分页不完整均不绑定。禁止创建、恢复或提交消息。
3. 使用完整 ID 读取并校验 thread 身份、来源与状态；空白会话无 rollout 仍可确认身份；不把 loaded 当 running，保持 unknown 身份与默认回复分类分离。
4. 应用查询前复核终端 Session、进程代次和当前前缀；切换、退出使旧结果失效，缓存不得仅按目录。
5. 复用现有 Codex 集成入口提供 `[tui] terminal_title = ["app-name", "thread-id"]`；保留无关配置，不使用 `-c` 替代共享 daemon 配置，不直接修改用户全局配置。
6. 编译与静态检查，自查后进行 R2 独立只读审查并处理确认问题，最后重新核验。

## 不做

不补救已打开旧 Codex；不重启 App/Bridge、不覆盖安装态；不改变 Pi 状态逻辑；保留所有并行未提交改动，尤其点击图标置闲；不运行单元测试、不提交或推送。

## 交付边界

区分源码编译和静态证据与真实新 App、新 Codex 运行验证；未执行的真实 API 或切换场景明确列为待实测，不以历史标题实验代替产品链路验证。
