# Phase 2: Broadcast Dispatch & Safety - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

在 Phase 1 已落地的广播 UI + per-tab 状态之上，接通**命令分发与安全**逻辑：

1. 用户审批（Approve）AI 提议的命令时，主标签走既有 `executeCommand`（带 sentinel + exit-code 回显的 `full_cmd`），所有勾选的广播目标通过 `broadcastToSessions` 收到 raw `cmd.cmd + "\n"`（BCAST-05）。
2. 广播分发与主标签执行**并行**——不阻塞主标签的输出收集（BCAST-06）。
3. AI 只读主标签的执行输出；广播目标静默执行、输出不回流 AI（BCAST-07，结构保证）。
4. 审批流程跟随现有 `danger_mode` / `auto_run_command` 设置；广播模式本身不引入额外审批 dialog（BCAST-08），但保留既有 raw device 安全约束。

**本阶段不做（范围锚点）：**
- Raw device（Serial/Telnet）默认排除广播目标 → **v2 deferred**（Phase 1 D-06 已让 raw 照常列出可勾；本阶段仅加"raw 目标存在时降级自动批准"的安全门，不做默认排除）
- 广播执行后的 toast 反馈、断线/失联目标检测、审计日志 → **v2 deferred**
- 广播模式下抑制 auto-approve（作为独立全局安全增强）→ **v2 deferred**（本阶段只做"raw 目标触发降级"，不做全局抑制）
- 汇总所有终端输出返回 AI、不同标签执行不同命令 → **Out of Scope**
- 任何 Rust/Tauri 后端改动 → 纯前端实现（REQUIREMENTS Out of Scope，复用现有 broadcastToSessions）

**广播模式关闭时行为必须与当前完全一致**，不影响现有 AI 流程（PROJECT 约束）——所有 Phase 2 改动须以"广播关闭即原行为"为前提。

</domain>

<decisions>
## Implementation Decisions

### 分发触发与并行（BCAST-05/06，D-01）
- **D-01: approve() 里先广播、再 await 主执行。** `CommandConfirmDialog.approve()`（`src/lib/ai/CommandConfirmDialog.svelte:121`）是唯一审批插入点。在 PTY 命令分支，先 `app.broadcastToSessions([...ai.broadcastTargets(tabId)], proposed.cmd.cmd + "\n")`（fire-and-forget，同步 for 循环、微秒级排队 invoke），**再** `await ai.executeCommand(tabId, cmd, targetKind, targetSessionId)`。
  - `broadcastToSessions` 是 fire-and-forget，本身不阻塞；放在 `await executeCommand` 之前，主标签执行与广播目标执行天然并行，满足 BCAST-06。
  - 广播在 `executeCommand` 的重入保护（`store.svelte.ts:581` 的 `_runningExecutions.has(tool_call_id)`）**之前**触发，因此 `approve()` 自身的 `executing` 锁 + `_ackedToolCalls` 已足够防重复广播，无需额外幂等保护。
  - **广播字段必须是 `cmd.cmd`（+ `"\n"`），绝不用 `full_cmd`**——`full_cmd` 含 sentinel + exit-code 回显（`src/lib/ai/types.ts:134-137`，后端拼装），广播它会污染目标 shell 并留下残留 echo 命令。沿用 `EditPane.svelte:56` 的 `text + "\n"` 先例。
  - 广播前置守卫：`if (ai.broadcastEnabled(tabId) && targets.size > 0)`，广播关闭或无目标时 approve 行为与现状完全一致。

### danger_mode + raw device 安全门（BCAST-08，D-02）
- **D-02: 广播 targets 含任一 raw device → 自动批准降级为人工 dialog。** 当前 `autoApproveAllowed`（`CommandConfirmDialog.svelte:52-69`）的 `!isRawDeviceKind(targetKind)` 只检查**主标签**类型。Phase 2 在自动批准前置检查里追加：读取 `ai.broadcastTargets(tabId)`，若其中任一 tabId 对应的 session 是 raw device（serial/telnet），则不自动批准、回退到弹 dialog 人工确认。
  - 此确认源于**既有 raw device 安全约束**（raw 对 `reload`/`erase startup-config` 类命令不敏感于命令黑名单，见 CONCERNS.md "AI Auto-Execution"），**不是**广播开关本身引入的审批——与 BCAST-08 "广播不引入额外审批"不冲突。
  - 仅在"广播开启 + targets 含 raw"时触发；广播关闭或无 raw 目标时，自动批准行为与现状完全一致（兼容性约束）。

