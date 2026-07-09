---
phase: 01-broadcast-ui-state
verified: 2026-07-09T15:20:00Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 6/8 must-haves verified
  gaps_closed:
    - "T4 per-tab 持久化（SC4）：UAT test 1 pass —— 切 tab / 关重开 AI 面板后 ON 态、目标集合、折叠态全保留"
    - "T7 D-11 prune：UAT test 2 pass —— 目标 tab 关闭后徽标递减、目标剔除；主标签关闭后无残留"
    - "T6 D-08 视觉：UAT test 3 pass —— 广播开关 accent 蓝、DangerModeToggle 红，两者分明"
    - "T3 BCAST-02/03 勾选即时反映：UAT test 4 skipped —— 已由 Phase 2 UAT 场景 B/D 端到端覆盖（广播开启 + 勾选 SSH/serial 目标，halo+徽标实时反映）"
    - "EditPane hover 预览回归（01-01 D3 遗留）：UAT test 5 pass —— SessionPreviewPopover 弹出位置零回归"
  gaps_remaining: []
  regressions: []
human_uat:
  completed: 2026-07-09T15:20:00Z
  commit: 2c2cb02
  scenarios:
    - test: 1
      result: pass
      note: "SC4 per-tab 持久化 —— 切 tab / 关重开 AI 面板后 ON 态、2 目标、折叠态三者全保留"
    - test: 2
      result: pass
      note: "D-11 prune —— 目标 tab 关闭后徽标递减；主标签关闭后无残留"
    - test: 3
      result: pass
      note: "D-08 视觉 —— 广播开关 accent 蓝 vs DangerModeToggle 红，分明"
    - test: 4
      result: pass
      note: "BCAST-02/03 勾选即时反映 —— 跨阶段复验（Phase 2 UAT 场景 B/D 端到端覆盖 halo+徽标实时反映）"
    - test: 5
      result: pass
      note: "EditPane hover 预览回归 —— SessionPreviewPopover 弹出位置零回归"
behavior_unverified_items:

  - truth: "广播开关状态与目标选择按 tab 持久化于 ai store，切 tab / 关重开 AI 面板后保持（BCAST-04, D-10）"
    test: "在桌面 GUI 开启广播 + 勾选若干目标 → 切到另一 tab 再切回（状态应保持）→ 关闭 AI 面板再重新打开（状态仍应保持）"
    expected: "开关 ON 态、目标勾选集合、barCollapsed 折叠态三者均与关面板前一致（_broadcastByTab 是 store.svelte.ts 模块顶层 $state，ChatPanel unmount 不影响它）"
    why_human: "持久化断言是生命周期不变式（state 跨组件 unmount/remount 存活），grep 只能证伪状态在模块顶层、非组件本地，无法证明 Svelte 5 运行期在 ChatPanel 重挂载时确实读到同一份模块状态；仓库内无 broadcast store 单测覆盖该路径"

  - truth: "已选目标 tab 被关闭时自动从选择剔除（D-11 prune $effect）；主标签关闭时整条广播状态清理（Plan 01-01 stopSession）"
    test: "勾选一个目标终端 → 关闭该目标终端 tab → 观察广播开关徽标计数；另开一个主标签开启广播 → 关闭该主标签 → 重开同位置确认无残留"
    expected: "目标 tab 关闭后徽标 N 递减、对应 tabId 从 targets Set 剔除；主标签关闭后 _broadcastByTab[tab_id] 整条被 delete（stopSession 第 364 行）"
    why_human: "prune 路径是反应管道（connectedSessions() 变 → sessions $derived 重算 → $effect 重跑 → pruneBroadcastTargets filter+重建 Set → _broadcastByTab 重赋值 → 徽标 $derived 重算），grep 能验证每段接线但无法证明链路在运行期按时序触发；仓库内无 broadcast prune 单测"
