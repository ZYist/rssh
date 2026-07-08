# Architecture Patterns

**Domain:** AI Broadcast Mode for RSSH terminal multiplexer
**Researched:** 2026-07-08

## System Architecture Overview

```
+-------------------+       +-------------------+       +-------------------+
|   AppShell        |       |   AI Store        |       |   App Store       |
|   (Layout)        |       |   (store.svelte)  |       |   (app.svelte)    |
+-------------------+       +-------------------+       +-------------------+
        |                           |                           |
        | renders                   | manages sessions          | manages tabs
        v                           | commands, events          | sessions, controls
+-------------------+       +-------------------+       +-------------------+
|   ChatPanel       |       | CommandConfirm    |       |  TerminalPane     |
|   (per-tab AI UI) |       | Dialog            |       |  (per-tab pane)   |
+-------------------+       +-------------------+       +-------------------+
        |                           |                           |
        | sendMessage()             | approve() ->             | registerSession()
        | ensureSession()           | executeCommand()         | registerTerminalControls()
        v                           v                           v
+-----------------------------------------------------------------------+
|                     Tauri Backend (Rust)                               |
|   ai_session_start | ai_user_message | ssh_write | pty_write | ...    |
+-----------------------------------------------------------------------+
```

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `app.svelte.ts` (App Store) | Tab lifecycle, session registry, terminal controls map, `broadcastToSessions` | TerminalPane (registration), AppShell (tab state), AI Store (session lookup) |
| `store.svelte.ts` (AI Store) | AI session lifecycle, chat timeline, command execution (`executeCommand`), event listeners | Backend (Tauri invoke/listen), ChatPanel (state reads), CommandConfirmDialog (execution) |
| `AppShell.svelte` | Layout composition, AI panel visibility gate, tab routing | App Store (tabs/activeTab), AI Store (open/position), ChatPanel (renders) |
| `ChatPanel.svelte` | AI chat UI, message input, session lazy-start | AI Store (start/send/cancel), receives `tabId` + `targetKind` + `targetId` props |
| `CommandConfirmDialog.svelte` | Command approval UI, auto-approve logic, triggers execution | AI Store (`executeCommand`, `rejectCommand`, `terminateCommand`) |
| `TerminalPane.svelte` | xterm.js instance, PTY/SSH/serial/telnet transport, session registration | App Store (registers controls + session), AI Store (rebind on reconnect) |

## Data Flow: Command Proposal to Execution

### Current Single-Tab Flow

```
1. User sends message
   ChatPanel.send() -> ai.sendMessage(tabId, text)
       -> invoke("ai_user_message", { tabId, text })

2. Backend AI actor proposes command
   Rust emits event: ai:command_proposed:<tabId>
       -> AI Store listener pushes ChatItem{kind:"command"} to _chatByTab
       -> Sets _pendingByTab[tabId] = proposed

3. ChatPanel renders CommandConfirmDialog
   Props: tabId, targetKind, targetSessionId, cmd, result, rejected

4. User approves (or auto-approve fires)
   CommandConfirmDialog.approve()
       -> ai.executeCommand(tabId, proposed, targetKind, targetSessionId)

5. executeCommand pastes command into PTY
   - Determines transport: TRANSPORT[targetKind] -> { write, data }
   - Listens on `${dataEvent}:${targetSessionId}` for output
   - invoke(writeCmd, { sessionId: targetSessionId, data: [...cmd + Enter] })
   - Watches for sentinel in output buffer
   - On sentinel hit: invoke("ai_command_result", { tabId, toolCallId, exitCode, output, ... })

6. Backend processes result, may propose next command
   Rust emits: ai:command_completed:<tabId>
       -> AI Store clears pending, attaches result to ChatItem
```

### Key Architectural Facts

1. **AI session is 1:1 with tab** (`_sessionByTab[tabId]`). The AI actor's lifetime equals the tab's lifetime.

2. **`executeCommand` targets a single terminal** via `target_session_id` — it pastes the full command string into one PTY and listens on that PTY's data event for sentinel output.

3. **`broadcastToSessions(tabIds, text)` is transport-agnostic** — it iterates `tabIds`, calls `_terminalControls.get(tabId)?.sendText(text)` for each. The pane's `sendText` handles EOL transform, slow-send, etc.

