# Phase 1: Broadcast UI & State - Research

**Researched:** 2026-07-08
**Domain:** Svelte 5 前端组件抽取 + per-tab runes 状态（纯前端，无后端）
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### 目标选择器呈现（D-01 ~ D-03）
- **D-01：复用 EditPane 现成广播选择器 UX。** 把 `src/lib/components/EditPane.svelte` 里 `.session-panel` 的**目标列表部分**抽成共享组件（`BroadcastTargetSelector.svelte`），EditPane 与 ChatPanel **同时使用它**（DRY）。复用：`SessionMinimap` 缩略图 + 类型图标（SSH/`$`/`⎓`/`T`）+ 标签 + accent 光晕选中态 + "全选/全不选" 链接按钮。
- **D-02：AI 面板里以"工具栏下方内联条"呈现。** 广播 ON → 内联条在工具栏下方展开（把对话区往下挤）；OFF → 整条隐藏。
- **D-03：目标条可折叠。** 广播 ON 时用户可临时收起目标条腾出对话区，广播保持开启。折叠时工具栏开关按钮的计数徽章是唯一状态反馈。

#### 主标签（源）处理（D-05）
- **D-05：隐藏主标签。** 承载 AI 面板的标签是广播的"源"。选择器里**不出现主标签自己**，只列 `app.connectedSessions()` 中"除主标签 session 外"的终端。

#### Raw device 处理（D-06）
- **D-06：Phase 1 照常列出、照常可勾。** Serial/Telnet 与 SSH/local 一视同仁。Raw device 的安全默认排除完整留给 **v2**。

#### 开关按钮外观（D-07 ~ D-09）
- **D-07：工具栏 `.btn-icon`，发射塔/广播波图标。** 16×16 手绘 stroke SVG，`currentColor`，`stroke-width=2`。
- **D-08：激活态用 accent 色（非红）。** **严禁用红色**——红色是 `DangerModeToggle` 的危险语义。
- **D-09：带目标计数徽章。** 按钮右下角小圆徽显示已选目标数。0 个目标时徽标隐藏。

#### 状态与生命周期（D-10 ~ D-12，沿代码先例）
- **D-10：状态放 `src/lib/ai/store.svelte.ts`，per-tab，in-memory。** 按 AI 会话的 tabId 索引。**不放 `app.svelte.ts`**。
- **D-11：关闭的目标 tab 自动从选择里剔除。** 复用 EditPane 的 `$effect` prune 先例。
- **D-12：新开的终端 tab 不自动选中。**

#### UI-SPEC Discretion 锁定项（已在 01-UI-SPEC.md 中定案）
- state 字段形状：`{ enabled, barCollapsed, targets: Set<string> }` 单 record，按 tabId 索引于 `_broadcastByTab`。
- 徽标 0 值视觉：**隐藏**（不渲染）。
- 开关在工具栏位置：`clear` 与 `DangerModeToggle` 之间（紧邻 danger 左侧）。
- 折叠条默认初始态：首次开启广播 = **展开**。
- 折叠机制：折叠 = 收起列表区，保留单行标题条（标题 + N/M + chevron）。
- 共享组件边界：`BroadcastTargetSelector` = 列表 + 全选/全不选（受控）；**不含**标题、chevron、Broadcast(N) 按钮。

### Claude's Discretion
- 具体 state 字段形状（已在 UI-SPEC 锁定为单 record `_broadcastByTab`）。
- 空状态文案、tooltip 文案、徽章 0 值视觉（已在 UI-SPEC 锁定）。
- 开关按钮在工具栏里的精确位置（已在 UI-SPEC 锁定为 clear 与 DangerModeToggle 之间）。
- 折叠条的默认初始态（已在 UI-SPEC 锁定为首次展开）。
- 共享组件抽取的边界（已在 UI-SPEC 锁定）。

### Deferred Ideas (OUT OF SCOPE)
- **Raw device（Serial/Telnet）默认排除 + 显式解锁勾选** —— v2（Phase 1 按 D-06 照常列出）。
- **目标选择跨 session/重启持久化** —— v2（Phase 1 仅 in-memory per-tab）。
- **广播执行后的 toast 反馈提示** —— v2。
- **断线/失联目标自动检测和 toast 提示** —— v2。
- **广播事件写入审计日志** —— v2。
- **广播模式下抑制 auto-approve（安全增强）** —— v2。
- **命令分发逻辑**（`executeCommand` + `broadcastToSessions` 在审批时联动、并行执行、输出隔离）→ **Phase 2**（BCAST-05/06/07/08）。
- **任何 Rust/Tauri 后端改动** → 纯前端实现。
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BCAST-01 | AI 面板工具栏显示广播模式 toggle 按钮，点击切换开/关状态 | 见 §Architecture Patterns §ChatPanel 工具栏插入 + §Code Examples §开关按钮（镜像 `.danger-toggle.on` 换 `--accent`）；`aria-pressed` + 动态 `aria-label`/`title` |
| BCAST-02 | 广播模式开启后，显示目标选择器，列出所有已打开的终端标签 | 见 §Architecture Patterns §目标条宿主 + §主标签过滤；数据源 `app.connectedSessions().filter(s => s.tabId !== tabId)` |
| BCAST-03 | 用户可勾选/取消勾选任意终端标签作为广播目标 | 见 §Architecture Patterns §目标勾选 + §Code Examples §受控 BroadcastTargetSelector；复用 EditPane `.session-item.selected` halo 语言 |
| BCAST-04 | 广播 toggle 和目标选择状态为 per-tab 级别，保存在 AI store 中 | 见 §Architecture Patterns §store.svelte.ts 状态形状 + §Code Examples §mutator（整体替换 record）；`closeTab` → `stopSession` 清理路径确认 |
</phase_requirements>

## Summary

