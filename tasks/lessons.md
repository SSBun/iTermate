# 2026-07-28 — 不默认启用浮动面板点击穿透

## Trigger

- 新增或调整覆盖其他应用的 `NSPanel`。
- 用户未明确要求鼠标事件穿透面板。

## Rule

- 不要设置 `ignoresMouseEvents = true`。
- 展示型面板也应默认接收其覆盖区域内的点击，除非用户明确要求 click-through。

## Check

- 运行时确认面板的 `ignoresMouseEvents` 为 `false`。
- 点击面板覆盖区域不会命中下方应用。
