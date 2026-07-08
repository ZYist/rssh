---
status: testing
phase: 01-broadcast-ui-state
source: [01-VERIFICATION.md]
started: 2026-07-08T13:05:00Z
updated: 2026-07-08T13:05:00Z
---

# Phase 01: Broadcast UI & State — UAT

自动化三件套全绿（`tsc` / `npm run build` / 391 tests），6/8 must-haves 已由代码 grep + 接线验证 VERIFIED。以下 5 项是**运行期 / 像素级**行为，CI 无法证伪，需在桌面 GUI（`npm run tauri dev`）人工确认。

每项测完把 `result: [pending]` 改成 `result: pass` 或 `result: fail`（失败时附复现步骤）。全部 pass 后跑 `/gsd-verify-work 01` 收尾，phase 自动转 complete。

## Current Test

number: 1
name: SC4 per-tab 持久化（互补 T4）
expected: |
  开启广播 + 勾选 2 个目标 + 折叠目标条 → 切到另一 AI tab → 切回 → 关闭 AI 面板 → 重新打开 AI 面板。
  ON 态、2 个目标勾选、折叠态三者全保留（`_broadcastByTab` 是 `store.svelte.ts:78` 模块顶层 `$state`，ChatPanel unmount 不影响它）。
awaiting: user response

## Tests

### 1. SC4 per-tab 持久化（互补 T4）

**操作：** 开启广播 + 勾选 2 个目标终端 + 折叠目标条 → 切到另一个 AI tab → 切回原 tab → 关闭 AI 面板 → 重新打开 AI 面板。

**预期：** ON 态、2 个目标、折叠态三者与关面板前完全一致。

**为什么人工：** 模块级 `$state` 跨组件 unmount 的存活是 Svelte 5 运行期契约，grep 只能证伪"状态在模块顶层、非组件本地"，无法证明重挂载时确实读到同一份模块状态。仓库内无 broadcast store 单测覆盖 close-reopen 路径。

expected: ON 态、2 个目标、折叠态三者全保留
result: [pending]

### 2. D-11 prune（互补 T7）

**操作：** 勾选目标终端 A → 关闭 tab A → 观察广播开关徽标计数。

**预期：** 徽标 N 减 1，A 从选中态剔除（accent halo 消失）。

**为什么人工：** prune 是反应管道（`connectedSessions()` 变 → `sessions` `$derived` 重算 → `$effect` 重跑 → `pruneBroadcastTargets` filter+重建 Set → `_broadcastByTab` 重赋值 → 徽标 `$derived` 重算），grep 能验证每段接线但无法证明链路在运行期按时序触发。仓库内无 broadcast prune 单测。

**互补测试（主标签路径）：** 另开一个主标签开启广播 → 关闭该主标签 → 重开同位置 → 确认 `_broadcastByTab[tab_id]` 无残留（`stopSession` 第 364 行 `delete`）。

expected: 目标 tab 关闭后徽标 N 递减、A 剔除；主标签关闭后无残留
result: [pending]

### 3. D-08 视觉（accent 非红）

**操作：** 开启广播模式，同时开启 DangerModeToggle（危险模式）。对比两个开关的激活色。

**预期：** 广播开关激活态是 accent 蓝（`var(--accent)`），DangerModeToggle 激活态是 error 红（`var(--error)`），两者视觉语义不混淆。

**为什么人工：** CSS token 已 grep 确认（无 `--error` 出现在任何 `.broadcast-` 规则，`ChatPanel.svelte:564-571` 用 `var(--accent)`），但像素级着色需人眼确认。

expected: 广播开关 accent 蓝，DangerModeToggle 红，两者分明
result: [pending]

### 4. BCAST-02/03 功能冒烟（勾选即时反映）

**操作：** 开启广播 → 目标条出现 → 勾选一个终端 → 观察 halo + 徽标 → 取消勾选 → 观察 halo + 徽标。

**预期：** 勾选即时出现 accent halo + 徽标 +1；取消即时消失 + 徽标 -1。

**为什么人工：** Svelte 5 Set 反应性（重建 Set + 整体替换 record）由代码 grep 证明，但 UI 实时刷新需运行期确认。

expected: 勾选/取消即时反映 halo + 徽标计数
result: [pending]

### 5. EditPane hover 预览回归（01-01 D3 遗留）

**操作：** 打开 EditPane（编辑器底部的"新建编辑"面板），悬停目标列表行。

**预期：** `SessionPreviewPopover` 弹出，锚点位置与 01-01 改造前一致（`onHover` 经 `BroadcastTargetSelector` 可选 prop 转发，零回归）。

**为什么人工：** popover 锚点坐标是运行期 DOM 行为，自动化编译/类型/单测无法证伪。

expected: SessionPreviewPopover 弹出位置与改造前一致
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps

（测完填写——失败项在此记录复现步骤）