Phase 1 是一个**纯前端、零新依赖**的组件抽取 + 状态扩展任务，所有"标准栈"已在代码库中就位（Svelte 5 runes、Vitest 4、既有 `.btn-icon`/`.session-item`/`.danger-toggle` 样式、`SessionMinimap`、`connectedSessions()`、`broadcastToSessions()`）。研究的权威来源是**代码库本身**——不存在需要外部查阅的库文档，因为本阶段复用的每个模式都能在 `EditPane.svelte`、`ai/store.svelte.ts`、`ChatPanel.svelte`、`DangerModeToggle.svelte` 中找到可直接复制的运行中先例。

核心工作分三块：(1) 从 `EditPane.svelte` 抽取目标列表部分为受控组件 `BroadcastTargetSelector.svelte`，EditPane 与 ChatPanel 共用；(2) 在 `ai/store.svelte.ts` 新增 `_broadcastByTab: Record<tabId, {enabled, barCollapsed, targets: Set<string>}>` per-tab 状态 + getter/mutator，沿 `_sessionByTab` / `_pendingByTab` 既有先例；(3) 在 `ChatPanel.svelte` 工具栏（`clear` 与 `DangerModeToggle` 之间）插入广播开关 `.btn-icon`，工具栏下方插入可折叠目标条。i18n 双语 key 同步进 `en.ts` + `zh.ts`（flat dotted-key 结构）。

**Primary recommendation:** 严格逐字复用 EditPane 的目标列表 markup + `.session-item` / `.session-item.selected` / `.link-btn` / `.select-actions` 样式；状态 mutator 一律**整体替换 record 条目 + 重建 Set**（不可 in-place `.add()/.delete()` Set）；prune `$effect` 放在 **ChatPanel 组件内**（store 模块不能用 `$effect`），调用 store 导出的 `pruneBroadcastTargets` mutator；主标签关闭的整 record 清理挂在 `ai.stopSession`（已存在的 per-tab teardown 点）。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 广播开关 toggle（UI + 点击） | Browser / Client | — | 纯前端按钮，无后端调用；状态写 ai store（client 层） |
| 目标选择器渲染（缩略图、勾选） | Browser / Client | — | 复用 `SessionMinimap`（读既有 xterm buffer，无新连接）、`connectedSessions()`（client 已有数据） |
| per-tab 广播状态（enabled/targets/collapsed） | Browser / Client | — | 模块级 `$state` 于 `ai/store.svelte.ts`，in-memory，不落 DB、不过 IPC |
| 主标签识别（D-05 过滤） | Browser / Client | — | ChatPanel 的 `tabId` prop = `aiActiveTab.id`（承载 AI 面板的标签），纯客户端坐标 |
| 失效目标 prune（D-11） | Browser / Client | — | ChatPanel 内 `$effect` 跟踪 `app.connectedSessions()` 变化，调 store mutator |
| 目标条折叠/展开 | Browser / Client | — | per-tab `barCollapsed` 布尔在 ai store，CSS `max-height` 过渡 |

本阶段**完全不触及** API/Backend、Database、CDN/Static 任何 tier——REQUIREMENTS.md 明确"后端（Rust/Tauri）修改 — 纯前端实现"为 Out of Scope。

## Standard Stack

### Core（全部复用，零新依赖）

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `svelte` | `^5` | runes 响应式（`$state`/`$derived`/`$effect`/`$props`） | `[VERIFIED: package.json:34]` 项目锁定；`tsconfig.json` strict + `@sveltejs/vite-plugin-svelte` 编译 |
| `vitest` | `^4.1.5` | TS 单测（如需测 store mutator 纯逻辑） | `[VERIFIED: package.json:37]` `src/**/*.test.ts` 模式，node env，svelte plugin 启用（`.svelte.ts` runes 需要） |

**无 Core 新增。** 本阶段不 `npm install` 任何包。

### Supporting（代码先例组件，直接 import 复用）

| Asset | Location | Purpose | When to Use |
|---------|---------|---------|-------------|
| `SessionMinimap.svelte` | `src/lib/components/SessionMinimap.svelte` | 终端缩略图（canvas，每 500ms 重绘 xterm viewport） | 目标行视觉主体，`<BroadcastTargetSelector>` 内每行复用 `[VERIFIED: codebase]` |
| `SessionPreviewPopover.svelte` | `src/lib/components/SessionPreviewPopover.svelte` | hover 预览 popover | 如保留 hover 预览则复用（EditPane 现用；ChatPanel 是否保留 hover 预览由 planner 决定，UI-SPEC 未强制） |
| `app.connectedSessions()` | `src/lib/stores/app.svelte.ts:456` | 返回 `SessionInfo[]`（`{tabId, sessionId, type, label}`） | 选择器数据源；`.filter(s => s.tabId !== primaryTabId)` 即 D-05 `[VERIFIED: codebase]` |
| `app.broadcastToSessions()` | `src/lib/stores/app.svelte.ts:466` | 按 tabId 调各 pane 的 `sendText` | **Phase 2 用**；Phase 1 不调用，但 targets 集合设计要为 Phase 2 传给它铺路 `[VERIFIED: codebase]` |
| `.danger-toggle.on` 样式 | `src/lib/ai/ChatPanel.svelte:480` | 工具栏 toggle 激活态（`--error` 14%/22% tint） | 广播开关 `.broadcast-toggle.on` **镜像此规则，把 `--error` 换成 `--accent`** `[VERIFIED: codebase]` |
| `.session-item` / `.session-item.selected` 样式 | `src/lib/components/EditPane.svelte:234-260` | 目标行默认/hover/选中态（accent halo） | 逐字复用进 `BroadcastTargetSelector`（抽取时随组件带走或在共享样式块） `[VERIFIED: codebase]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 抽共享 `BroadcastTargetSelector` | 在 ChatPanel 里复制粘贴一份目标列表 | CONTEXT D-01 + 用户强偏好"复用不重新发明"已锁定抽取；复制粘贴违反 DRY，且 EditPane 未来改动会两处不同步 |
| store 内 `$effect.root` 做 prune | ChatPanel 组件内 `$effect` + store mutator | `$effect`/`$effect.root` 在 `.svelte.ts` 模块需手动生命周期管理（teardown）；组件内 `$effect` 随组件挂载/卸载自动管理，且镜像 EditPane 先例。**推荐组件内 `$effect`**（见 §Common Pitfalls §Pitfall 2） |
| `Set<string>` 存 targets | `string[]` 数组 | Set 语义更准（去重、has/delete），且 EditPane 先例用 `Set<string>`；数组需手动去重。沿用 Set |

**Installation:**
```bash
# 无安装。本阶段零新依赖。
```

**Version verification:** 无需验证新包；`svelte ^5` 与 `vitest ^4.1.5` 已在 `package.json` 锁定，`package-lock.json` 提交在库。

## Package Legitimacy Audit

> 本阶段**不安装任何外部包**（UI-SPEC §Registry Safety："本阶段不引入任何第三方注册表、block、依赖"；新增广播图标为手绘 SVG，路径从 lucide.dev 复制 canonical path，**不装 `lucide-svelte` 包**）。故 Package Legitimacy Gate Step 1–3 均 N/A。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| —（无新包） | — | — | — | — | N/A | 不适用 |

**Packages removed due to [SLOP] verdict:** none（未提议任何新包）
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram（数据流）

```
用户点击广播开关
      │
      ▼
