# Phase 2: Broadcast Dispatch & Safety - Research

**Researched:** 2026-07-09
**Domain:** Svelte 5 前端命令分发逻辑 + raw device 安全门（纯前端，无后端）
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### 分发触发与并行（BCAST-05/06，D-01）
- **D-01: approve() 里先广播、再 await 主执行。** 在 `CommandConfirmDialog.approve()` PTY 命令分支，先 `app.broadcastToSessions([...ai.broadcastTargets(tabId)], proposed.cmd.cmd + "\n")`（fire-and-forget），**再** `await ai.executeCommand(tabId, cmd, targetKind, targetSessionId)`。
  - 广播字段必须是 `cmd.cmd`（+ `"\n"`），绝不用 `full_cmd`。
  - 广播前置守卫：`if (ai.broadcastEnabled(tabId) && targets.size > 0)`。

#### danger_mode + raw device 安全门（BCAST-08，D-02）
- **D-02: 广播 targets 含任一 raw device → 自动批准降级为人工 dialog。** 在自动批准前置检查里追加 raw 目标检查。

#### 终止对称性（D-03）
- **D-03: 广播模式下点"终止"，向主标签 + 所有广播目标对称发 `\x03`(Ctrl+C)。**

#### 失败处理（D-04）
- **D-04: 无用户可见反馈、fire-and-forget；代码层吞 invoke reject + console.warn。** 不用空 `.catch(() => {})`。

### Claude's Discretion
- 广播分发在 `approve()` 内的具体代码组织（是否抽 helper 封装，还是 inline）。
- 终止广播 `\x03` 的发送原语（由 D-03 风险点驱动，researcher 已核实——见下文）。
- raw 安全门检查的精确落点（在 `autoApproveAllowed` 内扩展，还是在其调用处加 guard）。
- `approve()` 失败时 `ai_command_result` 审计漏洞——Phase 2 **不**修（超出范围）。

### Deferred Ideas (OUT OF SCOPE)
- Raw device 默认排除广播目标 — v2
- 广播执行后的 toast 反馈 — v2
- 断线/失联目标自动检测 — v2
- 广播事件写入审计日志 — v2
- 广播模式下全局抑制 auto-approve — v2
- `approve()` 失败时补发 `ai_command_result` — 既有问题，超出 Phase 2 范围
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BCAST-05 | 用户 Approve 命令后，主标签执行 executeCommand（带 sentinel），广播目标通过 broadcastToSessions 接收 cmd.cmd + "\n" | §Integration Points D-01：`approve()` PTY 分支插入点已确认（line 152 前），`cmd.cmd` vs `full_cmd` 区别已核实（types.ts:130-152） |
| BCAST-06 | 广播分发与主标签执行并行，不阻塞主标签的输出收集 | §Integration Points D-01：broadcastToSessions 是同步 for 循环 fire-and-forget，放在 `await executeCommand` 之前，天然并行 |
| BCAST-07 | AI 只读取主标签（当前活跃标签）的执行输出，广播目标静默执行 | §Resolved Questions Q-Output：executeCommand 只 listen `dataEvent`（主 session），广播目标走 sendText 从不被监听 → 结构性隔离 |
| BCAST-08 | 审批流程跟随现有 danger_mode / auto_run_command 设置，广播模式不引入额外审批逻辑 | §Integration Points D-02：raw 安全门是既有 raw device 安全约束的延伸，非广播开关引入的额外审批 |
</phase_requirements>

## Summary

Phase 2 是一个**纯前端、零新依赖、仅改两个文件**的命令分发接线任务。所有广播状态基础设施（`_broadcastByTab`、`broadcastEnabled()`、`broadcastTargets()`）已在 Phase 1 落地，`broadcastToSessions()` 原语早已存在。Phase 2 的全部工作是在 `CommandConfirmDialog.svelte` 的 `approve()` / `terminate()` / `onMount` 三处插入广播调用 + raw 安全门检查，以及在 `TerminalPane.svelte` 的 `sendText()` 补一处缺失的 `.catch()`。