human_verification:

  - test: "SC4 持久化（互补 T4）：开启广播 + 勾选 2 个目标 + 折叠目标条 → 切到另一 AI tab → 切回 → 关 AI 面板 → 重开 AI 面板"
    expected: "ON 态、2 个目标、折叠态三者全保留"
    why_human: "模块级 $state 跨组件 unmount 的存活是 Svelte 5 运行期契约，CI 内无单测覆盖"

  - test: "D-11 prune（互补 T7）：勾选目标 A → 关闭 tab A → 观察徽标"
    expected: "徽标 N 减 1，A 从选中态剔除"
    why_human: "反应管道时序需运行期确认"

  - test: "D-08 视觉：开启广播，对比开关激活色与 DangerModeToggle 激活色"
    expected: "广播开关是 accent 蓝（var(--accent)），DangerModeToggle 是 error 红（var(--error)），两者不混淆"
    why_human: "CSS token 已 grep 确认（无 --error 出现在 .broadcast- 规则），但像素级着色需人眼确认"

  - test: "BCAST-02/03 功能冒烟：开启广播 → 目标条出现 → 勾选一个终端 → 观察 halo + 徽标 → 取消勾选 → 观察 halo+徽标消失"
    expected: "勾选即时出现 accent halo + 徽标 +1；取消即时消失 + 徽标 -1"
    why_human: "Svelte 5 Set 反应性（重建 Set + 整体替换 record）由代码 grep 证明，但 UI 实时刷新需运行期确认"

  - test: "EditPane hover 预览回归（01-01 D3 遗留）：打开 EditPane，悬停目标行"
    expected: "SessionPreviewPopover 弹出位置与改造前一致（onHover 经 BroadcastTargetSelector 可选 prop 转发）"
    why_human: "popover 锚点坐标是运行期 DOM 行为，自动化编译/类型/单测无法证伪"
---

# Phase 01: Broadcast UI & State — 验证报告

**Phase Goal:** Users can enable broadcast mode in the AI panel and configure which terminal tabs participate as broadcast targets
**Verified:** 2026-07-09T15:20:00Z
**Status:** passed (human UAT complete 2026-07-09 — 5/5 pass; see `re_verification` + `human_uat` in frontmatter)
**Re-verification:** Human UAT closed the 2 previously-unverified behavioral truths (T4 持久化, T7 prune) plus the visual/smoke checkpoints (D-08, EditPane hover; BCAST-02/03 cross-verified via Phase 2 UAT scenarios B/D). Score advances 6/8 → 8/8. Commit `2c2cb02`.

## 验证立场

本报告所有结论基于源代码 grep/read + 三件套自动化（tsc/build/test）实测，**不采信 SUMMARY.md 的"已完成"声明**。SUMMARY 声称的"Plan 01-01 store 用例覆盖"经核实为误导：仓库内唯一含 `broadcast` 字样的测试 `src/lib/terminal/broadcast-text.test.ts` 测的是 EditPane 既有 `pickBroadcastText`（编辑器文本抽取），**无任何针对 `_broadcastByTab` mutator 或 prune $effect 的单测**。391/391 passing 是回归基线，非新功能覆盖。

