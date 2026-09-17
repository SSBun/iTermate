## 审查模式与快照

模式：独立子代理（`independent subagent`），单轮只读审查。

范围：九个限定源码文件及相关设置、渲染、通知调用方；重点检查第四轮之后新增的问号摇晃与 Reduce Motion 行为。

- 差异：["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product-5.diff"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product-5.diff)
- 快照：["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot-5.txt"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot-5.txt)
- 声明 HEAD：`0c79ef67e35e86646cf857e954c41c4e4c368002`
- 差异 SHA256：`e194fe9557592c76518f8faf2b50d5a0b55028e2f68fe836d97ae0d38e80205d`

## 审查结果

**Findings: none**

No issues found.

源码证据确认：

- **摇晃局限于像素问号。** ["/Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift)，1423–1485 行：问号使用四秒周期、短暂 ±1pt 水平位移，其余时间居中；字形、像素尺寸和颜色绘制未改变。其他待回复预设仍通过静态矩阵渲染。
- **减少动态效果具有明确静态路径。** 同文件 1443、1458–1462 行：读取系统环境值，同时暂停时间轴并强制零位移，不会停留在偏移位置。
- **会话与设置共用实现和偏好。** 同文件 847–856 行与 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/SettingsViews.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/SettingsViews.swift)，746–766 行均调用 `AgentWaitingStatusView`，保持 36×16pt 区域及相同样式、颜色解析。
- **状态语义未因动画改变。** 已复核 Pi 生命周期、两条状态通道、等待租约及聚焦清除路径。通知与计数使用的完成追踪仍要求 `running → finished`，见 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift)，8–24 行。

本轮没有确认需要整改的问题，未分配 TR5。

## 未验证风险

1. **T6 连续动画与 Reduce Motion 动态切换未观察。**  
   单帧只能证明该帧字形可辨、没有裁剪，不能证明连续节奏或系统设置切换效果。按已接受的源码交付及禁止启动边界，**不阻断源码层面的 Target 验证**；不能声称运行验收通过。

2. **T1、T2、T5 的完整运行场景仍未覆盖。**  
   本轮未操作设置持久化交互、双终端生命周期、断线恢复或租约超时。用户确认的是此前像素问号显示，不是本轮摇晃。此限制**不构成新增源码整改项**。

3. **快照身份依赖主会话哈希复核。**  
   开始与结束均读取快照声明，并复读摇晃实现，未观察到漂移；只读工具无法独立计算哈希或核验 Git HEAD。主会话须确认九个文件及差异的前后身份一致；**若发生漂移，阻断当前快照验证**。

## 既有发现复核

- **TR1：resolved，源码层面。** ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，207–215、242–247 行仍采用实际运行标记处理树导航。
- **TR2：resolved，针对既有反例。** 同文件 62–67 行保留中英文否定等待排除；相关测试源码保留负例。不是零误报保证。
- **TR3：resolved，源码层面。** 同文件 107–195 行保留实际 ACK、完整转换重试及 generation 检查；两端接收路径仍反馈实际接受结果，未被动画改动影响。
- **TR4：resolved，源码层面。** ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，1335–1347 行仍先断言旧心跳拒绝，再建立合法运行转换和租约；未执行自检。

## 实际检查与作者证据

**本审查实际完成：**需求与有效修订对照、差异和相关调用方阅读、第四轮问号实现比较、时间轴与绘制边界检查、偏好和协议路径复核、三份测试源码阅读、图片观察及结束前关键内容复读。

**读取但未重跑的作者证据：**

- ["/Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md)：Target、Implementation Checks、Result、Review Assessment。
- ["/tmp/iTermate-pending-questions-build.log"](file:///tmp/iTermate-pending-questions-build.log)，135 行记录 `BUILD SUCCEEDED`。
- ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/pixel-question-shake-frame.png"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/pixel-question-shake-frame.png)：普通离屏单帧，问号可辨；不是运行中 App 或 Reduce Motion 验证。
- 减少动态效果注入失败及随后移除辅助程序覆写，仅依据作者记录，不作为成功验证证据。

## 覆盖限制

未执行测试、构建、命令或事件回放；未启动 App、替换安装态、修改文件或任务状态，也未继续委派。现有静态矩阵测试不覆盖新 SwiftUI 时间轴。本反馈限于当前源码与可读证据，不是运行验收或完成授权。