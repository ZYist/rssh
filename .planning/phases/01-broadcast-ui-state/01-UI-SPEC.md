---
phase: 1
slug: broadcast-ui-state
status: approved
shadcn_initialized: false
preset: none
created: 2026-07-08
reviewed_at: 2026-07-08
review_verdict: APPROVED (4 PASS, 2 FLAG non-blocking, 0 BLOCK)
review_flags: Typography (字重表格 500 vs prose 400/700 一致性); Spacing (6px padding 继承 EditPane 先例，非标准集)
---

# Phase 1 — UI Design Contract: Broadcast UI & State

> 广播模式 UI 与 per-tab 状态的视觉/交互契约。由 gsd-ui-researcher 生成，gsd-ui-checker 校验。
> 本契约**形式化** CONTEXT.md 的 12 条锁定决策（D-01..D-12），并补齐 CONTEXT 未覆盖的维度：design-token 落地、交互状态机、响应式、空/错误态、可访问性、动效。

**需求覆盖**: BCAST-01（工具栏开关）、BCAST-02（目标选择器列表）、BCAST-03（勾选/取消勾选）、BCAST-04（per-tab 状态持久化到 AI store）。
**范围锚点**: 本阶段**纯前端、纯状态**，不调用 `broadcastToSessions`、不动 Rust 后端、不引入审批/toast/持久化（均 Phase 2 或 v2）。

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none（Svelte 5 项目，不适用 shadcn gate） |
| Preset | not applicable |
| Component library | none（自研 Svelte 5 组件 + 手绘 SVG 图标） |
| Icon library | 手绘 stroke SVG（lucide/feather 风格）；本阶段新增"广播"图标取自 lucide `radio` / `radio-tower` 形 |
| Font | 系统栈：`-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif`（`global.css` html 规则，base 13px） |

> 本阶段不引入任何新依赖、新注册表、新字体。所有视觉资产复用 `src/styles/global.css` 既有 token 与 `src/lib/components/`、`src/lib/ai/` 既有组件。

---

## Spacing Scale

沿用 `global.css` 的 `--space-*`（均乘以 `--density`，cozy=1.0）。本阶段用到的值：

| Token | Value | 本阶段用法 |
|-------|-------|-------|
| `--space-1` | 4px | 图标内边距、徽章偏移、session-item 内 `gap` |
| `--space-2` | 8px | 工具栏 `gap`、目标条内边距纵向、select-actions `gap` |
| `--space-3` | 12px | 目标条左右内边距、EditPane `.session-panel` 内边距（既有） |
| `--space-4` | 16px | 空状态/placeholder 内边距（既有 `.placeholder`） |
| `--space-5` | 20px | —（本阶段不新增） |
| `--space-6` | 24px | —（本阶段不新增） |

**Exceptions**: 无。所有间距走 `--space-*` token，不写裸 px（`global.css` 内 `:root` 的 token 定义本身除外）。

---

## Typography

base 13px（`global.css` html）。本阶段涉及的字号/字重（全部来自既有先例，不新增字号挡位）：

| Role | Size | Weight | Line Height | 来源/用法 |
|------|------|--------|-------------|-----------|
| 目标条标题 | 13px | 700 | 1.2 | 复用 EditPane `.panel-header`；目标条顶部"广播目标"标题 |
| 计数 N/M | 12px | 500 | 1.2 | `--text-dim`，monospace 可选；标题右侧 |
| 目标项标签 | 12px | 400 | 1.4 | 复用 EditPane `.session-item` `font-size` |
| 类型图标字 | 10px | 700 | 1 | 复用 EditPane `.session-type`（SSH/`$`/`⎓`/`T`），`--accent` |
| 空状态提示 | 12px | 400 | 1.4 | 复用 EditPane `.empty-hint`，`--text-dim` |
| 全选/全不选链接 | 12px | 400 | 1 | 复用 EditPane `.link-btn`，`--accent` |
| 计数徽标 | 10px | 700 | 1 | `--white` on `--accent` |
| 工具栏 tooltip | 原生 | — | — | 走 `title=` 属性，浏览器默认 |