ChatPanel.onclick → ai.toggleBroadcast(tabId)
      │                        │
      │                        ▼
      │              _broadcastByTab[tabId].enabled 翻转
      │              （整体替换 record，触发 runes 反应）
      │
      ▼
$derived(broadcastEnabled) 重算 → 工具栏按钮 .on 着色 + 目标条条件渲染
      │
      ▼
目标条渲染：app.connectedSessions() ──filter(s.tabId !== tabId)──▶ 候选目标
      │                                                                │
      │   ◀──用户勾选──▶  ai.toggleBroadcastTarget(tabId, targetId)    │
      │                     （重建 Set + 替换 record）                  │
      ▼                                                                │
BroadcastTargetSelector（受控） ◀── selectedIds / onToggle props ──┘
      │
      │  （Phase 1 到此为止 —— 不调用 broadcastToSessions）
      │
      ▼  [Phase 2 入口，本阶段不实现]
ai.broadcastTargets(tabId)  ──传给──▶  app.broadcastToSessions(tabIds, text)


旁路清理路径：
  目标 tab 关闭 ──▶ ChatPanel $effect 跟踪 connectedSessions() ──▶ ai.pruneBroadcastTargets(...)
  主标签关闭   ──▶ app.closeTab ──▶ ai.stopSession(tabId) ──▶ 内部 delete _broadcastByTab[tabId]
