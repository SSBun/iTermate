# 编写项目 README

Status: Completed (2026-08-21 16:02)
Kind: Task

## Scope

- 包含英文主 README、对应中文版本、用户提供的原始预览图片，以及基于当前仓库与发布状态的徽章和使用说明。
- 不新增许可证、CI 工作流或应用功能，也不改变现有代码和运行行为。

## Target
- [x] T1: 仓库根目录包含一份准确反映当前 iTermate 项目的英文主 README，读者可据此了解项目用途、主要能力、运行要求、安装与基本使用方式，并可通过其中的链接访问对应中文版本。
- [x] T2: 英文主 README 展示用户提供的项目预览图，并包含与项目当前状态一致、链接有效且风格专业的徽章。
- [x] T3: 除新增或更新英文、中文 README、预览图片资源及任务记录外，不改变应用代码或运行行为。

## Plan

1. 核对当前项目能力、发布资产、平台要求与预览图片。
2. 编写互相链接的英文主 README 和中文版本，并加入真实可验证的专业徽章与预览图。
3. 检查文档结构、本地资源链接、外部链接与最终差异。

## Result

- T1: README.md 为英文主文档，完整介绍当前项目并链接 README.zh-CN.md；GitHub GFM 渲染与全部本地链接检查通过。
- T2: 英文 README 的 4 个项目徽章及其链接均返回 HTTP 200，并成功渲染 4734×2698 的用户预览图 docs/images/itermate-preview.webp。
- T3: git status 仅列出 README.md、README.zh-CN.md、docs/images/itermate-preview.webp 与本任务记录/索引，未改动应用代码。
- Review gate: Skipped — 用户未要求独立 Reviewer、对抗审查或双 Agent 审批。

## Verification

- Passed: GitHub GFM 渲染、本地资源与空白检查、12 个外部链接/徽章 HTTP 检查、图片格式尺寸检查及 git diff --check 全部通过；按用户规则未运行项目测试。