### 终止对称性（D-03）
- **D-03: 广播模式下点"终止"，向主标签 + 所有广播目标对称发 `\x03`(Ctrl+C)。** 当前 `terminate()`（`CommandConfirmDialog.svelte:182`）→ `exec.terminate()`（`store.svelte.ts:615-625`）只向主标签发。Phase 2 扩展为：广播开启时，终止同时向 `ai.broadcastTargets(tabId)` 各目标发 `\x03`。
  - 符合广播语义（广播了命令就广播终止），避免目标机器在主标签被 Ctrl+C 后继续跑已广播的危险命令。
  - `\x03` 是中断非执行，对所有目标（含 raw）无差别安全，不触发 D-02 的 raw 安全门。
  - ⚠️ **实现风险点（需 researcher 核实）**：`sendText`（`TerminalPane.svelte:621-633`）注释明确"控制序列（箭头/Esc/Tab）不得通过此处"，且对 raw device 会过 `normalizeOutgoing`。终止广播的 `\x03` 走 `broadcastToSessions → sendText` 是否被 `normalizeOutgoing` 破坏、或是否需要专门的控制字符写入路径（绕过 normalizeOutgoing 直写 `\x03`），须在 research 阶段验证。**禁止想当然用 sendText 发 `\x03`。**

### 失败处理（D-04）
- **D-04: 无用户可见反馈、fire-and-forget；代码层吞 invoke reject + console.warn。** `broadcastToSessions`（`app.svelte.ts:466`）当前无 try/catch、静默丢弃失败目标，且 `sendText` 内部 invoke reject 会冒泡为**未处理 Promise rejection**（`.catch` 被省略）。Phase 2 接入审批路径后会暴露此噪音。
  - Phase 2 **不**加 toast/审计/断线检测（REQUIREMENTS 明确列为 v2 deferred）。
  - 代码卫生：广播路径需吞掉每个目标的 invoke reject 并 `console.warn("[broadcast] target <tabId> write failed:", e)`（符合 CONVENTIONS：非致命 background 失败用 `console.warn` + `[domain]` tag）。**不**用空 `.catch(() => {})`（CONVENTIONS Pr2 禁止静默吞错，除非 cleanup 路径）。

### Claude's Discretion
- 广播分发在 `approve()` 内的具体代码组织（是否抽一个 `broadcastApprovedCommand(tabId, cmd)` helper 封装，还是 inline 在 approve 里）——planner 按 ChatPanel/CommandConfirmDialog 现有结构决定。
- 终止广播 `\x03` 的发送原语——由 D-03 风险点驱动，researcher 核实 `normalizeOutgoing` 对 `\x03` 的行为后定（可能需要直写路径）。
- raw 安全门检查的精确落点（在 `autoApproveAllowed` 内扩展，还是在其调用处 `onMount` 分支前加 guard）——planner 选最小侵入处。
- `approve()` 失败时 `ai_command_result` 不触发导致的审计漏洞（侦察发现，既有问题、非广播引入）——Phase 2 **不**修（超出范围），记为已知约束。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级（需求与锁定决策）
- `.planning/REQUIREMENTS.md` — BCAST-05（Approve 后主标签 executeCommand 带 sentinel + 广播目标收 cmd.cmd+"\n"）/ BCAST-06（并行不阻塞）/ BCAST-07（AI 只读主标签）/ BCAST-08（审批跟随 danger_mode/auto_run）；v2 deferred 清单（含 toast/审计/断线/raw 默认排除/抑制 auto-approve）；Out of Scope（汇总输出回 AI、不同标签不同命令、后端改动）
- `.planning/PROJECT.md` — "Constraints"（兼容性/性能/安全）、"Key Decisions"表（AI 只读主标签输出、复用 broadcastToSessions、审批跟随 danger_mode、广播目标可勾选）、"Out of Scope"（raw device 默认参与广播）
- `.planning/ROADMAP.md` §"Phase 2: Broadcast Dispatch & Safety" — Goal + 4 条 Success Criteria + Depends on: Phase 1
- `.planning/phases/01-broadcast-ui-state/01-CONTEXT.md` — **Phase 1 锁定决策**（复用 broadcastToSessions、发 raw cmd 不发 full_cmd、状态在 ai/store.svelte.ts per-tab、fire-and-forget、Svelte 5 Set 响应性陷阱、D-06 raw 照常列出）。Phase 2 继承全部。