**最关键的可行性验证（D-03 BLOCKER）已解决**：`broadcastToSessions(targets, "\x03")` 对所有 transport 类型安全。`normalizeOutgoing` 的正则 `/\r\n|\r|\n/g` 仅匹配换行符，`\x03`（U+0003）不是换行符，原样通过。对 SSH/local 标签，`sendText("\x03")` 产出 `invoke(writeCmd, {data: [3]})`——与主标签 `exec.terminate()` 的发送路径字节级一致。无需专门的控制字符直写路径。

**Primary recommendation:** 在 `CommandConfirmDialog.svelte` 直接 import `app`（与 ChatPanel 先例一致），inline 广播调用（2 行 guard + call），不抽 helper——因为 `ai/store.svelte.ts` → `app.svelte.ts` 会形成循环依赖（`app.svelte.ts:2` 已 import `ai/store.svelte.ts`）。

## D-03 Ctrl+C Broadcast Path（关键发现）

### 结论：`broadcastToSessions(targets, "\x03")` 对所有 transport 安全，无需专门直写路径

**置信度：HIGH** — 全部经代码库逐行核实 `[VERIFIED: codebase]`

#### 逐层追踪

**1. `broadcastToSessions(tabIds, "\x03")` 做了什么？**

```typescript
// src/lib/stores/app.svelte.ts:466-473 [VERIFIED: codebase]
export function broadcastToSessions(tabIds: string[], text: string) {
  for (const tabId of tabIds) {
    _terminalControls.get(tabId)?.sendText(text);
  }
}
```

对每个目标 tabId 调用其 pane 注册的 `sendText("\x03")`。

**2. `sendText("\x03")` 对 SSH/local 标签做了什么？**

```typescript
// src/lib/components/TerminalPane.svelte:626-633 [VERIFIED: codebase]
function sendText(text: string) {
    if (!text || disconnected || !sessionId) return;
    if (streamOpts) {
        streamSendText(normalizeOutgoing(text, streamOpts.inputNewline));
        return;
    }
    // SSH/local 路径（无 streamOpts）：
    invoke(writeCmd, { sessionId, data: Array.from(new TextEncoder().encode(text)) });
}
```

- `!text` 检查：`"\x03"` 是 truthy（非空字符串），通过。
- 无 `streamOpts`（SSH/local）→ 直接 `invoke(writeCmd, { sessionId, data: [3] })`。
- `new TextEncoder().encode("\x03")` → `Uint8Array [3]` → `Array.from(...)` → `[3]`。
- **这与主标签 `exec.terminate()` 的发送路径字节级一致**：

```typescript
// src/lib/ai/store.svelte.ts:615-625 [VERIFIED: codebase]
terminate: async () => {
    if (exec.resolved) return;
    exec.userInterrupted = true;
    const ctrlC = Array.from(new TextEncoder().encode("\x03"));
    void invoke(writeCmd, { sessionId: target_session_id, data: ctrlC })
        .catch((err) => console.warn("[ai] terminate Ctrl+C failed:", err));
    // ...
}
```

两者都产出 `invoke(writeCmd, { sessionId, data: [3] })`。唯一差异：主标签的 terminate 已有 `.catch()`，broadcast 路径的 sendText 没有（D-04 修这个）。

**3. `sendText("\x03")` 对 Serial/Telnet 标签做了什么？**

有 `streamOpts` → 走 `streamSendText(normalizeOutgoing("\x03", streamOpts.inputNewline))`。

```typescript
// src/lib/terminal/serial-transforms.ts:108-110 [VERIFIED: codebase]
export function normalizeOutgoing(text: string, mode: string): string {
  return text.replace(/\r\n|\r|\n/g, inputNewline(mode));
}
```

**正则 `/\r\n|\r|\n/g` 只匹配换行符**（U+000A LF / U+000D CR / CRLF）。`\x03`（U+0003 ETX）**不是换行符**，正则不匹配，`replace` 原样返回 `"\x03"`。

