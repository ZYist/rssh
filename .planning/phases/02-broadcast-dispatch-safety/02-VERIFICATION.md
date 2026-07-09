---
phase: 02-broadcast-dispatch-safety
verified: 2026-07-09T14:20:00Z
status: passed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps: []
human_verification:
  - test: "场景 A（兼容性）：广播关闭，Approve 一条 AI 命令 → 主标签正常执行，其它标签无变化（与 Phase 1 一致）"
    expected: "主标签经 executeCommand 正常执行命令；其它终端标签无任何写入或视觉变化"
    why_human: "需运行桌面 GUI + 真实终端，自动化无法观察跨标签的实际副作用与视觉无变化"
  - test: "场景 B（BCAST-05/06）：广播开启 + 勾选 2 个 SSH 目标，Approve 一条命令 → 主 + 2 目标几乎同时执行该命令"
    expected: "三个标签几乎同时出现该命令的执行；主标签输出收集不被广播阻塞"
    why_human: "需真实 SSH session 验证命令实际抵达并执行；并行时序需人工肉眼观察"
  - test: "场景 C（BCAST-07）：广播执行完成后，AI 的后续回复只引用主标签输出，不含目标标签输出"
    expected: "AI 后续 turn 的 context 仅含主标签 sentinel 采集的输出；广播目标的输出不回流 AI"
    why_human: "需真实 LLM 调用 + 多终端输出对比；结构性隔离已在源码验证，运行时回流确认需端到端环境"
  - test: "场景 D（BCAST-08 + D-02）：广播开启 + 勾选一个 serial 标签 + danger_mode 开启 + auto_run_command 开启 → 命令不自动批准，弹出人工 Approve/Reject dialog"
    expected: "onMount 因 hasRawBroadcastTarget() 返回 true 不触发自动 approve；显示人工 Approve/Reject 按钮"
    why_human: "需真实 serial 标签 + AI 命令提议链路；条件组合的运行时降级行为需桌面 GUI 确认"
  - test: "场景 E（D-03）：广播执行中点'终止' → 主标签 + 所有目标标签同时收到 Ctrl+C 中断"
    expected: "所有广播目标与主标签对称收到 \\x03；目标机器不在主标签中断后继续跑已广播的命令"
    why_human: "需真实终端验证 Ctrl+C 实际中断各目标；对称终止的运行时效果需人工观察"
---

# Phase 2: Broadcast Dispatch & Safety 验证报告

**Phase Goal:** Approved AI commands automatically broadcast to all selected targets in parallel while the AI reads only the primary tab's output
**Verified:** 2026-07-09T14:20:00Z
**Status:** passed (human UAT complete 2026-07-09 — 5/5 scenarios pass)
**Re-verification:** Human UAT completed after the initial structural pass. All 5 GUI scenarios (A–E) passed in `02-UAT.md`. **Value of the human pass:** scenario B surfaced a runtime Enter-byte bug the structural verification could not catch — PowerShell/ConPTY broadcast targets received `\n` instead of `\r` and never auto-executed (sendText SSH/local branch wrote raw). Fixed in quick `260709-jat` (commit `1e137e0`, +5 unit tests) and re-verified pass. The 9/9 must-have structural truths remain accurate; BCAST-05/06 now hold at runtime too.

## Goal Achievement

### Observable Truths

