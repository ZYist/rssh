# Feature Landscape: AI Broadcast Mode

**Domain:** AI-assisted multi-terminal command broadcast
**Researched:** 2026-07-08

## AI Command Execution Pipeline (Current State)

The full flow from AI proposing a command to execution result:

### Step 1: User sends message
- `ChatPanel.send()` calls `ai.ensureSession()` (lazy start) then `ai.sendMessage(tabId, text)`
- Backend `ai_user_message` invoke pushes text to the Rust actor

### Step 2: LLM proposes a command
- Backend emits `ai:command_proposed:<tab_id>` event with a `CommandProposed` payload
- Payload contains: `id`, `tool_call_id`, `cmd` (display), `full_cmd` (with sentinel + exit-code echo), `sentinel`, `explain`, `side_effect`, `timeout_s`, `kind`
- Store listener pushes a `{ kind: "command", cmd }` ChatItem to the timeline
- `CommandConfirmDialog` renders as an approval card in the chat

### Step 3: User approves (or auto-approve in danger mode)
- `CommandConfirmDialog.approve()` is called (manually or by `onMount` auto-approve logic)
- Auto-approve path: `danger_mode === true` AND `autoApproveAllowed(settings, cmd.kind)` AND not a raw device
- Calls `ai.executeCommand(tabId, cmd, targetKind, targetSessionId)`

### Step 4: Command execution (`executeCommand` in store)
- Re-entrancy guard via `_runningExecutions` Map (keyed by `tool_call_id`)
- Determines transport: `TRANSPORT[targetKind]` maps to `{ write: "ssh_write"|"pty_write"|"serial_write"|"telnet_write", data: "ssh:data"|"pty:data"|... }`
- Listens on `${dataEvent}:${targetSessionId}` for PTY output
- Writes `proposed.full_cmd + "\r"` (or `"\r\n"` for telnet) via `invoke(writeCmd, { sessionId, data })`
- Starts timeout timer (`proposed.timeout_s * 1000`)
- On each chunk: appends to `CappedBuffer`, calls `findSentinel()` to detect completion
- On sentinel hit or timeout: calls `finish()` which invokes `ai_command_result` to backend

### Step 5: Result returned to LLM
- Backend receives `ai_command_result` with `{ exitCode, output, timedOut, earlyTerminated }`
- Emits `ai:command_completed:<tab_id>` event
- Store updates the ChatItem with the result
- LLM processes the output and continues the conversation

### Key Properties
- **Single-target**: `executeCommand` takes exactly one `target_session_id`
- **Sentinel-based**: SSH/local commands embed a unique sentinel to detect exit; raw devices (serial/telnet) rely on user-driven "submit output"
- **Front-end driven**: The backend never executes commands directly; it's the frontend that pastes into the PTY
- **Blocking promise**: `executeCommand` returns a Promise that resolves only when `finish()` runs

---

## Edit Pane Broadcast (Current State)

The Edit pane is a dedicated tab type (`type: "edit"`) with a CodeMirror editor and a session selector panel.

### End-to-End Flow

1. **Session registry**: `app.svelte.ts` maintains `_sessions: SessionEntry[]` (tabId, sessionId, type)
   - Populated by `registerSession()` when any terminal connects
   - `connectedSessions()` returns all entries enriched with tab labels

2. **Target selection**: EditPane renders all connected sessions as toggleable buttons
   - `selectedTabIds: Set<string>` tracks which tabs are broadcast targets
   - `selectAll()` / `selectNone()` convenience actions
   - Stale entries pruned via `$effect` when sessions disconnect

3. **Text picking**: `pickBroadcastText(doc, ranges)` from `broadcast-text.ts`
   - If selection exists: sends selected text (multi-cursor joined with newlines)
   - If no selection: sends entire document
   - Caller appends `"\n"` (Enter) after the picked text

4. **Broadcast dispatch**: `app.broadcastToSessions(tabIds, text)`
   - Iterates `tabIds`, calls `_terminalControls.get(tabId)?.sendText(text)` for each
   - `sendText` is registered per-pane via `registerTerminalControls`
   - Each pane's `sendText` handles its own transport rules (serial EOL transform, slow-send, etc.)
   - **Parallel by nature**: no awaiting, no sequencing, all fire simultaneously

### Key Properties
- **Transport-agnostic**: `broadcastToSessions` delegates EOL/encoding to each pane's registered `sendText`
- **No output collection**: broadcast is fire-and-forget; no result aggregation
- **No approval**: text goes straight to terminals; no confirmation step
- **Stateless**: no persistent broadcast target memory; user re-selects each time

---

## Gap Analysis: Bridging AI Commands to Broadcast

| Aspect | Current AI Flow | Current Broadcast | Gap to Bridge |
|--------|----------------|-------------------|---------------|
| Target | Single `targetSessionId` | Multiple `tabIds` | Need multi-target dispatch after approval |
| Approval | Per-command card in chat | None (direct) | Keep existing approval; broadcast happens post-approve |
| Execution | `executeCommand` with sentinel tracking | `broadcastToSessions` (raw text) | Broadcast targets get raw `cmd` text, NOT `full_cmd` with sentinel |
| Output | Captures output from single PTY | No output collection | AI reads only primary target; broadcast targets execute silently |
| Transport | Determined by `targetKind` | Per-pane `sendText` handles it | Broadcast can reuse `broadcastToSessions` which already handles per-pane transport |
| Result | exitCode + output sent to backend | None | Only primary target's result feeds back to LLM |