**字重挡位**：本阶段仅用 `400`（regular）与 `700`（bold），与既有面板一致；不引入 500/600 新挡位（计数 N/M 用 500 是既有 `.tokens` 风格的例外，已有先例）。

---

## Color

严格遵循 Pr3（禁裸 hex，走 token）。60/30/10 映射：

| Role | Token | Value | 本阶段用法 |
|------|-------|-------|-------|
| Dominant (60%) | `--bg` | #2B2D3A | AI 面板背景、目标条背景、session-item 默认背景 |
| Secondary (30%) | `--surface` | #32343F | session-item `:hover` 背景、输入态填充（既有） |
| Accent (10%) | `--accent` | #4A6CF7 | **见下方 reserved-for 清单** |
| Accent soft | `--accent-soft` | rgba(74,108,247,.15) | 选中项背景着色（与 `.session-item.selected` 的 `color-mix` 等价的预混值，二选一） |
| Text primary | `--text` | #E0E5EC | 标题、选中项标签 |
| Text sub | `--text-sub` | #A0A8BB | 未选中 session-item 标签 |
| Text dim | `--text-dim` | #6B7A99 | 计数 N/M、空状态、tooltip 副文本 |
| Divider | `--divider` | #3C3F50 | 目标条与工具栏/对话区的分隔线 |
| Destructive | `--error` | #E05555 | **本阶段禁用**（见下） |

**Accent (`--accent`) reserved-for 清单（穷举，不得挪用他处）**：
1. 广播开关按钮激活态（图标色 + 背景着色，D-08）
2. 计数徽标背景（`--accent` fill + `--white` 字）
3. 目标项选中态：边框 `--accent` + `box-shadow` 光晕（复用 `.session-item.selected` halo 语言）
4. 类型图标字色（SSH/`$`/`⎓`/`T`，复用 `.session-type`）
5. "全选/全不选"链接按钮字色（复用 `.link-btn`）
6. 焦点环（既有 `input:focus` 的 `border-color: var(--accent)` 先例）

**Destructive (`--error`) 本阶段不得用于广播任何状态**（D-08 锁定）：红色是 `DangerModeToggle` 的危险语义，广播是常规功能态。`--error` 仅在既有 danger toggle / banner 路径继续使用，本阶段不新增 `--error` 用法。

---

## Copywriting Contract

所有用户可见字符串经 `t()`，新 key 同步进 `src/lib/i18n/locales/en.ts` + `zh.ts`，命名空间 `ai.broadcast.*` 与 `ai.toolbar.broadcast_*`。

| Element | Key | en | zh |
|---------|-----|----|----|
| 工具栏开关 tooltip（OFF→启用） | `ai.toolbar.broadcast_enable` | Enable Broadcast Mode | 开启广播模式 |
| 工具栏开关 tooltip（ON→运行中） | `ai.toolbar.broadcast_on_tip` | Broadcast is ON — approved commands will sync to selected terminals | 广播已开启——批准的命令将同步到已选终端 |
| 工具栏开关 aria-label | `ai.toolbar.broadcast_aria` | Broadcast mode | 广播模式 |
| 目标条标题 | `ai.broadcast.title` | Broadcast Targets | 广播目标 |
| 计数格式 N/M | `ai.broadcast.count` | {selected}/{total} targets | {selected}/{total} 个目标 |
| 空状态（仅主标签） | `ai.broadcast.empty` | No other terminals | 没有其它终端 |
| 全选链接 | `ai.broadcast.select_all` | All | 全选 |
| 全不选链接 | `ai.broadcast.select_none` | None | 全不选 |
| 折叠按钮 aria-label | `ai.broadcast.collapse` | Collapse target bar | 收起目标栏 |
| 展开按钮 aria-label | `ai.broadcast.expand` | Expand target bar | 展开目标栏 |

**计数格式细节**：`N/M`，N=已选目标数，M=除主标签外的终端数。M=0 时显示空状态文案而非 `0/0`。`t("ai.broadcast.count", { selected, total })` 走既有 i18n 参数插值。

**空状态**：当 `app.connectedSessions()` 过滤掉主标签后为空（M=0），目标条显示标题 + `.empty-hint`（`ai.broadcast.empty`），隐藏"全选/全不选"链接与列表。开关按钮上的计数徽标隐藏（见 Badge 规则）。