→ `streamSendText("\x03")` → `streamSendBytes([3])`：

```typescript
// src/lib/components/TerminalPane.svelte:506-525 [VERIFIED: codebase]
function streamSendBytes(bytes: number[]) {
    if (!sessionId || disconnected || !bytes.length) return;
    if (!streamOpts?.slowSend) {
        invoke(writeCmd, { sessionId, data: bytes }).catch(() => {});
        return;
    }
    // Slow devices: one byte at a time, ~5ms apart.
    // ...tick loop, each byte invoke(writeCmd, ...).catch(() => {})
}
```

- `[3]` 是单字节数组。
- 非 slow-send：一次 `invoke(writeCmd, {data: [3]})`，已有 `.catch(() => {})`（静默吞错——D-04 可选改善）。
- slow-send：单字节也是一次 invoke（`i=0, bytes[0]=3, i++` → `i >= bytes.length` 退出），~5ms 延迟可忽略。

**4. "控制序列不得通过此处" 注释的含义**

```typescript
// src/lib/components/TerminalPane.svelte:621-625 注释 [VERIFIED: codebase]
/** Inject user text as input (snippet / broadcast, and the serial/telnet
 *  paste path). ... Control sequences (arrows / Esc / Tab) must NOT
 *  come through here — they go raw via the registered terminal writer. */
```

此注释警告的是**多字节转义序列**：
- 箭头键 `\x1b[A`（3 字节）——slow-send 逐字节发会破坏时序，设备可能将 `\x1b`、`[`、`A` 解析为三个独立输入而非一个 CSI 序列。
- Tab `\t`（单字节但语义复杂，可能触发补全）。
- Esc `\x1b`（单字节但可能是多字节序列前缀）。

`\x03`（Ctrl+C / ETX）是**单字节、无后续序列、语义明确**（中断/INTR）——不受 slow-send 逐字节分解影响（只有一个字节），不被 `normalizeOutgoing` 破坏（不是换行符）。**此注释不适用于 `\x03`。**

**5. 为什么主标签的 terminate 不走 sendText？**

主标签的 `exec.terminate()` 在 `ai/store.svelte.ts` 内部，直接持有 `writeCmd` + `target_session_id`，所以直接 `invoke(writeCmd, ...)`——它不需要经 pane 的 `sendText`，因为它自己就知道 transport 类型和 sessionId。广播目标没有这个信息（`broadcastToSessions` 是 transport-agnostic 的），所以必须经各 pane 的 `sendText`，由 pane 应用自己的 transport 规则。

#### D-03 实现方案

```typescript
// CommandConfirmDialog.svelte terminate() 扩展
async function terminate() {
    if (terminating) return;
    terminating = true;
    try {
        // D-03: 广播终止——对称向所有广播目标发 \x03
        if (ai.broadcastEnabled(tabId)) {
            const targets = ai.broadcastTargets(tabId);
            if (targets.size > 0) {
                app.broadcastToSessions([...targets], "\x03");
            }
        }
        await ai.terminateCommand(cmd.tool_call_id);  // 主标签原有路径
    } catch (e) {
        console.error("[ai] terminate failed:", e);
        terminating = false;
    }
}
```

注意：广播 `\x03` 放在 `await ai.terminateCommand(...)` **之前**——与 D-01 同理（先广播再主执行），保证对称性。

## Integration Points

### D-01: approve() 命令广播

**当前代码（`CommandConfirmDialog.svelte:121-167` `[VERIFIED: codebase]`）：**

```typescript
async function approve() {
    if (executing) return;
    if (isAckOnly && _ackedToolCalls.has(cmd.tool_call_id)) return;
    executing = true;
    try {
        if (isAckOnly) {
            // ack-only 路径（download_file / analyze_locally）...
            _ackedToolCalls.add(cmd.tool_call_id);
            try {
                await invoke("ai_command_result", { ... });
            } catch (e) {
                _ackedToolCalls.delete(cmd.tool_call_id);
                throw e;
            }
            return;  // ← ack-only 在此 return，不走 PTY 分支
        }
        // ↓ PTY 命令分支（line 152）—— D-01 插入点
        await ai.executeCommand(tabId, cmd, targetKind, targetSessionId);
    } catch (e) {
        console.error("[ai] execute failed:", e);
        alert(t("ai.cmd.alert.exec_failed", { error: errMsg(e) }));
        executing = false;
        terminating = false;
        submitting = false;
        return;
    }
    // 成功路径...
}
```

