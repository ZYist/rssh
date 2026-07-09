# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — AI Broadcast Mode

**Shipped:** 2026-07-09
**Phases:** 2 | **Plans:** 3 | **Tasks:** 6
**Git range:** `9b6f07e..495685c` (28 commits, 32 files, +2888/−843)
**Closeout:** verified (both phases `verification_status: passed`; UAT Phase 1 5/5 + Phase 2 5/5; 0 overrides)

### What Was Built
- Per-tab 广播状态机（`ai/store.svelte.ts` `_broadcastByTab`：BroadcastState + 9 getter/mutator + stopSession teardown）+ 从 EditPane 抽取的受控组件 `BroadcastTargetSelector.svelte`（5 必选 + 2 可选 hover props，零内部状态）
- ChatPanel 工具栏广播开关（accent 激活态 + 目标计数徽标）+ 可折叠目标条 + D-11 prune `$effect` + 10 个 en/zh 双语 i18n key
- AI 审批命令广播分发（D-01 approve fire-and-forget raw cmd → 目标，D-02 raw device 安全门降级自动批准，D-03 对称 Ctrl+C 终止，D-04 sendText SSH/local invoke reject 捕获）

### What Worked
- **结构性验证（源码 grep + 接线）+ 人工 UAT 双层把关**：9/9 structural truths 在 Phase 2 全 VERIFIED，但 UAT 场景 B 仍抓出结构验证抓不到的 Enter-byte 运行期 bug（PowerShell/ConPTY 收 LF 不执行）。两层数据互补，单靠任一层都会漏。
- **per-tab state 模块级 $state + 受控组件模式**：store.svelte.ts 零 reactive-effect 不变量 + `BroadcastTargetSelector` 可被 ChatPanel 与 EditPane 共用，Phase 2 不需改 UI 层就能接分发逻辑。状态架构一次做对。
- **中央化 EOL 归一化**：Enter-byte bug 修在 `normalizePtyOutgoing`（sendText 接缝）而非 broadcast 调用点，一处修复同时覆盖广播/snippet/paste 三条路径。
- **零依赖、零后端改动**：纯前端实现复用既有 `broadcastToSessions`，未动 Rust，A2 零新依赖假设兑现。

### What Was Inefficient
- **Phase 1 在 UAT 未跑完时就被标 complete**（2026-07-08）：直到 milestone 预关 audit 才暴露 `01-UAT.md` 仍 `testing`、`01-VERIFICATION.md` `human_needed`。本应在 `phase.complete` 前关闭 UAT。代价是一次中断 + 决策往返。
- **`gsd-tools` PATH shim 坏掉**（npm shim 指向不存在的 `tiger-flow` 模块）拖了整个 session——每次 CLI 调用都得用 `node ~/.claude/gsd-core/bin/gsd-tools.cjs` 直跑。早修早省心，但用户选择"先归档后修"。
- **Phase 1 UAT test 4（勾选即时反映）的覆盖关系靠人工跨阶段复验**：完成度谓词把 skipped 算 blocker，逼我把 test 4 改 `pass` + `source: cross-verified`（依据 Phase 2 UAT 场景 B/D）。诚实但繁琐——UAT 模板没有"已被其他 phase 覆盖"的一等公民状态。

### Patterns Established
- **Svelte 5 $state Set 反应性三步**：`new Set(prev)` → 整体替换 record → 重赋值整个 map（in-place `.add()/.delete()` 静默失效，pitfall 1）。本项目新增的广播 mutator 全部遵守。
- **宿主组件 $effect 调 store mutator 完成 prune**（store 零 reactive-effect 不变量）；prune mutator 带 size-unchanged early-return 守卫防 spurious 反应。
- **广播调用从组件层发起**（`CommandConfirmDialog` 同时 import `app` + `ai` 两个 store），不在 `ai/store.svelte.ts` import `app`——避免 ES module 循环依赖。
- **`{#if broadcastOn}` 整条不渲染** = broadcast-OFF 像素一致性的实现手段（兼容性约束，grep 可守门）。

### Key Lessons
1. **结构性验证 ≠ 运行期正确**：grep + tsc + 单测能在源码层证伪接线与类型，但跨 transport 的 EOL 字节语义（LF vs CR）、反应管道时序、像素着色只能靠人工 GUI UAT。Enter-byte bug 是铁证——9/9 structural pass 仍漏了 ConPTY 的 LF 不提交。
2. **不要在 UAT/verification 未关闭前标 phase complete**：`phase.complete` 应是 UAT `complete` + verification `passed` 之后的事，否则 milestone 关尾会撞上陈旧 artifact。本里程碑因这一步多花了一轮决策。
3. **把 EOL 归一化放在 transport 接缝（sendText），不是每个调用点**：调用点保持 `cmd + "\n"` 的自然写法，接缝负责按 transport 翻译。一处修复覆盖多路径。
4. **完成度谓词把 skipped 当 blocker**：跨阶段覆盖的测试应显式标 `pass` + `source: cross-verified`（附引用），不能留 `skipped`——否则 `phase uat-passed --require-verification` 返回 false。

### Cost Observations
- Model mix: 100% inherit（单模型会话，未分层调度）
- Sessions: 本里程碑跨 2 个自然日（2026-07-08 规划+执行 Phase 1，2026-07-09 Phase 2 + UAT + 归档）
- Notable: 3 plans 平均 ~9 min/plan（含 01-02 的 4 min 与 02-01 的 260s），计划质量高——Phase 2 plan 执行零返工、零自动修复触发（SUMMARY "Deviations from Plan: None"）。瓶颈不在执行，而在 milestone 关尾的 verification 协调。

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 2 | 2 | 引入 verified_closeout 门槛 + 结构验证与人工 UAT 双层把关；确立 Svelte 5 Set 反应性三步模式 |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 391 passing（31 files）+ 5 新增（quick 260709-jat）= 396 | N/A（未配 coverage 阈值） | 0（零新 npm/cargo 依赖） |

### Top Lessons (Verified Across Milestones)

1. 结构性验证 ≠ 运行期正确——人工 GUI UAT 不可省（v1.0 Enter-byte 为证）
2. UAT/verification 未关闭前不得标 phase complete（v1.0 关尾撞陈旧 artifact 为证）