**错误状态**：**本阶段无错误态**。Phase 1 是纯前端 in-memory 状态，无 `invoke`、无网络、无 IPC，不存在可失败操作。目标在中途被关闭由 D-11 prune 静默处理（不弹 toast、不报错——toast 反馈属 v2）。Phase 2 的分发错误（`broadcastToSessions` 失败）不在本阶段范围。

**破坏性操作**：**本阶段无破坏性操作**。开关切换、勾选/取消勾选、全选/全不选、折叠/展开均无确认弹窗（广播不是 `DangerModeToggle` 那样的脚枪，**不走 confirm modal**——与 D-04 一致：AI 面板的广播状态可自由切换）。关闭广播时已选目标集合**保留在 state 中**（不清空），下次开启恢复选择。

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable（Svelte 项目，无 shadcn） |
| 第三方注册表 | none | not applicable |

本阶段**不引入任何第三方注册表、block、依赖**。新增 SVG 图标手绘（取 lucide `radio` 形作参考，路径由实现时从 lucide.dev 复制 canonical path，**不**装 `lucide-svelte` 包）。

---

## Component Inventory（组件清单，供 planner 拆任务）

### 新增

**`src/lib/components/BroadcastTargetSelector.svelte`**（共享组件，D-01）
- 职责：渲染目标终端列表 + 全选/全不选链接。**受控组件**（props in、callbacks out），自身不持状态。
- Props（TypeScript）：
  ```ts
  let {
    sessions,          // SessionInfo[] — 已过滤掉主标签的列表（宿主负责过滤）
    selectedIds,       // Set<string> — 当前已选 tabId 集合
    onToggle,          // (tabId: string) => void
    onSelectAll,       // () => void
    onSelectNone,      // () => void
  }: {
    sessions: SessionInfo[];
    selectedIds: Set<string>;
    onToggle: (tabId: string) => void;
    onSelectAll: () => void;
    onSelectNone: () => void;
  } = $props();
  ```
- 渲染：`SessionMinimap` 缩略图 + 类型图标字（`SSH`/`$`/`⎓`/`T`，复用 EditPane 逻辑）+ 标签 + 选中 halo。空列表时渲染 `.empty-hint`（文案由宿主通过 prop 或 slot 传入；默认走 `ai.broadcast.empty`）。
- **不含**：标题行、折叠 chevron、`Broadcast(N)` 发送按钮（D-04，这些是宿主专属）。
- 复用：`SessionMinimap.svelte`、`.session-item` / `.session-item.selected` / `.link-btn` / `.select-actions` 样式（从 EditPane 抽到此组件或共享样式块）。

### 修改

**`src/lib/ai/ChatPanel.svelte`**（开关宿主 + 目标条宿主）
- 工具栏：在 `clear` 与 `DangerModeToggle` 之间插入广播开关 `.btn-icon.broadcast-toggle`（D-07 位置：紧邻 DangerModeToggle 左侧，两个 mode toggle 相邻；`close ×` 保持最右）。
- 工具栏下方：`.banner` 之后、`.chat` 之前插入可折叠目标条（D-02）。
- 读写广播状态经 `ai.*` getter/mutator（见下 store 改动），**不在组件内建全局状态**（R8）。

**`src/lib/components/EditPane.svelte`**（改造为消费共享组件）
- 把 `.session-list` + `.select-actions` 部分替换为 `<BroadcastTargetSelector>`，保留：`.panel-header`、`Broadcast(N)` 按钮、`pickBroadcastText` / `broadcast()` 立即发送逻辑、hover popover。
- `selectedTabIds` 仍是 EditPane 本地 `$state`（EditPane 的选择不进 AI store，它是编辑器一次性发送语义，与 AI 广播状态不同寿命）。

**`src/lib/ai/store.svelte.ts`**（广播状态宿主，D-10）
- 新增私有 state（沿 `_xByTab` 先例）：
  ```ts
  interface BroadcastState {
      enabled: boolean;        // 开关 on/off
      barCollapsed: boolean;   // 目标条折叠/展开（仅 enabled=true 时有意义）
      targets: Set<string>;    // 已选目标 tabId 集合
  }
  let _broadcastByTab = $state<Record<string, BroadcastState>>({});
  ```