## 自动化检查结果（实测）

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `npx tsc --noEmit` | 0 | TS 类型检查通过 |
| `npm test -- --run` | 0 | 31 文件 / 391 测试全绿（回归基线） |
| `npm run build` | 0 | 314 模块编译通过，dist 产物输出 |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| T1 (SC1/BCAST-01) | 用户可在 AI 面板工具栏点击广播开关按钮切换广播模式 on/off | ✓ VERIFIED | `src/lib/ai/ChatPanel.svelte:303-318` `<button class="btn-icon broadcast-toggle" class:on={broadcastOn} onclick={() => ai.toggleBroadcast(tabId)} aria-pressed={broadcastOn}>`；`src/lib/ai/store.svelte.ts:166-172` `toggleBroadcast` mutator 翻转 enabled + 整体替换 record |
| T2 (SC2/BCAST-02) | 广播 ON 时工具栏下方出现可折叠目标条，列出除主标签外的所有已连接终端 | ✓ VERIFIED | `ChatPanel.svelte:347` `{#if broadcastOn}<div class="broadcast-bar">…<BroadcastTargetSelector sessions={sessions}>…`；`ChatPanel.svelte:56` `sessions = $derived(app.connectedSessions().filter(s => s.tabId !== tabId))`（D-05 主标签过滤） |
| T3 (SC3/BCAST-03) | 用户可勾选/取消勾选任意终端标签作为广播目标，选中态 accent 光晕 | ✓ VERIFIED | `BroadcastTargetSelector.svelte:42` `onclick={() => onToggle(s.tabId)}`；`ChatPanel.svelte:365` `onToggle={(tid) => ai.toggleBroadcastTarget(tabId, tid)}`；`store.svelte.ts:182-191` mutator 重建 Set（`new Set(prev.targets)`）+ 整体替换 record；`BroadcastTargetSelector.svelte:40` `class:selected={selectedIds.has(s.tabId)}` + 96-102 行 `.session-item.selected` accent halo |
| T4 (SC4/BCAST-04) | 广播开关状态与目标选择按 tab 持久化于 ai store，切 tab / 关重开 AI 面板后保持 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `store.svelte.ts:78` `let _broadcastByTab = $state<Record<string, BroadcastState>>({});` 在模块顶层（非组件本地）；`ChatPanel.svelte:53` `bState = $derived(ai.broadcastState(tabId))` 只读快照。架构上 Svelte 5 模块级 $state 是单例、跨组件 unmount 存活——但此持久化是**生命周期不变式**，仓库内无单测覆盖 close-reopen 路径，需人工 GUI 确认（见 human_verification） |
| T5 (兼容性约束) | 广播 OFF 时 ChatPanel 工具栏与对话区与当前完全一致 | ✓ VERIFIED | `ChatPanel.svelte:347` `{#if broadcastOn}` 整条包裹 `.broadcast-bar` → OFF 时零渲染；`.broadcast-toggle` 按钮恒渲染但 `class:on={broadcastOn}=false` 不应用 `.on` 样式；OFF 路径无任何 invoke/IPC 副作用（纯前端 $state 翻转） |
| T6 (D-08/D-09) | 广播开关激活态用 `--accent`（非 `--error` 红），徽标显示已选目标数 | ✓ VERIFIED | `ChatPanel.svelte:564-571` `.broadcast-toggle.on { color: var(--accent); background: color-mix(in srgb, var(--accent) 14%/22%, transparent); }`；负向 grep `broadcast-toggle[^}]*--error|broadcast-bar[^}]*--error|.badge[^}]*--error` 零命中；`ChatPanel.svelte:573-581` `.broadcast-toggle .badge { background: var(--accent); … }`；`ChatPanel.svelte:315-317` `{#if broadcastOn && selectedCount > 0}<span class="badge">{selectedCount}</span>{/if}`（0 隐藏） |
| T7 (D-11) | 已选目标 tab 关闭时自动从选择剔除；主标签关闭时整条广播状态清理 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | 双路径接线齐备：(a) 目标 tab 关闭 —— `ChatPanel.svelte:61-64` `$effect(() => { … ai.pruneBroadcastTargets(tabId, activeIds); })` + `store.svelte.ts:211-220` mutator 用 `[...prev.targets].filter(id => activeTabIds.has(id))` + size-unchanged early-return 守卫；(b) 主标签关闭 —— `store.svelte.ts:364` `delete _broadcastByTab[tab_id];` 在 `stopSession` delete 簇内。但 (a) 是**反应管道**（connectedSessions → $derived → $effect → mutator → $derived），运行期时序触发无单测覆盖，需人工确认（见 human_verification） |
| T8 (D-06/D-12) | Serial/Telnet 与 SSH/local 一视同仁列出可勾选；新开终端 tab 不自动勾选 | ✓ VERIFIED | `ChatPanel.svelte:56` sessions $derived **无 type 过滤**（D-06）；ChatPanel 唯一 `$effect`（61-64 行）只调 `pruneBroadcastTargets`（仅剔除），**无任何 add 类 mutator 调用**（D-12 新 tab 不自动勾）—— 排除法确认 |

