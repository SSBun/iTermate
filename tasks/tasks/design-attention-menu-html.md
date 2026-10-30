# 制作待处理菜单单页 HTML 设计

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-28 16:46) |
| Artifacts | [Artifacts](../artifacts/design-attention-menu-html/) |
| Kind | Task |

## Scope

制作并迭代独立设计 HTML 和浏览器截图证据，不修改产品源码或安装态。中文原型，以用户截图的深色半透明菜单为视觉参考；StyleKit Glassmorphism 的玻璃材质、深色底和 24px 圆角作为补充。当前状态、项目和等待原因均为模拟，不表示真实运行数据。

## Plan

1. 收紧统计区域，将待回复置于收藏项目之前；保留设置、退出入口。
2. 使用内嵌 CSS/JavaScript、Canvas 动画，提供查看、模拟回复、提醒开关、重置和空态；迭代加入待回复/未读完成/失败分类、18条未读完成、固定高度内部滚动与批量已读。
3. 进行 JavaScript 语法检查和独立无头 Chrome 页面检查，查看桌面/窄屏截图；不运行项目测试。

## Decisions

- 点击查看不移除等待或失败项，只有显式模拟回复才移除等待并增加模拟运行数；完成项模拟定位成功后标为已读，批量已读只影响未读完成分类；全部分类继续保留已读完成与空闲，排除运行中。默认待回复，无等待时按失败、未读完成、全部顺序选择；用户主动选择的分类在清空后也保持，不自动跳页。
- 不调用通知权限、真实终端或网络服务；减少动态效果偏好下停止动画，后台暂停绘制。
- 页面为离线单文件；截图与浏览器观察记录仅为验证证据，不是运行依赖。
- 浏览器 MCP 连接失败，改用独立临时配置的无头 Chrome。首次 CDP 错选非页面 target，修正为 type=page 后成功完成检查；未修改用户 Chrome 配置或重启 iTermate。
- 第二版已查看桌面完成分类及390px窄屏截图，无横向溢出；待回复、18条完成、失败与空态下菜单高度均为830px，列表可视310px、18条内容1448px，滚动可达末项。查看完成18→17，批量已读17→0，等待仍2、失败仍1；点击等待或失败不清除状态；模拟回复与重置正常。浏览器未捕获运行异常。证据为 browser-check-v2.txt 和 menu-v2-* 截图。未验证原生 macOS UI，未运行单元测试。
- 本任务没有改变项目事实，Context 与 Lessons 不修改。

## Target
- [x] T4: 同一 HTML 新增全部分类，展示所有非运行会话（待回复、已读及未读完成、失败、空闲）；运行会话不在全部中，单条和批量已读不删除全部中的完成项，模拟回复后转运行并从全部移除。
- [x] T1: 参考用户截图制作可直接打开的单文件 HTML，展示加入待回复入口的新版 iTermate 菜单，保留运行概览、收藏项目与设置退出入口。
- [x] T2: 使用模拟数据展示基本交互与动画像素状态图标，不连接或修改真实 App 和会话。
- [x] T3: 同一 HTML 展示待回复、未读完成、失败分类和大量会话内部滚动；查看或批量已读仅清除完成项，保留等待失败；统计注明次数，设置去除省略号与未实现快捷键。

## Result

- T1: 同一离线HTML继续保留概览、收藏与底部入口；第三版桌面和390px窄屏截图已查看，无横向溢出。
- T2: Canvas状态含新增空闲图标，内存模拟回复及重置正常；JS语法通过、浏览器无运行异常，无真实会话操作。
- T3: 原有分类和固定滚动布局保留；未读完成18→17→0，等待2和失败1不受已读操作影响；设置及统计文案保留。
- T4: 全部显示24个非运行会话，含待回复/完成/失败/空闲，运行行0；已读后全部仍24，重复查看不重复减少未读；回复后全部24→23、运行2→3，已回复会话从全部移除；390px下四个分类容器无溢出。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 独立原型新增一个筛选视图并分离已读标记，影响可控且可重置。
- Snapshot: snapshot:tasks/artifacts/design-attention-menu-html/evidence/80eb7fb1ac3f4fb96ed94e8bf1203614864538ef6c8db47889a460e3ec323535.json#80eb7fb1ac3f4fb96ed94e8bf1203614864538ef6c8db47889a460e3ec323535
- Evidence: browser-check-v3.txt及已查看的menu-v3-all.png、menu-v3-mobile.png。
- Result clarity: 全部定义为非运行会话，保留已读完成及空闲，已在当前Target声明。
- Bounded impact: 仅单文件原型内存筛选和已读标记，未改产品或安装态。
- Low risk: 模拟数据可重置，无网络、真实权限或数据删除。
- Sufficient verification: 脚本语法、浏览器全部类型及排除运行、单条重复/批量已读、模拟回复、窄屏和截图检查通过；未运行单元测试。
- Task fingerprint: 7a442205771fa1e219146460af23326f87334691cb5cebb0620e7ddd348c6848

## Verification

- Passed: 第三版内容与快照一致；全部数和未读数独立，等待回复后转运行并被排除，桌面和窄屏布局已观察；Context无产品事实变化无需更新。