- 新增 getter/mutator（getter 动词短语、无 `get` 前缀，沿命名规范）：
  - `broadcastState(tabId): BroadcastState` — 返回该 tab 的广播状态（不存在则返回默认 `{ enabled: false, barCollapsed: false, targets: new Set() }`）。
  - `broadcastEnabled(tabId): boolean` — 便捷 getter。
  - `broadcastTargets(tabId): Set<string>` — 便捷 getter（Phase 2 分发时读它传给 `broadcastToSessions`）。
  - `toggleBroadcast(tabId): void` — 翻转 enabled。
  - `setBroadcastBarCollapsed(tabId, collapsed): void` — 折叠/展开。
  - `toggleBroadcastTarget(tabId, targetTabId): void` — 勾选/取消单个目标。
  - `setBroadcastTargets(tabId, ids: Set<string>): void` — 全选/全不选。
  - `clearBroadcastState(tabId): void` — tab 关闭时清理（防泄漏，D-11 协同）。
- **响应性**：所有 mutator 必须**整体替换** record 条目（`_broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, ...patch } }`），因 `Set`/对象嵌套字段需重新赋值才触发 Svelte 5 runes 反应（沿 EditPane `selectedTabIds = new Set(...)` 重新赋值先例）。
- **prune（D-11）**：在 store 内或 ChatPanel 内用 `$effect` 跟踪 `app.connectedSessions()`，剔除 `targets` 中已不存在的 tabId。**推荐放 store**（一处 prune，所有宿主受益），通过导出的 `pruneBroadcastTargets(tabId, activeTabIds: Set<string>): void` 由宿主 `$effect` 调用。

**`src/lib/i18n/locales/en.ts` + `zh.ts`** — 同步新增 `ai.broadcast.*` 与 `ai.toolbar.broadcast_*` 全部 key（见 Copywriting 表）。

---

## Design Token Grounding（token 落地清单）

| 元素 | 落地 token |
|------|-----------|
| 广播开关按钮（默认） | 复用 ChatPanel 局部 `.btn-icon`：`background: transparent; color: var(--text); padding: 4px 6px; border-radius: 4px` |
| 广播开关按钮（激活，D-08） | `.broadcast-toggle.on`：`color: var(--accent); background: color-mix(in srgb, var(--accent) 14%, transparent)`；`:hover` 升到 `22%`（**镜像 `.danger-toggle.on` 但把 `--error` 换成 `--accent`**） |
| 广播开关图标 SVG | `width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"`（与 audit/clear/danger 完全一致） |
| 计数徽标（D-09） | `position: absolute; bottom: -2px; right: -2px; min-width: 16px; height: 16px; padding: 0 4px; border-radius: 50%; background: var(--accent); color: var(--white); font-size: 10px; font-weight: 700; border: 2px solid var(--bg); display: flex; align-items: center; justify-content: center`；按钮需 `position: relative` |
| 徽标 0 值（D-09 discretion） | **隐藏**（`count === 0` 时不渲染徽标节点）。开关激活态（accent 着色）已足以表达"开"，徽标只在有目标时出现，避免视觉噪音 |
| 目标条容器 | `border-bottom: 1px solid var(--divider); background: var(--bg); flex-shrink: 0`（与 `.toolbar` / `.banner` 同一族） |
| 目标条标题 | `.panel-header` 既有：`font-size: 13px; font-weight: 700; color: var(--text)` |
| 计数 N/M | `font-size: 12px; color: var(--text-dim)` |
| 折叠 chevron | `color: var(--text-sub)`，16×16 stroke SVG（lucide `chevron-down` / `chevron-up`） |
| session-item 默认 | 复用 EditPane：`color: var(--text-sub); background: none; border: 1px solid transparent; border-radius: var(--radius-sm); padding: 6px` |
| session-item hover | `background: var(--surface); color: var(--text)` |
| session-item 选中（D-01 halo） | `color: var(--text); border-color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, transparent); box-shadow: 0 0 0 1px var(--accent), 0 0 12px -2px color-mix(in srgb, var(--accent) 65%, transparent)`（**逐字复用 `.session-item.selected`**） |
| 类型图标字 | `font-size: 10px; font-weight: 700; color: var(--accent)`（复用 `.session-type`） |
| 全选/全不选链接 | `color: var(--accent); font-size: 12px; background: none; border: none`（复用 `.link-btn`） |
| 空状态提示 | `font-size: 12px; color: var(--text-dim)`（复用 `.empty-hint`） |