**插入点确认：**
- `ack-only` 分支在 line 150 `return`，不影响 PTY 路径。
- `executing = true` 在 line 124 已设置——防止重入。
- 重入保护 `_runningExecutions.has(tool_call_id)` 在 `store.svelte.ts:581`（`executeCommand` 内部首行）——在广播**之后**才执行，因此广播在重入保护之前触发。但 `executing` 锁（line 122 + 124）+ `_ackedToolCalls`（line 123）已防重复 `approve()` 调用，不会重复广播。
- `cmd.cmd` vs `full_cmd` 已确认：`types.ts:130-152` `[VERIFIED: codebase]` — `full_cmd` 含 sentinel + exit-code 回显（后端拼装），广播它会污染目标 shell。

**D-01 目标代码：**

```typescript
// PTY 命令分支，executeCommand 之前：
if (ai.broadcastEnabled(tabId)) {
    const targets = ai.broadcastTargets(tabId);
    if (targets.size > 0) {
        app.broadcastToSessions([...targets], cmd.cmd + "\n");
    }
}
await ai.executeCommand(tabId, cmd, targetKind, targetSessionId);
```

**需新增 import：** `import * as app from "../stores/app.svelte.ts";`

> **⚠️ 循环依赖警告：** 不要把 `broadcastToSessions` 的调用封装进 `ai/store.svelte.ts` 的 helper。`app.svelte.ts:2` 已有 `import * as ai from "../ai/store.svelte.ts"`——反向 import 会形成循环依赖。广播调用必须在**组件层**（CommandConfirmDialog）发起，组件可安全 import 两个 store（ChatPanel 先例）。

### D-02: autoApproveAllowed + Raw 目标安全门

**当前代码（`CommandConfirmDialog.svelte:52-69, 82-110` `[VERIFIED: codebase]`）：**

```typescript
function autoApproveAllowed(s: AiSettings | null, kind?: CommandKind): boolean {
    if (!s || !s.danger_mode || !kind) return false;
    switch (kind) { /* ... */ }
}

onMount(() => {
    // ... inFlight 检查 ...
    if (
        isPending
        && !executing
        && !isRawDeviceKind(targetKind)   // ← 仅检查主标签
        && !ai.isCommandRunning(cmd.tool_call_id)
        && !_ackedToolCalls.has(cmd.tool_call_id)
        && autoApproveAllowed(ai.settings(), cmd.kind)
    ) {
        void approve();
    }
});
```

**raw 目标检查所需的数据源：**

`app.connectedSessions()` 返回 `SessionInfo[]`，其中 `SessionEntry.type` 是 `"ssh" | "local" | "serial" | "telnet"` `[VERIFIED: codebase app.svelte.ts:406-413]`——与 `AiTargetKind` 完全相同的 string union，`isRawDeviceKind(s.type)` 类型检查通过。

**最小侵入落点：在 `onMount` 自动批准条件里追加一个检查项。** 不改 `autoApproveAllowed` 本身（它是 pure function，不应依赖外部 store 状态）。

```typescript
// CommandConfirmDialog.svelte 内新增 helper（local function）
function hasRawBroadcastTarget(): boolean {
    if (!ai.broadcastEnabled(tabId)) return false;
    const targets = ai.broadcastTargets(tabId);
    if (targets.size === 0) return false;
    const sessions = app.connectedSessions();
    return [...targets].some(tid => {
        const s = sessions.find(s => s.tabId === tid);
        return s ? isRawDeviceKind(s.type) : false;
    });
}

// onMount 自动批准条件追加：
if (
    isPending
    && !executing
    && !isRawDeviceKind(targetKind)
    && !hasRawBroadcastTarget()           // ← D-02 新增
    && !ai.isCommandRunning(cmd.tool_call_id)
    && !_ackedToolCalls.has(cmd.tool_call_id)
    && autoApproveAllowed(ai.settings(), cmd.kind)
) {
    void approve();
}
```

