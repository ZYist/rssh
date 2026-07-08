# Phase 1: Broadcast UI & State - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

在 AI 面板（`ChatPanel.svelte`）里新增**广播模式**的 UI 与 per-tab 状态：

1. 工具栏一个**广播开关按钮**（toggle），点击切换开/关。
2. 开关 ON 时，工具栏下方出现一个**目标选择器**，列出除主标签外的所有已连接终端标签，用户可勾选/取消勾选作为广播目标。
3. 广播开关状态与目标勾选**按 tab 持久化**到 AI store —— 切换 tab、关闭/重开 AI 面板后状态保持（in-memory，跨 app 重启不保持）。

**本阶段不做（范围锚点）：**
- 命令分发逻辑（`executeCommand` + `broadcastToSessions` 在审批时联动、并行执行、输出隔离）→ **Phase 2**（BCAST-05/06/07/08）
- 跨 session/重启持久化、Raw device 默认排除、toast 反馈、断线检测、审计日志 → **v2 deferred**
- 任何 Rust/Tauri 后端改动 → 纯前端实现（REQUIREMENTS Out of Scope）

广播模式**关闭时行为必须与当前完全一致**，不影响现有 AI 流程（PROJECT 约束）。

</domain>

<decisions>
## Implementation Decisions

### 目标选择器呈现（D-01 ~ D-03）
- **D-01:复用 EditPane 现成广播选择器 UX。** 不另起炉灶设计新交互。把 `src/lib/components/EditPane.svelte` 里 `.session-panel` 的**目标列表部分**抽成一个共享组件（暂称 `BroadcastTargetSelector.svelte`），EditPane 与 ChatPanel **同时使用它**（DRY，而非复制粘贴）。复用：`SessionMinimap` 缩略图 + 类型图标（SSH/`$`/`⎓`/`T`）+ 标签 + accent 光晕选中态 + "全选/全不选" 链接按钮。
- **D-02:AI 面板里以"工具栏下方内联条"呈现。** AI 面板（`.ai-side`）宽 280–380px（默认 380、可拖拽、min 280），EditPane 的 200px 右侧栏放不下。广播 ON → 内联条在工具栏下方展开（把对话区往下挤）；OFF → 整条隐藏。
- **D-03:目标条可折叠。** 广播 ON 时用户可临时收起目标条腾出对话区，广播保持开启。折叠时工具栏开关按钮的计数徽章是唯一状态反馈。
- **D-04:不带 EditPane 的 `Broadcast(N)` 动作按钮。** EditPane 底部那个按钮是"立即发送编辑器文本"，属立即触发语义；AI 面板的分发发生在 Phase 2 命令审批时，Phase 1 这条只负责**选目标**，不放发送按钮。目标数量由开关徽章显示。

### 主标签（源）处理（D-05）
- **D-05:隐藏主标签。** 承载 AI 面板的标签是广播的"源"（AI 只读它的输出，Phase 2 命令也由它经 `executeCommand` 执行）。选择器里**不出现主标签自己**，只列 `app.connectedSessions()` 中"除主标签 session 外"的终端。计数 `N/M` 的 M = 除主标签外的终端数；仅主标签存在时显示空状态"没有其它终端"。

### Raw device 处理（D-06）
- **D-06:Phase 1 照常列出、照常可勾。** Serial/Telnet 与 SSH/local 一视同仁地出现在选择器里、可勾选。符合 BCAST-02/03 字面要求（"列出所有终端标签""可勾选任意终端标签"）+ 与"复用 EditPane"一致（EditPane 现状即如此）。Raw device 的安全默认排除完整留给 **v2**。Phase 1 用户自行决定是否勾选 raw 标签。

### 开关按钮外观（D-07 ~ D-09）
- **D-07:工具栏 `.btn-icon`，发射塔/广播波图标。** 16×16 手绘 stroke SVG，`currentColor`，`stroke-width=2`，跟现有工具栏图标（audit/clear/danger）视觉重量一致。概念选"发射塔/广播波"（一源辐射多目标，最贴广播语义）；实现时从 lucide/feather 风格中取最贴合的具体形（如 radio-tower / radio），保持 stroke 风格统一。
- **D-08:激活态用 accent 色（非红）。** 跟全 app 的"选中/激活"语义一致。**严禁用红色**——红色是 `DangerModeToggle` 的危险语义，广播是常规功能态，混用会误导。
- **D-09:带目标计数徽章。** 按钮右下角小圆徽显示已选目标数。0 个目标时徽标置灰或隐藏。因目标条可折叠（D-03），徽章是折叠时唯一的状态反馈。