---

## Interaction State Machines（交互状态机）

### 1. 广播开关按钮（toolbar toggle）

```
状态: OFF (默认)  ←—————— click ————————  ON
  │                                            │
  │ click                                      │ click
  ↓                                            ↓
  ON  ——— click ——→ OFF (保留 targets 集合)    OFF
```

| 当前态 | 事件 | 次态 | 副作用 |
|--------|------|------|--------|
| OFF | click | ON | `toggleBroadcast(tabId)`；目标条展开（首次开启默认 `barCollapsed=false`，见 Discretion 决定） |
| ON | click | OFF | `toggleBroadcast(tabId)`；目标条整体不渲染；**targets 集合不清空**（再开启恢复） |
| 任一 | hover | — | `:hover` 着色（默认态 neutral，激活态 accent 22%） |

- **aria-pressed**：`aria-pressed={broadcastEnabled(tabId)}`（镜像 danger toggle）。
- **aria-label**：动态——OFF 时 `t("ai.toolbar.broadcast_aria")`；ON 时 `${t("ai.toolbar.broadcast_aria")}, ${selected}/${total}`（含计数，供 SR 用户在折叠态获知选择数）。
- **title**：OFF→`ai.toolbar.broadcast_enable`；ON→`ai.toolbar.broadcast_on_tip`。
- **disabled**：**永不 disabled**（广播是 per-tab 配置，session 启动前后均可设；类比 danger toggle 不设 `disabled={!session}`）。
- **无 confirm modal**：广播不是脚枪，开关即切（与 D-04 一致，区别于 DangerModeToggle 的启用确认流）。

### 2. 目标条展开/折叠（D-03）

| 当前态 | 事件 | 次态 | 副作用 |
|--------|------|------|--------|
| 展开 | 点折叠 chevron | 折叠 | `setBroadcastBarCollapsed(tabId, true)`；列表区不渲染，仅留标题行 + N/M + 展开-chevron |
| 折叠 | 点展开 chevron | 展开 | `setBroadcastBarCollapsed(tabId, false)` |
| 折叠/展开 | 关闭广播 | — | 整条不渲染（折叠态随广播关闭失去意义，但 state 保留） |

- **折叠态视觉**（Discretion 决定）：折叠**不是**整条消失，而是**收起列表区**，保留单行标题条（标题 + N/M + 展开-chevron，约 32px 高）。理由：(a) 保留"再展开"的入口 affordance；(b) "腾出对话区"达成（列表是占高的部分）；(c) 工具栏徽标仍是主 at-a-glance 反馈，标题条 N/M 是辅助。注：CONTEXT.md D-03 措辞"计数徽章是唯一状态反馈"——本契约将其理解为"折叠后丢失 per-target 细节，仅剩计数这一汇总信息"，故保留极简标题条不违背其精神。
- **chevron aria**：`aria-expanded={!collapsed}` + `aria-controls={barContentId}` + `aria-label`（collapse/expand key）。
- **首次开启默认**（Discretion 决定）：**展开**。用户首次开启广播需看到列表才能选目标；之后折叠态 per-tab 持久化（in-memory）。

### 3. 目标勾选/取消勾选（D-12）

| 事件 | 行为 |
|------|------|
| 点未选 session-item | `toggleBroadcastTarget(tabId, targetTabId)` → 加入 targets |
| 点已选 session-item | 同上 → 移出 targets |
| 点"全选" | `setBroadcastTargets(tabId, new Set(所有非主标签终端的 tabId))` |
| 点"全不选" | `setBroadcastTargets(tabId, new Set())` |
| 新终端 tab 被打开 | **不自动勾选**（D-12），仅出现在列表中；用户主动勾 |
| 已选目标 tab 被关闭 | prune `$effect` 自动剔除该 tabId（D-11）；计数随之更新 |

