# 排查本地模型不可用的原因

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 11:32) |
| Kind | Task |

## Scope

仅诊断当前本地模型不可用并给出恢复方法；不修改产品代码、配置或服务状态。

## Plan

1. 对照设置错误路径与本机 Ollama 监听、服务、配置及模型库存文件，区分已确认原因与后续校验风险。

## Task Summary

未修改代码或组件。

## Target
- [x] T1: 根据当前 Ollama 状态与应用检测路径说明本地模型不可用的原因及恢复方法

## Result

- T1: 两次 curl 查询 127.0.0.1:11434/api/tags 均报连接失败，lsof 无监听，brew services list 显示 ollama none。LocalLLMService.refresh/request 固定访问该端口，异常映射为截图提示，且不启动 Ollama；配置有效并选中 qwen3.5:2b，本地清单及627个layer文件存在。恢复建议为 brew services start ollama 后点击 Check & Warm Model。清单 SHA256 为8a230d7333ad1d13bf1afab0d170382b40ad95e6a50f48b1ff650d96a1651861，与App固定dfaf2605…不同，服务恢复后应核实/api/tags返回的digest；未启动服务，未验证预热或推理。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 只读诊断，无请求交付文件改动
- Snapshot: no-file:2026-10-27-ollama-port11434-refused-service-none
- Evidence: T1的curl、lsof、服务状态及源码错误路径交叉验证；Context无新增耐久事实，无需更新
- Task fingerprint: 711195be466ecd71f22168bccc566a2c53f62b11f745795e9a724f65616dfc0f

## Verification

- Passed: 再次curl仍立即报连接失败；已检查配置、源码与模型文件边界，未修改或启动服务；未运行测试，未宣称预热成功