### 现有实现先例（Phase 2 改动落点 + 复用源）
- `src/lib/ai/CommandConfirmDialog.svelte:121-167` — **`approve()` 审批插入点**（D-01 广播在此触发）；`:52-69` `autoApproveAllowed`（D-02 raw 安全门扩展点）；`:82-110` onMount 自动批准分支；`:182` `terminate()`（D-03 对称终止扩展点）
- `src/lib/ai/store.svelte.ts:568` — **`executeCommand`**（单目标，Phase 2 保持纯度不改其签名）；`:581` 重入保护 `_runningExecutions`；`:615-625` `exec.terminate()`（只发主标签 Ctrl+C）；`:644-663` `finish()` + `ai_command_result`（输出回流唯一汇合点）；`:73-83` `BroadcastState` + `:156-228` Phase 1 广播 getter/mutator（`broadcastTargets(tabId)` 等，D-01/D-02/D-03 都读它）
- `src/lib/stores/app.svelte.ts:466` — **`broadcastToSessions(tabIds, text)`**（D-01/D-03 复用；D-04 在此或调用层加 reject 吞咽）；`:456` `connectedSessions()`；`:331-346` `TerminalControls`/`sendText` 契约
- `src/lib/components/TerminalPane.svelte:621-633` — **每 pane `sendText`**（EOL 转换 + slow-send 所有者；D-03 `\x03` 风险点的核心）；`:1209-1216` `registerTerminalControls`
- `src/lib/components/EditPane.svelte:56` — **`broadcastToSessions` 参考用法**（`text + "\n"`，D-01 沿用此加 `\n` 约定）
- `src/lib/ai/types.ts:130-152` — **`CommandProposed`**（`cmd` vs `full_cmd` 区别，D-01 广播 `cmd.cmd` 的依据）；`:104-114` `AiTargetKind` + `isRawDeviceKind`（D-02 判定 raw 目标）

### 约束与规范（实现时遵守）
- `AGENT.md`（根）— R1..R10 + Pr1..Pr5（R1 事件命名 `<domain>:<event>:<sid>`、R7 runes、R8 状态不放组件、Pr2 禁静默 `.catch(()=>{})`、Pr3 无 emoji/走 design token）
- `.planning/codebase/CONVENTIONS.md` — 命名、Svelte 5 runes、store getter 模式、CSS token、i18n 双语 key、错误处理（toast/errMsg）、console.warn + `[domain]` tag
- `.planning/codebase/ARCHITECTURE.md` — "AI diagnose flow"（理解 approve→executeCommand→ai_command_result 链路）、"Centralized frontend state"
- `.planning/codebase/CONCERNS.md` — "AI Auto-Execution (danger_mode) Default Behavior"（raw device 黑名单失效，D-02 依据）、"Single-Thread SSH Worker"（广播跨不同 session 真并发，不受单线程序列化影响）
- `src/lib/i18n/locales/en.ts` + `src/lib/i18n/locales/zh.ts` — 若 D-02 降级 dialog 需新文案，同步进两份 catalog

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`app.broadcastToSessions(tabIds, text)`**（`app.svelte.ts:466`）— Phase 2 分发与终止广播的核心原语。同步 for 循环遍历 tabIds，每目标 `_terminalControls.get(tabId)?.sendText(text)`。fire-and-forget，不改其签名（PROJECT 锁定）。调用者自加 `"\n"`。
- **`ai.broadcastTargets(tabId): Set<string>`**（`store.svelte.ts:156-163`）— Phase 1 已落地，D-01/D-02/D-03 读取当前勾选目标的统一入口。
- **`ai.broadcastEnabled(tabId): boolean`**（同上）— 所有 Phase 2 广播逻辑的"广播关闭即跳过"守卫。
- **`CommandConfirmDialog.approve()` / `terminate()`**（`CommandConfirmDialog.svelte:121,182`）— D-01/D-03 的改动宿主，已有 `tabId`/`targetKind`/`targetSessionId`/`cmd` props。
- **`autoApproveAllowed(settings, kind)`**（`CommandConfirmDialog.svelte:52-69`）— D-02 的扩展点，已含 `!isRawDeviceKind` 主标签检查。

