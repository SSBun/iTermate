# 提交全部改动并发布 iTermate v0.4.0

Status: Completed (2026-09-10 11:51)
Kind: Queue

## Scope

- 包含：当前工作区全部 tracked/untracked 改动、0.4.0/build 11 版本元数据、CHANGELOG、DMG、SHA-256、annotated tag、GitHub Release、Sparkle appcast 与发布后仓库收敛。
- 不包含：新增产品功能、安装到 `/Applications`、启动或重启 iTermate/Bridge/终端。
- 按工作区规则不运行测试套件；使用构建、打包、签名、校验值、XML、公开下载与 feed 验证。当前环境没有 Developer ID Application identity，远端发布前须明确接受 ad hoc 签名且未公证限制。

## Target
- [x] T1: 当前工作区全部改动被纳入明确提交，且 iTermate v0.4.0 按项目现有 GitHub Release 与 Sparkle 链路公开发布并可验证。

## Plan

1. 执行 `prepare-v0-4-0-release`，完成版本、发布说明、最终资产与本地验证。
2. 仅在准备任务完成后执行 `publish-v0-4-0-release`，创建发布提交与 tag，并在独立安全确认后发布远端资产和 feed。
3. 汇总公开验证、收敛任务记录与 Git 状态。

## Children

1. [准备 iTermate v0.4.0 本地发布版本与资产](prepare-v0-4-0-release.md)
2. [发布 iTermate v0.4.0 到 GitHub 与 Sparkle](publish-v0-4-0-release.md)

## Result

- T1: 两个子任务均 Completed；release commit 8b203de、annotated v0.4.0、GitHub Release 资产与公开 Sparkle 0.4.0/build 11 feed 已完成一致性验证。
- Review gate: Skipped — Queue 父任务未直接修改产品交付文件；版本/资产改动已在 prepare 子任务完成 mandatory task-review。

## Verification

- Passed: 子任务完成；远端 tag/main、稳定 Release、独立下载 checksum、DMG、HTTP 200、公开 appcast 与 EdDSA 均通过。