### Critical Design Decision

The broadcast targets should receive the **user-facing command** (`cmd` field, not `full_cmd`) because:
- `full_cmd` contains a sentinel string and exit-code echo specific to one PTY listener
- Multiple sentinels would create listener confusion
- The AI only needs output from the primary target (per PROJECT.md: "AI reads only current tab output")

The correct approach: after `executeCommand` completes on the primary target, broadcast the raw `cmd` text (with newline) to the selected broadcast targets via `broadcastToSessions`.

---

## Table Stakes

Features the broadcast mode must have to be useful.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Broadcast toggle in AI panel toolbar | Users need to turn it on/off without leaving the panel | Low | Single icon button, same pattern as danger-mode toggle |
| Target session selector | Users must choose which tabs receive broadcasts | Medium | Can reuse EditPane's session list pattern with minimaps |
| Post-approval dispatch | Approved command must auto-send to targets | Low | Hook into `approve()` success path, call `broadcastToSessions` |
| Per-tab state persistence | Switching tabs should not lose broadcast mode / selection | Low | Store in `$state` map keyed by tabId (same as `_sftpOpenByTab` pattern) |
| Raw device exclusion by default | Serial/telnet too sensitive for auto-broadcast | Low | Filter by `isRawDeviceKind` in the selector, require explicit opt-in |

## Differentiators

Features that add value beyond the minimum.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Visual feedback per-target | Show which targets received the command (checkmark/spinner) | Medium | Ephemeral status per broadcast event |
| Broadcast-only commands | Send text to targets without AI involvement (quick entry in panel) | Low | Thin text input that bypasses AI, goes straight to `broadcastToSessions` |
| Session minimap previews | Same hover-preview as EditPane for selecting targets | Low | Reuse `SessionMinimap` + `SessionPreviewPopover` components |
| Selective broadcast per-command | Override broadcast targets for a specific command | High | Requires per-card UI; likely over-engineering for v1 |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Aggregate multi-target output to AI | Blows up context window; N terminals * output is unmanageable | AI reads only primary target; user reviews others manually |
| Per-target sentinel tracking | Complex listener management, timing issues, unclear UX for partial failures | Fire-and-forget broadcast; primary target is the source of truth |
| Different commands per target | Not broadcast semantics; becomes orchestration | Keep it simple: same command, all targets |
| Auto-enable broadcast on session connect | Surprising behavior; could cause accidental mass-execution | Always off by default; explicit user action to enable + select targets |

## Feature Dependencies

```
Session Registry (existing) --> Target Selector UI --> Broadcast Dispatch
Danger Mode Toggle (existing UX pattern) --> Broadcast Toggle Button
executeCommand (existing) --> Post-Approval Hook --> broadcastToSessions (existing)
```

## UX Patterns for Mode Toggles in This App

Existing toggle patterns to follow for consistency:

| Toggle | Location | Mechanism | Visual Language |
|--------|----------|-----------|----------------|
| Danger Mode | AI panel toolbar | `DangerModeToggle` component with confirmation modal | Icon button, `.on` class adds colored background tint |
| SFTP | Per-tab | `_sftpOpenByTab` record keyed by tabId | Panel appears/disappears |
| Command Block Bar | Global | `_commandBlockBar` boolean persisted to settings DB | Sidebar shows/hides |
| Copy on Select | Global | `_copyOnSelect` persisted via `invoke("set_setting")` | Settings toggle |

**Recommended pattern for Broadcast Mode toggle:**
- Toolbar icon button (same row as danger-mode, audit, clear, close)
- Per-tab state in a `$state<Record<string, boolean>>` (mirrors `_sftpOpenByTab`)
- `.on` class with accent-colored background tint (differentiate from danger's red)
- No confirmation modal needed (unlike danger mode, broadcast is not inherently dangerous -- the approval card is the safety gate)
- Target selector panel slides in below toolbar or as a collapsible section above the chat

## MVP Recommendation

Prioritize:
1. **Broadcast toggle button** in AI panel toolbar (per-tab state)
2. **Target selector** panel (reuse `connectedSessions()` + `SessionMinimap` from EditPane)
3. **Post-approval hook** in `CommandConfirmDialog.approve()` that calls `broadcastToSessions` with the raw `cmd` text

Defer:
- Per-command target override: adds UI complexity without proportional value in v1
- Broadcast status feedback: fire-and-forget is sufficient for initial release
- Broadcast-only quick input: can be added later as an enhancement

## Sources

- `src/lib/ai/store.svelte.ts` — `executeCommand`, `_runningExecutions`, event listeners
- `src/lib/ai/CommandConfirmDialog.svelte` — approval flow, auto-approve, danger mode
- `src/lib/ai/ChatPanel.svelte` — session lifecycle, send flow, toolbar pattern
- `src/lib/ai/types.ts` — `CommandProposed`, `CommandKind`, `AiTargetKind`
- `src/lib/stores/app.svelte.ts` — `broadcastToSessions`, session registry, `_terminalControls`
- `src/lib/components/EditPane.svelte` — broadcast UI pattern, session selector, minimap
- `src/lib/terminal/broadcast-text.ts` — text picking logic
- `.planning/PROJECT.md` — project requirements and constraints
