# Phase 1: Broadcast UI & State - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 1-Broadcast UI & State
**Areas discussed:** 目标选择器呈现方式、当前标签(源)的处理、Raw device 标签处理、开关按钮外观与徽章

---

## 目标选择器呈现方式

| Option | Description | Selected |
|--------|-------------|----------|
| 内联折叠条 (推荐) | 工具栏下方持久目标条，复用 EditPane .session-panel 紧凑行视觉，挤占对话区 | |
| 气泡弹层 popover | 锚定开关按钮的气泡，按需弹出，对话区全高 | |
| 我另有想法 | 用户描述自定义布局 | ✓（初选） |

**User's choice:** 初选"我另有想法"，随后说明："现阶段已有的广播按钮已经很好了，就是新建编辑按钮点击后出来的 Edit 界面" —— 即要求**复用 EditPane 现成广播选择器 UX**，不另设计。

**Notes:** 发现约束：AI 面板（`.ai-side`）宽 280–380px，EditPane 200px 右侧栏无法原样套入。回放适配方案后用户确认：(1) 抽共享组件 `BroadcastTargetSelector.svelte`，EditPane + ChatPanel 复用；(2) AI 面板里以工具栏下方内联条呈现；(3) 不带 EditPane 的 `Broadcast(N)` 动作按钮。

| 子决策 | Option | Selected |
|--------|--------|----------|
| 目标条展开行为 | 始终展开 / 允许折叠 | 允许折叠 ✓（用户："允许折叠，然后继续"） |

---

## 当前标签（源）的处理

| Option | Description | Selected |
|--------|-------------|----------|
| 锁定源行置顶 (推荐) | 主标签作锁定"源"行置顶，不可勾，淡 accent 背景，把非对称模型可视化 | |
| 隐藏主标签 | 主标签不出现在列表，只列其它终端，最简洁 | ✓ |

**User's choice:** 隐藏主标签
**Notes:** 选择器只列 `app.connectedSessions()` 中除主标签 session 外的终端；计数 N/M 与空状态按"除主标签"计算。

---

## Raw device 标签处理

| Option | Description | Selected |
|--------|-------------|----------|
| 照常列出可勾 (推荐) | serial/telnet 跟 SSH/local 一视同仁，符合 BCAST-02/03 + 复用 EditPane 一致 | ✓ |
| 列出但警告锁定 | 加 "⚠ raw device" 标记、默认锁定、需显式解锁，把 v2 安全提前 | |
| 暂不列入（只 SSH/local） | 最安全，但违反 BCAST-02 "列出所有终端标签" | |

**User's choice:** 照常列出可勾
**Notes:** raw device 安全默认排除完整留给 v2（PROJECT Out of Scope + REQUIREMENTS v2）。Phase 1 符合 BCAST-02/03 字面要求。

---

## 开关按钮外观与徽章

**预设默认（用户未反对）：** 激活态用 accent 色（非红 —— 红色是 DangerModeToggle 危险语义，广播是常规功能态，混用误导）。

| 计数徽章 Option | Description | Selected |
|--------|-------------|----------|
| 带计数徽章 (推荐) | 右下角小圆徽显示已选目标数；折叠时是唯一状态反馈；0 时置灰/隐藏 | ✓ |
| 不带徽章 | 纯图标，最简洁；折叠后无数量反馈 | |

| 开关图标 Option | Description | Selected |
|--------|-------------|----------|
| 发射塔/广播波 (推荐) | 一源辐射多目标，最贴广播语义 | ✓ |
| 扩音器 megaphone | 一对多宣告，偏公告感 | |
| 卫星锅 satellite | 信号中继，但易与 Wi-Fi 图标混 | |
| 由 Claude 定 | 从 lucide/feather 选最贴合的 | |

**User's choice:** 带计数徽章 + 发射塔/广播波图标
**Notes:** 16×16 手绘 stroke SVG，currentColor，stroke-width=2，跟现有工具栏图标视觉重量一致。

---

## Claude's Discretion

- 具体 state 字段形状（按 `ai/store.svelte.ts` 现有 per-tab 结构对齐）
- 空状态文案、tooltip 文案、徽章 0 值视觉（置灰 vs 隐藏）
- 开关按钮在工具栏的精确位置（建议挨着 DangerModeToggle）
- 折叠条默认初始态（首次开启广播时展开 or 收起）
- 共享组件抽取边界（`BroadcastTargetSelector` 含/不含标题计数行；EditPane 改造时如何保留其 `Broadcast(N)` 按钮）

## Deferred Ideas

- Raw device 默认排除 + 显式解锁勾选 → v2
- 目标选择跨 session/重启持久化 → v2
- 广播执行后 toast 反馈 → v2
- 断线/失联目标自动检测 + toast → v2
- 广播事件写审计日志 → v2（与 `src-tauri/src/ai/audit.rs` 协同）
- 广播模式下抑制 auto-approve（安全增强）→ v2