| #   | Truth (派生自 ROADMAP Phase 2 Success Criteria) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | BCAST-05：Approve 且广播开启时，主标签经 executeCommand（带 sentinel）执行，所有勾选目标经 broadcastToSessions 收到 raw cmd.cmd + 换行 | ✓ VERIFIED | `CommandConfirmDialog.svelte:174-180`：`if (ai.broadcastEnabled(tabId))` 守卫 → 取 targets → `targets.size > 0` → `app.broadcastToSessions([...targets], cmd.cmd + "\n")`（line 177，用 `cmd.cmd` 非 `full_cmd`）紧接 `await ai.executeCommand(...)`（line 180）。grep 确认 dialog 内无 `full_cmd` |
| 2 | BCAST-06：广播 fire-and-forget 在 await executeCommand 之前完成排队，主标签输出收集不被阻塞 | ✓ VERIFIED | 源码顺序证明：broadcastToSessions 在 line 174-179，`await ai.executeCommand` 在 line 180。`broadcastToSessions`（app.svelte.ts:466-473）是同步 for 循环返回 void（每目标 `_terminalControls.get(tabId)?.sendText(text)`），在 await 之前完成 invoke 排队 |
| 3 | BCAST-07：AI 只读主标签输出——executeCommand 只 listen 主 session 的 data 事件，广播目标走 sendText 从不被监听（结构性隔离） | ✓ VERIFIED | `store.svelte.ts:592` `const dataEvent = \`${TRANSPORT[target_kind].data}:${target_session_id}\``（绑定主 session id）→ `store.svelte.ts:666` `exec.unlisten = await listen(dataEvent, ...)`。广播目标经 sendText→invoke(writeCmd) 写入各自 session，其输出 emit `<transport>:data:<target_session_id>`（不同事件名），listener 按名隔离无法接收。结构性保证，无需过滤代码 |
| 4 | BCAST-08：审批流程在广播开关与否时行为一致——广播关闭/无目标时 approve/terminate/onMount 与 Phase 1 完全一致；D-02 raw 降级是既有 raw 约束延伸 | ✓ VERIFIED | 三处广播块均以 `if (ai.broadcastEnabled(tabId))` 开头（line 174, 218）→ 关闭时跳过；`hasRawBroadcastTarget()` 首行 `if (!ai.broadcastEnabled(tabId)) return false`（line 76）→ 关闭时 onMount 条件不受影响。D-02 降级同时要求 broadcastEnabled AND raw 目标存在（line 76-83），是既有 raw 安全约束（`!isRawDeviceKind(targetKind)` line 118）的扩展，非广播开关单独引入的新 dialog |
| 5 | 广播模式下点终止，主标签 + 所有广播目标对称收到 \x03（Ctrl+C） | ✓ VERIFIED | `CommandConfirmDialog.svelte:218-224`：`if (ai.broadcastEnabled(tabId))` → `app.broadcastToSessions([...targets], "\x03")`（line 221，字面单字节 ETX）紧接 `await ai.terminateCommand(...)`（line 224）。与主标签 exec.terminate()（store.svelte.ts:618-623 `invoke(writeCmd, {data: [3]})`）字节级一致 |
| 6 | sendText 的 SSH/local invoke 路径不再产生 unhandled Promise rejection——失败时 console.warn | ✓ VERIFIED | `TerminalPane.svelte:632-633`：`void invoke(writeCmd, {...}).catch((e) => console.warn("[broadcast] sendText 写入失败:", e))`。非空箭头；签名仍 `function sendText(text: string)` 返回 void |
| 7 | 广播关闭 OR 无目标时，approve/terminate/onMount 行为与 Phase 1 完全一致（零回归） | ✓ VERIFIED | 见 Truth 4 守卫分析。broadcastToSessions 在 broadcastEnabled=false 时整体跳过；targets.size===0 时内层 if 跳过；sendText 的 .catch 是纯附加（成功路径不变） |
| 8 | 广播调用从组件层（CommandConfirmDialog）发起，组件 import app + ai；不在 ai/store.svelte.ts import app（避免 ES module 循环依赖） | ✓ VERIFIED | import 在 `CommandConfirmDialog.svelte:17` `import * as app from "../stores/app.svelte.ts"`。app.svelte.ts:2 已 import ai/store.svelte.ts，反向 import 会成循环——确认 store.svelte.ts 未 import app |
| 9 | raw 广播目标存在时自动批准降级为人工 dialog（D-02，BCAST-08 安全约束延伸） | ✓ VERIFIED | `hasRawBroadcastTarget()`（line 75-84）读 broadcastTargets + connectedSessions，对每个 target 查 session 并 `isRawDeviceKind(s.type)` 判定；onMount 条件（line 121）`&& !hasRawBroadcastTarget()`。SessionEntry.type（app.svelte.ts:409）= `"ssh"\|"local"\|"serial"\|"telnet"` 与 AiTargetKind（types.ts:104）相同 string union，类型检查通过 |

**Score:** 9/9 truths verified (0 present, behavior-unverified)

全部 9 条 must-have truths 在源码层 VERIFIED。无 FAILED、无 STUB、无 MISSING、无 NOT_WIRED。

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `src/lib/ai/CommandConfirmDialog.svelte` | D-01 approve 广播 + D-02 raw 安全门 + D-03 对称终止 + import app | ✓ VERIFIED | Level 1 存在（434 行）；Level 2 实质（import:17、hasRawBroadcastTarget:75-84、approve 广播:174-179、terminate 广播:218-223、onMount 守卫:121）；Level 3 wired（被 ChatPanel 渲染）；Level 4 数据流真实（broadcastEnabled/broadcastTargets 读 _broadcastByTab 真实状态） |
| `src/lib/components/TerminalPane.svelte` | D-04 sendText SSH/local invoke 补 .catch | ✓ VERIFIED | Level 1 存在；Level 2 实质（sendText:626-634 含 `void invoke(...).catch(...)`）；Level 3 wired（被 AppShell tab dispatcher 渲染 + registerTerminalControls:1209）；Level 4 数据流真实（broadcastToSessions→sendText→invoke 写真实 sessionId） |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| approve() PTY 分支 | broadcastToSessions | `app.broadcastToSessions([...targets], cmd.cmd + "\n")` 在 `await ai.executeCommand` 之前 | ✓ WIRED | line 177 调用 → line 180 await。源码顺序确认 |
| terminate() | broadcastToSessions | `app.broadcastToSessions([...targets], "\x03")` 在 `await ai.terminateCommand` 之前 | ✓ WIRED | line 221 调用 → line 224 await。对称性确认 |
| onMount 自动批准 | hasRawBroadcastTarget | `&& !hasRawBroadcastTarget()` 守卫项 | ✓ WIRED | line 121。放在 `!isRawDeviceKind(targetKind)`（line 118）之后 |
| sendText SSH/local 路径 | invoke writeCmd | `void invoke(writeCmd, ...).catch(e => console.warn(...))` | ✓ WIRED | line 632-633。void 前缀 + console.warn（非空箭头） |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| CommandConfirmDialog approve 广播 | `targets` | `ai.broadcastTargets(tabId)` → `_broadcastByTab`（Phase 1 真实 per-tab 状态） | ✓ | FLOWING |
| CommandConfirmDialog 广播字段 | `cmd.cmd` | CommandProposed.cmd（用户可见原始命令） | ✓ | FLOWING |
| hasRawBroadcastTarget | sessions | `app.connectedSessions()` → `_sessions`（真实连接表） | ✓ | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| 类型检查 | `npx tsc --noEmit` | TSC_OK（退出码 0） | ✓ PASS |
| 既有测试零回归 | `npx vitest run` | 391 passed (31 files) | ✓ PASS |
| Svelte 编译 | `npm run build` | built in 4.28s（退出码 0） | ✓ PASS |
| 端到端命令分发（多 SSH 目标） | 需桌面 GUI + 真实终端 | 无法自动化 | ? SKIP → human_verification |

