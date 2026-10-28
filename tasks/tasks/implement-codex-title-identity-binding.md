# 实现Codex原生标题精准会话绑定

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 19:30) |
| Artifacts | [Artifacts](../artifacts/implement-codex-title-identity-binding/) |
| Kind | Task |

## Scope

实施前序研究推荐链路；历史研究保持独立，不把尚未执行的API实验当验证。仅新开会话；不修改用户全局配置、不重启App/Bridge、不覆盖安装态、不运行单元测试、不提交推送，不改Pi状态路径。保留既有点击状态置闲等并行改动。

## Plan

1. 恢复历史证据，核对固定版本协议与现有身份／状态调用边界。
2. 接入共享服务只读完整分页唯一匹配，并消除自动路径上的目录／时间猜测与rollout前置依赖。
3. 严格校验thread来源和状态，复核异步终端／进程代次／标题，保留unknown与回复分类语义。
4. 在既有Agents入口提供原生标题配置方式，不直接修改全局配置；编译、静态核验后完成R2独立只读审查。

- Current artifacts: [实施计划](../artifacts/implement-codex-title-identity-binding/specs/implementation-plan.md)
- Next action: 对当前冻结源码与证据执行R2独立只读审查，处理确认问题后最终核验。
- Required input: None

## Task Summary

**Codex 监控与集成**：["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/)新增共享服务完整分页唯一前缀查询及根thread校验，自动身份不再依赖文件或目录／启动信号；Store复核真实进程与终端前缀，失败撤销自动overlay，并在Agents中展示可选择复制的原生标题配置而不写配置。

**验证源码**：["/Users/caishilin/Desktop/personal/iTermate/iTermateTests/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests/)调整被本次行为替换的自动匹配断言及文件读取场景输入，补充前缀、根来源和进程代次覆盖；未执行测试。

**监控说明**：["/Users/caishilin/Desktop/personal/iTermate/docs/"](file:///Users/caishilin/Desktop/personal/iTermate/docs/)更新原生标题、共享服务绑定、失败边界与配置入口说明。

## Target
- [x] T1: 未来新开的Codex通过当前终端原生标题前缀与共享服务唯一完整thread ID绑定，首次提问前及/new、/resume可用，无法唯一确定则保持未绑定
- [x] T2: 只读分页与thread/read完整校验，空白会话无需rollout，状态和unknown语义保持准确，过期异步结果与多终端缓存不串绑
- [x] T3: 复用Codex集成配置入口且不覆盖无关配置，不改全局配置、Pi逻辑或安装态，不重启、不提交推送并保留并行改动
- [x] T4: 实施计划落盘，完成获准编译与静态检查及独立只读审查，明确实测缺口且不运行单元测试

## Result

- T1: 固定rust-v0.164.0协议与handler源码已核对（evidence/protocol/manifest.json及thread_processor.rs:2945-3100）；客户端完整loaded分页唯一匹配后读取root thread，Store在无rollout时仍发起前缀查询。源码追踪与Debug build通过；首次提问前、/new、/resume和双终端产品实测尚未执行，历史标题实验不充当API证据。
- T2: 自查loaded分支对缺失nextCursor、重复游标、超页、无效UUID和歧义均抛错；thread/read校验ID/source/parent/status且loaded不映射running。Store应用前复核真实前台进程代次、终端ID及前缀，失败清自动绑定；无目录缓存。evidence/static-checks.log与typecheck.log支持语法/类型及只读RPC清单；测试源码已适配但未执行。
- T3: Agents既有Codex行只展示可选择复制的[tui]原生配置说明，无配置写入动作；未改Pi集成/Bridge。evidence/task-owned.diff排除了启动前并行修改，static-checks.log核对App原PID/启动时间和两并行源文件SHA256一致。未执行安装、重启、提交或推送。
- T4: 计划先于产品修改保存于specs/implementation-plan.md；evidence/build.log记录Debug BUILD SUCCEEDED，七文件swiftc -parse、三个受影响测试源码swiftc -typecheck及git diff --check通过。Context结构有效，保留既有未索引章节警告。未运行单元测试或新版App；独立只读审查由Review Reports及Review gate单独记录，不以作者自查替代。
- Review gate: Passed — 独立fresh/read-only Reviewer 6ac3b946-1a02-463d-8edf-6b4ba652fe05的round-01无确定性问题；主Agent返回后check-evidence逐项核验24文件与Git身份一致，快照闭环完成。真实API/App场景未实测不冒充通过，交付限源码与静态验证。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨共享服务分页、异步身份绑定和生命周期状态合并，错误关联会污染多终端状态；编译和类型检查不能覆盖所有运行时竞态，需独立审查。
- Snapshot: snapshot:tasks/artifacts/implement-codex-title-identity-binding/evidence/4b308ddd0089c20da7fbb220fc7cdc56447a038a8fbec8323074448368812a37.json#4b308ddd0089c20da7fbb220fc7cdc56447a038a8fbec8323074448368812a37
- Evidence: Result T1-T4；evidence/build.log、typecheck.log、static-checks.log与task-owned.diff及固定版本协议源码。真实API与App场景未实测。
- Task fingerprint: 0f631284e332988feea379c40488916aba6f9b70fccb55d3f651b5ce09efb0ae

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/implement-codex-title-identity-binding/reviews/round-01.md) | snapshot:tasks/artifacts/implement-codex-title-identity-binding/evidence/4b308ddd0089c20da7fbb220fc7cdc56447a038a8fbec8323074448368812a37.json#4b308ddd0089c20da7fbb220fc7cdc56447a038a8fbec8323074448368812a37 | no blocking findings | 853ac0cee68732cb64ee730e08d4e40c42aad840652e7f6275753bab0c4ad994 |

## Verification

- Passed: 独立审查后再次Debug build成功、三个受影响测试源码仅typecheck通过、七文件parse与git diff --check通过；check-evidence复核24文件快照及round-01报告一致。两并行源文件hash与启动时一致，原App PID70525/启动时间未变；未运行测试、未换安装态，真实API及新App场景仍待用户自行运行后验证。