- **session-item aria**：`aria-pressed={selectedIds.has(s.tabId)}`（复用 EditPane）。
- **键盘**：session-item 是 `<button type="button">`，Tab 键顺序遍历，Enter/Space 触发 toggle（原生 button 行为）。

### 4. 焦点顺序（tabbing）

广播 ON 且目标条展开时，AI 面板内 Tab 序列：
1. 工具栏各按钮（model 不可聚焦 → tokens 不可聚焦 → audit → clear → **broadcast-toggle** → danger-toggle → close）
2. 目标条：折叠 chevron → 全选链接 → 全不选链接 → session-item（自上而下）
3. 对话区 / 输入框

广播 OFF 或折叠时，跳过对应区域。

---

## Responsive Behavior（响应式）

遵循 R9/P7（`app.isMobile` 一次性 UA 嗅探，不响应 resize）。

| 场景 | 行为 |
|------|------|
| 桌面（`!isMobile`） | AI 面板 `.ai-side` 默认 380px、可拖拽、min 280（`AI_PANEL_MIN_WIDTH`）。目标条占面板全宽，列表区 `overflow-y: auto; max-height` 建议 `40vh` 上限避免吃满对话区 |
| 移动（`isMobile`） | AI 面板 full-width takeover（`.ai-side { flex: 1 }`）。目标条仍渲染于工具栏下方；列表区 `max-height: 40vh`（移动屏高有限，硬上限防吃满）；不可拖拽宽度（触屏） |
| 三平台（R10） | 桌面 GUI / 移动 GUI / JetBrains JCEF（浏览器态经 ipc-shim）三者前端代码同源，目标条逻辑无平台分支；仅 `app.isMobile` 影响 `max-height`。CLI 无 AI 面板，不涉及 |

**主标签过滤（D-05）**：选择器数据源 = `app.connectedSessions().filter(s => s.tabId !== primaryTabId)`，其中 `primaryTabId` = ChatPanel 的 `tabId` prop（承载 AI 面板的标签）。计数 M = 过滤后长度。

---

## Empty / Error States

| 状态 | 触发 | 表现 |
|------|------|------|
| 空状态（无其它终端） | M=0（仅主标签存在或无其它连接终端） | 目标条显示标题 + `.empty-hint`（`ai.broadcast.empty` = "没有其它终端"）；隐藏列表、全选/全不选；徽标隐藏；开关仍可关闭 |
| 选择中途全被关 | 选中目标 tab 全部关闭 | prune `$effect` 剔除；计数降到 0；若 M 仍 >0 则列表显示剩余项，若 M=0 则转空状态；无 toast（v2） |
| 错误态 | — | **本阶段无**（纯前端状态，无可失败操作） |

---

## Accessibility（可访问性）

| 元素 | aria/语义 |
|------|----------|
| 广播开关按钮 | `role="button"`（隐式）；`aria-pressed={enabled}`；动态 `aria-label`（ON 含计数）；`title` |
| 计数徽标 | `aria-hidden="true"`（装饰性；计数已通过按钮 `aria-label` 与目标条 N/M 传达，避免 SR 重复读） |
| 目标条容器 | `role="group"`；`aria-labelledby` 指向标题 id |
| 折叠 chevron | `aria-expanded`；`aria-controls`；`aria-label`（collapse/expand） |
| session-item | `<button type="button" aria-pressed={selected}>`；`title={label}` |
| 全选/全不选 | `<button type="button">`，`aria-label` 可选（文本已自解释） |
| 焦点环 | 走既有 `:focus` → `border-color: var(--accent)` / 浏览器默认 outline；不抑制 |
| 色对比 | accent #4A6CF7 on `--bg` #2B2D3A 满足 WCAG AA（激活态字图对比度 > 4.5:1 经 `--text`/`--white` 保证） |

**不依赖仅颜色传达信息**：开关状态除 accent 着色外，还有 `aria-pressed` + tooltip 文案 + 徽标计数；选中态除 halo 外还有 `aria-pressed` + 类型图标字色。

---

## Motion（动效）

代码库**不用 `svelte/transition`**（全局 grep 无命中），统一 CSS `transition`。本阶段遵循同族节奏：