**i18n：无需新 key。** 当 `hasRawBroadcastTarget()` 返回 true 时，自动批准条件不满足，dialog 自然显示 Approve/Reject 按钮供人工确认——这与"主标签是 raw device"时的现有行为完全一致，复用既有 UI 文案。

### D-03: terminate() 对称终止

见上文 §D-03 Ctrl+C Broadcast Path。插入点：`CommandConfirmDialog.svelte:182-191` 的 `terminate()` 函数，在 `await ai.terminateCommand(...)` 之前插入广播调用。

### D-04: sendText 错误卫生

**问题根源（`TerminalPane.svelte:626-633` `[VERIFIED: codebase]`）：**

```typescript
function sendText(text: string) {
    if (!text || disconnected || !sessionId) return;
    if (streamOpts) {
        streamSendText(normalizeOutgoing(text, streamOpts.inputNewline));
        return;
    }
    // SSH/local 路径：invoke 返回 Promise，未 catch → 失败时 unhandled rejection
    invoke(writeCmd, { sessionId, data: Array.from(new TextEncoder().encode(text)) });
}
```

**各路径错误处理现状：**

| 路径 | 当前处理 | 问题 |
|------|---------|------|
| SSH/local `sendText` invoke（line 632） | 无 catch | **unhandled Promise rejection**（D-04 要修） |
| Serial/Telnet 非 slow-send（`streamSendBytes` line 509） | `.catch(() => {})` | 静默吞错（CONVENTIONS Pr2 禁止，但本路径既有，Phase 2 可选改善） |
| Serial/Telnet slow-send（`streamSendBytes` line 520） | `.catch(() => {})` | 同上 |

**关键发现：修复必须在 `sendText` 内部，不能在 `broadcastToSessions` 层。** 因为 `sendText` 返回 `void`——invoke 产生的 Promise 从不离开 `sendText`，`broadcastToSessions` 调用 `sendText(text)` 拿到的是 void，无法 catch 内部的 Promise。

**D-04 修复方案（TerminalPane.svelte line 632）：**

```typescript
// Before:
invoke(writeCmd, { sessionId, data: Array.from(new TextEncoder().encode(text)) });

// After:
void invoke(writeCmd, { sessionId, data: Array.from(new TextEncoder().encode(text)) })
    .catch((e) => console.warn("[broadcast] sendText failed:", e));
```

这是对**共享原语** `sendText` 的行为修改（所有调用方——snippets、paste、EditPane 广播——都受益），但**不改签名**（`sendText(text: string): void` 不变）。修复正确性：unhandled rejection 始终是 bug，不论调用方是谁。

`broadcastToSessions` 签名不变（`broadcastToSessions(tabIds: string[], text: string): void`），满足 PROJECT 约束。

> **可选改善（非 Phase 2 必须）：** 将 `streamSendBytes` 的 `.catch(() => {})` 也改为 `.catch((e) => console.warn(...))` 以符合 CONVENTIONS Pr2。但这影响 serial/telnet 的所有写入路径（含正常输入），scope 更大。planner 可按"最小侵入"原则仅修 SSH/local 路径。

## Resolved Questions

### Q1: `broadcastToSessions(targets, "\x03")` 是否安全？

**RESOLVED: 安全。** 见 §D-03 Ctrl+C Broadcast Path 完整追踪。`normalizeOutgoing` 的正则仅匹配换行符，`\x03` 原样通过。对 SSH/local 产出与主标签 terminate 字节级一致的 invoke。对 serial/telnet 走单字节 `streamSendBytes`。无需专门直写路径。

### Q2: approve() PTY 分支插入点是否安全？

