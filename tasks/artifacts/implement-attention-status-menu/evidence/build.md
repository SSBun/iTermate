# 编译与源码检查

- 已执行 `xcodegen generate`，生成变更仅新增菜单视图及回归用例的工程引用。
- 已执行 `xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/itermate-attention-build build CODE_SIGNING_ALLOWED=NO`：BUILD SUCCEEDED，15.490秒。
- 后续加入回归用例及完成时间恢复逻辑后，执行同配置 `build-for-testing`：TEST BUILD SUCCEEDED，7.103秒。该动作只编译App及测试bundle，没有执行测试或启动App。
- 编译警告：AppIntents元数据提取跳过；当前Xcode的XCTest动态库面向macOS14，而项目最低系统为macOS13。没有因此更改产品部署版本。
- `git diff --check` 通过。
- 源码自查：分类以Store已确认的非运行Agent观察为准；等待覆盖不使用手动idle展示；批量已读仅记录当前非失败完成身份；点击结果确认只针对捕获身份，不确认后来轮次；标题使用真实Pi摘要或终端标题；未知状态不当作idle。
- 回归用例已编译，覆盖分类排除、批量已读与统计隔离、Pi已读失败保留至新工作、精确时间完成恢复、手动等待覆盖、断连重连和过期选择拒绝。未运行这些用例，不将其断言记为通过。
- TR-1修复后执行相同 `build-for-testing`：TEST BUILD SUCCEEDED，8.573秒；Python `ast.parse` 通过。未执行Swift用例或Bridge self-test。
- 修复源码检查：菜单请求改为独立 `activateMenuSession`，不调用Bridge完成清除；FocusMonitor保护菜单激活目标直到真实失焦，Codex同步保护自动焦点确认。Store成功回调只确认当前仍等于点击时捕获身份的完成；Bridge已B/Swift仍A以及激活等待时新B的用例已编写，未运行。
- 未运行、重启、安装或替换iTermate/Bridge。菜单真实布局、鼠标与键盘操作、系统前台切换仍需用户自行运行新版后验证。