Step 7b/7c: 行为 spot-check 的前 3 项已 PASS。端到端运行时行为（场景 A-E）需桌面 GUI + 真实 SSH/serial 终端，转入 human_verification。无 phase 声明或常规 probe（纯前端阶段），Step 7c SKIPPED。

### Probe Execution

无 phase 声明 probe（PLAN/SUMMARY 无 probe 引用），scripts/ 下无常规 probe-*.sh。纯前端阶段。SKIPPED（无 probe 适用）。

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| BCAST-05 | 02-01-PLAN | Approve 后主标签 executeCommand + 广播目标收 cmd.cmd+"\n" | ✓ SATISFIED | Truth 1 |
| BCAST-06 | 02-01-PLAN | 广播与主执行并行，不阻塞主标签输出收集 | ✓ SATISFIED | Truth 2 |
| BCAST-07 | 02-01-PLAN | AI 只读主标签输出，广播目标静默执行 | ✓ SATISFIED | Truth 3 |
| BCAST-08 | 02-01-PLAN | 审批流程跟随 danger_mode/auto_run，广播不引入额外审批 | ✓ SATISFIED | Truth 4 |

无 ORPHANED 需求：REQUIREMENTS.md 将 BCAST-05/06/07/08 全部映射到 Phase 2，PLAN frontmatter 声明全部 4 个 ID，一一对应。

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | 无 TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER/未实现标记 | ℹ️ Info | 两个改动文件均无 debt marker |
| — | — | 无空实现（return null / return [] / => {}）于改动路径 | ℹ️ Info | sendText 的 .catch 非 CONVENTIONS Pr2 禁止的空箭头 |

Commits 验证：`44a7295`（feat: wire broadcast dispatch）+ `f8b3cef`（fix: catch sendText rejection）均存在（git cat-file -t → commit）。

### Human Verification Required

5 个端到端 GUI 场景（PLAN §verification 列出 A-E），需运行桌面 GUI + 真实 SSH/serial 终端，无法在此自动化。结构性 truths 已全部 VERIFIED，以下为运行时端到端确认项（详见 frontmatter human_verification）：

1. **场景 A（兼容性）** — 广播关闭 Approve → 主标签正常、其它无变化
2. **场景 B（BCAST-05/06）** — 广播开启 + 2 SSH 目标 Approve → 三标签几乎同时执行
3. **场景 C（BCAST-07）** — AI 后续回复只引用主标签输出
4. **场景 D（BCAST-08 + D-02）** — 广播 + serial 目标 + danger_mode + auto_run → 不自动批准、弹人工 dialog
5. **场景 E（D-03）** — 广播执行中终止 → 主 + 所有目标同时 Ctrl+C

### Gaps Summary

无 gap。全部 9 条 must-have truths 在源码层 VERIFIED，所有 artifact 通过 Level 1-4 检查，所有 key link WIRED，tsc/vitest(391)/build 全绿，无 debt marker，commits 存在。

**状态为 human_needed 而非 passed 的原因：** 5 个端到端 GUI 场景（A-E）需运行桌面 GUI + 真实 SSH/serial 终端，自动化无法完成。这是 PLAN §verification 明确列为人工的项，且任务要求捕获为 human_verification。结构性保证（广播接线、并行源码顺序、输出按 session-id 名隔离、兼容性守卫、sendText 错误卫生）已全部在源码验证通过；human 项是端到端运行时确认，非结构性 gap。

---

_Verified: 2026-07-09T10:15:00Z_
_Verifier: Claude (gsd-verifier)_
