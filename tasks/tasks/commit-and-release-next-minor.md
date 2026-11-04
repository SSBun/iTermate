# 提交全部本地改动并发布下一个次版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-11-04 15:33) |
| Kind | Queue |

## Plan

1. commit-all-before-v080：保存全部当前本地改动。
2. release-v080：在前项完成后构建并发布0.8.0（build15）。
3. 核对远端发布、更新源与提交范围，完成集成验收。

## Execution Log

### 001 — 确认版本与发布渠道

当前本地及最新GitHub发布均为0.7.0（build14）；下一次版本确定为0.8.0（build15）。沿用SSBun/iTermate、main与GitHub Pages Sparkle更新源。临时签名、未经Apple公证为既定限制；不运行测试，不安装或重启应用。

## Target

- [ ] T1: 全部本地改动提交并发布下一个minor版本，远端发布产物与更新源可核验

## Children

1. [保存发布前全部本地改动](commit-all-before-v080.md)
2. [构建并发布 iTermate 0.8.0](release-v080.md)
