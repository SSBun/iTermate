# 0.6.0 本地发布验证

- 版本：0.5.0/build 12 → 0.6.0/build 13；权威 project.yml，XcodeGen 工程已同步。
- DMG：`dist/iTermate-0.6.0_20260924-153219/iTermate-0.6.0.dmg`。
- 字节数：4087624。
- DMG SHA256：`2a13723699dd30b7e4ae6bf690fcf45198d9b7634b2145570a425342e1979f47`。
- checksum 文件 SHA256：`8cadb5d77b0523529bacabf12e806a4b796bcbec12207baa0547065e0c93146d`。
- Release 构建及 hdiutil verify 通过；只读挂载后版本/build/macOS 最低版本、公钥/feed、Pi/Bridge/Laya/连接模板资源与源码一致；已卸载挂载点。
- 架构 arm64，最低 macOS 13；本地模型可选功能另需 macOS 14+。
- deep strict codesign 验证通过；实际 Signature=adhoc，无 TeamIdentifier，未进行 Apple notarization。
- Sparkle framework 包含 Updater.app、Autoupdate、Downloader.xpc、Installer.xpc；公钥与既有 Keychain account SSBun.iTermate 一致，未导出私钥或轮换密钥。
- generate_appcast 对最终 DMG 签名；sign_update --verify 通过。新条目 0.6.0/build 13、arm64/macOS 13、长度、未来 GitHub 资产 URL 均匹配；旧条目 XML 全部保持一致。
- 未来资产 URL：https://github.com/SSBun/iTermate/releases/download/v0.6.0/iTermate-0.6.0.dmg。

## 测试

- Bridge `python3 iTermateBridge/iTermateBridge.py --self-test`：通过。
- `tsx --test integrations/pi/iTermate-integration.test.ts`：7 项通过。
- `node --experimental-vm-modules --test integrations/pi/subagent-lifecycle.test.mjs`：10 项通过。
- `xcodebuild ... -derivedDataPath /tmp/itermate-release-tests-060 test`：57 项通过、0 失败；日志 `/tmp/itermate-release-xctest.log`。
- Release 日志 `/tmp/itermate-release-dmg.log`；git diff --check 通过。

## 测试修复

首次 Bridge 自检在空闲 Agent 循环场景失败。跟踪确认当前 ID 为 1、状态字典只含 ID 1，断言却要求跳到 ID 2；此前缺少生命周期所有权的 finished 测试状态已被正常清除。为该场景通过 set_agent_status 明确注册第二个 idle Agent，并增加激活次数和 idle 状态不变断言。原选择断言保留，无产品逻辑改动。

## 边界

未替换或重启用户正在运行的 App/Bridge，未安装新集成。XCTest 使用独立测试构建并受 App 的 XCTest 启动保护。未进行真实客户端升级安装；尚未创建远端 tag、Release 或发布 feed。公开上传须另行确认。
