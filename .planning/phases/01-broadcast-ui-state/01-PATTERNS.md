# Phase 1: Broadcast UI & State - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 7 (2 new, 5 modified; 1 optional new test)
**Analogs found:** 7 / 7 (every target file has a strong, mostly exact in-codebase analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| NEW `src/lib/components/BroadcastTargetSelector.svelte` | component (controlled, presentational) | request-response (props in → events out) | `src/lib/components/EditPane.svelte` (138-168 markup, 234-299 styles) | **exact** — this IS the extraction source |
| MODIFY `src/lib/ai/store.svelte.ts` | store (runes module) | CRUD / state (per-tab maps) | itself: `_sessionByTab`/`_pendingByTab` (52-55), `stopSession` delete cluster (255-260), `rebindTarget` (285-289) | **exact** — new `_broadcastByTab` slots into the existing pattern |
| MODIFY `src/lib/ai/ChatPanel.svelte` | component (toolbar host + target bar host) | event-driven (click → store → derived re-render) | `src/lib/ai/DangerModeToggle.svelte` trigger (48) + ChatPanel `.toolbar`/`.btn-icon`/`.danger-toggle.on` (246-302, 460-487) | **exact** for toggle button; **role-match** for collapsible bar (mirror `.banner`) |
| MODIFY `src/lib/components/EditPane.svelte` | component (refactor to consume shared child) | event-driven (unchanged semantics) | itself: current EditPane implementation | **exact** — in-place refactor |
| MODIFY `src/lib/i18n/locales/en.ts` | config / i18n catalog | static lookup | itself: existing `ai.toolbar.*` / `ai.session.*` keys (409-419) | **exact** — append along dotted-key convention |
| MODIFY `src/lib/i18n/locales/zh.ts` | config / i18n catalog | static lookup | itself (mirror of en.ts) | **exact** — append in lockstep with en.ts |
| NEW (optional) `src/lib/ai/store.broadcast.test.ts` | test (pure-logic unit) | transform (Set rebuild / prune diff) | `src/lib/ai/tokens.test.ts` (whole file, 27 lines) | **role-match** — co-located `*.test.ts` pure-logic pattern |

---

## Pattern Assignments

### NEW `src/lib/components/BroadcastTargetSelector.svelte` (component, request-response)

**Analog:** `src/lib/components/EditPane.svelte` — this component is **literally the extraction** of EditPane's `.session-panel` list region (D-01). Copy markup + styles verbatim, swap local `$state` for `$props`.

**Imports pattern** (mirror EditPane.svelte:10-12):
```typescript
import * as app from "../stores/app.svelte.ts";
import SessionMinimap from "./SessionMinimap.svelte";
// (only if hover preview is retained) import SessionPreviewPopover from "./SessionPreviewPopover.svelte";
```
Note: `app` import is only needed if the component itself resolves labels; per UI-SPEC the host filters and passes `SessionInfo[]`, so `app` import can be dropped. `SessionMinimap` is required.

**Controlled `$props` contract** (from RESEARCH.md §Pattern 1, UI-SPEC-locked):
```typescript
let {
  sessions,      // SessionInfo[] — already filtered (host removes primary tabId per D-05)
  selectedIds,   // Set<string> — current selected tabId set (read-only)
  onToggle,      // (tabId: string) => void
  onSelectAll,   // () => void
  onSelectNone,  // () => void
}: {
  sessions: import("../stores/app.svelte.ts").SessionInfo[];
  selectedIds: Set<string>;
  onToggle: (tabId: string) => void;
  onSelectAll: () => void;
  onSelectNone: () => void;
} = $props();
```

**Core list markup** — copy verbatim from EditPane.svelte:141-168 (the `{#if sessions.length === 0}` empty branch + `{#each}` + `.select-actions`):
```svelte
{#if sessions.length === 0}
  <div class="empty-hint">{t("ai.broadcast.empty")}</div>
{:else}
  <div class="session-list">
    {#each sessions as s (s.tabId)}
      <button
        type="button"
        class="session-item"
        class:selected={selectedIds.has(s.tabId)}
        aria-pressed={selectedIds.has(s.tabId)}
        onclick={() => onToggle(s.tabId)}
        title={s.label}
      >
        <SessionMinimap tabId={s.tabId} />
        <span class="session-meta">
          <span class="session-type">{s.type === "local" ? "$" : s.type === "serial" ? "⎓" : s.type === "telnet" ? "T" : "SSH"}</span>
          <span class="session-label">{s.label}</span>
        </span>
      </button>
    {/each}
  </div>
  <div class="select-actions">
    <button class="link-btn" onclick={onSelectAll}>{t("ai.broadcast.select_all")}</button>
    <button class="link-btn" onclick={onSelectNone}>{t("ai.broadcast.select_none")}</button>
  </div>
{/if}
```
Changes vs source: (a) drop `onmouseenter`/`onmouseleave` hover handlers unless keeping preview (A1 — planner discretion); (b) local `toggle`/`selectAll`/`selectNone` become prop callbacks; (c) the literal strings `"No connected sessions"` / `"All"` / `"None"` go through `t()` (new i18n keys, see en.ts assignment).

**Styles to move into the new component's `<style>`** (EditPane.svelte:226-299 — Svelte scoped styles follow the DOM, so these come with the markup):
```css
/* Copy verbatim from EditPane.svelte: */
.session-list        /* :226-232 */
.session-item        /* :234-248 */
.session-item:hover  /* :249 */
.session-item.selected /* :254-260 — the accent halo language (D-01 reuse) */
.session-meta        /* :262-267 */
.session-type        /* :269-274 */
.session-label       /* :276-282 */
.select-actions      /* :284-288 */
.link-btn, .link-btn:hover  /* :290-299 */
.empty-hint          /* :220-224 */
```
Leave in EditPane (host-only): `.session-panel` (201-210), `.panel-header` (212-218), `.broadcast-btn` (301-318) — D-04 says the action button stays EditPane-exclusive.

**No `$effect` here** — this is a controlled component; prune lives in the host (see ChatPanel assignment).

---

### MODIFY `src/lib/ai/store.svelte.ts` (store, CRUD/state)

**Analog:** itself — add `_broadcastByTab` next to the existing `_xByTab` maps and follow their getter/mutator/delete conventions exactly.

**Module-level state declaration** — insert near `_pendingByTab` (store.svelte.ts:52-55). Source pattern:
```typescript
// store.svelte.ts:52-55 — existing per-tab maps (the template)
let _sessionByTab = $state<Record<string, AiSessionInfo>>({});
let _chatByTab = $state<Record<string, ChatItem[]>>({});
let _pendingByTab = $state<Record<string, CommandProposed | null>>({});
let _keyboardLockedByTab = $state<Record<string, boolean>>({});
```
New code (RESEARCH.md §Pattern 2):
```typescript
interface BroadcastState {
    enabled: boolean;
    barCollapsed: boolean;
    targets: Set<string>;
}
let _broadcastByTab = $state<Record<string, BroadcastState>>({});
const DEFAULT_BROADCAST: BroadcastState = { enabled: false, barCollapsed: false, targets: new Set() };
```

**Getter naming** — copy the no-`get`-prefix verb-phrase convention (store.svelte.ts:103-126):
```typescript
// existing (template): sessionForTab, pendingCommand, isKeyboardLocked, tokenUsage
// new:
export function broadcastState(tabId: string): BroadcastState { ... }
export function broadcastEnabled(tabId: string): boolean { ... }
export function broadcastTargets(tabId: string): Set<string> { ... }
```

**Mutator pattern — rebuild Set + replace whole record + reassign whole `_broadcastByTab`** (THE critical pattern, from EditPane.svelte:29-37 + store.svelte.ts:285-289). Source:
```typescript
// EditPane.svelte:29-34 — Set rebuild under $state (the canonical proof this is needed)
function toggle(tid: string) {
    const next = new Set(selectedTabIds);
    if (next.has(tid)) next.delete(tid);
    else next.add(tid);
    selectedTabIds = next;   // whole-Set reassignment
}

// store.svelte.ts:285-289 — whole-record replacement under $state
const info = _sessionByTab[tab_id];
if (info) {
    _sessionByTab[tab_id] = { ...info, target_id };  // spread + replace field
}
```
Combined for broadcast (RESEARCH.md §Code Examples):
```typescript
export function toggleBroadcastTarget(tabId: string, targetTabId: string): void {
    const prev = _broadcastByTab[tabId] ?? DEFAULT_BROADCAST;
    const next = new Set(prev.targets);
    if (next.has(targetTabId)) next.delete(targetTabId);
    else next.add(targetTabId);
    _broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, targets: next } };
}
```
`toggleBroadcast` / `setBroadcastBarCollapsed` / `setBroadcastTargets` / `pruneBroadcastTargets` all follow the same shape. `pruneBroadcastTargets` should early-return when `next.size === prev.targets.size` to avoid spurious reactivity (see RESEARCH.md §Pitfall 1).

**Teardown integration** — add one line to the existing `stopSession` delete cluster (store.svelte.ts:255-260). Source:
```typescript
// store.svelte.ts:255-260 — the existing per-tab delete cluster
delete _sessionByTab[tab_id];
delete _pendingByTab[tab_id];
delete _keyboardLockedByTab[tab_id];
delete _targetKindByTab[tab_id];
delete _chatByTab[tab_id];
delete _tokensByTab[tab_id];
```
New (append):
```typescript
delete _broadcastByTab[tab_id];   // primary tab closed → broadcast state for it goes too
```
This is the D-11 "primary tab closed = whole-record cleanup" path. It is distinct from prune (which handles a *target* tab closing). Both must be implemented.

**Forbidden in this file:** `$effect` at module top level — store.svelte.ts has zero `$effect` calls today; all reactive side-effects go through `attachListeners`. Prune `$effect` belongs in ChatPanel (see next assignment, and RESEARCH.md §Pitfall 2).

---

### MODIFY `src/lib/ai/ChatPanel.svelte` (component, event-driven)

**Analogs:** (1) `DangerModeToggle.svelte` + the `.danger-toggle.on` CSS rule for the toggle button; (2) ChatPanel's own `.toolbar` / `.banner` layout for the collapsible target bar insertion.

**Imports** — add `BroadcastTargetSelector` + `app` store (for `connectedSessions`) + existing `ai` store + `t` already imported. ChatPanel.svelte:1-11 currently imports `ai`, `t`, `errMsg`; needs:
```typescript
import * as app from "../stores/app.svelte.ts";
import BroadcastTargetSelector from "../components/BroadcastTargetSelector.svelte";
```

**Props are already correct** — ChatPanel.svelte:16-20 receives `tabId` (= primary tab id; passed as `aiActiveTab.id` from AppShell.svelte:1059). This is the D-05 filter key. No prop changes needed.

**Toggle button — mirror the DangerModeToggle trigger verbatim, swap red→accent, no confirm modal.** Source (ChatPanel.svelte:287-300):
```svelte
<DangerModeToggle onError={(m) => (banner = m)}>
    {#snippet trigger(requestToggle, saving)}
        <button class="btn-icon danger-toggle" class:on={dangerMode}
                onclick={requestToggle} disabled={saving}
                title={dangerMode ? t("ai.title.danger_tip") : t("ai.toolbar.danger_enable")}
                aria-label={t("ai.toolbar.danger_aria")} aria-pressed={dangerMode}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                 stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                <line x1="12" y1="9" x2="12" y2="13"/>
                <line x1="12" y1="17" x2="12.01" y2="17"/>
            </svg>
        </button>
    {/snippet}
</DangerModeToggle>
```
New broadcast toggle (UI-SPEC D-07/D-08/D-09 — **no** `DangerModeToggle` wrapper since there's no confirm modal; **no** `disabled` since broadcast is per-tab UI state settable anytime):
```svelte
<button class="btn-icon broadcast-toggle" class:on={broadcastOn}
        onclick={() => ai.toggleBroadcast(tabId)}
        title={broadcastOn ? t("ai.toolbar.broadcast_on_tip") : t("ai.toolbar.broadcast_enable")}
        aria-label={t("ai.toolbar.broadcast_aria")} aria-pressed={broadcastOn}>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <!-- lucide radio / radio-tower canonical path — copy from lucide.dev at impl time (A2) -->
        <path d="..."/>
    </svg>
    {#if broadcastOn && selectedCount > 0}
        <span class="badge" aria-hidden="true">{selectedCount}</span>
    {/if}
</button>
```
**Insert position (UI-SPEC D-07 locked):** between `clear-btn` (ChatPanel.svelte:273-282) and `<DangerModeToggle>` (287) — the two mode toggles sit adjacent; `close-btn` (301) stays rightmost.

**Local `$derived` for the toggle:**
```typescript
let bState = $derived(ai.broadcastState(tabId));
let broadcastOn = $derived(bState.enabled);
let selectedCount = $derived(bState.targets.size);
let sessions = $derived(app.connectedSessions().filter(s => s.tabId !== tabId));  // D-05 filter
let totalCount = $derived(sessions.length);
```

**Collapsible target bar — insert after `.banner`, before `{#if auditOpen && session}` (ChatPanel.svelte:309-311).** Mirror `.banner`'s `flex-shrink: 0` and use the same `{#if}` conditional-render discipline. Skeleton:
```svelte
{#if broadcastOn}
  <div class="broadcast-bar">
    <div class="bar-header" onclick={() => ai.setBroadcastBarCollapsed(tabId, !bState.barCollapsed)}
         role="button" tabindex="0" aria-expanded={!bState.barCollapsed}
         aria-label={bState.barCollapsed ? t("ai.broadcast.expand") : t("ai.broadcast.collapse")}>
      <span class="bar-title">{t("ai.broadcast.title")}</span>
      <span class="bar-count">{t("ai.broadcast.count", { selected: selectedCount, total: totalCount })}</span>
      <span class="chevron" class:collapsed={bState.barCollapsed}>▾</span>
    </div>
    {#if !bState.barCollapsed}
      <div class="bar-list">
        <BroadcastTargetSelector
          sessions={sessions}
          selectedIds={bState.targets}
          onToggle={(tid) => ai.toggleBroadcastTarget(tabId, tid)}
          onSelectAll={() => ai.setBroadcastTargets(tabId, new Set(sessions.map(s => s.tabId)))}
          onSelectNone={() => ai.setBroadcastTargets(tabId, new Set())} />
      </div>
    {/if}
  </div>
{/if}
```
Note: `bState.targets` passed as `selectedIds` is read-only by contract — the selector must NOT mutate it in place (mutators live in `ai.*`).

**Prune `$effect` — copy EditPane.svelte:23-27 verbatim into ChatPanel `<script>`.** Source:
```svelte
<!-- EditPane.svelte:20-27 — the canonical prune pattern -->
let sessions = $derived(app.connectedSessions());
let selectedTabIds = $state<Set<string>>(new Set());

$effect(() => {
  const activeIds = new Set(sessions.map(s => s.tabId));
  const pruned = [...selectedTabIds].filter(id => activeIds.has(id));
  if (pruned.length !== selectedTabIds.size) selectedTabIds = new Set(pruned);
});
```
ChatPanel variant delegates to the store mutator (since state lives in store, not component-local):
```typescript
$effect(() => {
    const activeIds = new Set(sessions.map(s => s.tabId));
    ai.pruneBroadcastTargets(tabId, activeIds);
});
```
The `$effect` is valid here because ChatPanel is a component init context (not a `.svelte.ts` module top level — see RESEARCH.md §Pitfall 2). It dies when ChatPanel unmounts (AI panel closed); that's acceptable because state persists in the module-level store and the same `$effect` re-mounts when the panel reopens (RESEARCH.md §Pitfall 3).

**CSS — new `.broadcast-toggle` rule mirrors `.danger-toggle.on` with `--accent` instead of `--error`.** Source (ChatPanel.svelte:480-487):
```css
.danger-toggle.on {
    color: var(--error);
    background: color-mix(in srgb, var(--error) 14%, transparent);
}
.danger-toggle.on:hover {
    color: var(--error);
    background: color-mix(in srgb, var(--error) 22%, transparent);
}
```
New (UI-SPEC D-08 — red is DangerMode-only):
```css
.broadcast-toggle { position: relative; }  /* anchor for .badge */
.broadcast-toggle.on {
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
}
.broadcast-toggle.on:hover {
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 22%, transparent);
}
.broadcast-toggle .badge {  /* UI-SPEC §Token Grounding values */
    position: absolute; bottom: -2px; right: -2px;
    min-width: 16px; height: 16px; padding: 0 4px;
    border-radius: 50%; background: var(--accent); color: var(--white);
    font-size: 10px; font-weight: 700; line-height: 1;
    border: 2px solid var(--bg);
    display: flex; align-items: center; justify-content: center;
}
```

**Target bar layout** — mirror `.banner` (ChatPanel.svelte:488-497): `flex-shrink: 0; border-bottom: 1px solid var(--divider);`. List region: `max-height: 40vh; overflow-y: auto` (UI-SPEC). The `.chat` pane below must keep R4 three-piece (`flex:1; overflow-y:auto; min-height:0`) — verify the existing rule isn't broken by the inserted bar (RESEARCH.md §Pitfall 6).

---

### MODIFY `src/lib/components/EditPane.svelte` (component, event-driven)

**Analog:** itself — in-place refactor. Keep `selectedTabIds` as **component-local** `$state` (editor one-shot send semantics, different lifetime from AI broadcast; explicitly NOT moved to ai store per RESEARCH.md §Pattern 1).

**Replace the inline list** (EditPane.svelte:141-168) with the shared component:
```svelte
<!-- BEFORE (141-168): inline {#if}/{#each}/.select-actions -->
<!-- AFTER: -->
<BroadcastTargetSelector
  sessions={sessions}
  selectedIds={selectedTabIds}
  onToggle={toggle}
  onSelectAll={selectAll}
  onSelectNone={selectNone} />
```
Imports to add (near EditPane.svelte:11):
```typescript
import BroadcastTargetSelector from "./BroadcastTargetSelector.svelte";
```
**Keep unchanged:** the `selectedTabIds` `$state` (line 21), `toggle`/`selectAll`/`selectNone` (29-37), the prune `$effect` (23-27 — still needed; EditPane's local set is independent of ai store), `broadcast()` (49-54), `.broadcast-btn` (170-176), `.session-panel`/`.panel-header` styles (201-218, 301-318), hover popover (179-181 — EditPane-only; do not force into shared component).

**Styles to remove from EditPane `<style>`** (they moved with the markup into the new component): `.session-list`, `.session-item`, `.session-item:hover`, `.session-item.selected`, `.session-meta`, `.session-type`, `.session-label`, `.select-actions`, `.link-btn`, `.empty-hint` (EditPane.svelte:220-299). Leave `.session-panel`, `.panel-header`, `.broadcast-btn`.

---

### MODIFY `src/lib/i18n/locales/en.ts` (config / i18n)

**Analog:** itself — existing `ai.toolbar.*` keys at en.ts:409-419.

**Structure** (en.ts:1-2 — flat object, dotted keys, no nesting):
```typescript
const en = {
  "common.save": "Save",
  ...
  "ai.toolbar.audit": "View audit log",        // :409
  "ai.toolbar.danger_enable": "Enable Danger Mode",  // :419
  ...
};
```

**New keys to append** (UI-SPEC §Copywriting locked — both files must stay in lockstep):
```typescript
"ai.toolbar.broadcast_enable": "Enable Broadcast Mode",
"ai.toolbar.broadcast_on_tip": "Broadcast is ON — approved commands will sync to selected terminals",
"ai.toolbar.broadcast_aria": "Broadcast mode",
"ai.broadcast.title": "Broadcast Targets",
"ai.broadcast.count": "{selected}/{total} targets",   // interpolation placeholders — see ai.toolbar.tokens_tip (:415) for the {x} convention
"ai.broadcast.empty": "No other terminals",
"ai.broadcast.select_all": "All",
"ai.broadcast.select_none": "None",
"ai.broadcast.collapse": "Collapse target bar",
"ai.broadcast.expand": "Expand target bar",
```
`{selected}/{total}` mirrors the existing `{tin}/{tout}` placeholder syntax at en.ts:415.

---

### MODIFY `src/lib/i18n/locales/zh.ts` (config / i18n)

**Analog:** itself — mirror of en.ts. Append the **same keys** with Chinese values. No structure difference; zh.ts uses the same flat dotted-key object shape. The two files must contain the same key set (CONVENTIONS.md §i18n 双语 key).

---

### NEW (optional) `src/lib/ai/store.broadcast.test.ts` (test, transform)

**Analog:** `src/lib/ai/tokens.test.ts` (whole file, 27 lines) — the project's canonical "co-located pure-logic unit test" pattern.

**Imports pattern** (tokens.test.ts:1-2):
```typescript
import { describe, it, expect } from "vitest";
import { formatTokenCount } from "./tokens.ts";
```

**Note on testing store mutators:** the mutators (`toggleBroadcastTarget`, `pruneBroadcastTargets`) read/write the module-level `_broadcastByTab` `$state`. Because `vitest.config.ts` enables the svelte plugin (per CLAUDE.md), `.svelte.ts` runes transform works in tests. However, the mutators don't have a "reset" export — planner may want to add a `_test_resetBroadcast()` helper exported under `if (import.meta.env)` — or alternatively test the Set-rebuild/prune-diff logic as standalone exported pure functions. `pruneBroadcastTargets` is the highest-value target (pure diff logic). Pattern:
```typescript
import { describe, it, expect } from "vitest";
// import the mutators under test from "./store.svelte.ts"

describe("pruneBroadcastTargets", () => {
  it("drops target ids no longer in the active set", () => { ... });
  it("no-ops when the set is unchanged", () => { ... });   // guards spurious reactivity
});
```
This file is **optional** per CONTEXT.md (Claude's Discretion). Planner may defer.

---

## Shared Patterns

### Svelte 5 runes — private `$state` + getter export, no `get` prefix
**Source:** `src/lib/ai/store.svelte.ts:49-55, 75-126`
**Apply to:** `store.svelte.ts` broadcast additions; any new state lives behind a getter.
```typescript
let _broadcastByTab = $state<Record<string, BroadcastState>>({});
export function broadcastState(tabId: string): BroadcastState { return _broadcastByTab[tabId] ?? DEFAULT_BROADCAST; }
```

### Mutator pattern — rebuild Set, replace whole record, reassign whole map
**Source:** `src/lib/components/EditPane.svelte:29-37` + `src/lib/ai/store.svelte.ts:285-289`
**Apply to:** every broadcast mutator that changes `targets`. Never `.add()`/`.delete()` on a Set in place — Svelte 5 `$state` proxy does not intercept Set methods (RESEARCH.md §Pitfall 1).
```typescript
const next = new Set(prev.targets);
if (next.has(id)) next.delete(id); else next.add(id);
_broadcastByTab = { ..._broadcastByTab, [tabId]: { ...prev, targets: next } };
```

### Prune `$effect` — host component, not store module
**Source:** `src/lib/components/EditPane.svelte:23-27`
**Apply to:** `ChatPanel.svelte <script>`. Store cannot host `$effect` (RESEARCH.md §Pitfall 2); component-scoped effect calls the store's `pruneBroadcastTargets` mutator.
```typescript
$effect(() => {
  const activeIds = new Set(sessions.map(s => s.tabId));
  ai.pruneBroadcastTargets(tabId, activeIds);
});
```

### Per-tab teardown — append to existing `stopSession` delete cluster
**Source:** `src/lib/ai/store.svelte.ts:255-260` + `src/lib/stores/app.svelte.ts:224-241` (closeTab → ai.stopSession)
**Apply to:** `store.svelte.ts stopSession` — add `delete _broadcastByTab[tab_id];`. This is the "primary tab closed" path; it is distinct from prune and both must exist.

### Toolbar `.btn-icon` + mode-toggle `.on` tint
**Source:** `src/lib/ai/ChatPanel.svelte:460-487` (`.btn-icon` base + `.danger-toggle.on`)
**Apply to:** new `.broadcast-toggle.on` — copy with `--accent` substituted for `--error`. Never use red for broadcast (D-08 — red is DangerMode-only).

### i18n flat dotted keys, dual-catalog
**Source:** `src/lib/i18n/locales/en.ts:1-2, 409-419`
**Apply to:** every new user-visible string — append the same key set to both `en.ts` and `zh.ts`. Interpolation uses `{name}` placeholders (see `ai.toolbar.tokens_tip` en.ts:415).

### CSS via design tokens, no raw hex
**Source:** EditPane `.session-item.selected` (254-260) uses `var(--accent)` + `color-mix(... var(--accent) ...)`.
**Apply to:** `BroadcastTargetSelector` styles (moved as-is) and any new `.broadcast-*` rules. Reuse `--accent`, `--divider`, `--bg`, `--text-dim`, `--radius-sm` — no hex.

### R4 flex three-piece on panes
**Source:** CLAUDE.md (Conventions §CSS) — `flex:1; overflow-y:auto; min-height:0;` on any tab/pane root.
**Apply to:** the new broadcast bar's `.bar-list` region and the existing `.chat` pane (must remain shrinkable after bar insertion — RESEARCH.md §Pitfall 6).

---

## No Analog Found

None. Every target file has at least a role-match analog inside the codebase. The two genuinely new artifacts — the `BroadcastTargetSelector` markup and the `.broadcast-toggle.on` CSS rule — are **defined** by direct verbatim copy of EditPane's `.session-panel` list and `.danger-toggle.on` respectively (D-01 and UI-SPEC D-07 lock these as the templates). The only `[ASSUMED]` item is the lucide SVG path value for the broadcast icon (RESEARCH.md A2) — the planner should direct the implementer to copy the canonical path from lucide.dev (`radio` or `radio-tower`) at write time.

## Metadata

**Analog search scope:**
- `src/lib/components/` (EditPane, SessionMinimap, SessionPreviewPopover, Modal)
- `src/lib/ai/` (store.svelte.ts, ChatPanel.svelte, DangerModeToggle.svelte, tokens.test.ts)
- `src/lib/stores/app.svelte.ts` (connectedSessions, broadcastToSessions, closeTab)
- `src/lib/i18n/locales/{en,zh}.ts`
- `src/lib/components/AppShell.svelte` (ChatPanel mount point + .ai-side layout)

**Files scanned:** 9 (all relevant ranges read; no re-reads)
**Pattern extraction date:** 2026-07-08
**Confidence:** HIGH — every pattern is `[VERIFIED: codebase]` against the live source; the phase is "extract + wire" with zero novel UI patterns.