**RESOLVED: 安全。** `[VERIFIED: codebase CommandConfirmDialog.svelte:121-167]`
- `ack-only` 分支在 line 150 `return`，PTY 分支从 line 152 开始。
- `executing = true`（line 124）在广播之前设置。
- 无 early-return / guard 会跳过广播。
- 重入保护在 `executeCommand` 内部（store.svelte.ts:581），在广播之后。

### Q3: `cmd.cmd` vs `full_cmd` 确认

**RESOLVED: 必须用 `cmd.cmd`。** `[VERIFIED: codebase types.ts:130-152]`
- `cmd: string` — 用户可见的原始命令。
- `full_cmd: string` — "实际要粘贴到终端的命令（含 sentinel + exit code 回显），由后端拼装"。
- 广播 `full_cmd` 会在目标 shell 留下 sentinel 字符串 + `echo $?` 残留。

### Q4: D-02 raw 目标检查的精确落点

**RESOLVED: 在 `onMount` 自动批准条件里追加 `&& !hasRawBroadcastTarget()`。** 不改 `autoApproveAllowed` 函数本身（pure function，不应依赖外部 store）。新增 local helper `hasRawBroadcastTarget()` 读 `ai.broadcastTargets` + `app.connectedSessions()`。

### Q5: broadcastToSessions 错误处理修复位置

**RESOLVED: 必须在 `TerminalPane.svelte` 的 `sendText` 内部修。** `sendText` 返回 void，`broadcastToSessions` 无法 catch 其内部 Promise。修复：给 SSH/local 路径的 `invoke(...)` 加 `.catch(e => console.warn(...))`。签名不变。

### Q6: Phase 2 是否引入新广播状态 mutator

**RESOLVED: 不引入。** Phase 2 只读 `ai.broadcastEnabled(tabId)` / `ai.broadcastTargets(tabId)`。所有 mutator（`toggleBroadcast`、`toggleBroadcastTarget`、`setBroadcastTargets`、`pruneBroadcastTargets`、`clearBroadcastState`）已在 Phase 1 落地。无 Svelte 5 Set 响应性风险。

### Q7: D-02 降级 dialog 是否需要新 i18n key

**RESOLVED: 不需要。** raw 目标存在时 `hasRawBroadcastTarget()` 返回 true → 自动批准条件不满足 → dialog 显示正常 Approve/Reject 按钮。这与"主标签是 raw device"时的现有行为一致，复用既有文案。

### Q8: 循环依赖——能否在 ai/store.svelte.ts 封装广播 helper

**RESOLVED: 不能。** `app.svelte.ts:2` 已 `import * as ai from "../ai/store.svelte.ts"`。若 `ai/store.svelte.ts` 反向 import `app.svelte.ts`，形成 ES module 循环依赖。广播调用必须在组件层（CommandConfirmDialog）发起。

### Q9: BCAST-07 输出隔离保证

**RESOLVED: 结构性保证，无需写过滤代码。** `[VERIFIED: codebase store.svelte.ts:568-680]`
`executeCommand` 只 `listen(dataEvent, ...)`，其中 `dataEvent = \`${TRANSPORT[target_kind].data}:${target_session_id}\``——只监听主标签的 session。广播目标走 `sendText` → `invoke(writeCmd, ...)`，写入的数据触发各自 pane 的 `ssh:data:<sid>` 事件，但 `executeCommand` 的 listener 只绑定主 session id，不会收到广播目标的事件。

## Risks & Landmines

### Risk 1: sendText 的 "控制序列不得通过此处" 注述

**风险：** 开发者看到此注释可能误判 `\x03` 也不能走 sendText，从而过度设计专门的直写路径。

**缓解：** 本 research 已逐字节追踪证明 `\x03` 安全（见 §D-03）。`normalizeOutgoing` 正则不匹配它，单字节不受 slow-send 分解影响。注释针对的是多字节转义序列。

### Risk 2: CommandConfirmDialog 新增 `import * as app`