| 元素 | transition |
|------|-----------|
| 开关按钮着色（hover / 激活） | `transition: background 0.13s, color 0.13s`（对齐 `.btn-icon` 既有节奏） |
| session-item（hover / 选中） | `transition: background 0.1s, border-color 0.1s, box-shadow 0.1s`（逐字复用 `.session-item`） |
| 目标条展开/折叠 | 折叠时列表区 `max-height: 0; opacity: 0; overflow: hidden; transition: max-height 0.15s ease, opacity 0.15s ease`；展开 `max-height: <cap>; opacity: 1`。cap 用 `40vh`（响应式一致） |
| 目标条整体出现（广播 ON） | 简单条件渲染 + 可选 `opacity 0→1` 淡入 `0.15s`（与 `.banner` 出现节奏一致；非必须，实现可省略以匹配 banner 的无动效直接出现） |

**遵守 `prefers-reduced-motion`**：若全局已处理则随动；本契约不新增独立 reduced-motion 分支（动效均 ≤0.15s 且非必要，风险低）。

---

## Discretion 决定（CONTEXT.md 留给 researcher 的项，此处锁定）

| 项 | 决定 | 理由 |
|----|------|------|
| state 字段形状 | `{ enabled, barCollapsed, targets: Set }` 单 record，按 tabId 索引于 `_broadcastByTab` | 沿 `_sessionByTab` / `_pendingByTab` 先例；广播三字段同寿命，合放一个 record |
| 空状态文案 | `ai.broadcast.empty` = "没有其它终端" / "No other terminals" | 与 EditPane `.empty-hint` 语气一致，明确指向"除主标签外" |
| tooltip 文案 | 见 Copywriting 表（enable / on_tip / aria） | ON 态 tooltip 说明"批准的命令将同步"，预告 Phase 2 语义但不越界 |
| 徽标 0 值视觉 | **隐藏**（不渲染） | 激活态 accent 着色已表"开"；0 目标时徽标多余 |
| 开关在工具栏位置 | `clear` 与 `DangerModeToggle` 之间（紧邻 danger 左侧） | 两个 mode toggle 相邻成组；`close ×` 保持最右 |
| 折叠条默认初始态 | 首次开启广播 = **展开** | 用户需看到列表才能选目标；折叠态随后 per-tab 持久化 |
| 折叠机制 | 折叠 = 收起列表区，保留单行标题条（标题 + N/M + chevron） | 保留再展开 affordance；"腾出对话区"达成 |
| 共享组件边界 | `BroadcastTargetSelector` = 列表 + 全选/全不选（受控）；**不含**标题、chevron、Broadcast(N) 按钮 | EditPane 需保留自己的标题 + 立即发送按钮；ChatPanel 需加自己的标题 + 折叠 chevron |

---

## Requirement Traceability

| REQ-ID | 契约落地处 |
|--------|-----------|
| BCAST-01（工具栏开关） | Component Inventory §ChatPanel + State Machine §1 + Token Grounding §开关按钮 |
| BCAST-02（开启后显示选择器列表） | Component Inventory §BroadcastTargetSelector + State Machine §1（ON→展开）+ Responsive §主标签过滤 |
| BCAST-03（勾选/取消勾选） | State Machine §3 + Token Grounding §session-item 选中 |
| BCAST-04（per-tab 状态存 AI store） | Component Inventory §store.svelte.ts + Discretion §state 字段形状 |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS（全部可见字符串经 `t()`，en/zh 双语 key 列齐）
- [ ] Dimension 2 Visuals: PASS（组件清单 + token 落地 + 状态机穷举）
- [ ] Dimension 3 Color: PASS（60/30/10 映射，accent reserved-for 穷举，--error 明确禁用）
- [ ] Dimension 4 Typography: PASS（仅 400/700 两挡，字号来自既有先例）
- [ ] Dimension 5 Spacing: PASS（全走 `--space-*`，无裸 px）
- [ ] Dimension 6 Registry Safety: PASS（无第三方注册表/依赖）

**Approval:** pending

---

*Phase: 1-Broadcast UI & State*
*UI-SPEC drafted: 2026-07-08*
*Locked decisions formalized: D-01..D-12 (from 01-CONTEXT.md)*