4. **Terminal controls registration** happens per-pane on mount:
   ```typescript
   app.registerTerminalControls(tabId, {
     getSelection, paste, sendText, focus, readViewport, readViewportText
   });
   ```

5. **Session registry** tracks all connected terminals:
   ```typescript
   interface SessionEntry { tabId: string; sessionId: string; type: "ssh"|"local"|"serial"|"telnet"; }
   ```
   Registered in a `$effect` inside TerminalPane when `sessionId && !disconnected`.

## How Broadcast Fits Into Existing Architecture

### Integration Point: Between Approval and Execution

The broadcast insertion point is **after approval, before/during execution**. The current flow:

```
approve() -> ai.executeCommand(tabId, proposed, targetKind, targetSessionId)
```

For broadcast mode, the approved command text needs to additionally flow through:

```
approve() -> ai.executeCommand(...)          // primary tab (watches output)
           -> app.broadcastToSessions(       // broadcast targets (fire-and-forget)
                broadcastTabIds,
                proposed.cmd + Enter
              )
```

### Why This Split Works

- **Primary tab**: Full sentinel-based execution with output capture and exit code. AI gets the result.
- **Broadcast targets**: Fire-and-forget text injection via existing `broadcastToSessions`. No output capture needed (PROJECT.md explicitly scopes this out).
- **Transport handling**: `broadcastToSessions` routes through each pane's `sendText`, which already handles per-transport EOL and slow-send — no new transport logic.

### Suggested Implementation Architecture

```
+---------------------------+
|  AI Store (store.svelte)  |
+---------------------------+
|  + broadcastMode: boolean |  (per-tab state, new)
|  + broadcastTargets:      |  (per-tab Set<tabId>, new)
|    string[]               |
+---------------------------+
        |
        | executeCommand() checks broadcastMode
        | if ON: also calls app.broadcastToSessions(targets, cmd)
        v
+---------------------------+
|  App Store (app.svelte)   |
+---------------------------+
|  broadcastToSessions()    |  (existing, unchanged)
|  connectedSessions()      |  (existing, for target picker)
+---------------------------+
```

### Component Changes

| Component | Change | Rationale |
|-----------|--------|-----------|
| AI Store | Add `_broadcastModeByTab`, `_broadcastTargetsByTab` state | Per-tab broadcast config, survives panel close/reopen |
| AI Store | Modify `executeCommand` or add post-approval hook | Dispatch to broadcast targets after primary execution starts |
| ChatPanel | Add broadcast toggle button + target selector UI | User controls which tabs receive broadcast |
| CommandConfirmDialog | Show broadcast indicator when mode is on | User sees that approval will fan out |
| App Store | No changes | `broadcastToSessions` and `connectedSessions()` already exist |
| TerminalPane | No changes | Already registers `sendText` via terminal controls |

### State Location Decision

Broadcast state belongs in **AI Store** (not App Store) because:

1. It's AI-feature-specific — only relevant when AI panel is active
2. It's per-tab, matching AI session's tab-indexed model
3. It needs to be read during `executeCommand` (AI Store's own function)
4. The target list should persist across panel close/reopen (same as AI session itself)

### Broadcast Dispatch Detail

```typescript
// In AI Store, after primary executeCommand succeeds in pasting to PTY:
if (_broadcastModeByTab[tab_id]) {
    const targets = _broadcastTargetsByTab[tab_id] ?? [];
    // Exclude the primary tab (it already got the command via executeCommand)
    const others = targets.filter(id => id !== tab_id);
    if (others.length > 0) {
        // Use the raw user-visible command, not full_cmd (which has sentinel)
        // broadcastToSessions is parallel (iterates synchronously)
        app.broadcastToSessions(others, proposed.cmd + "\n");
    }
}
```

Critical detail: broadcast sends `proposed.cmd` (the human-readable command), NOT `proposed.full_cmd` (which wraps with sentinel + exit-code echo). Broadcast targets are fire-and-forget; sentinel output from them would confuse anything watching their PTY.

## Patterns to Follow

### Pattern 1: Per-Tab Indexed State (established convention)

**What:** All AI state is `Record<string, T>` keyed by `tabId`.
**When:** Any new per-session feature.
**Example:**
```typescript
let _broadcastModeByTab = $state<Record<string, boolean>>({});
let _broadcastTargetsByTab = $state<Record<string, string[]>>({});

export function isBroadcastMode(tab_id: string): boolean {
    return _broadcastModeByTab[tab_id] === true;
}
export function setBroadcastMode(tab_id: string, on: boolean) {
    _broadcastModeByTab[tab_id] = on;
}
export function broadcastTargets(tab_id: string): string[] {
    return _broadcastTargetsByTab[tab_id] ?? [];
}
export function setBroadcastTargets(tab_id: string, targets: string[]) {
    _broadcastTargetsByTab[tab_id] = targets;
}
```

### Pattern 2: Toolbar Button in ChatPanel

**What:** Feature toggles live in ChatPanel's `.toolbar` div as `btn-icon` buttons.
**When:** Adding a panel-level control.
**Example:** Follow the DangerModeToggle pattern — a separate component for complex toggle logic, rendered inline via snippet slot.

### Pattern 3: Session Cleanup on Tab Close

**What:** `app.closeTab(id)` calls `ai.stopSession(id)` — any broadcast state for that tab must also be cleaned.
**When:** Tab state has per-tab entries.
**Example:** In `stopSession`, add cleanup:
```typescript
delete _broadcastModeByTab[tab_id];
delete _broadcastTargetsByTab[tab_id];
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Modifying broadcastToSessions

**What:** Adding broadcast-mode awareness inside `app.broadcastToSessions`.
**Why bad:** This function is used by EditPane for its own broadcast workflow. Coupling AI broadcast logic into it creates cross-feature dependency.
**Instead:** Call `broadcastToSessions` as a consumer from AI Store; keep the function a dumb "send text to these tabs" primitive.

### Anti-Pattern 2: Awaiting Broadcast Targets

**What:** Making broadcast execution sequential or awaiting results from broadcast targets.
**Why bad:** PROJECT.md constraint says broadcast must be parallel. Waiting would block the AI flow for N terminals.
**Instead:** Fire-and-forget. `broadcastToSessions` is already synchronous (iterates and calls `sendText` which internally does `invoke(writeCmd, ...)` — the invoke is async but not awaited in the loop).

### Anti-Pattern 3: Storing Broadcast State in localStorage

**What:** Persisting broadcast targets across app restarts.
**Why bad:** Tab IDs are ephemeral (UUID per session). Persisted target lists would reference dead tabs on next launch.
**Instead:** Session-scoped state only. The toggle (on/off) could persist per-profile if desired later, but target selection is always runtime.

### Anti-Pattern 4: Broadcasting full_cmd (with sentinel)

**What:** Sending the sentinel-wrapped command to broadcast targets.
**Why bad:** Broadcast targets would echo `__rssh_done_<uuid>:<exit_code>` into their terminal — meaningless noise for the user, and if any listener is watching that PTY (e.g., another AI session), it would incorrectly parse it.
**Instead:** Always broadcast `proposed.cmd` (the raw command the user sees).

## Scalability Considerations

| Concern | 5 tabs | 20 tabs | 100+ tabs |
|---------|--------|---------|-----------|
| Broadcast dispatch | Trivial — synchronous loop | Fine — 20 `invoke` calls are sub-ms each | May want to batch or chunk; Tauri IPC is per-call |
| Target selector UI | Checkbox list | Scrollable list with search | Group-based selection ("all SSH", "all in group X") |
| State cleanup | Manual delete per key | Still fine | Consider a WeakMap or centralized cleanup hook |

## Sources

- `src/lib/stores/app.svelte.ts` — Session registry, broadcastToSessions, terminal controls
- `src/lib/ai/store.svelte.ts` — AI session lifecycle, executeCommand, per-tab state model
- `src/lib/ai/ChatPanel.svelte` — AI panel UI, toolbar pattern, props contract
- `src/lib/ai/CommandConfirmDialog.svelte` — Approval flow, auto-approve, execution trigger
- `src/lib/components/TerminalPane.svelte` — Session registration, terminal controls registration
- `src/lib/components/AppShell.svelte` — Layout composition, AI panel visibility gate
- `.planning/PROJECT.md` — Requirements, constraints, key decisions