**风险：** CommandConfirmDialog 目前不 import `app`。新增后需确认不引入意外的响应性追踪（`connectedSessions()` 返回 `$state` 值）。

**缓解：** `hasRawBroadcastTarget()` 只在 `onMount` 时调用一次（非 `$derived`/`$effect`），不会建立响应性订阅。`approve()`/`terminate()` 里调用 `app.broadcastToSessions(...)` 是命令式调用，不涉及响应性。与 ChatPanel import `app` 先例一致。

### Risk 3: 广播目标 pane 未挂载（sendText 为 no-op）

**场景：** `broadcastToSessions` 遍历 tabIds 时，某 tabId 的 pane 未挂载（`_terminalControls.get(tabId)` 返回 undefined）→ `?.sendText()` 跳过，静默失败。

**评估：** 这是既有行为（非 Phase 2 引入）。所有 tab 都会 mount TerminalPane（`[VERIFIED: codebase AppShell.svelte]` tab dispatcher 渲染所有非 home tab 的 TerminalPane，仅 active 可见）。只有 tab 正在关闭/重连的瞬态窗口可能 miss。Phase 2 不修（断线检测是 v2 deferred）。

### Risk 4: D-04 修改共享 sendText 影响所有调用方

**场景：** 给 `sendText` 的 SSH/local invoke 加 `.catch()` 后，所有调用方（snippets、paste、EditPane 广播）的失败行为从"unhandled rejection"变为"console.warn"。

**评估：** 这是**正确的行为修正**——unhandled rejection 始终是 bug。`console.warn` 不影响任何调用方的控制流（sendText 本就返回 void，调用方不依赖其返回值/异常）。

### Risk 5: 兼容性守卫遗漏

**场景：** 忘记加 `ai.broadcastEnabled(tabId)` 守卫，导致广播关闭时也触发分发/终止广播。

**缓解：** 每个 Phase 2 改动点都必须以 `if (ai.broadcastEnabled(tabId) && ai.broadcastTargets(tabId).size > 0)` 开头。广播关闭时条件为 false，行为与现状完全一致。

## Files to Create/Modify

| 文件 | 操作 | 改动内容 | 决策 |
|------|------|---------|------|
| `src/lib/ai/CommandConfirmDialog.svelte` | **修改** | ① 新增 `import * as app from "../stores/app.svelte.ts"` ② `approve()` PTY 分支：executeCommand 前插入广播（D-01） ③ `terminate()`：terminateCommand 前插入 `\x03` 广播（D-03） ④ 新增 `hasRawBroadcastTarget()` local function + onMount 自动批准条件追加（D-02） | D-01/D-02/D-03 |
| `src/lib/components/TerminalPane.svelte` | **修改** | `sendText()` SSH/local 路径 invoke 加 `.catch(e => console.warn(...))` （D-04，仅 line 632 一处） | D-04 |

**零新文件。零新依赖。零 i18n key。零后端改动。**

## Assumptions

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `hasRawBroadcastTarget()` 在 `onMount` 调用一次即可（auto-approve 决策时刻的广播目标集合不会在 mount 后到 approve() 前变化） | D-02 | 极低：用户在 dialog 显示后勾选 raw 目标，但此时已过了 auto-approve 检查窗口——dialog 已显示人工 Approve 按钮，用户仍需手动批准，安全无退化 |
| A2 | `streamSendBytes` 的 `.catch(() => {})` 静默吞错保持不修（仅修 SSH/local sendText 路径） | D-04 | 低：serial/telnet 广播失败仍静默，但已有既有行为；planner 可选改为 console.warn |
| A3 | `broadcastToSessions` 对未挂载 pane 的 tabId 静默跳过是可接受的（tab 关闭/重连瞬态） | Risks §3 | 低：既有行为；断线检测是 v2 deferred |

> 全部 D-01/D-02/D-03 核心路径 claim 为 `[VERIFIED: codebase]`（逐行 grep/read 核实）。A1-A3 为边界场景假设，不影响核心实现可行性。

## RESEARCH COMPLETE
