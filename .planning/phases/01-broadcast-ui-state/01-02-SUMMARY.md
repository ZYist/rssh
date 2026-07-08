---
phase: 01-broadcast-ui-state
plan: "02"
subsystem: ui
tags: [svelte5, runes, chatpanel, toolbar-toggle, collapsible-bar, i18n-bilingual]

requires:
  - phase: 01-broadcast-ui-state (CONTEXT/RESEARCH/PATTERNS/UI-SPEC 锁定决策 + 01-01 store/selector 产物)
    provides: D-01..D-12 锁定决策、ai/store 广播 mutator/getter 契约、BroadcastTargetSelector 受控组件
provides:
  - ChatPanel 工具栏广播开关（accent 激活态 + 目标计数徽标）+ 可折叠目标条 + D-11 prune $effect
  - en.ts/zh.ts 10 个 ai.toolbar.broadcast_* / ai.broadcast.* 双语 i18n key
affects: [broadcast-dispatch, chat-panel-broadcast-toggle]

tech-stack:
  added: []  # 零新依赖（D-07 手绘 SVG，不装 lucide-svelte）
  patterns:
    - "宿主组件 $effect 调 store mutator 完成 prune（store 零 reactive-effect 不变量保持，Pitfall 2 合规）"
    - "{#if broadcastOn} 整条不渲染 = broadcast-OFF 像素一致性的实现手段（兼容性全局约束）"
    - "镜像 .danger-toggle.on 但 --error 全换 --accent = accent-not-red 视觉区分（D-08）"

key-files:
  created: []
  modified:
    - src/lib/ai/ChatPanel.svelte
    - src/lib/i18n/locales/en.ts
    - src/lib/i18n/locales/zh.ts

key-decisions:
  - "广播开关在工具栏 clear 与 DangerModeToggle 之间（D-07 位置），两 mode toggle 相邻成组，close × 保持最右"
  - "目标条折叠 = 收起列表区，保留单行标题条（标题 + N/M 计数 + chevron），保留再展开 affordance"
  - "lucide radio 图标 path 逐字复制（4 arcs + 中心圆点），零依赖，currentColor stroke-width=2 与既有工具栏图标等重"
  - "BroadcastTargetSelector 在 ChatPanel 不传 onHover/onHoverLeave（Q1 RESOLVED，AI 面板天然无 hover）"
  - "aria-label ON 态含 ${selectedCount}/${totalCount} 计数（UI-SPEC §A11y），折叠时 SR 用户仍能获知选择数"

patterns-established:
  - "宿主 $derived sessions 过滤主标签（D-05）+ prune $effect 跟踪 sessions 变化调 store mutator"
  - "受控组件 selectedIds 只读契约：bState.targets 作 selectedIds 注入，变更经 onToggle/onSelectAll/onSelectNone 委托 ai.* mutator"

requirements-completed:
  - BCAST-01
  - BCAST-02
  - BCAST-03
  - BCAST-04

coverage:
  - id: D4
    description: "ChatPanel 工具栏广播开关（D-07 位置 / D-08 accent / D-09 徽标），ON/OFF 切换 + aria-pressed/title/aria-label（BCAST-01）"
    requirement: BCAST-01
    verification:
      - kind: integration
        ref: "npm run build (EXIT=0, 314 modules) + grep 守门：broadcast-toggle×5, class:on={broadcastOn}×1, aria-pressed={broadcastOn}×1"
        status: pass
      - kind: type
        ref: "npx tsc --noEmit (EXIT=0)"
        status: pass
    human_judgment: true
    rationale: "开关激活态 accent 视觉（D-08）最终需人工在桌面 GUI 点击开关确认着色与徽标渲染；自动化无法证伪像素表现。"
  - id: D5
    description: "广播 ON 时可折叠目标条出现，列出除主标签外所有已连接终端（D-05 过滤），可勾选/取消勾选（BCAST-02/03）"
    requirement: BCAST-02
    verification:
      - kind: integration
        ref: "npm run build (EXIT=0) + grep 守门：broadcast-bar×2, app.connectedSessions().filter(s => s.tabId !== tabId)×1, BroadcastTargetSelector×2"
        status: pass
    human_judgment: true
    rationale: "目标列表 + 选中 halo + 全选/全不选交互需人工在 GUI 实际勾选确认；自动化编译/类型无法证伪运行期 DOM 交互。"
  - id: D6
    description: "per-tab 状态持久化于 ai store（Plan 01-01），切 tab / 关重开 AI 面板保持（BCAST-04）"
    requirement: BCAST-04
    verification:
      - kind: integration
        ref: "npm test --run (391/391 passed 零回归) — Plan 01-01 store 用例覆盖；ChatPanel 仅读快照委托 mutator"
        status: pass
    human_judgment: true
    rationale: "切 tab / 关重开面板后状态保持需人工在 GUI 实际切换确认（模块级 _broadcastByTab 存活，非组件本地）。"
  - id: D7
    description: "已选目标 tab 关闭自动 prune（D-11）；广播 OFF 整条不渲染（兼容性约束）；en/zh 10 key 双语 lockstep"
    requirement: BCAST-04
    verification:
      - kind: integration
        ref: "grep: ai.pruneBroadcastTargets(tabId×1, \$effect×5; diff en/zh broadcast key set 空 (lockstep)"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-07-08