**Score:** 6/8 truths verified（2 个 ⚠️ PRESENT_BEHAVIOR_UNVERIFIED：T4、T7 —— 代码接线齐备，运行期行为未由单测覆盖）

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `src/lib/ai/store.svelte.ts` | `_broadcastByTab` per-tab 状态 + 9 getter/mutator + stopSession teardown | ✓ VERIFIED | `interface BroadcastState`（73-77）；`_broadcastByTab`（78）；`DEFAULT_BROADCAST`（79-83）；9 个 export 函数全数命中（156/159/162/166/174/182/193/211/227）；`delete _broadcastByTab[tab_id]`（364） |
| `src/lib/components/BroadcastTargetSelector.svelte` | 受控组件（5 必选 + 2 可选 hover props，零内部状态/effects） | ✓ VERIFIED | 142 行；`$props()` 解构 5 必选 + `onHover/onHoverLeave = undefined`（19-20）；`$state`/`$effect` grep 计数 0；`on:click`/`export let`/`$:` grep 计数 0（R7 合规）；含 SessionMinimap + accent halo 样式 |
| `src/lib/ai/ChatPanel.svelte` | 工具栏 `.broadcast-toggle` + `.broadcast-bar` 可折叠目标条 + prune $effect + 5 $derived | ✓ VERIFIED | import BroadcastTargetSelector（9）；5 $derived（53-57）；prune $effect（61-64）；toggle 按钮（303-318）位于 clear-btn（290-299）与 DangerModeToggle（323-336）之间；目标条（347-371）；配套 CSS（563-602） |
| `src/lib/components/EditPane.svelte` | 消费共享组件，保留 Broadcast(N) + 本地 selectedTabIds + hover 预览 | ✓ VERIFIED | import BroadcastTargetSelector（11）；`<BroadcastTargetSelector>` 消费（144-152，传 onHover={onHover}）；`selectedTabIds = $state`（21）；prune $effect（23-27）；`broadcast()` 调 `app.broadcastToSessions`（52-57）；`.broadcast-btn`（154-160）；SessionPreviewPopover（163-165）；无 `class="session-list"` 残留 |
| `src/lib/i18n/locales/en.ts` + `zh.ts` | 10 个 ai.toolbar.broadcast_* / ai.broadcast.* 双语 lockstep | ✓ VERIFIED | en.ts 420-429（10 key）；zh.ts 423-432（10 key）；`diff <(en) <(zh)` 输出空（LOCKSTEP_OK） |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| ChatPanel `.broadcast-toggle` onclick | `ai.toggleBroadcast(tabId)` | `onclick={() => ai.toggleBroadcast(tabId)}`（ChatPanel:304） | ✓ WIRED | mutator 在 store.svelte.ts:166 |
| ChatPanel `sessions` $derived | `app.connectedSessions()` filter | `app.connectedSessions().filter(s => s.tabId !== tabId)`（ChatPanel:56） | ✓ WIRED | D-05 主标签过滤 |
| ChatPanel prune $effect | `ai.pruneBroadcastTargets(tabId, activeIds)` | `$effect(() => { … ai.pruneBroadcastTargets(…) })`（ChatPanel:61-64） | ✓ WIRED | 在组件 init 上下文（Pitfall 2 合规） |
| 目标条 `<BroadcastTargetSelector>` onToggle | `ai.toggleBroadcastTarget(tabId, tid)` | `onToggle={(tid) => ai.toggleBroadcastTarget(tabId, tid)}`（ChatPanel:365） | ✓ WIRED | Set 重建 mutator（store:182） |
| 目标条 onSelectAll/onSelectNone | `ai.setBroadcastTargets(tabId, new Set(...))` | ChatPanel:366-367 | ✓ WIRED | |
| `ai.stopSession(tab_id)` delete 簇 | `delete _broadcastByTab[tab_id]` | store.svelte.ts:364 | ✓ WIRED | D-11 主标签路径，与既有 per-tab map 同清理点 |
| ChatPanel 不传 onHover/onHoverLeave | BroadcastTargetSelector 可选 prop 默认 undefined | ChatPanel:362-367 调用未传 onHover | ✓ WIRED | D-04 / Q1 RESOLVED：AI 面板天然无 hover |
| i18n `t("ai.broadcast.count", { selected, total })` | en.ts/zh.ts `ai.broadcast.count` 含 `{selected}/{total}` 插值 | en.ts:424 / zh.ts:427 / ChatPanel:358 | ✓ WIRED | 沿既有 `tokens_tip` 的 `{tin}/{tout}` 语法 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `BroadcastTargetSelector` (sessions prop) | `sessions` | `app.connectedSessions()` 实时 registry（_sessions map） | ✓ 真实数据（连接的终端 tab） | ✓ FLOWING |
| `.badge` {selectedCount} | `selectedCount` | `$derived(bState.targets.size)` → `_broadcastByTab[tabId].targets.size` | ✓ 真实数据（Set 基数） | ✓ FLOWING |
| `.bar-count` {selected}/{total} | `selectedCount` / `totalCount` | 同上 + `sessions.length` | ✓ 真实数据 | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| TS 类型安全 | `npx tsc --noEmit` | EXIT=0 | ✓ PASS |
| Svelte 编译（含 BroadcastTargetSelector + ChatPanel 改造） | `npm run build` | EXIT=0，314 modules transformed | ✓ PASS |
| 既有单测零回归 | `npm test -- --run` | 391/391 passed | ✓ PASS |
| store `$effect(` 调用计数（Pitfall 2 不变量） | `grep -c '\$effect' src/lib/ai/store.svelte.ts` | 1（仅注释提及，零调用） | ✓ PASS |
| 所有 targets mutator 含 `new Set(` | `grep -c "new Set(" src/lib/ai/store.svelte.ts` | 4（1 DEFAULT_BROADCAST + 3 mutator：toggleBroadcastTarget/setBroadcastTargets/pruneBroadcastTargets） | ✓ PASS |
| `_broadcastByTab =` 整体赋值 | `grep -nE "_broadcastByTab =" store.svelte.ts` | 6 命中（1 声明 + 5 mutator 重赋值；clearBroadcastState 用 delete 不重赋值，正确） | ✓ PASS |
| 双语 i18n lockstep | `diff <(en broadcast keys) <(zh broadcast keys)` | 空 | ✓ PASS |
| D-08 负向 grep | `grep -cE 'broadcast-(toggle|bar)[^}]*--error\|\.badge[^}]*--error' ChatPanel.svelte` | 0 | ✓ PASS |
| D-04 负向 grep | `grep -c "broadcast-btn" ChatPanel.svelte` | 0 | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — 本阶段为纯前端 Svelte UI + 状态，无 `scripts/*/tests/probe-*.sh` 约定，PLAN/SUMMARY 未声明 probe。

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| BCAST-01 | 01-02 | AI 面板工具栏显示广播模式 toggle 按钮，点击切换开/关 | ✓ SATISFIED | T1 VERIFIED |
| BCAST-02 | 01-02 | 广播模式开启后，显示目标选择器，列出所有已打开的终端标签 | ✓ SATISFIED | T2 VERIFIED |
| BCAST-03 | 01-02 | 用户可勾选/取消勾选任意终端标签作为广播目标 | ✓ SATISFIED | T3 VERIFIED |
| BCAST-04 | 01-01 + 01-02 | 广播 toggle 和目标选择状态为 per-tab 级别，保存在 AI store 中 | ✓ SATISFIED (code-level) | 状态架构 VERIFIED；持久化行为 ⚠️ PRESENT_BEHAVIOR_UNVERIFIED（T4）—— 路由到人工确认 |

