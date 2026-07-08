# Project Research Summary

**Project:** AI Broadcast Mode for RSSH Terminal Multiplexer
**Synthesized:** 2026-07-08

## Executive Summary

AI Broadcast Mode extends RSSH existing AI command execution pipeline to fan out approved commands to multiple terminal sessions simultaneously. The research reveals an unusually favorable architectural situation: all required primitives already exist in the codebase. broadcastToSessions handles transport-agnostic text dispatch to multiple terminals, the session registry tracks all connected targets, and the AI store already uses per-tab indexed state. The feature is essentially a routing extension -- after the AI proposes a command and the user approves, the approved command text additionally flows to selected broadcast targets via the existing broadcastToSessions function.

The recommended approach is a pure frontend implementation with no backend (Rust) changes. State lives in store.svelte.ts following the established _*ByTab pattern. The broadcast toggle and target selector live in ChatPanel following the DangerModeToggle pattern. The critical architectural decision -- broadcast targets receive the raw cmd string (not full_cmd with sentinel) -- prevents listener confusion and terminal noise. Only the primary tab gets sentinel-based execution with output capture; all other targets are fire-and-forget.

The primary risks center on safety: auto-approve (danger mode) must be suppressed when broadcast is active, raw devices (serial/telnet) must be excluded by default, and stale/disconnected targets must be pruned before dispatch. These are all preventable with straightforward guards at known insertion points. The feature scope is well-bounded by the explicit anti-features (no output aggregation, no per-target sentinel tracking, no different commands per target).
## Key Findings

### From STACK.md -- Technology and Patterns

- **No new dependencies required.** The feature builds entirely on existing Svelte 5 runes, Tauri IPC, and the broadcastToSessions primitive.
- **State pattern:** Module-level `$state<Record<string, T>>` keyed by `tabId`, exported via getter functions. Broadcast state (`_broadcastEnabledByTab`, `_broadcastTargetsByTab`) follows this exactly.
- **IPC is frontend-driven:** The backend never executes commands directly. The frontend pastes into PTY via transport-specific write commands. Broadcast is the same -- just more targets.
- **Transport abstraction:** broadcastToSessions delegates EOL, slow-send, and encoding to each pane registered sendText. No transport-specific broadcast logic needed.

### From FEATURES.md -- What to Build

**Must-have (table stakes):**
1. Broadcast toggle button in AI panel toolbar (per-tab state)
2. Target session selector (reuse `connectedSessions()` + EditPane pattern)
3. Post-approval dispatch hook calling `broadcastToSessions(targets, cmd + newline)`
4. Per-tab state persistence across panel close/reopen (store-level, not component-level)
5. Raw device exclusion by default (`isRawDeviceKind` filter)

**Should-have (differentiators):**
- Visual feedback per-target (checkmark/spinner after broadcast)
- Session minimap previews in target selector
- Broadcast-only quick input (bypass AI, go straight to broadcastToSessions)

**Defer to v2+:**
- Per-command target override (high complexity, low v1 value)
- Aggregate multi-target output to AI (anti-feature: blows up context)
- Per-target sentinel tracking (anti-feature: complexity explosion)
- Auto-enable on session connect (anti-feature: surprising behavior)

### From ARCHITECTURE.md -- How to Build It

- **Integration point:** Between approval and execution. `approve()` triggers `executeCommand(primaryTab)` + `broadcastToSessions(otherTabs, cmd)`.
- **State location:** AI Store (`store.svelte.ts`), not App Store -- broadcast is AI-feature-specific.
- **No modification to broadcastToSessions:** Use it as a consumer, not as a thing to extend.
- **Component changes:** AI Store (new state + dispatch logic), ChatPanel (toggle + selector UI), CommandConfirmDialog (broadcast indicator + auto-approve gate). App Store and TerminalPane unchanged.
- **Cleanup:** `stopSession` must delete broadcast state for closed tabs.

### From PITFALLS.md -- Top Risks

1. **Double-execution via executeCommand reuse** (Critical) -- Broadcast targets must NOT use executeCommand. Only broadcastToSessions for non-primary targets.
2. **Raw device broadcast without safeguards** (Critical) -- Default-exclude serial/telnet; require explicit opt-in with confirmation.
3. **Sentinel contamination** (Critical) -- Always broadcast cmd (human-readable), never full_cmd (sentinel-wrapped).
4. **Danger mode auto-approve bypass** (Moderate) -- Disable auto-approve when broadcast is active with targets selected.
5. **Stale/disconnected targets** (Moderate) -- Prune against connectedSessions() at dispatch time; show toast for skipped targets.
## Implications for Roadmap

### Suggested Phase Structure

**Phase 1: Broadcast State and Toggle**
- Rationale: Foundation -- state must exist before UI or dispatch can reference it
- Delivers: Per-tab broadcast enabled/disabled state, target list storage, cleanup on tab close
- Features: State in AI Store, broadcast toggle button in ChatPanel toolbar
- Pitfalls to avoid: State lost on panel close (Pitfall 5) -- must be store-level
- Research needed: No -- well-documented pattern (mirrors existing `_pendingByTab`, `_sftpOpenByTab`)