status: complete
---

# Phase 01 Plan 02: ChatPanel 广播开关 + 可折叠目标条 + 双语 i18n Summary

**在 ChatPanel 工具栏插入广播开关（accent 激活态 + 目标计数徽标）与可折叠目标条，接线 ai store 的 per-tab 广播状态（Plan 01-01 已就位），补 D-11 prune $effect 与 en/zh 10 个 i18n key —— Phase 1 全部 4 条 Success Criteria 达成，广播 OFF 时 ChatPanel 与改造前像素一致**

## Performance

- **Duration:** 约 4 分钟
- **Started:** 2026-07-08T12:34:56Z
- **Completed:** 2026-07-08T12:39:22Z
- **Tasks:** 2
- **Files modified:** 3（ChatPanel.svelte + en.ts + zh.ts）

## Accomplishments

- 在 `src/lib/ai/ChatPanel.svelte` 工具栏 clear 与 DangerModeToggle 之间新增 `.btn-icon.broadcast-toggle` 开关：lucide `radio` 图标（4 arcs + 中心圆点，16×16 stroke SVG，currentColor）+ `class:on={broadcastOn}` accent 激活态（D-08，`.broadcast-toggle.on` 逐字镜像 `.danger-toggle.on` 但 `--error` 全换 `--accent`）+ 右下角 `.badge` 目标计数徽标（D-09，`broadcastOn && selectedCount > 0` 时渲染，0 隐藏）+ 动态 `aria-label`（ON 含 `${selectedCount}/${totalCount}`）+ `aria-pressed` + title 双态文案。
- 在 `.banner` 之后、`{#if auditOpen && session}` 之前新增 `.broadcast-bar` 可折叠目标条：`{#if broadcastOn}` 整条条件渲染（广播 OFF 不渲染，兼容性约束）；标题条（chevron + 标题 + N/M 计数，可点折叠）+ 列表区（`{#if !bState.barCollapsed}`）内嵌 `BroadcastTargetSelector` 受控组件，`sessions={app.connectedSessions().filter(s => s.tabId !== tabId)}`（D-05 主标签过滤）、`selectedIds={bState.targets}` 只读注入、`onToggle/onSelectAll/onSelectNone` 委托 `ai.*` mutator。
- 新增 prune `$effect`（组件 init 上下文，D-11）：跟踪 `sessions` 变化，调 `ai.pruneBroadcastTargets(tabId, activeIds)` 剔除已关闭的目标 tabId；store 零 reactive-effect 不变量保持（Pitfall 2 合规），面板关闭 effect 销毁但状态在模块级 store 存活、重开重生（Pitfall 3 合规）。
- 新增 5 个本地 `$derived`（`bState/broadcastOn/selectedCount/sessions/totalCount`）+ 2 个 imports（`app` store、`BroadcastTargetSelector`）。
- 新增 CSS：`.broadcast-toggle`/`.on`/`.on:hover`/`.badge`（accent 镜像 + 徽标 absolute 锚点）+ `.broadcast-bar`/`.bar-header`/`.bar-title`/`.bar-count`/`.bar-list`（`max-height: 40vh` 防吃满对话区，Pitfall 6）+ `.chevron`/`.chevron.rotated`（折叠旋转 -90°，transition 0.15s）；全部走 design token（Pr3），`--error` 负向 grep 确保不出现在任何 `.broadcast-` 规则（D-08）。
- `src/lib/i18n/locales/en.ts` + `zh.ts` 同步新增 10 个 key（双语 lockstep）：3 个 `ai.toolbar.broadcast_*`（enable/on_tip/aria）+ 7 个 `ai.broadcast.*`（title/count/empty/select_all/select_none/collapse/expand），文案逐字取自 UI-SPEC §Copywriting Contract 锁定表，`{selected}/{total}` 插值沿用 `tokens_tip` 的 `{tin}/{tout}` 语法。
- 全量验证通过：`npx tsc --noEmit` EXIT=0；`npm run build` EXIT=0（314 模块编译通过）；`npm test --run` 391/391 passed（零回归 Wave 1）。

## Task Commits

每个 task 原子提交：

1. **Task 1: ChatPanel 广播开关 + 可折叠目标条 + prune $effect + CSS** — `ed9e41f` (feat)
2. **Task 2: en.ts + zh.ts 同步 10 个广播 i18n key** — `f2290fc` (feat)

**Plan metadata:** 待追加（docs: complete plan）

