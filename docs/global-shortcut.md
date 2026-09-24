# 全局切换 Agent Session：等待回复优先

在 **Settings → General → Global Shortcut** 中点击 **Record Shortcut**，按下需要的组合键。默认不设置快捷键，不会占用系统按键。

- 组合键必须包含 Command、Control 或 Option，单独 Shift 或普通字符不接受。
- 录入时暂停原快捷键；按 Escape、离开设置页或切换到其他窗口／App 会取消录入并恢复原配置。录入时按无修饰键的 Delete，或点击 Clear，可以清除快捷键。
- 注册冲突或保存失败会显示错误。发生冲突时可继续录入，或按 Escape 恢复原配置。
- 配置保存到 iTermate 现有配置文件，重启后恢复；写入前重新读取当前配置，避免覆盖其他设置。

快捷键在其他 App 前台时也有效。触发后由 iTerm2 Bridge 按当前 Window → Tab → Session 层级顺序，从当前 Session 后面开始查找，末尾回绕；目标的 Window、Tab 和分屏 Session 一并激活。

只匹配状态来源明确标记为 `activityKind = agent` 的 Session，并依次按以下优先级查找：

1. `awaitingInput`：等待回复，界面为问号。
2. `finished`：已结束，包括成功与失败。
3. `running`：运行中。
4. `idle`：空闲。

只有较高优先级没有其他候选时，才查找下一类；同类均按上述层级顺序循环。普通命令不参与选择，也不会阻止 Agent 的兜底查找。例如较近的 Agent 已结束、较远的 Agent 等待回复时，先切换到较远的问号 Session。

始终跳过当前 Session，不包含未知状态或独立的模型辅助估计。只有没有其他等待回复、已结束或运行中的 Agent 时，才会跳转到空闲 Agent；普通空闲 Shell 不参与。已结束目标激活后沿用现有的“已查看完成状态”清理逻辑；等待回复、运行中及空闲目标的状态和起始时间保持不变，聚焦不会清除问号。四类都没有其他 Agent 目标、只有普通命令，或 iTerm2 没有运行时，不切换，也不会启动 iTerm2。

该动作固定作用于 iTerm2，即使当前前台是 Ghostty。快捷键注册使用系统热键 API，不读取其他 App 的普通键盘输入；录入只监听 iTermate 自己的按键事件。

当前保存的是物理键码及录入时的显示名称。键盘布局改变后若显示名称不符合预期，可重新录入。系统保留或其他程序占用的组合键可能不可用。
