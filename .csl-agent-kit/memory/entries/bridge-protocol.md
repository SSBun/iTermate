---
title: Bridge协议与集成兼容
summary: App自管Bridge的内部协议边界、独立更新集成的格式兼容，以及变更后的验收要求。
---

- [2026-11-05] App 从 bundle 安装 Bridge 并杀旧启新、保证两端同版本时，内部新增消息字段或重构 MUST NOT 递增协议版本，MUST NOT 在握手或每条消息中添加版本校验；若两端可独立更新，MUST 重新判断此条件。
- [2026-11-09] 不随 App 更新的 integration MUST 考虑格式兼容；当前 Bridge 按操作所需字段和值验证，允许版本元数据但不按版本号拒绝请求。MUST NOT 将旧 lessons 的固定版本或白名单建议作为当前实现要求。
- [2026-11-12] 修改上述内部协议或移除版本检查后，验收 MUST 核对 App↔Bridge 握手及逐消息路径未检查协议版本，并运行 Swift 与 Python 全量测试确认通过。
