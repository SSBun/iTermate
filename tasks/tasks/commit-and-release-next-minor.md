# 提交全部本地改动并发布下一个次版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-04 15:40) |
| Kind | Queue |

## Plan

1. commit-all-before-v080：保存全部当前本地改动。
2. release-v080：在前项完成后构建并发布0.8.0（build15）。
3. 核对远端发布、更新源与提交范围，完成集成验收。

## Execution Log

### 001 — 确认版本与发布渠道

当前本地及最新GitHub发布均为0.7.0（build14）；下一次版本确定为0.8.0（build15）。沿用SSBun/iTermate、main与GitHub Pages Sparkle更新源。临时签名、未经Apple公证为既定限制；不运行测试，不安装或重启应用。

### 002 — 集成发布验收

两个子任务均完成：373b392保存全部本地改动，e85d4cc发布0.8.0/build15。远端tag解析至发布提交，main包含全部原本地提交；稳定Release资产独立下载校验通过，公开Sparkle首条与最终包匹配。后续仅同步本次生命周期记录，不改发布字节。

## Task Summary

父任务仅协调提交与发布，未直接修改代码或组件。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 两个顺序阶段复用既有发布系统 | 无新增流程或基础设施 |
| 稳定性 | A | 全部原改动已保存，远端下载及公钥验签、公开feed和提交对应关系实际核对通过 | 未运行测试及GUI升级；ad hoc未公证为已接受限制 |
| 完整性 | S | 0.8.0/build15稳定发布和自动更新源均已公开，原本地改动全部包含 | 最后记录同步不改变发布标签或安装包 |

## Target
- [x] T1: 全部本地改动提交并发布下一个minor版本，远端发布产物与更新源可核验

## Children

1. [保存发布前全部本地改动](commit-all-before-v080.md)
2. [构建并发布 iTermate 0.8.0](release-v080.md)

## Result

- T1: 全部本地改动已由373b392及前序提交保存，e85d4cc/v0.8.0发布0.8.0 build15；稳定GitHub资产下载校验通过，公开Sparkle匹配最终包，Pages built提交一致。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 父任务仅协调，无父任务产品文件变更。
- Snapshot: integration:e85d4cc/v0.8.0;sha256:2852d3aa575e6c1395b3674a5495b6957f5c981fd33ba6d1ce06f81a96dc8027
- Evidence: release-v080 T1/T2及父Execution Log 002；两个子任务均Completed，next为空。
- Task fingerprint: 5cdd5f3e5e2234da05d7dc17f2302e73bda2f1d544011cc830d3d5fedcdd777e

## Verification

- Passed: 最终GitHub稳定Release、Pages built和公开feed已核对，远端main及tag解析至e85d4cc，所有原本地改动均纳入；未运行测试或GUI升级。