### 状态与生命周期（D-10 ~ D-12，沿代码先例）
- **D-10:状态放 `src/lib/ai/store.svelte.ts`，per-tab，in-memory。** 广播开关布尔 + 目标 tabId 集合，按 AI 会话的 tabId 索引。切 tab / 关重开 AI 面板保持；跨 app 重启不持久化（v2）。**不放 `app.svelte.ts`**（PROJECT/STATE 锁定：广播是 AI 面板语义，跟 AI 会话同寿命）。
- **D-11:关闭的目标 tab 自动从选择里剔除。** 复用 EditPane 的 `$effect` prune 先例（`app.connectedSessions()` 变化时剔除已不存在的 tabId）。
- **D-12:新开的终端 tab 不自动选中。** 新 session 出现在列表里但默认不勾，用户主动勾选（与 EditPane 行为一致）。"全选"= 选全部"除主标签外"的目标。

### Claude's Discretion
- 具体 state 字段形状（如 `Map<tabId, { enabled: boolean; targets: Set<string> }>` 还是分两个导出）—— 由 planner/researcher 按 `ai/store.svelte.ts` 现有 per-tab 结构（如 `_sessions` 模式）对齐。
- 空状态文案、tooltip 文案、徽章 0 值视觉（置灰 vs 隐藏）。
- 开关按钮在工具栏里的精确位置（建议挨着 DangerModeToggle，两个都是 mode toggle）。
- 折叠条的默认初始态（首次开启广播时默认展开还是收起）。
- 共享组件抽取的边界（`BroadcastTargetSelector` 是否含标题/计数行，还是只含列表；EditPane 改造时如何保持其 `Broadcast(N)` 按钮）。

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目级（需求与锁定决策）
- `.planning/REQUIREMENTS.md` — BCAST-01..04（Phase 1 需求）+ BCAST-05..08（Phase 2，明确本阶段不做）+ v2 deferred 清单 + Out of Scope（"后端 Rust/Tauri 修改 — 纯前端实现"）
- `.planning/PROJECT.md` — "Constraints"（兼容性/性能/安全）、"Key Decisions" 表（AI 只读主标签输出、复用 broadcastToSessions、审批跟随 danger_mode、状态在 AI Store）、"Out of Scope"（raw device 默认排除、汇总输出回 AI）
- `.planning/ROADMAP.md` §"Phase 1: Broadcast UI & State" — Goal + 4 条 Success Criteria + "UI hint: yes" + Depends on: Nothing

### 现有实现先例（复用源）
- `src/lib/components/EditPane.svelte` — **广播选择器 UX 源头**（`.session-panel`、`selectedTabIds: Set<string>`、prune `$effect`、selectAll/selectNone、`broadcast()` 触发）。Phase 1 要把其目标列表部分抽成共享组件。
- `src/lib/components/SessionMinimap.svelte` — 终端缩略图组件，目标行直接复用。
- `src/lib/components/SessionPreviewPopover.svelte` — hover 预览 popover（EditPane 用），如保留 hover 预览则复用。
- `src/lib/ai/ChatPanel.svelte` — **开关按钮宿主**（`.toolbar` + `.btn-icon` + `DangerModeToggle` 先例）。工具栏布局/样式在此。
- `src/lib/ai/store.svelte.ts` — **广播状态宿主**（per-tab AI 会话状态的家）。新增广播 state 按此文件现有 per-tab 模式。
- `src/lib/stores/app.svelte.ts` — `broadcastToSessions(tabIds, text)` (:466) + `connectedSessions()` + `_sessions` registry。只读复用，不改。

### 约束与规范（实现时遵守）
- `AGENT.md`（根）— R1..R10 + Pr1..Pr5（尤其 R7 runes、R8 状态不放组件、Pr3 无 emoji/走 design token、R1 事件命名）
- `.planning/codebase/CONVENTIONS.md` — 命名、Svelte 5 runes、store getter 模式、CSS token、i18n 双语 key
- `.planning/codebase/ARCHITECTURE.md` — "Svelte 5 runes only"、"Centralized frontend state"、"AI diagnose flow"（理解 ChatPanel/ai store 关系）
- `src/lib/i18n/locales/en.ts` + `src/lib/i18n/locales/zh.ts` — 新 UI 字符串必须同步进两份 catalog

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`SessionMinimap.svelte`** — 终端缩略图，目标行的视觉主体，直接复用。
- **EditPane 的 `.session-panel`（目标列表部分）** — 抽成 `BroadcastTargetSelector.svelte` 后 EditPane 与 ChatPanel 共用。注意：EditPane 的 `Broadcast(N)` 动作按钮与 `pickBroadcastText`/`broadcast()` 是 EditPane 专属（立即发送编辑器文本），不进共享组件。
- **`app.connectedSessions()`** — 返回 `{ tabId, type, label, sessionId }[]`，选择器列表的数据源。筛掉主标签自己的 session 即 D-05。
- **`app.broadcastToSessions(tabIds, text)`** — Phase 2 分发用，Phase 1 不调用，但状态设计要为 Phase 2 调用它铺路（目标集合即传给它的 `tabIds`）。
- **`DangerModeToggle.svelte`** — 工具栏内 toggle 的实现先例（`.btn-icon.danger-toggle` + `class:on` + snippet trigger + confirm modal）。广播开关结构上仿它（但语义非危险、激活用 accent、且广播是 per-tab 状态而非全局 setting，所以**不**走它的 confirm 流程）。
- **`.btn-icon` / `.toolbar` 样式（ChatPanel `<style>`）** — 开关按钮直接套现有图标按钮样式。

