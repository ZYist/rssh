# Technology Stack

**Project:** AI Broadcast Mode (RSSH)
**Researched:** 2026-07-08

## Existing Stack (Relevant to Broadcast Mode)

This documents the patterns already in the codebase that the broadcast feature builds upon. No new dependencies are needed.

### Core Framework

| Technology | Version | Purpose | File Reference |
|------------|---------|---------|----------------|
| Svelte 5 | ^5 | UI framework with runes reactivity | `package.json` |
| Tauri 2 | ^2 | Desktop shell, Rust backend | `package.json` (@tauri-apps/api ^2) |
| TypeScript | ^5.6 | Type-safe frontend | `package.json` |
| Rust (Tokio) | — | Backend async runtime, AI session actor | `src-tauri/src/ai/session.rs` |

### Terminal & Editor

| Technology | Version | Purpose | File Reference |
|------------|---------|---------|----------------|
| xterm.js | 6.0.0 | Terminal rendering | `package.json` (@xterm/xterm) |
| CodeMirror 6 | ^6.0.2 | Broadcast editor (EditPane) | `package.json` (codemirror) |

### AI Backend (Rust)

| Module | Purpose | File Reference |
|--------|---------|----------------|
| `ai::session` | Actor per tab; manages LLM conversation loop | `src-tauri/src/ai/session.rs` |
| `ai::commands` | Tauri command entry points (invoke bridge) | `src-tauri/src/ai/commands.rs` |
| `ai::tools` | Tool call definitions (run_command, file_ops, etc.) | `src-tauri/src/ai/tools.rs` |
| `ai::llm` | Multi-provider LLM clients (Anthropic, OpenAI, DeepSeek, GLM) | `src-tauri/src/ai/llm/` |
| `ai::sanitize` | Redaction + command blacklist enforcement | `src-tauri/src/ai/sanitize.rs` |

## State Management Patterns

### Svelte 5 Runes (Module-level Stores)

The codebase uses **module-level `$state` variables** exported as getter functions. No class-based stores, no Svelte stores API (`writable`/`readable`). This is the canonical pattern for the broadcast feature to follow.

```typescript
// Pattern: module-level reactive state (src/lib/ai/store.svelte.ts)
let _sessionByTab = $state<Record<string, AiSessionInfo>>({});
let _chatByTab = $state<Record<string, ChatItem[]>>({});

// Getter functions (not direct export of $state)
export function sessionForTab(tab_id: string): AiSessionInfo | undefined {
  return _sessionByTab[tab_id];
}

// Derived values in components
let session = $derived(ai.sessionForTab(tabId));
```

**Key conventions:**
- State indexed by `tab_id` (the stable identity; survives reconnects)
- Private `_foo` naming with exported getter functions
- `$derived` in components for reactive reads
- `$effect` for side-effect reactions (e.g., prefill, auto-scroll)
- Direct mutation of `$state` proxy properties (Svelte 5 tracks field assignments)

### Where Broadcast State Should Live

Based on existing patterns, broadcast mode state belongs in `src/lib/ai/store.svelte.ts` alongside the existing AI session state:

```typescript
// Broadcast mode: per-tab state (follows existing _*ByTab pattern)
let _broadcastEnabled = $state<Record<string, boolean>>({});
let _broadcastTargets = $state<Record<string, Set<string>>>({});
```

This mirrors how `_pendingByTab`, `_keyboardLockedByTab`, and `_tokensByTab` are structured.

## IPC Architecture

### Frontend → Backend (Tauri `invoke`)

Synchronous request/response. The AI module exposes commands prefixed `ai_*`:

| Command | Purpose | File |
|---------|---------|------|
| `ai_session_start` | Create actor for a tab | `commands.rs` |
| `ai_session_stop` | Destroy actor | `commands.rs` |
| `ai_user_message` | Send user text to LLM | `commands.rs` |
| `ai_command_result` | Report PTY execution output | `commands.rs` |
| `ai_command_reject` | User rejected proposed command | `commands.rs` |
| `ai_cancel_stream` | Abort streaming LLM response | `commands.rs` |
| `ssh_write` / `pty_write` / `serial_write` / `telnet_write` | Write bytes to terminal | transport modules |

### Backend → Frontend (Tauri Events)

Async push, namespaced by `ai:<event>:<tab_id>`:

| Event | Payload | Purpose |
|-------|---------|---------|
| `ai:command_proposed:<tab_id>` | `CommandProposed` | LLM wants to run a command |
| `ai:command_executing:<tab_id>` | `{ id, lock_keyboard }` | Command approved, executing |
| `ai:command_completed:<tab_id>` | `CommandResult` | Execution finished |
| `ai:assistant_delta:<tab_id>` | `{ id, text }` | Streaming token |
| `ai:error:<tab_id>` | `{ message }` | Error in session |

### Terminal Data Flow (PTY Events)

Terminal output flows via events namespaced by transport and session ID:

| Event Pattern | Transport |
|---------------|-----------|
| `ssh:data:<session_id>` | SSH |
| `pty:data:<session_id>` | Local PTY |
| `serial:data:<session_id>` | Serial |
| `telnet:data:<session_id>` | Telnet |

## Command Execution Flow (Critical for Broadcast)

The command execution path is entirely frontend-driven. This is the path that broadcast mode must intercept:

```
1. Backend emits `ai:command_proposed:<tab_id>` with CommandProposed
2. Frontend shows CommandConfirmDialog
3. User clicks Approve (or auto-approve if danger_mode + auto_run_command)
4. Frontend calls ai.executeCommand(tab_id, proposed, targetKind, targetSessionId)
   - Registers PTY data listener for sentinel
   - Invokes transport write (ssh_write/pty_write/etc.) with full_cmd
   - Waits for sentinel in PTY output stream
5. Sentinel detected → extracts output + exit code
6. Frontend invokes ai_command_result → backend continues LLM loop
```

**Broadcast insertion point:** Between step 3 and step 4. After approval, additionally call `broadcastToSessions(targetTabIds, cmd.cmd + "\n")` for the broadcast targets. The broadcast targets only get the raw command (no sentinel wrapping), so they execute silently.

## Existing Broadcast Infrastructure

### `broadcastToSessions` (app.svelte.ts:466)

```typescript
export function broadcastToSessions(tabIds: string[], text: string) {
  for (const tabId of tabIds) {
    _terminalControls.get(tabId)?.sendText(text);
  }
}
```

Routes through each pane's `sendText` — which handles transport-specific concerns (serial EOL transform, slow-send). This is the correct primitive for AI broadcast too.

### `pickBroadcastText` (broadcast-text.ts)

Utility for the EditPane's "selection or whole doc" logic. Not directly relevant to AI broadcast (AI sends the approved command string).

### Session Registry (app.svelte.ts)

```typescript
interface SessionEntry {
  tabId: string;
  sessionId: string;
  type: "ssh" | "local" | "serial" | "telnet";
}
let _sessions = $state<SessionEntry[]>([]);
export function connectedSessions(): SessionInfo[] { ... }
export function registerSession(info: SessionEntry) { ... }
```

The broadcast target selector already exists in `EditPane.svelte` — it uses `connectedSessions()` to list available targets and lets the user toggle each. The AI broadcast feature should reuse this exact pattern.

### EditPane Target Selection Pattern

```svelte
<!-- EditPane.svelte — reusable pattern for target selection -->
let sessions = $derived(app.connectedSessions());
let selectedTabIds = $state<Set<string>>(new Set());

// Auto-prune disconnected sessions
$effect(() => {
  const activeIds = new Set(sessions.map(s => s.tabId));
  const pruned = [...selectedTabIds].filter(id => activeIds.has(id));
  if (pruned.length !== selectedTabIds.size) selectedTabIds = new Set(pruned);
});
```

## Transport Routing

The codebase maps `AiTargetKind` to write commands and data events:

```typescript
const TRANSPORT: Record<AiTargetKind, { write: string; data: string }> = {
  ssh:    { write: "ssh_write",    data: "ssh:data" },
  local:  { write: "pty_write",    data: "pty:data" },
  serial: { write: "serial_write", data: "serial:data" },
  telnet: { write: "telnet_write", data: "telnet:data" },
};
```

Broadcast does NOT need this directly — `broadcastToSessions` abstracts the transport via each pane's registered `sendText`. The pane owns EOL / slow-send transforms.

## Component Hierarchy (AI Panel)

```
AppShell
  └── ChatPanel (props: tabId, targetKind, targetId)
        ├── Input area + send button
        ├── Chat timeline (ChatItem[])
        │     └── CommandConfirmDialog (per command card)
        │           ├── Approve → ai.executeCommand(...)
        │           └── Reject → ai.rejectCommand(...)
        ├── DangerModeToggle
        └── AuditPanel (modal)
```

The broadcast toggle and target selector would live inside `ChatPanel`, near the `DangerModeToggle` — conceptually the same "mode switch" area.

## Key Architectural Decisions for Broadcast

| Decision | Rationale |
|----------|-----------|
| State in `ai/store.svelte.ts`, not a new file | Follows existing per-tab state pattern; broadcast is part of AI session semantics |
| Use `broadcastToSessions` for dispatch | Already handles transport abstraction; tested in EditPane |
| No backend changes for basic broadcast | Broadcast is a frontend routing concern; backend stays single-tab |
| Broadcast sends raw command (no sentinel) | Other tabs don't need output collection; AI only reads the active tab |
| Raw devices excluded by default | `isRawDeviceKind` gate; explicit opt-in required (PROJECT.md constraint) |
| Parallel dispatch (Promise.all not needed) | `broadcastToSessions` is synchronous iteration over `sendText`; each pane's write is fire-and-forget to its transport invoke |

## No New Dependencies Required

The broadcast feature is a pure frontend routing extension:
- State: Svelte 5 `$state` / `$derived` (already used)
- IPC: `broadcastToSessions` (already exists)
- UI: Svelte components (already the pattern)
- Persistence: `localStorage` or Tauri `get_setting`/`set_setting` (already used for other toggles)

## Sources

All findings from direct codebase analysis:
- `src/lib/ai/store.svelte.ts` — AI state management, executeCommand flow
- `src/lib/ai/types.ts` — Type definitions, AiTargetKind, CommandProposed
- `src/lib/stores/app.svelte.ts` — Session registry, broadcastToSessions, TerminalControls
- `src/lib/components/EditPane.svelte` — Existing broadcast UI pattern
- `src/lib/terminal/broadcast-text.ts` — Broadcast text utility
- `src/lib/ai/ChatPanel.svelte` — AI panel component structure
- `src/lib/ai/CommandConfirmDialog.svelte` — Command approval flow
- `src-tauri/src/ai/session.rs` — Backend actor architecture
- `src-tauri/src/ai/commands.rs` — Tauri command bridge
- `.planning/PROJECT.md` — Project constraints and requirements