**Phase 2: Target Selector UI**
- Rationale: User must select targets before dispatch logic has anything to act on
- Delivers: Session selector panel in ChatPanel, raw device exclusion, disconnect pruning
- Features: Target selector (reuse EditPane pattern), `isRawDeviceKind` gate, visual type badges, auto-prune on disconnect
- Pitfalls to avoid: Raw device broadcast without safeguards (Pitfall 2), false confidence UX (Pitfall 9)
- Research needed: No -- directly copies EditPane existing selector pattern

**Phase 3: Broadcast Dispatch and Safety Gates**
- Rationale: Core execution logic -- depends on state (Phase 1) and targets (Phase 2)
- Delivers: Post-approval broadcast dispatch, auto-approve suppression, broadcast indicator in approval card
- Features: Hook in `approve()` path, broadcastToSessions call with raw cmd, danger-mode gate, audit entry
- Pitfalls to avoid: Double-execution (Pitfall 1), sentinel contamination (Pitfall 4), auto-approve bypass (Pitfall 8)
- Research needed: No -- insertion point is clearly identified (after approval, before/during executeCommand)

**Phase 4: Polish and Edge Cases**
- Rationale: Hardening after core flow works end-to-end
- Delivers: Visual feedback per-target, keyboard lock during broadcast, reconnect guard, stale target toast
- Features: Broadcast status indicators, keyboard lock for targets, rebindTarget guard
- Pitfalls to avoid: Stale targets (Pitfall 6), reconnect race (Pitfall 3), keyboard lock confusion (Pitfall 10)
- Research needed: Maybe -- reconnect handling (Pitfall 3) may need deeper investigation of rebindTarget edge cases

### Research Flags

- **Needs research:** Phase 4 (reconnect/rebindTarget interaction is a pre-existing race condition amplified by broadcast)
- **Standard patterns (skip research):** Phase 1, Phase 2, Phase 3 -- all follow established codebase conventions with clearly identified insertion points
## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies; all from direct codebase analysis of existing files |
| Features | HIGH | Clear requirements from PROJECT.md; existing EditPane broadcast as reference implementation |
| Architecture | HIGH | All integration points identified with line-number precision; data flow fully mapped |
| Pitfalls | HIGH | Derived from actual code paths (executeCommand, broadcastToSessions, autoApproveAllowed); not theoretical |

**Overall: HIGH** -- This is an unusually well-scoped feature. The existing codebase provides all primitives, the architecture documents show exact insertion points, and the pitfalls are preventable with known guards.

### Gaps to Address

- **Reconnect race (Pitfall 3):** The rebindTarget interaction with in-flight executions is a pre-existing bug amplified by broadcast. Phase 4 should investigate whether to fix it generally or just guard against it in broadcast context.
- **Slow-send timeout (Pitfall 7):** Serial primary tab timeouts may need adjustment. Low priority -- serial as AI primary target is an edge case.
- **Audit trail format:** No existing pattern for broadcast audit entries. Phase 3 should define the AuditKind variant shape.
## Critical Constraints

These are non-negotiable based on PROJECT.md and architectural analysis:

1. **AI reads only primary tab output** -- broadcast targets are fire-and-forget, no output collection
2. **Raw devices excluded by default** -- explicit user opt-in required with confirmation
3. **No backend changes** -- broadcast is purely frontend routing
4. **Broadcast sends cmd not full_cmd** -- no sentinel in broadcast targets
5. **State persists per-tab in store** -- survives panel close/reopen, cleaned on tab close
6. **Auto-approve disabled when broadcast active** -- multiplied damage risk requires manual approval
7. **broadcastToSessions used as-is** -- no modification to the shared primitive

## Risk Register

| # | Risk | Severity | Likelihood | Mitigation |
|---|------|----------|------------|------------|
| 1 | Destructive command broadcast to N machines via auto-approve | Critical | Medium | Suppress auto-approve when broadcast active |
| 2 | Raw device (PLC/switch) receives inappropriate command | Critical | Low | Default-exclude + confirmation dialog |
| 3 | Sentinel string appears in broadcast target terminals | High | High (if not prevented) | Always use cmd not full_cmd for broadcast |
| 4 | Double-execution via executeCommand reuse | High | Medium | Use broadcastToSessions for non-primary targets only |
| 5 | Stale targets cause silent partial broadcast | Medium | Medium | Prune at dispatch + toast notification |
| 6 | State lost on panel close/reopen | Medium | High (if component-local) | Store in store.svelte.ts keyed by tabId |
| 7 | Reconnect mid-execution causes timeout on primary | Low | Low | Guard in rebindTarget (Phase 4) |

## Sources

- `.planning/research/STACK.md` -- Technology stack analysis, state patterns, IPC architecture
- `.planning/research/FEATURES.md` -- Feature landscape, table stakes, anti-features, MVP recommendation
- `.planning/research/ARCHITECTURE.md` -- Component boundaries, data flow, integration points, patterns
- `.planning/research/PITFALLS.md` -- Critical/moderate/minor pitfalls with prevention strategies
- `src/lib/ai/store.svelte.ts` -- AI session state, executeCommand implementation
- `src/lib/stores/app.svelte.ts` -- Session registry, broadcastToSessions, terminal controls
- `src/lib/ai/ChatPanel.svelte` -- AI panel UI, toolbar pattern
- `src/lib/ai/CommandConfirmDialog.svelte` -- Approval flow, auto-approve logic
- `src/lib/components/EditPane.svelte` -- Existing broadcast pattern (reference implementation)
- `.planning/PROJECT.md` -- Project requirements and constraints
