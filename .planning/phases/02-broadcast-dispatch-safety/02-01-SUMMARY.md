---
phase: 02-broadcast-dispatch-safety
plan: "01"
subsystem: ai-broadcast-dispatch
tags: [svelte5, runes, broadcast-dispatch, safety-gate, fire-and-forget]
dependency_graph:
  requires:
    - "phase-01 broadcast UI + per-tab state (broadcastEnabled/broadcastTargets/toggleBroadcast)"
    - "app.broadcastToSessions primitive (app.svelte.ts:466)"
    - "ai.isRawDeviceKind helper (types.ts:112)"
  provides:
    - "AI command broadcast dispatch on approve (D-01)"
    - "Raw device broadcast target safety gate on auto-approve (D-02)"
    - "Symmetric Ctrl+C terminate across broadcast targets (D-03)"
    - "sendText SSH/local invoke rejection hygiene (D-04)"
  affects:
    - "src/lib/ai/CommandConfirmDialog.svelte"
    - "src/lib/components/TerminalPane.svelte"
tech_stack:
  added: []
  patterns:
    - "fire-and-forget broadcast before await executeCommand (parallel dispatch)"
    - "component-layer dual-store import (app + ai) to avoid ES module cycle"
    - "void invoke(...).catch(console.warn) for unhandled rejection hygiene"
key_files:
  created: []
  modified:
    - "src/lib/ai/CommandConfirmDialog.svelte"
    - "src/lib/components/TerminalPane.svelte"
decisions:
  - "D-01: broadcastToSessions(cmd.cmd + newline) before await executeCommand — fire-and-forget parallel"
  - "D-02: hasRawBroadcastTarget() degrades auto-approve to manual dialog when raw targets present"
  - "D-03: broadcastToSessions(\"\\x03\") before terminateCommand — symmetric Ctrl+C"
  - "D-04: sendText SSH/local invoke gets void prefix + .catch(console.warn)"
  - "Import app store in component layer (not ai/store) to avoid circular ES module dependency"
metrics:
  duration: "260s"
  completed: 2026-07-09
  tasks: 2
  files: 2
status: complete
---

# Phase 02 Plan 01: Broadcast Dispatch & Safety Summary

**One-liner:** 接通 AI 审批命令的广播分发——approve 先 fire-and-forget 广播 raw cmd.cmd 到所有勾选目标再执行主标签；raw device 广播目标降级自动批准为人工 dialog；terminate 对称向所有目标发 Ctrl+C；sendText SSH/local 路径补 invoke reject 捕获。

## What Was Built

### Task 1: CommandConfirmDialog 广播分发 + 安全门 + 对称终止 (D-01/D-02/D-03)

对 `src/lib/ai/CommandConfirmDialog.svelte` 做 4 处改动，全部严格复用既有 API：

1. **新增 import** — `import * as app from "../stores/app.svelte.ts";`（组件层同时 import app + ai 两个 store，与 ChatPanel 先例一致；禁止在 ai/store.svelte.ts import app 以避免 ES module 循环依赖）。

2. **D-01 approve() PTY 分支广播** — 在 `await ai.executeCommand(...)` 之前插入 fire-and-forget 广播。前置守卫 `if (ai.broadcastEnabled(tabId))` + 内层 `if (targets.size > 0)`，广播字段严格用 `cmd.cmd + "\n"`（用户可见原始命令，绝不使用 full_cmd——后者含 sentinel + exit-code 回显会污染目标 shell）。广播在 await 之前完成同步排队 invoke，主标签执行与广播目标执行天然并行（BCAST-06）。

3. **D-02 raw 广播目标安全门** — 新增 local helper `hasRawBroadcastTarget()`：读 `ai.broadcastEnabled(tabId)` + `ai.broadcastTargets(tabId)` + `app.connectedSessions()`，对每个 target tabId 查 session 并用 `isRawDeviceKind(s.type)` 判定。在 onMount 自动批准条件里追加 `&& !hasRawBroadcastTarget()` 守卫项（放在 `!isRawDeviceKind(targetKind)` 之后）。不改 `autoApproveAllowed` pure function。raw 目标存在时自动批准条件不满足，dialog 自然显示人工 Approve/Reject——零新 i18n key。