无 ORPHANED 需求（REQUIREMENTS.md Traceability 表中 BCAST-01..04 全部映射到 Phase 1 且全部被 plan 的 `requirements` 字段声明覆盖；BCAST-05..08 属 Phase 2，不在本阶段验证范围）。

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| （无） | — | — | — | — |

`TBD/FIXME/XXX/HACK/PLACEHOLDER` 在 5 个修改文件（store.svelte.ts / ChatPanel.svelte / BroadcastTargetSelector.svelte / EditPane.svelte / en.ts / zh.ts）中零命中。无 debt marker 阻塞项。

### Human Verification Required

5 项需人工在桌面 GUI 确认（见 frontmatter `human_verification`）：

1. **SC4 持久化**（互补 T4）—— 切 tab / 关重开 AI 面板后 ON 态、目标集合、折叠态全保留
2. **D-11 prune**（互补 T7）—— 关闭已选目标 tab 后徽标递减
3. **D-08 视觉** —— 开关激活态 accent 蓝，与 DangerModeToggle 红 不可混淆
4. **BCAST-02/03 功能冒烟** —— 勾选/取消勾选即时反映到 halo + 徽标
5. **EditPane hover 预览回归**（01-01 D3 遗留）—— SessionPreviewPopover 弹出位置与改造前一致

### Gaps Summary

无 must-have FAILED。所有 artifact 三层（exists / substantive / wired）+ 第四层（data-flow）全部通过；自动化三件套（tsc/build/test）全绿；无 debt marker；无 R7/R8 违规。

2 条 must-have（T4 持久化、T7 prune）标 ⚠️ PRESENT_BEHAVIOR_UNVERIFIED：代码与接线齐备（架构正确性由 grep 证明），但断言的运行期行为（跨组件 unmount 的状态存活、反应管道的时序触发）**仓库内无单测覆盖**，且本质需桌面 GUI 运行期确认。这两条路由到 `human_needed`，不阻塞 Phase 2 进入（state 层与 UI 层均已就位，Phase 2 仅需在 `executeCommand` 审批路径接 `app.broadcastToSessions`）。

---

_Verified: 2026-07-08T13:05:00Z_
_Verifier: Claude (gsd-verifier)_