```

### Recommended Project Structure（文件改动清单）

```
src/lib/components/
├── BroadcastTargetSelector.svelte   # 新增：从 EditPane 抽出的受控目标列表组件
├── EditPane.svelte                  # 修改：消费 BroadcastTargetSelector（保留 Broadcast(N) 按钮）
├── SessionMinimap.svelte            # 不改：被 BroadcastTargetSelector 复用
└── SessionPreviewPopover.svelte     # 不改：可选复用（hover 预览）
src/lib/ai/
├── ChatPanel.svelte                 # 修改：工具栏加广播开关 + 下方加可折叠目标条
└── store.svelte.ts                  # 修改：加 _broadcastByTab + getter/mutator
src/lib/i18n/locales/
├── en.ts                            # 修改：加 ai.broadcast.* / ai.toolbar.broadcast_* key
└── zh.ts                            # 修改：同步同批 key
```

### Pattern 1: EditPane 目标列表抽取边界（D-01）

**What:** 把 `EditPane.svelte` 中 `.session-panel` 的**列表部分**（`<div class="session-list">` + `<div class="select-actions">`，源码 144–167 行）抽成受控组件 `BroadcastTargetSelector.svelte`。

**抽取边界（逐行核对 EditPane.svelte:138-177）：**

| EditPane 元素 | 进共享组件？ | 说明 |
|---------------|-------------|------|
| `<div class="panel-header">Target Sessions</div>` (139) | ❌ 留 EditPane | 标题由宿主负责（UI-SPEC：EditPane 保留自己的标题；ChatPanel 加自己的"广播目标"标题 + 折叠 chevron） |
| `{#if sessions.length === 0}<div class="empty-hint">` (141-142) | ✅ 进组件（或由宿主通过 prop/slot 传文案） | UI-SPEC：空状态 `.empty-hint` 由组件渲染，文案走 `ai.broadcast.empty` |
| `<div class="session-list">{#each...}` (144-163) | ✅ 进组件 | 核心列表 + `SessionMinimap` + 类型图标 + 选中 halo，逐字复用 |
| `<div class="select-actions">All/None` (164-167) | ✅ 进组件 | 全选/全不选链接按钮 |
| `<button class="broadcast-btn">Broadcast(N)` (170-176) | ❌ 留 EditPane | D-04：立即发送语义是 EditPane 专属，不进共享组件 |
| hover popover `{#if hoveredTabId}` (179-181) | ❌ 留 EditPane（ChatPanel 可选另加） | hover 预览状态是宿主本地 `$state`，由宿主决定是否启用 |

**受控组件 props 契约（UI-SPEC §Component Inventory 锁定）：**
```typescript
// src/lib/components/BroadcastTargetSelector.svelte
let {
  sessions,          // SessionInfo[] — 已过滤掉主标签（宿主负责 filter）
  selectedIds,       // Set<string> — 当前已选 tabId 集合
  onToggle,          // (tabId: string) => void
  onSelectAll,       // () => void
  onSelectNone,      // () => void
}: {
  sessions: import("../stores/app.svelte.ts").SessionInfo[];
  selectedIds: Set<string>;
  onToggle: (tabId: string) => void;
  onSelectAll: () => void;
  onSelectNone: () => void;
} = $props();
```

**EditPane 改造后形态：** `selectedTabIds` 仍是 EditPane 本地 `$state`（编辑器一次性发送语义，与 AI 广播状态不同寿命，**不进 ai store**）；`.session-panel` 内部把列表 + actions 替换为 `<BroadcastTargetSelector sessions={sessions} selectedIds={selectedTabIds} onToggle={toggle} onSelectAll={selectAll} onSelectNone={selectNone} />`，保留 `.panel-header` + `.broadcast-btn`。

**When to use:** 凡要呈现"终端多选目标列表"的宿主都用此组件。

### Pattern 2: store.svelte.ts per-tab 状态形状（D-10）

**What:** 在 `ai/store.svelte.ts` 沿 `_sessionByTab` / `_pendingByTab` / `_chatByTab` 既有先例新增广播状态。

**形状（UI-SPEC §store.svelte.ts 锁定，沿 `_xByTab` 先例 `[VERIFIED: codebase store.svelte.ts:52-55]`）：**
```typescript
// src/lib/ai/store.svelte.ts（新增，置于现有 _xxxByTab 声明附近，如 _pendingByTab 之后）
interface BroadcastState {
    enabled: boolean;        // 开关 on/off
    barCollapsed: boolean;   // 目标条折叠/展开（仅 enabled=true 时有意义）
    targets: Set<string>;    // 已选目标 tabId 集合
}
let _broadcastByTab = $state<Record<string, BroadcastState>>({});

const DEFAULT_BROADCAST: BroadcastState = { enabled: false, barCollapsed: false, targets: new Set() };
```

**getter/mutator 命名沿既有规范（无 `get` 前缀，动词短语 `[VERIFIED: codebase app.svelte.ts:175 命名规范]`）：**
- `broadcastState(tabId): BroadcastState` — 不存在则返回 `DEFAULT_BROADCAST`（只读快照，调用方不应原地改返回的 Set）
- `broadcastEnabled(tabId): boolean` — 便捷 getter
- `broadcastTargets(tabId): Set<string>` — 便捷 getter（Phase 2 分发时读它传给 `broadcastToSessions`）
- `toggleBroadcast(tabId): void`
- `setBroadcastBarCollapsed(tabId, collapsed): void`
- `toggleBroadcastTarget(tabId, targetTabId): void`
- `setBroadcastTargets(tabId, ids: Set<string>): void` — 全选/全不选
- `pruneBroadcastTargets(tabId, activeTabIds: Set<string>): void` — 由宿主 `$effect` 调用
- `clearBroadcastState(tabId): void` — 在 `stopSession` 内调用（见 Pattern 4）

**When to use:** 所有 per-tab AI-语义状态都按此 `_xByTab` + getter/mutator 模式。

### Pattern 3: ChatPanel 工具栏 + 目标条插入点

**What:** 在 `ChatPanel.svelte` 工具栏插入广播开关，工具栏下方插入可折叠目标条。

**工具栏精确插入点（核对 ChatPanel.svelte:246-302 `[VERIFIED: codebase]`）：**
当前工具栏顺序：`model`(250) → `tokens`(251) → audit-btn(257) → clear-btn(273) → **DangerModeToggle(287-300)** → close-btn(301)。

UI-SPEC D-07 锁定：广播开关插入 **clear-btn(273) 与 DangerModeToggle(287) 之间**（紧邻 danger 左侧，两个 mode toggle 相邻）。close-btn(301) 保持最右。

**目标条精确插入点：** `{#if banner}`(304-309) 之后、`{#if auditOpen && session}` / `.chat`(311-314) 之前。目标条用 `{#if ai.broadcastEnabled(tabId)}` 条件渲染（广播 OFF 整条不渲染）。

**关键约束：** ChatPanel 的 `tabId` prop（16-20 行）即**主标签 id**（= `AppShell.svelte:1059` 传入的 `aiActiveTab.id`）。D-05 过滤就是 `app.connectedSessions().filter(s => s.tabId !== tabId)`。

**When to use:** 所有 ChatPanel 工具栏新增控件都套 `.btn-icon`，按"mode toggle 相邻成组"组织。

### Pattern 4: 主标签关闭的整 record 清理（stopSession 集成点）

**What:** 主标签（承载 AI 面板的标签）关闭时，其 `_broadcastByTab[tabId]` 整条要删除，防内存泄漏。

**集成点（核对 `[VERIFIED: codebase]`）：**
- `app.closeTab(id)`（app.svelte.ts:224-245）在 239 行调 `ai.stopSession(id)`（仅当该 tab 起过 AI 会话）。
- `ai.stopSession(tab_id)`（store.svelte.ts:225-262）在 255-260 行 `delete` 所有 per-tab map（`_sessionByTab`、`_pendingByTab`、`_keyboardLockedByTab`、`_targetKindByTab`、`_chatByTab`、`_tokensByTab`）。

**实现：** 在 `stopSession` 的 delete 簇（store.svelte.ts:255-260 附近）加 `delete _broadcastByTab[tab_id];`（或调 `clearBroadcastState(tab_id)`）。这保证主标签关闭 → 广播状态随之清，与既有 per-tab teardown 语义一致。

**注意：** 这与 D-11 prune 是**两条不同路径**——prune 处理"目标 tab 关闭"（从某主标签的 targets Set 里剔除一个 id）；stopSession 清理处理"主标签自己关闭"（删整条 record）。两者都必须实现，缺一即泄漏。

### Anti-Patterns to Avoid

- **在 ChatPanel 组件内建全局广播状态**（违反 R8）：状态必须放 `ai/store.svelte.ts`，组件只读写 store。
- **对 `Set` 做 in-place `.add()/.delete()` 期望触发响应**：Svelte 5 `$state` 对 `Set` 无方法拦截，必须重建 Set + 替换 record（见 §Common Pitfalls §Pitfall 1）。
- **把 prune `$effect` 放进 store 模块顶层**：`$effect` 只能在组件 init 上下文或 `$effect.root` 内运行（见 §Common Pitfalls §Pitfall 2）。
- **用 `--error` 红色作广播激活态**（违反 D-08）：红色是 DangerModeToggle 专属危险语义。
- **新建 IPC/事件/OSC 通道**（违反 R1/R2）：本阶段零后端调用，不引入任何 `invoke`/`listen`/OSC kind。
- **用 `on:click`/`$:`/`export let`**（违反 R7）：一律 `onclick={fn}` + runes。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 目标终端列表 UI | 新画一套 session 卡片 | 抽 EditPane `.session-list` → `BroadcastTargetSelector` | 已有 accent halo、类型图标、缩略图、aria-pressed，DRY（D-01） |
| 终端缩略图 | 新写 buffer 抓取 | `SessionMinimap.svelte` | 已封装 canvas 重绘 + `readTerminalViewport` |
| 已连接终端数据源 | 新维护一份 tab→session 映射 | `app.connectedSessions()` | 已有 `_sessions` registry + label 解析 |
| per-tab 状态模式 | 新发明一套状态结构 | `_broadcastByTab` 沿 `_xByTab` 先例 | 与 `_sessionByTab`/`_pendingByTab` 同寿命同清理路径 |
| 工具栏 toggle 视觉 | 新设计激活态样式 | 镜像 `.danger-toggle.on`（换 `--accent`） | 已验证的 `color-mix` tint 节奏 |
| 目标分发（Phase 2） | —（本阶段不做） | `app.broadcastToSessions(tabIds, text)` | 已实现各 transport sendText，Phase 1 只为它铺路 |

**Key insight:** 本阶段是"抽取 + 接线"，不是"新建"。每个需求（BCAST-01..04）都能在 EditPane + DangerModeToggle + ai/store 里找到可直接复制的运行中先例。手画任何新交互模式都是反 D-01。

## Common Pitfalls

### Pitfall 1: Svelte 5 `$state` 不拦截 Set/Map 方法调用（反应性静默失效）
**What goes wrong:** 直接 `_broadcastByTab[tabId].targets.add(tid)` 或 `.delete(tid)`，UI 不更新——开关徽标计数、选中 halo 都不刷新。
**Why it happens:** Svelte 5 的 `$state` 深代理对普通 object/array 字段赋值生效（见 store.svelte.ts:715 注释 "Svelte 5's $state proxy picks up field assignments"），但对 `Set`/`Map` 的 `.add()/.delete()/.clear()` **没有代理拦截**——这些方法不触发 set trap。`[VERIFIED: codebase EditPane.svelte:29-34]` EditPane 的 `toggle()` 正因如此才**重建整个 Set** 再赋值给 `$state`。
**How to avoid:** 所有改 targets 的 mutator 必须：
```typescript
function toggleBroadcastTarget(tabId: string, targetTabId: string): void {
    const prev = _broadcastByTab[tabId] ?? DEFAULT_BROADCAST;
    const next = new Set(prev.targets);
    if (next.has(targetTabId)) next.delete(targetTabId);
    else next.add(targetTabId);
    _broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, targets: next } };
}
```
即"重建 Set → 整体替换 record 条目 → 重新赋值整个 `_broadcastByTab`"。`setBroadcastTargets`/`pruneBroadcastTargets` 同理。
**Warning signs:** 勾选/取消勾选后徽标 N 不变、halo 不出现——先查 mutator 是否 in-place 改 Set。

### Pitfall 2: `$effect` 只能在组件 init 上下文运行（store 模块不能用）
**What goes wrong:** 在 `store.svelte.ts` 顶层写 `$effect(() => { ... app.connectedSessions() ... })` 抛 "effect_can_only_be_used_during_component_initialization" 或不运行。
**Why it happens:** Svelte 5 `$effect`（非 `$effect.root`）必须在与组件生命周期绑定的上下文里跑。`.svelte.ts` 模块顶层没有组件实例。`[VERIFIED: codebase]` store.svelte.ts 全文无 `$effect` 调用——所有响应式副作用经 `attachListeners`（显式 listen/unlisten）实现。
**How to avoid:** prune `$effect` 放在 **ChatPanel.svelte 的 `<script>` 内**（镜像 EditPane.svelte:23-27 的 `$effect`），跟踪 `app.connectedSessions()`，调 `ai.pruneBroadcastTargets(tabId, new Set(sessions.map(s => s.tabId)))`。store 只提供无副作用的 mutator。
**Warning signs:** "我想把 prune 集中到 store 一处" → 不要用顶层 `$effect`；要么组件内 `$effect` 调 store mutator，要么用 `$effect.root` + 手动 teardown（后者本阶段不必引入）。

### Pitfall 3: ChatPanel 在 AI 面板关闭时 unmount（prune `$effect` 生命周期）
**What goes wrong:** 以为 prune `$effect` 一直跑——实际 AI 面板一关就停。
**Why it happens:** `[VERIFIED: codebase AppShell.svelte:1049]` `<aside class="ai-side">` + `<ChatPanel>` 包在 `{#if aiVisible && aiActiveTab && aiSessionId}` 内，AI 面板关闭 / 无活跃 session tab → ChatPanel 整个 unmount → 其 `$effect` 销毁。
**How to avoid:** 这**不是 bug**——prune 只需在面板可见时跑。但需确保：(a) 主标签关闭的清理**不依赖** prune `$effect`（那条路径走 `closeTab` → `ai.stopSession` → `clearBroadcastState`，见 Pattern 4，与面板可见性无关）；(b) 状态持久化不依赖组件存活——`_broadcastByTab` 是模块级 `$state`，ChatPanel unmount/remount 期间状态不丢（BCAST-04 "关重开 AI 面板状态保持" 由此满足）。
**Warning signs:** 测试"关 AI 面板再开"发现状态丢 → 检查状态是否误放进组件本地 `$state` 而非 store。

### Pitfall 4: 抽取样式时 Svelte `<style>` scoped 隔离导致两边样式失效
**What goes wrong:** 把 `.session-item` 样式移进 `BroadcastTargetSelector.svelte` 后，EditPane 原先靠这些样式的部分失去样式（scoped class 不跨组件）。
**Why it happens:** Svelte 组件 `<style>` 默认 scoped，class 只作用于本组件 DOM。`SessionMinimap` 内部 `.minimap` 也 scoped。
**How to avoid:** 抽取策略二选一：(a) 把 `.session-item`/`.session-item.selected`/`.session-meta`/`.session-type`/`.session-label`/`.select-actions`/`.link-btn`/`.empty-hint` 样式**随组件移入** `BroadcastTargetSelector.svelte` 的 `<style>`（这些 class 在该组件 DOM 内使用，scoped 正常生效）；EditPane 保留 `.session-panel`/`.panel-header`/`.broadcast-btn` 等宿主专属样式。(b) 若两边都要用同一 class，用 `:global(...)` 包裹——但本阶段 (a) 已足够（EditPane 改造后不再直接渲染 `.session-item`，而是经 `<BroadcastTargetSelector>`）。
**Warning signs:** 抽取后 EditPane 的列表样式崩 → 确认是否漏移了某个 class 或误用了 `:global`。

### Pitfall 5: 类型图标字映射漏了新 TabType
**What goes wrong:** 类型图标字逻辑（`s.type === "local" ? "$" : s.type === "serial" ? "⎓" : s.type === "telnet" ? "T" : "SSH"`）硬编码在 EditPane，抽取时照抄。
**Why it happens:** `TabType` 是 `"home" | "ssh" | "local" | "serial" | "telnet" | "forward" | "edit"`（`[VERIFIED: codebase app.svelte.ts:16]`）。但 `connectedSessions()` 只含连接的终端类型（ssh/local/serial/telnet），home/forward/edit 不会出现，故现有三元逻辑对列表数据安全。
**How to avoid:** 照抄 EditPane 的三元即可（已覆盖 4 种终端类型）；不要为"补全所有 TabType"过度泛化（YAGNI）。若想防漂移，抽成一个纯函数 `terminalTypeIcon(type): string` 放纯逻辑模块并配单测——但非本阶段必须。
**Warning signs:** 无；现有逻辑对 `connectedSessions()` 数据是完备的。

### Pitfall 6: 折叠条的 `max-height` 过渡与 flex 布局挤压对话区
**What goes wrong:** 目标条展开/折叠时对话区跳动、或列表区把对话区挤没。
**Why it happens:** `.ai-side` 是固定 flex-basis 宽列（`[VERIFIED: codebase AppShell.svelte:1232]` `flex: 0 0 380px`），内部纵向排：toolbar + banner + 目标条 + chat。目标条吃高 = chat 减高。
**How to avoid:** 目标条列表区给 `max-height` 上限（UI-SPEC：`40vh`），`overflow-y: auto`；折叠态 `max-height: 0; opacity: 0; overflow: hidden`。目标条容器 `flex-shrink: 0`（像 `.toolbar`/`.banner` 一样不被压缩）。对话区 `.chat` 保持 `flex: 1; overflow-y: auto; min-height: 0`（R4 三件套）。
**Warning signs:** 展开目标条后对话区不可滚 / 列表无限长 → 查 max-height + overflow。

## Code Examples

以下模式均逐字摘自代码库运行中代码，`[VERIFIED: codebase]`。

### 开关按钮（镜像 DangerModeToggle trigger，换 accent）

```svelte
<!-- 来源：src/lib/ai/ChatPanel.svelte:287-300（DangerModeToggle trigger），改 color -->
<button class="btn-icon broadcast-toggle" class:on={broadcastOn}
        onclick={() => ai.toggleBroadcast(tabId)}
        title={broadcastOn ? t("ai.toolbar.broadcast_on_tip") : t("ai.toolbar.broadcast_enable")}
        aria-label={broadcastOn
            ? `${t("ai.toolbar.broadcast_aria")}, ${selectedCount}/${totalCount}`
            : t("ai.toolbar.broadcast_aria")}
        aria-pressed={broadcastOn}>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <!-- 发射塔/广播波：从 lucide.dev 复制 radio / radio-tower canonical path -->
        <path d="..."/>
    </svg>
    {#if broadcastOn && selectedCount > 0}
        <span class="badge" aria-hidden="true">{selectedCount}</span>
    {/if}
</button>
```

### 激活态样式（镜像 .danger-toggle.on，换 --accent）

```css
/* 来源：src/lib/ai/ChatPanel.svelte:480-487，--error → --accent */
.broadcast-toggle { position: relative; }  /* 给徽标 absolute 锚点 */
.broadcast-toggle.on {
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
}
.broadcast-toggle.on:hover {
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 22%, transparent);
}
/* 徽标（UI-SPEC §Token Grounding 锁定值） */
.broadcast-toggle .badge {
    position: absolute; bottom: -2px; right: -2px;
    min-width: 16px; height: 16px; padding: 0 4px;
    border-radius: 50%; background: var(--accent); color: var(--white);
    font-size: 10px; font-weight: 700; line-height: 1;
    border: 2px solid var(--bg);
    display: flex; align-items: center; justify-content: center;
}
```

### store mutator（整体替换 record + 重建 Set）

```typescript
// 来源模式：src/lib/components/EditPane.svelte:29-37（toggle/selectAll/selectAll 重建 Set）
//          + src/lib/ai/store.svelte.ts:286-289（rebindTarget 整体替换 record 条目）
export function toggleBroadcastTarget(tabId: string, targetTabId: string): void {
    const prev = _broadcastByTab[tabId] ?? DEFAULT_BROADCAST;
    const next = new Set(prev.targets);
    if (next.has(targetTabId)) next.delete(targetTabId);
    else next.add(targetTabId);
    _broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, targets: next } };
}

export function toggleBroadcast(tabId: string): void {
    const prev = _broadcastByTab[tabId] ?? DEFAULT_BROADCAST;
    _broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, enabled: !prev.enabled } };
}

export function pruneBroadcastTargets(tabId: string, activeTabIds: Set<string>): void {
    const prev = _broadcastByTab[tabId];
    if (!prev) return;
    const next = new Set([...prev.targets].filter(id => activeTabIds.has(id)));
    if (next.size === prev.targets.size) return;  // 无变化不触发
    _broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, targets: next } };
}
```

### prune `$effect`（ChatPanel 内，镜像 EditPane）

```svelte
<!-- 来源：src/lib/components/EditPane.svelte:23-27（EditPane prune $effect 原样） -->
<script>
    // ... ChatPanel 既有 imports ...
    let sessions = $derived(app.connectedSessions());
    $effect(() => {
        const activeIds = new Set(sessions.map(s => s.tabId));
        ai.pruneBroadcastTargets(tabId, activeIds);
    });
</script>
```

### stopSession 清理（既有 delete 簇加一行）

```typescript
// 来源：src/lib/ai/store.svelte.ts:255-260（既有 delete 簇），加最后一行
  delete _sessionByTab[tab_id];
  delete _pendingByTab[tab_id];
  delete _keyboardLockedByTab[tab_id];
  delete _targetKindByTab[tab_id];
  delete _chatByTab[tab_id];
  delete _tokensByTab[tab_id];
  delete _broadcastByTab[tab_id];   // ← 新增：主标签关闭，广播状态随之清
```

### i18n key（flat dotted-key 结构）

```typescript
// 来源结构：src/lib/i18n/locales/en.ts:1-20（flat 对象 + dotted key）
// en.ts 与 zh.ts 同步新增（UI-SPEC §Copywriting 表锁定文案）：
  "ai.toolbar.broadcast_enable": "Enable Broadcast Mode",
  "ai.toolbar.broadcast_on_tip": "Broadcast is ON — approved commands will sync to selected terminals",
  "ai.toolbar.broadcast_aria": "Broadcast mode",
  "ai.broadcast.title": "Broadcast Targets",
  "ai.broadcast.count": "{selected}/{total} targets",   // 带 {selected}/{total} 插值
  "ai.broadcast.empty": "No other terminals",
  "ai.broadcast.select_all": "All",
  "ai.broadcast.select_none": "None",
  "ai.broadcast.collapse": "Collapse target bar",
  "ai.broadcast.expand": "Expand target bar",
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Svelte 4 `on:click` / `$:` / `export let` | Svelte 5 runes（`onclick`/`$state`/`$derived`/`$props`） | Svelte 5 / 项目锁定 | R7：用旧语法 review 拒绝合并 |
| 组件内建全局状态 | `stores/*.svelte.ts` 私有 `_x = $state` + getter 导出 | 项目 R8 | 广播状态必须进 `ai/store.svelte.ts`，不进组件 |
| 各终端 transport 各自 invoke | `broadcastToSessions` 统一走各 pane 的 `sendText` | 既有（app.svelte.ts:466） | Phase 2 分发复用它，Phase 1 只铺路 |

**Deprecated/outdated:**
- Svelte 4 语法（`on:click`/`$:`/`export let`）在本项目 review 即拒（R7）。
- 任何"在 ChatPanel 组件内用模块外全局变量管广播状态"——违反 R8。

## Assumptions Log

> 本阶段几乎所有 claim 都 `[VERIFIED: codebase]`（代码库是权威来源）。以下为需用户/planner 留意的低置信假设。

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | hover 预览（`SessionPreviewPopover`）在 ChatPanel 目标条里**可选**（UI-SPEC 未强制保留） | Architecture Patterns §Pattern 1 | 若需保留，ChatPanel 要复制 EditPane 的 `hoveredTabId`/`hoverAnchor` 本地 `$state` + popover 渲染；不影响核心状态逻辑 |
| A2 | 广播图标采用 lucide `radio` / `radio-tower` canonical SVG path（手绘复制，不装包） | UI-SPEC §Design System | 具体选哪个形由实现时定；`[ASSUMED]` 路径需从 lucide.dev 现取（本 research 未抓取具体 path d 值，planner 应在实现时从 lucide.dev 复制） |
| A3 | `connectedSessions()` 返回的 `type` 字段恒为 `"ssh"\|"local"\|"serial"\|"telnet"`（不含 home/forward/edit） | Code Examples §类型图标 | `[VERIFIED: codebase app.svelte.ts:406-413]` SessionEntry.type 定义即此四值；安全 |

**Note:** A2 是唯一真正的 `[ASSUMED]`（具体 SVG path 值）。其余 claim 经代码库 grep/read 确认为 `[VERIFIED: codebase]`。本阶段无 `[VERIFIED: npm registry]` / `[CITED: docs]` 标签——因为没有外部库/文档需要查，代码库自身即权威。

## Open Questions (RESOLVED)

1. **ChatPanel 目标条是否保留 hover 预览（SessionPreviewPopover）？**
   - What we know: EditPane 有 hover 预览；UI-SPEC 未明确要求/禁止 ChatPanel 目标条保留它。
   - What's unclear: AI 面板宽度（380px）比 EditPane 右栏（200px）宽，popover 锚点空间足够，但增加了组件复杂度。
   - Recommendation: planner 可作为 Claude's Discretion 项——首版可不带 hover 预览（减复杂度），后续按需加。不阻塞核心状态逻辑。
   - → RESOLVED: ChatPanel 首版不带 hover；EditPane 既有 hover 通过 01-01 Task2 新增的 onHover/onHoverLeave 可选 prop 保留（见 W2 修订）。

2. **lucide `radio` vs `radio-tower` 具体图标形？**
   - What we know: UI-SPEC D-07 倾向"发射塔/广播波"，从 lucide 取形。
   - What's unclear: `radio`（弧形波）与 `radio-tower`（塔形）哪个更贴。
   - Recommendation: 实现时从 lucide.dev 复制其一的 canonical path；两者都符合 stroke 风格统一要求。不阻塞规划。
   - → RESOLVED: 选 lucide radio 形（01-02 Task1 step C 实现时从 lucide.dev 复制 canonical path）。

3. **store mutator 是否需要单测？**
   - What we know: 项目有 `src/**/*.test.ts` 单测约定；`nyquist_validation: false`（config.json）表示不强制 Validation Architecture 节。
   - What's unclear: planner 是否为 `_broadcastByTab` mutator 写纯逻辑单测（Set 重建、prune 剔除）。
   - Recommendation: mutator 是纯函数逻辑（尤其 prune 的差集计算），配单测成本低、收益高；planner 可选加 `store.broadcast.test.ts`。非阻塞。
   - → RESOLVED: 不加单测（workflow.nyquist_validation=false；prune 差集为纯逻辑，非阻塞，后续可选补 store.broadcast.test.ts）。

## Environment Availability

> Step 2.6: SKIPPED — 本阶段为纯前端 Svelte 组件 + 状态改动，无外部工具/服务/运行时/CLI/数据库依赖。所需 Node.js ≥ 20 + 既有 Vite/Vitest 工具链已在库（`package.json` + `package-lock.json` 提交）。无新增环境项。

## Security Domain

> `security_enforcement` 在 config.json 中缺省（默认 enabled）。但本阶段为**纯前端 in-memory UI 状态**：零 `invoke`、零网络、零 IPC、零 crypto、零持久化（不落 DB）、零 auth。UI-SPEC §Empty/Error States 明确"本阶段无错误态""本阶段无破坏性操作"。故绝大多数 ASVS 类别不适用。

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | 不涉及（无登录/auth 路径） |
| V3 Session Management | no | 不涉及（不动 AI session 生命周期，只加旁路 UI 状态） |
| V4 Access Control | no | 不涉及（无权限判定） |
| V5 Input Validation | no (边界) | 无用户自由文本输入；勾选/全选是枚举操作。i18n 文案静态。无注入面 |
| V6 Cryptography | no | 不涉及（in-memory 明文 tabId 集合，不加密、不落盘） |
| V7 Error/Logging | no | 本阶段无错误态、无 invoke 失败路径 |
| V8 Data Protection | no | 不持久化（in-memory，app 重启即失，v2 才持久化） |

### Known Threat Patterns for Svelte 5 frontend-only state

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 状态泄漏（关闭的 tab 残留 targets） | Information Disclosure（极低） | D-11 prune `$effect` + `stopSession` 清理（Pattern 4） |
| 误广播到 raw device | Tampering（Phase 1 不触发；Phase 2 才有分发） | D-06：Phase 1 照常列出但**不分发**（分发是 Phase 2）；v2 默认排除 |

**结论：** 本阶段安全面为零（纯 UI 状态，无执行、无网络、无持久化）。Raw device 安全默认排除明确属 **v2**（D-06 + REQUIREMENTS v2），本阶段按 D-06 照常列出且不可执行（Phase 2 才接 `broadcastToSessions`）。

## Sources

### Primary (HIGH confidence)
- **代码库自身**（本阶段权威来源，逐文件 grep/read 核对）：
  - `src/lib/components/EditPane.svelte` — 广播选择器 UX 源头（`.session-panel` 138-177、`.session-item.selected` halo 254-260、prune `$effect` 23-27、toggle/selectAll 重建 Set 29-37、`broadcast()` 49-54）
  - `src/lib/ai/store.svelte.ts` — per-tab 状态宿主（`_sessionByTab`/`_pendingByTab`/`_chatByTab` 52-55、`stopSession` delete 簇 255-260、rebindTarget 整体替换 record 286-289、`$state` 代理注释 715）
  - `src/lib/ai/ChatPanel.svelte` — 工具栏宿主（toolbar 246-302、`.btn-icon` 460-476、`.danger-toggle.on` 480-487、`.banner` 488-497、props tabId 16-20）
  - `src/lib/ai/DangerModeToggle.svelte` — toggle + snippet trigger + confirm modal 先例（trigger snippet 48、requestToggle 25-32）
  - `src/lib/components/AppShell.svelte` — ChatPanel 条件渲染（`{#if aiVisible && aiActiveTab && aiSessionId}` 1049、`tabId={aiActiveTab.id}` 1059、`.ai-side flex: 0 0 380px` 1232-1238）
  - `src/lib/stores/app.svelte.ts` — `connectedSessions()` 456、`broadcastToSessions()` 466、`SessionEntry/SessionInfo` 406-413、`closeTab`→`ai.stopSession` 224-245
  - `src/lib/components/SessionMinimap.svelte` — 缩略图组件（canvas paint、`readTerminalViewport`）
  - `src/lib/i18n/locales/en.ts` — flat dotted-key 结构（1-20）
  - `package.json` — `svelte ^5`、`vitest ^4.1.5`（12,34,37）
  - `.planning/config.json` — `nyquist_validation: false`（→ 跳过 Validation Architecture 节）

### Secondary (MEDIUM confidence)
- `01-CONTEXT.md` D-01..D-12 — 用户锁定决策（研究输入约束）
- `01-UI-SPEC.md` — 形式化设计契约（token 落地、状态机、discretion 锁定项）

### Tertiary (LOW confidence)
- 无（本阶段无仅 WebSearch 单源 claim；所有 claim 经代码库核对或源自锁定决策文档）

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 全部复用既有库，`package.json` 锁定，无新依赖
- Architecture (抽取 + 状态 + 插入点): HIGH — 逐文件逐行核对代码库运行中先例
- Pitfalls: HIGH — Set 反应性、`$effect` 上下文、unmount 生命周期、scoped 样式均经代码库证据确认
- Security: HIGH（适用面为零）— 纯前端 in-memory，无执行/网络/持久化

**Research date:** 2026-07-08
**Valid until:** 稳定期 30 天（代码库模式不随外部库版本漂移；若 Svelte 大版本升级或 EditPane/ChatPanel 结构重构则需复审）

---

*Phase: 1-Broadcast UI & State*
*Research completed: 2026-07-08*
