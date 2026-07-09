# Roadmap: AI Broadcast Mode

## Overview

AI Broadcast Mode extends RSSH's AI panel so that approved commands fan out to multiple terminal tabs simultaneously. Phase 1 delivers the broadcast UI and per-tab state management. Phase 2 wires up the actual dispatch logic and safety guarantees. Together they enable a single AI diagnosis to drive identical operations across many machines.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Broadcast UI & State** - Toggle button, target selector, and per-tab state persistence in the AI panel (completed 2026-07-08)
- [x] **Phase 2: Broadcast Dispatch & Safety** - Post-approval command fan-out to selected targets with parallel execution and output isolation (plan executed + structurally verified; pending human verification — 02-UAT.md) (completed 2026-07-09)

## Phase Details

### Phase 1: Broadcast UI & State

**Goal**: Users can enable broadcast mode in the AI panel and configure which terminal tabs participate as broadcast targets
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: BCAST-01, BCAST-02, BCAST-03, BCAST-04
**Success Criteria** (what must be TRUE):

  1. User can toggle broadcast mode on/off via a button in the AI panel toolbar
  2. When broadcast is enabled, a target selector appears listing all open terminal tabs
  3. User can check/uncheck individual terminal tabs as broadcast targets
  4. Broadcast toggle state and target selections persist when switching between tabs or closing/reopening the AI panel

**Plans**: 2/2 plans complete
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — 广播状态地基（ai/store.svelte.ts per-tab _broadcastByTab + getter/mutator + stopSession teardown）+ 抽取 BroadcastTargetSelector 共享组件 + 改造 EditPane 消费（回归安全）

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — ChatPanel 广播开关按钮 + 可折叠目标条 + prune $effect + en/zh i18n 双语 key（交付 Phase 1 全部 4 条用户可见 Success Criteria）

**UI hint**: yes

### Phase 2: Broadcast Dispatch & Safety

**Goal**: Approved AI commands automatically broadcast to all selected targets in parallel while the AI reads only the primary tab's output
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: BCAST-05, BCAST-06, BCAST-07, BCAST-08
**Success Criteria** (what must be TRUE):

  1. When user approves a command with broadcast active, the primary tab executes via executeCommand (with sentinel) and all selected targets receive the raw command via broadcastToSessions
  2. Broadcast dispatch runs in parallel with primary execution — primary tab output collection is not delayed by broadcast
  3. AI responses reference only the primary tab's output; broadcast targets execute silently without feeding back to the AI
  4. Approval flow (manual confirm, danger mode, auto-run) works identically whether broadcast is on or off — no extra approval dialogs introduced

**Plans**: 1/1 plans complete
Plans:

- [x] 02-01-PLAN.md — 广播命令分发接线（D-01 approve 广播 + D-02 raw 安全门 + D-03 对称终止 + D-04 sendText 错误卫生），交付 BCAST-05/06/07/08 全部 4 条 Success Criteria

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Broadcast UI & State | 2/2 | Complete   | 2026-07-08 |
| 2. Broadcast Dispatch & Safety | 1/1 | Complete    | 2026-07-09 |