### Established Patterns
- **Svelte 5 runes only** — `$state`/`$derived`/`$effect`/`$props`；`onclick={fn}`；禁 `on:click`/`$: `/`export let`（R7）。
- **状态私有化 + getter 导出** — 广播状态已在 `ai/store.svelte.ts`，Phase 2 不新增全局状态（R8）。
- **Svelte 5 `$state` 对 `Set` 无响应** — 若 Phase 2 需新广播 mutator，必须三步重建（重建 Set → 替换 record → 重赋 `_broadcastByTab`），原地 `.add()/.delete()` 静默失败（`store.svelte.ts:68-71` 注释）。
- **i18n 双语** — 任何新用户可见字符串经 `t()`，同步 en.ts + zh.ts。
- **错误处理** — `try { await invoke } catch (e) { toast.error(errMsg(e)) }`；fire-and-forget 用 `void invoke(...).catch(e => console.warn("[broadcast] ...", e))`（D-04）。

### Integration Points
- **`approve()` PTY 分支**（`CommandConfirmDialog.svelte:152`）— 在 `await ai.executeCommand(...)` 之前插入 `if (ai.broadcastEnabled(tabId)) app.broadcastToSessions([...ai.broadcastTargets(tabId)], cmd.cmd + "\n")`（D-01）。
- **`terminate()`**（`CommandConfirmDialog.svelte:182`）— 广播开启时，向 `broadcastTargets` 各目标发 `\x03`（D-03，发送原语待 researcher 定）。
- **`onMount` 自动批准分支 / `autoApproveAllowed`**（`CommandConfirmDialog.svelte:82-110,52-69`）— 追加 raw 目标检查（D-02）。
- **输出回流** — `executeCommand` 只监听 `<transport>:data:<target_session_id>`（主 session）；广播目标走 `sendText` 从不被监听 → 输出隔离**结构性保证**，Phase 2 无需写"过滤目标输出"代码（BCAST-07）。

</code_context>

<specifics>
## Specific Ideas

- 用户对"复用、不重新发明"有强偏好（Phase 1 已确立）——Phase 2 严格复用 `broadcastToSessions`，不改共享原语签名；`executeCommand` 保持单目标纯度，广播作为 approve 里的独立 fire-and-forget 调用。
- 安全优先于"字面最小实现"——D-02 的 raw 安全门虽给 danger_mode+广播+raw 场景加了一次确认，但用户认可这是既有 raw 安全约束的延伸，而非广播开关的额外负担。
- 终止对称性是用户明确的语义要求——"广播了命令就要广播终止"，避免目标机器失控。

</specifics>

<deferred>
## Deferred Ideas

- **Raw device 默认排除广播目标** — v2（REQUIREMENTS v2、PROJECT Out of Scope、Phase 1 D-06）。Phase 2 仅做"raw 目标存在时降级自动批准"（D-02），不做默认排除。
- **广播执行后的 toast 反馈** — v2（REQUIREMENTS v2）。Phase 2 保持无可见反馈（D-04）。
- **断线/失联目标自动检测和 toast 提示** — v2。Phase 2 静默跳过失败目标（D-04）。
- **广播事件写入审计日志** — v2（与 `src-tauri/src/ai/audit.rs` 协同）。Phase 2 不接入审计。
- **广播模式下全局抑制 auto-approve** — v2（REQUIREMENTS v2 首条）。Phase 2 只做 raw 目标定向降级（D-02），不做全局抑制。
- **`approve()` 失败时补发 `ai_command_result` 修审计漏洞** — 既有问题（侦察发现），非广播引入，超出 Phase 2 范围。

None of these were folded into Phase 2 —— 它们要么明确属 v2（反馈/检测/审计/全局抑制/默认排除），要么是既有审计漏洞（超出范围）。

</deferred>

---

*Phase: 2-Broadcast Dispatch & Safety*
*Context gathered: 2026-07-09*
