---
status: testing
phase: 02-broadcast-dispatch-safety
source: [02-VERIFICATION.md]
started: 2026-07-09T10:20:00Z
updated: 2026-07-09T10:20:00Z
---

# Phase 2: Broadcast Dispatch & Safety — UAT

**自动化 + 结构性检查全部通过**（tsc 0 / vitest 391 / build OK；9/9 must-have truths 在源码 VERIFIED；BCAST-05/06/07/08 全部 SATISFIED）。以下 5 个端到端 GUI 场景需运行桌面 GUI + 真实 SSH/serial 终端，无法自动化。

## Current Test

number: 1
name: 场景 A（兼容性）—— 广播关闭，Approve 一条 AI 命令
expected: |
  主标签经 executeCommand 正常执行命令；其它终端标签无任何写入或视觉变化（与 Phase 1 行为完全一致）。
awaiting: user response

## Tests

### 1. 场景 A（兼容性）
expected: 广播关闭时 Approve 一条 AI 命令 → 主标签正常执行，其它标签无变化（与 Phase 1 一致）。结构性守卫：三处广播块均以 `if (ai.broadcastEnabled(tabId))` 开头，关闭时整体跳过。
result: [pending]

### 2. 场景 B（BCAST-05/06）
expected: 广播开启 + 勾选 2 个 SSH 目标，Approve 一条命令 → 主 + 2 目标三个标签几乎同时出现该命令的执行；主标签输出收集不被广播阻塞。源码顺序已证明：broadcastToSessions 在 `await executeCommand` 之前。
result: [pending]

### 3. 场景 C（BCAST-07）
expected: 广播执行完成后，AI 的后续回复只引用主标签 sentinel 采集的输出，不含目标标签输出。结构性隔离：executeCommand 只 listen 主 session 的 data 事件，广播目标走 sendText 从不被监听。
result: [pending]

### 4. 场景 D（BCAST-08 + D-02）
expected: 广播开启 + 勾选一个 serial 标签 + danger_mode 开启 + auto_run_command 开启 → 命令不自动批准，弹出人工 Approve/Reject dialog。onMount 因 `hasRawBroadcastTarget()` 返回 true 不触发自动 approve。
result: [pending]

### 5. 场景 E（D-03）
expected: 广播执行中点"终止" → 主标签 + 所有目标标签同时收到 Ctrl+C（`\x03`）中断；目标机器不在主标签中断后继续跑已广播的命令。源码：terminate() 在 `await terminateCommand` 之前 broadcastToSessions ETX。
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
