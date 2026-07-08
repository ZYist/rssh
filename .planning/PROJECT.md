# AI Broadcast Mode

## What This Is

RSSH 的 AI 面板新增"广播模式"开关。开启后，AI 只与当前活跃标签交互（读取输出、做诊断），但所提议的命令在用户批准后会自动同步发送给所有用户勾选的终端标签。适用于同时管理多台相同配置机器的运维场景。

## Core Value

AI 对一台机器做诊断/操作，操作指令自动同步到其它同类机器——减少重复操作，保持多机一致性。

## Requirements

### Validated

- ✓ Edit 面板广播功能 — existing（`broadcastToSessions`、`pickBroadcastText`）
- ✓ AI 面板单终端命令执行 — existing（`CommandConfirmDialog` → `executeCommand`）
- ✓ Session registry — existing（`_sessions` 列表、`registerSession`/`unregisterSession`）

### Active

- [ ] AI 面板广播模式开关 UI（toggle button in ChatPanel）
- [ ] 广播目标选择器（勾选哪些标签参与广播）
- [ ] 命令执行时广播分发逻辑（Approve 后同时发给勾选标签）
- [ ] 审批流程跟随现有 danger_mode / auto_run_command 设置
- [ ] 输出收集：AI 只读当前标签输出，其它标签静默执行
- [ ] 广播状态持久化（tab 级别，切换 tab 后模式保持）

### Out of Scope

- 汇总所有终端输出返回给 AI — 信息量过大，AI 上下文会爆
- 不同标签执行不同命令 — 不是广播的语义
- Raw device（Serial/Telnet）默认参与广播 — 这些设备太敏感，需要显式勾选确认

## Context

- 现有 `broadcastToSessions(tabIds, text)` 在 `app.svelte.ts:466` 已实现纯文本广播
- AI 命令执行入口在 `CommandConfirmDialog.svelte` 的 `approve()` → `ai.executeCommand()`
- `executeCommand` 针对单 tab 执行，需要在此基础上扩展广播路径
- Session registry（`_sessions`）已维护所有已打开的终端列表及其类型
- AI 面板绑定 tab 通过 `tabId` prop 传入，当前是一对一关系

## Constraints

- **Tech stack**: Svelte 5 + Tauri — 前端状态用 `$state`/`$derived` runes
- **兼容性**: 广播模式关闭时行为必须与当前完全一致，不能影响现有 AI 流程
- **性能**: 广播发送应并行，不能串行等待每个终端执行完
- **安全性**: Raw device 标签默认不参与广播（需显式勾选），避免误操作

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AI 只读当前标签输出 | 多终端输出汇总会爆 AI 上下文，且用户本意是同步操作，一台代表全部 | — Pending |
| 复用 broadcastToSessions 通道 | 已有基础设施，pane 的 sendText 已处理各 transport 的 EOL/slow-send | — Pending |
| 审批跟随现有 danger_mode 设置 | 一致的用户心智模型，不引入额外开关 | — Pending |
| 广播目标用户可勾选 | 比"全部"更安全、更灵活 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-08 after initialization*
