# Roadmap: AI Broadcast Mode

## Overview

AI Broadcast Mode extends RSSH's AI panel so that approved commands fan out to multiple terminal tabs simultaneously. Phase 1 delivers the broadcast UI and per-tab state management. Phase 2 wires up the actual dispatch logic and safety guarantees. Together they enable a single AI diagnosis to drive identical operations across many machines.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: Broadcast UI & State** - Toggle button, target selector, and per-tab state persistence in the AI panel
- [ ] **Phase 2: Broadcast Dispatch & Safety** - Post-approval command fan-out to selected targets with parallel execution and output isolation

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

**Plans**: 2 plans
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — 广播状态地基（ai/store.svelte.ts per-tab _broadcastByTab + getter/mutator + stopSession teardown）+ 抽取 BroadcastTargetSelector 共享组件 + 改造 EditPane 消费（回归安全）

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — ChatPanel 广播开关按钮 + 可折叠目标条 + prune $effect + en/zh i18n 双语 key（交付 Phase 1 全部 4 条用户可见 Success Criteria）

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

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Broadcast UI & State | 1/2 | In progress | - |
| 2. Broadcast Dispatch & Safety | 0/TBD | Not started | - |