4. **D-03 terminate() 对称终止** — 在 `await ai.terminateCommand(...)` 之前插入广播。前置守卫 + 取 targets，调 `app.broadcastToSessions([...targets], "\x03")`。控制字节是字面单字节 ETX（U+0003，源码写 `"\x03"`）。normalizeOutgoing 正则仅匹配换行符，ETX 原样通过；对所有 transport 字节级安全（02-RESEARCH §D-03 已逐层追踪）。

### Task 2: TerminalPane sendText 错误卫生 (D-04)

对 `src/lib/components/TerminalPane.svelte` 的 `sendText()` SSH/local 路径做一处修改：裸 `invoke(writeCmd, ...)` 改为 `void invoke(writeCmd, ...).catch((e) => console.warn("[broadcast] sendText 写入失败:", e))`。将 unhandled Promise rejection 转为可控日志输出。sendText 签名不变（void），所有调用方（snippets/paste/EditPane 广播/审批广播）受益。serial/telnet 路径（streamSendBytes）既有行为不变（scope 最小侵入）。

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `44a7295` | feat(02-01): wire broadcast dispatch, raw safety gate, symmetric terminate |
| 2 | `f8b3cef` | fix(02-01): catch sendText SSH/local invoke rejection (D-04) |

## Acceptance Criteria Results

**Task 1 源码断言（全部 grep 验证通过）：**
- AC1: `import * as app from` 出现 1 次 ✓
- AC2: `broadcastToSessions` 出现 3 次（>=2）✓
- AC3: `broadcastToSessions([...targets], cmd.cmd + "\n")` 命中 ✓
- AC4: `hasRawBroadcastTarget` 出现 2 次（定义 + onMount 引用）✓
- AC5: `isRawDeviceKind(s.type)` 命中 1 行 ✓
- AC6: `!hasRawBroadcastTarget()` onMount 守卫命中 ✓
- AC7: terminate 函数体 broadcastToSessions 在 terminateCommand 之前（源码顺序确认）✓
- AC7a: `\x03` 字面控制字节出现 3 次（>=1）✓

**Task 2 源码断言：**
- AC1: sendText SSH/local 路径（line 632）含 `.catch(` ✓
- AC2: catch 回调含 `console.warn`（非空箭头）✓
- AC3: `function sendText(text: string)` 签名不变 ✓

**构建/类型/测试断言：**
- `npx tsc --noEmit` → TSC_OK（退出码 0）✓
- `npm run build` → built in 4.51s（退出码 0）✓
- `npx vitest run` → 391 tests passed (31 files)，零回归 ✓

## Deviations from Plan

None — plan executed exactly as written. All 4 locked decisions (D-01..D-04) implemented verbatim per the research-verified insertion points. No auto-fixes needed.

## Compatibility Invariant (零回归验证)

广播关闭 OR 无目标时所有路径行为与 Phase 1 完全一致——结构性保证：
- **D-01/D-03**：`if (ai.broadcastEnabled(tabId))` 守卫——广播关闭时 broadcastEnabled 返回 false → 广播块整体跳过 → approve/terminate 与改动前字节级一致。
- **D-02**：`hasRawBroadcastTarget()` 首行 `if (!ai.broadcastEnabled(tabId)) return false` → 广播关闭时返回 false → `!false` 不影响 onMount 条件 → 自动批准行为不变。
- **D-04**：sendText 的 `.catch` 是纯附加——成功路径不变，仅失败时从 unhandled rejection 变为 console.warn，不影响任何调用方控制流（sendText 本就返回 void）。

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: src/lib/ai/CommandConfirmDialog.svelte
- FOUND: src/lib/components/TerminalPane.svelte

**Commits verified in git log:**
- FOUND: 44a7295
- FOUND: f8b3cef
