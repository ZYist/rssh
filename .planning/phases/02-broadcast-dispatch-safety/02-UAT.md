---
status: complete
phase: 02-broadcast-dispatch-safety
source: [02-VERIFICATION.md]
started: 2026-07-09T10:20:00Z
updated: 2026-07-09T14:20:00Z
---

# Phase 2: Broadcast Dispatch & Safety — UAT

**自动化 + 结构性检查全部通过**（tsc 0 / vitest 391 / build OK；9/9 must-have truths 在源码 VERIFIED；BCAST-05/06/07/08 全部 SATISFIED）。以下 5 个端到端 GUI 场景需运行桌面 GUI + 真实 SSH/serial 终端，无法自动化。

## Current Test

[testing complete]

## Tests

### 1. 场景 A（兼容性）
expected: 广播关闭时 Approve 一条 AI 命令 → 主标签正常执行，其它标签无变化（与 Phase 1 一致）。结构性守卫：三处广播块均以 `if (ai.broadcastEnabled(tabId))` 开头，关闭时整体跳过。
result: pass

### 2. 场景 B（BCAST-05/06）
expected: 广播开启 + 勾选 2 个 SSH 目标，Approve 一条命令 → 主 + 2 目标三个标签几乎同时出现该命令的执行；主标签输出收集不被广播阻塞。源码顺序已证明：broadcastToSessions 在 `await executeCommand` 之前。
result: pass
note: 初测 issue（目标标签缺回车不执行，PowerShell/ConPTY）→ quick 260709-jat (commit 1e137e0) 修复 sendText SSH/local 的 \n→\r 归一化后复测通过：主 + 2 目标标签几乎同时自动执行，无需手动按回车。

### 3. 场景 C（BCAST-07）
expected: 广播执行完成后，AI 的后续回复只引用主标签 sentinel 采集的输出，不含目标标签输出。结构性隔离：executeCommand 只 listen 主 session 的 data 事件，广播目标走 sendText 从不被监听。
result: pass

### 4. 场景 D（BCAST-08 + D-02）
expected: 广播开启 + 勾选一个 serial 标签 + danger_mode 开启 + auto_run_command 开启 → 命令不自动批准，弹出人工 Approve/Reject dialog。onMount 因 `hasRawBroadcastTarget()` 返回 true 不触发自动 approve。
result: pass

### 5. 场景 E（D-03）
expected: 广播执行中点"终止" → 主标签 + 所有目标标签同时收到 Ctrl+C（`\x03`）中断；目标机器不在主标签中断后继续跑已广播的命令。源码：terminate() 在 `await terminateCommand` 之前 broadcastToSessions ETX。
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "广播开启 + 勾选 SSH 目标 + Approve 命令 → 主标签与所有目标标签几乎同时执行该命令"
  status: resolved
  reason: "User reported: 只有主页面能够跑通指令，其它标签内都是只有指令，但是好像缺少回车符号，需要手动按回车才能跑起来（PowerShell/ConPTY 目标）。注意：'指令不太一样'（主标签带 __rssh_done_ sentinel 包裹、目标标签是裸命令）是 BCAST-07 的正确设计，非 bug。"
  severity: blocker
  test: 2
  resolved_by: "quick 260709-jat (commit 1e137e0) — normalizePtyOutgoing 在 sendText SSH/local 分支把 \\n→\\r"
  resolved_verify: "复测通过：目标标签自动执行，无需手动回车"
  root_cause: "广播 Enter 字节类型错误。主标签路径 executeCommand (src/lib/ai/store.svelte.ts:693) 用 `\\r` 并附注释「ConPTY/PowerShell only accepts \\r; Unix cooked PTY translates \\r → \\n via ICRNL」；广播路径 CommandConfirmDialog.svelte:177 用 `cmd.cmd + \"\\n\"`（LF），经 TerminalPane.svelte:626 sendText 的 SSH/local 分支原样写入（无 \\n→\\r 转换）。PowerShell/ConPTY 不把 LF 当作回车 → 目标标签命令停在提示符不执行。兄弟函数 pasteText (TerminalPane.svelte:644) 已有正确的 `text.replace(/\\r?\\n/g, \"\\r\")` 转换，sendText 遗漏了同一处理。"
  artifacts:
    - path: "src/lib/ai/CommandConfirmDialog.svelte"
      issue: "第 177 行：`app.broadcastToSessions([...targets], cmd.cmd + \"\\n\")` 追加 LF 而非跨平台回车 \\r；与主路径 store.svelte.ts:693 的 enter 推导逻辑不一致。"
    - path: "src/lib/components/TerminalPane.svelte"
      issue: "sendText (第 626 行) 的 SSH/local 分支原样写入 text，未做 \\n→\\r 转换；pasteText (第 644 行) 有此转换，sendText 遗漏。stream 分支已走 normalizeOutgoing 不受影响。"
  missing:
    - "广播发送的回车字节需与目标 transport 的 EOL 语义匹配：SSH/local 用 \\r，telnet 用 \\r\\n（与 executeCommand:693 同一规则）。最小修复：CommandConfirmDialog.svelte:177 把 `cmd.cmd + \"\\n\"` 改为按 transport 推导 enter，或让 broadcastToSessions/sendText 统一负责 EOL 归一化。"
    - "sendText 的 SSH/local 分支宜补 `\\r?\\n`→`\\r` 归一化（与 pasteText 对齐），顺带修复 snippet 路径在 PowerShell 上的同类问题（待确认 snippet 是否已自带 \\r）。"
    - "新增单元测试覆盖：广播文本的尾字节在 SSH/local 为 \\r、telnet 为 \\r\\n；并补一条针对 PowerShell/ConPTY Enter 语义的回归说明（现有 391 个测试未覆盖此跨平台回车差异）。"
  debug_session: ""

## Notes

- 测试 2 中"指令内容不同"（主标签 sentinel 包裹 / 目标标签裸命令）经核实是 **BCAST-07 的正确隔离设计**，不计为缺陷。仅"目标标签缺少回车"是真 bug。
- 测试 2 的 Enter-byte blocker 已由 quick 260709-jat (commit 1e137e0) 修复并复测通过；测试 3/5 现可在目标标签真正执行的前提下充分验证（隔离 / 终止语义）。测试 4（dialog 门禁）与该 bug 本就独立，已通过。