## Files Created/Modified

- `src/lib/ai/ChatPanel.svelte` — 新增 imports（app store + BroadcastTargetSelector）+ 5 个 $derived + prune $effect + 工具栏 `.broadcast-toggle` 开关（accent 激活 + 徽标）+ `.broadcast-bar` 可折叠目标条 + 配套 CSS
- `src/lib/i18n/locales/en.ts` — 新增 10 个 ai.toolbar.broadcast_* / ai.broadcast.* key（en 文案）
- `src/lib/i18n/locales/zh.ts` — 同步 10 个同 key（zh 文案，双语 lockstep）

## Decisions Made

- **lucide radio 图标 path 逐字复制**：从 lucide.dev 取 `radio` 图标的 canonical path（`M4.9 19.1C1 15.2...` 四弧 + `circle cx="12" cy="12" r="2"`），保持 `stroke-width=2`/`currentColor`/`stroke-linecap=round` 与既有 audit/clear/danger 工具栏图标视觉等重；不装 `lucide-svelte` 包（零新依赖，A2 ASSUMED 兑现）。
- **目标条折叠 = 收起列表区，保留标题条**（UI-SPEC §Discretion 锁定）：折叠时单行标题条（chevron + 标题 + N/M + 展开 affordance）仍显示，仅列表区 `{#if !bState.barCollapsed}` 不渲染；chevron 旋转 -90° 作折叠视觉提示。
- **`bar-count` 用 `margin-left: auto`** 右对齐：标题条 flex 布局下，计数靠右与既有 `.tokens` 工具栏右对齐节奏一致；无需额外 spacer。
- **键盘可达性**：`.bar-header` 加 `role="button" tabindex="0"` + `onkeydown` Enter/Space 处理（`e.preventDefault()` 防 Space 滚屏），`aria-expanded={!bState.barCollapsed}`；`.bar-header:focus-visible` 走 `--accent` outline 环。

## Deviations from Plan

None — 计划执行顺畅。所有 acceptance grep 守门首次达标，tsc/build/test 三件套首次全绿，无返工、无自动修复触发。

## Issues Encountered

None。

## User Setup Required

None — 纯前端 in-memory UI 接线 + 静态 i18n 文案，零外部服务、零环境变量、零 IPC、零新依赖。

## Next Phase Readiness

**Phase 1（broadcast-ui-state）全部完成。** 4 条 Success Criteria 达成：
- BCAST-01：工具栏广播开关可 on/off（accent 激活态 + 徽标）。
- BCAST-02：ON 时目标条出现，列出除主标签外所有已连接终端（D-05 过滤）。
- BCAST-03：可勾选/取消勾选，选中 accent halo（复用 BroadcastTargetSelector）。
- BCAST-04：per-tab 状态持久化于 ai store `_broadcastByTab`，切 tab / 关重开面板保持。

**Phase 2（broadcast-dispatch）的就绪面：**
- **state 层已就位**：`ai.broadcastTargets(tabId)` 返回 `Set<string>`，Phase 2 审批时直接传给 `app.broadcastToSessions(tabIds, rawCmd)`（PROJECT 锁定：raw cmd、复用 broadcastToSessions、审批跟随 danger_mode）。
- **UI 层已就位**：开关 + 目标选择完整可用；Phase 2 只需在 `executeCommand` 审批路径接广播分发，不需改 ChatPanel/selector。
- **prune 双路径**：目标 tab 关闭（D-11，ChatPanel `$effect` → `pruneBroadcastTargets`）+ 主标签关闭（Plan 01-01 `stopSession` delete 簇）已就位，Phase 2 分发不会发到死 session。

**建议人工确认项（D4/D5/D6 human_judgment）：**
1. 桌面 GUI 开启广播，确认开关 accent 蓝（非红）+ 徽标计数渲染（D-08）。
2. 多终端场景下勾选目标，确认列表 + halo + 全选/全不选交互（BCAST-02/03）。
3. 切 tab / 关重开 AI 面板，确认广播开关与目标选择保持（BCAST-04）。
4. 关闭一个已选目标 tab，确认该 tabId 自动从选择剔除、徽标递减（D-11）。

**Blockers / concerns：** 无。

---
*Phase: 01-broadcast-ui-state*
*Completed: 2026-07-08*

## Self-Check: PASSED

- 所有声称修改的文件均存在：`src/lib/ai/ChatPanel.svelte`、`src/lib/i18n/locales/en.ts`、`src/lib/i18n/locales/zh.ts`、`.planning/phases/01-broadcast-ui-state/01-02-SUMMARY.md`。
- 两个 task 提交哈希均在 `git log` 中命中：`ed9e41f`（Task 1）、`f2290fc`（Task 2）。
- 验证命令复跑结果：`npx tsc --noEmit` EXIT=0；`npm run build` EXIT=0（314 模块）；`npm test --run` 391/391 passed。