### Established Patterns
- **Svelte 5 runes only** — `$state`/`$derived`/`$effect`/`$props`；`onclick={fn}`；禁用 `on:click`/`$: `/`export let`（R7，违反=拒绝合并）。
- **状态私有化 + getter 导出** — `let _x = $state(...)` + `export function x() { return _x; }`，绝不导出裸 `$state`（R8）。广播状态加进 `ai/store.svelte.ts`，不放进组件。
- **per-tab 状态** — AI 会话已按 tabId 索引（`ai.sessionForTab(tabId)` 等）；广播状态跟随同一 tabId 键。
- **prune 已关闭 tab** — EditPane `$effect` 跟踪 `connectedSessions()` 变化剔除失效 tabId（D-11 复用）。
- **CSS 走 design token** — `--accent`/`--text-dim`/`--divider`/`--surface` 等，禁裸 hex（Pr3）；选中态 accent 光晕见 EditPane `.session-item.selected`。
- **i18n 双语** — 所有用户可见字符串经 `t()`，新 key 同步 en.ts + zh.ts。
- **flex 三件套** — 任何 tab/pane 根容器 `flex:1; overflow-y:auto; min-height:0;`（R4）。

### Integration Points
- **`ChatPanel.svelte` 工具栏** — 在 `.toolbar` 内、`DangerModeToggle` 旁插入广播开关 `.btn-icon`；工具栏下方、`.banner` 之后插入可折叠目标条（替换/抢占部分 `.chat` 高度）。
- **`ChatPanel` props** — 已有 `{ tabId, targetKind, targetId }`；`tabId` 即主标签 id，用于 D-05 过滤；广播状态经 `ai.*` getter 读。
- **`ai/store.svelte.ts`** — 新增广播状态 + getter/mutator（如 `broadcastState(tabId)` / `toggleBroadcast(tabId)` / `setBroadcastTargets(tabId, ids)`）。
- **`EditPane.svelte`** — 改造为消费新 `BroadcastTargetSelector`（保持其 `Broadcast(N)` 按钮与立即发送语义）。
- **`closeTab` / tab 关闭路径** — 确认 tab 关闭时连带清理其在广播状态里的记录（与 D-11 prune 协同；EditPane 现靠 `connectedSessions()` 自然 prune，per-tab 持久化状态需显式清理以防泄漏）。

</code_context>

<specifics>
## Specific Ideas

- 用户明确表态："现阶段已有的广播按钮已经很好了，就是新建编辑按钮点击后出来的 Edit 界面" —— 即**以 EditPane 的广播选择器为视觉/交互蓝本**，不要新设计。这是 Area 1 的决定性输入。
- 用户对"复用、不重新发明"有强偏好 —— 优先抽共享组件而非新建平行实现。

</specifics>

<deferred>
## Deferred Ideas

- **Raw device（Serial/Telnet）默认排除 + 显式解锁勾选** —— v2 需求（REQUIREMENTS v2、PROJECT Out of Scope）。Phase 1 按 D-06 照常列出。
- **目标选择跨 session/重启持久化** —— v2（"目标选择器持久化（跨 session 保持）"）。Phase 1 仅 in-memory per-tab。
- **广播执行后的 toast 反馈提示** —— v2（属 Phase 2 分发后的反馈，但 REQUIREMENTS 把它列在 v2）。
- **断线/失联目标自动检测和 toast 提示** —— v2。
- **广播事件写入审计日志** —— v2（与现有 `src-tauri/src/ai/audit.rs` 协同，属 Phase 2/v2）。
- **广播模式下抑制 auto-approve（安全增强）** —— v2（REQUIREMENTS v2 首条）。Phase 2 BCAST-08 明确"审批跟随现有 danger_mode/auto_run，不引入额外审批"。

None of these were folded into Phase 1 —— 它们要么明确属 Phase 2（分发相关），要么属 v2（安全/持久化/反馈增强）。

</deferred>

---

*Phase: 1-Broadcast UI & State*
*Context gathered: 2026-07-08*
