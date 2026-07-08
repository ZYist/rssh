<!-- refreshed: 2026-07-08 -->
# Architecture

**Analysis Date:** 2026-07-08

## System Overview

RSSH is a cross-platform SSH client built as a Tauri 2.x app: a Rust backend (`src-tauri/`) compiled to three binaries that share one `rssh_lib` core, and a Svelte 5 frontend (`src/`) running in a webview. The same frontend runs unchanged inside the desktop GUI, on mobile (Android), and headless inside a JetBrains IDE tool window via a WebSocket IPC shim.

```text
┌──────────────────────────────────────────────────────────────────┐
│                       Frontend (Svelte 5 + xterm.js)              │
│  `src/App.svelte` → `src/lib/components/AppShell.svelte`          │
├───────────────┬────────────────┬──────────────┬──────────────────┤
│  Tab shell    │ TerminalPane   │  AI ChatPanel│  Settings/Editors│
│ `AppShell`    │ `TerminalPane` │ `ChatPanel`  │  `*Settings`     │
│ `app.svelte.ts`│ `osc/handler` │ `store.svelte`│  `*Manager`     │
└───────┬───────┴────────┬───────┴───────┬──────┴────────┬─────────┘
        │ invoke()       │ OSC 7337      │ listen()      │
        ▼                ▼ (CLI↔GUI)     ▼ events        ▼
┌──────────────────────────────────────────────────────────────────┐
│            Tauri IPC boundary (invoke / listen)                   │
│   `src/lib/ipc-shim.ts` — emulates Tauri over WebSocket off-host  │
└───────────────────────────────┬──────────────────────────────────┘
                                │
        ▼                       ▼                       ▼
┌──────────────────┐  ┌──────────────────┐  ┌─────────────────────┐
│  GUI binary rssh │  │ CLI rssh-cli     │  │ Headless rssh-server│
│ `src-tauri/.../  │  │ `src-tauri/.../  │  │ `src-tauri/src/     │
│   main.rs`       │  │   bin/rssh/`     │  │   server_main.rs`   │
│  (Tauri webview) │  │ (DB direct,      │  │ (WS + embedded      │
│                  │  │  clap, TUI)      │  │  dist/, IDEA only)  │
└────────┬─────────┘  └────────┬─────────┘  └──────────┬──────────┘
         │ all three share    │                       │
         └────────────────────┴───────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                `rssh_lib` — shared Rust core                       │
│  `src-tauri/src/lib.rs` (module root + generate_handler!)         │
│  commands/  ssh/  ai/  db/  secret/  sync/  terminal/              │
│  state.rs (AppState) · models.rs · error.rs · emitter.rs          │
└──────────────────────────┬───────────────────────────────────────┘
                           ▼
┌──────────────────┬──────────────────┬────────────────────────────┐
│ SQLite ~/.rssh/  │ Platform keychain│ russh SSH/SFTP/forward      │
│  rssh.db (WAL)   │ (master key)     │ portable-pty / serial /    │
│ `db/*.rs`        │ `secret/*.rs`    │ telnet transports           │
└──────────────────┴──────────────────┴────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| GUI entry | Thin `main.rs` calling `rssh_lib::run()` | `src-tauri/src/main.rs` |
| Lib entry / wiring | Module declaration, Tauri builder, plugin/window setup, `generate_handler!` registration table | `src-tauri/src/lib.rs` |
| Global runtime state | All live sessions, forwards, auth waiters, AI sessions, caches | `src-tauri/src/state.rs` |
| Command layer | `#[tauri::command]` functions invoked by the frontend | `src-tauri/src/commands/*.rs` |
| Command registry | Single `generate_handler!` macro listing every command | `src-tauri/src/lib.rs` (lines ~163-352) |
| Host abstraction | Transport-agnostic `emit`/`state` over Tauri OR headless WS | `src-tauri/src/emitter.rs` |
| SSH engine | russh wrapper, connect/PTY/data/auth chain | `src-tauri/src/ssh/client.rs` |
| SFTP | russh-sftp wrapper, file ops, transfer streaming | `src-tauri/src/ssh/sftp.rs` |
| Port forwarding | local/remote/dynamic forward lifecycle + stats | `src-tauri/src/ssh/forward.rs` |
| Local PTY (desktop) | portable-pty local shell sessions | `src-tauri/src/terminal/pty.rs` |
| Serial (desktop) | serialport console transport | `src-tauri/src/terminal/serial.rs` |
| Telnet (all platforms) | plain-TCP telnet transport | `src-tauri/src/terminal/telnet.rs` |
| Database | rusqlite (bundled) + per-domain CRUD modules | `src-tauri/src/db/mod.rs` + `db/*.rs` |
| Schema/migrations | Table creation + versioned migrate; in-test `open_in_memory()` | `src-tauri/src/db/schema.rs`, `src-tauri/src/migration/` |
| Secret storage | Master-key envelope encryption; keychain or file backend | `src-tauri/src/secret/mod.rs` |
| AI engine | Diagnose sessions, LLM streaming, redaction, tool calls | `src-tauri/src/ai/` |
| Sync | Export/import config; GitHub + WebDAV push/pull | `src-tauri/src/sync/config.rs` |
| CLI | clap commands; reads/writes DB directly, no Tauri IPC | `src-tauri/src/bin/rssh/main.rs` |
| Headless server | WS server embedding `dist/` for JetBrains plugin | `src-tauri/src/server.rs` |
| Frontend entry | Mount + IPC shim boot + startup preheat | `src/main.ts`, `src/lib/ipc-boot.ts` |
| Root component | Welcome screen, onMount preheat, AppShell | `src/App.svelte` |
| Tab shell / dispatcher | Tab list, panes, AI side panel, context menus | `src/lib/components/AppShell.svelte` |
| Terminal pane | xterm.js, block detection, highlight injection, auth modals | `src/lib/components/TerminalPane.svelte` |
| Global UI state | Tabs, settings nav, profiles, forwards, toasts | `src/lib/stores/app.svelte.ts` |
| AI frontend state | Per-tab AI sessions, chat timeline, settings | `src/lib/ai/store.svelte.ts` |
| IPC shim | Lets frontend run off-Tauri over WebSocket | `src/lib/ipc-shim.ts` |
| OSC handler | CLI↔GUI embedded-terminal protocol (OSC 7337) | `src/lib/osc/handler.ts` |
| Keyboard shortcuts | Global keybinding registry + keymap | `src/lib/keyboard/registry.ts`, `keymap.ts` |
| Themes | Palette presets + theme store + terminal palettes | `src/lib/themes/store.svelte.ts`, `palettes.ts` |
| i18n | Translation function `t()` + locale catalogs | `src/lib/i18n/index.svelte.ts`, `locales/{en,zh}.ts` |

## Pattern Overview

**Overall:** Layered Tauri 2.x desktop/mobile app with a Tauri command (RPC) boundary between a Svelte 5 reactive frontend and a shared Rust core library. The same core backs three binaries (GUI / CLI / headless server).

**Key Characteristics:**
- **One frontend, three hosts.** The frontend imports `@tauri-apps/api` everywhere; `src/lib/ipc-shim.ts` installs a fake `__TAURI_INTERNALS__` over a WebSocket when the real webview global is absent (browser / JetBrains JCEF). Desktop behavior is unchanged.
- **Three binaries share `rssh_lib`.** `rssh` (GUI), `rssh-cli` (feature `cli`), `rssh-server` (feature `server`, JetBrains-only, lives outside `src/bin/` to dodge the Tauri bundler). All link `src-tauri/src/lib.rs`.
- **Svelte 5 runes only.** `$state` / `$derived` / `$effect` / `$props`; `onclick={fn}`. No legacy `$:` / `export let` / `on:click`.
- **Centralized frontend state.** All cross-page reactive state lives in `src/lib/stores/*.svelte.ts` as private `_x = $state(...)` plus exported getter functions. Never export raw `$state`, never build global state inside a component.
- **Sticky secret backend.** Master-key backend (keychain vs file) is probed once, persisted in `db.settings`, and never silently flipped — a flip would make existing ciphertext unreadable.
- **Coded error protocol.** Every `AppError` serializes to `__rssh_err__|{"code","params"}`. The frontend `errMsg()` decodes the prefix and localizes via the i18n catalog. There is no plain-string escape hatch.

## Layers

**Frontend UI layer:**
- Purpose: render tabs, terminals, settings, AI panel; handle user input.
- Location: `src/lib/components/*.svelte`, `src/lib/ai/*.svelte`, `src/lib/components/welcome/`
- Contains: Svelte 5 components; the tab dispatcher (`AppShell.svelte`); `TerminalPane.svelte` (~79KB, single-file terminal with highlight injection + auth modals).
- Depends on: `src/lib/stores/*.svelte.ts`, `src/lib/ai/store.svelte.ts`, `@tauri-apps/api` (invoke/listen).
- Used by: `src/App.svelte` root.

**Frontend state / logic layer:**
- Purpose: own global reactive state; pure helpers (terminal parsing, OSC, keyboard, themes, i18n).
- Location: `src/lib/stores/`, `src/lib/ai/`, `src/lib/terminal/`, `src/lib/osc/`, `src/lib/keyboard/`, `src/lib/themes/`, `src/lib/i18n/`, plus leaf `src/lib/*.ts` (`ipc-shim.ts`, `pick-file.ts`, `save-file.ts`, `local-drop.ts`).
- Contains: `$state`-backed stores with getter exports; pure functions paired with `*.test.ts`.
- Depends on: `@tauri-apps/api/core`, each other.
- Used by: components.

**Tauri command layer (RPC boundary):**
- Purpose: `#[tauri::command]` functions the frontend invokes by string name.
- Location: `src-tauri/src/commands/*.rs` (one file per domain: `profile`, `session`, `sftp`, `forward`, `sync`, `settings`, `pty`, `serial`, `telnet`, `window`, `ai::*`).
- Contains: argument parsing, calls into db/ssh/secret, returns `AppResult<T>`.
- Depends on: `state.rs` (`AppState`), `db/`, `ssh/`, `secret/`, `ai/`, `emitter.rs`.
- Used by: frontend via `invoke("name")`; MUST be registered in `src-tauri/src/lib.rs` `generate_handler!`.

**Engine / domain layer (shared lib):**
- Purpose: the real work — SSH, SFTP, forward, PTY, serial, telnet, AI, sync, crypto.
- Location: `src-tauri/src/ssh/`, `src-tauri/src/terminal/`, `src-tauri/src/ai/`, `src-tauri/src/sync/`, `src-tauri/src/crypto.rs`.
- Contains: long-running async sessions keyed by tab id; auth flows via oneshot channels.
- Depends on: `russh`, `russh-sftp`, `portable-pty`, `serialport`, `reqwest`, `db/`, `secret/`.
- Used by: command layer, CLI helpers, headless server.

**Persistence layer:**
- Purpose: SQLite + platform keychain.
- Location: `src-tauri/src/db/`, `src-tauri/src/secret/`, `src-tauri/src/migration/`.
- Contains: `Db` (Mutex<Connection>) with per-table CRUD modules; `SecretStore` trait with `HybridStore` (ChaCha20-Poly1305 over DB) + keychain/file master-key backends.
- Depends on: `rusqlite` (bundled, WAL), `keyring` (platform), `chacha20poly1305`, `argon2`.
- Used by: command layer, CLI (`db::*` + `secret_store` direct), engine layer.

**CLI layer:**
- Purpose: `rssh` / `rssh-cli` terminal commands.
- Location: `src-tauri/src/bin/rssh/main.rs` + `commands/` (add/edit/rm/ls/open/config/completions) + `helpers/` (cred, ssh_builder, tui) + `ctx.rs`.
- Contains: clap dispatch; reads/writes DB and `SecretStore` directly (no Tauri). On Linux with no subcommand + a display server, forks the GUI binary.
- Depends on: `rssh_lib::{db, secret}`.
- Used by: end users from a terminal; the GUI's embedded terminal talks back via OSC 7337.

## Data Flow

### Primary Request Path — SSH connect + data

1. User clicks a profile in `HomeScreen.svelte` → `app.addTab({ type: "ssh", ... })`.
2. `TerminalPane.svelte` onMount → `invoke("ssh_connect", {...})` (`src-tauri/src/commands/session.rs`).
3. `ssh_connect` builds the session via `ssh/client.rs::connect()` (russh), registering an auth waiter in `AppState.auth_waiters` keyed by tab id.
4. On keyboard-interactive / passphrase / host-key challenges, backend emits `ssh:auth_prompt:{tabId}` / `ssh:passphrase_prompt:{tabId}` / `ssh:host_key_prompt:{tabId}` (`src-tauri/src/emitter.rs` via `Host::emit`).
5. `TerminalPane.svelte` shows a modal; user response → `invoke("ssh_auth_respond", {...})` resolves the `oneshot` channel in `AppState.auth_waiters`.
6. Backend spawns a reader task; every stdout chunk is emitted as `ssh:data:{tabId}` bytes.
7. `TerminalPane.svelte` `listen()` writes bytes into xterm; command-block detection + highlight injection run inline (`src/lib/terminal/*.ts`).
8. Keystrokes → `invoke("ssh_write", { id, data })` → writes to the PTY stream.

### CLI ↔ embedded-GUI flow (OSC 7337)

1. User runs `rssh open prod` inside the GUI's embedded local terminal.
2. CLI resolves the profile name from DB and emits the escape sequence `OSC 7337 ; open:prod ST` to stdout (`src-tauri/src/bin/rssh/commands/open.rs`).
3. The xterm parser in `TerminalPane.svelte` decodes it; `registerRsshOscHandlers` (`src/lib/osc/handler.ts`) routes `open` → `openProfile`.
4. `openProfile` calls `list_profiles` + `get_credential` and `app.addTab({...})` — the new SSH tab opens in the same GUI window.

### AI diagnose flow

1. User opens the AI side panel on a terminal tab → `ai.openPanel()` + `invoke("ai_session_start", { tab_id, target_kind, target_id })` (`src-tauri/src/ai/commands.rs`).
2. `ai_session_start` creates a `DiagnoseSession` (`src-tauri/src/ai/session.rs`) stored in `AppState.ai_sessions[ai_session_id]`.
3. User message → `invoke("ai_user_message", ...)` → redacts via `src-tauri/src/ai/sanitize.rs` + `redact_rules.rs` → streams to the LLM (`src-tauri/src/ai/llm/`).
4. Model proposes commands → emitted as `ai:command_proposed:{tabId}` → `CommandConfirmDialog.svelte`.
5. User approves → `invoke("ai_command_result", ...)` executes via `ssh_write`/`pty_write`; result feeds back into the session. Every step is audited (`src-tauri/src/ai/audit.rs`).

**State Management:**
- Backend: `AppState` (`src-tauri/src/state.rs`) is a single Tauri-managed struct of `Mutex<HashMap<...>>` tables. It is shared (Arc) across windows; clone windows inherit the same handle (`window.__rssh_clone`). On `WindowEvent::Destroyed`, only sessions owned by that window label are closed (`commands::lifecycle::close_window_sessions`).
- Frontend: Svelte 5 runes in `src/lib/stores/app.svelte.ts` (tabs, settings nav, profiles, toasts) and `src/lib/ai/store.svelte.ts` (per-tab AI sessions + chat timeline). Theme state in `src/lib/themes/store.svelte.ts`; transfer queue in `transfers.svelte.ts`.

## Key Abstractions

**Host (transport-agnostic host context):**
- Purpose: let the engine emit events and reach `AppState` identically whether it runs under Tauri or the headless WS server.
- Examples: `src-tauri/src/emitter.rs` (`Host::Tauri`, `Host::Headless`); engine call sites use `host.state()` / `host.emit()`.
- Pattern: enum dispatch wrapping `tauri::AppHandle` vs a sink closure + `Arc<AppState>`.

**AppState (global runtime tables):**
- Purpose: one struct holding every live session map and waiter map, managed by Tauri.
- Examples: `src-tauri/src/state.rs` — `sessions`, `pty_sessions`, `serial_sessions`, `telnet_sessions`, `sftp_sessions`, `active_forwards`, `auth_waiters`, `passphrase_waiters`, `host_key_waiters`, `passphrase_cache`, `ai_sessions`, `window_sessions`, `window_groups`.
- Pattern: `Mutex<HashMap<String, Handle>>`; per-window cleanup via `window_sessions` (window_label → session ids).

**Tab (frontend unit of UI):**
- Purpose: each open pane is a tab; type dispatches the renderer.
- Examples: `src/lib/stores/app.svelte.ts` `Tab` interface; dispatched in `AppShell.svelte` (`home` → `HomeScreen`; terminal types → `TerminalPane`; `forward` → `ForwardPane`; `edit` → `EditPane`).
- Pattern: id forms are `home` (literal), `<type>:<uuid>` (ssh/local/edit), `fwd:<forward_id>:<timestamp>`.

**SecretStore (secret abstraction):**
- Purpose: uniform get/set across platforms; never store secrets in DB plaintext.
- Examples: `src-tauri/src/secret/mod.rs` trait; `HybridStore` (ChaCha20-Poly1305 ciphertext in `secrets` table) + `master_key.rs` (keychain or `<data_dir>/master.key`).
- Pattern: master-key envelope encryption; sticky backend marker in `db.settings`.

**Db (SQLite wrapper):**
- Purpose: `Mutex<Connection>` exposed only through domain methods; `lock()` is `pub(in crate::db)`.
- Examples: `src-tauri/src/db/mod.rs`; per-table modules (`profile.rs`, `credential.rs`, ...); `with_transaction` / `with_exclusive_lock` for cross-process safety (GUI + CLI + server all write the same file).
- Pattern: WAL + `busy_timeout=5000`; in-memory test helper `open_in_memory()`.

**CodedMsg / AppError (i18n error protocol):**
- Purpose: every error carries a stable `code` + `params` for frontend localization.
- Examples: `src-tauri/src/error.rs`; frontend decodes the `__rssh_err__|{...}` Display output.
- Pattern: `thiserror` enum; `CodedMsg` newtype; `AppResult<T>` return type on all commands.

## Entry Points

**GUI binary `rssh`:**
- Location: `src-tauri/src/main.rs` → `rssh_lib::run()` (`src-tauri/src/lib.rs`).
- Triggers: user launches the app; Linux CLI forks it when no subcommand + display present.
- Responsibilities: init logger, apply Linux/Wayland compat env, register Tauri plugins (opener/dialog/fs), wire `on_window_event` (per-window session cleanup + move-together window groups), `setup` (open DB, open secret store, run migrations, scan shells, manage `AppState`), and the `generate_handler!` command registry.

**CLI binary `rssh-cli` (`rssh`):**
- Location: `src-tauri/src/bin/rssh/main.rs` (feature `cli`).
- Triggers: `rssh ls`, `rssh open <name>`, `rssh add/edit/rm`, `rssh config ...`.
- Responsibilities: clap parse → open `~/.rssh/rssh.db` + secret store directly → dispatch to `commands::*`; format `AppError` into CLI-readable strings; Linux GUI-shadow self-launch.

**Headless server `rssh-server`:**
- Location: `src-tauri/src/server_main.rs` → `src-tauri/src/server.rs` (feature `server`).
- Triggers: JetBrains plugin starts it; exposes the full UI over a token-authenticated WebSocket.
- Responsibilities: serve the embedded `../dist` frontend; bridge `invoke`/events over WS; reuse `rssh_lib` engine via `Host::Headless`.

**Frontend entry:**
- Location: `src/main.ts` (boots IPC shim first, inits theme, mounts `App.svelte`).
- Responsibilities: ensure `__TAURI_INTERNALS__` exists before any store imports; preheat AI settings; start background update checks (skipped on clone/AI-handoff windows).

## Architectural Constraints

- **Threading:** Rust backend uses tokio (`sync`, `net`, `rt`, `process`, `time`). Reader tasks are spawned per session; `AppState` fields are `std::sync::Mutex` (held briefly). Frontend is single-threaded (webview). The IPC shim is single-connection, no reconnect — a closed WS rejects all in-flight invokes.
- **Global state:** Single Tauri-managed `AppState` (`src-tauri/src/state.rs`) shared across windows. Frontend global state lives in `src/lib/stores/app.svelte.ts` (R8: never build cross-page state inside components).
- **Event naming:** MUST follow `<domain>:<event>:<sessionId>` (R1) — global events without a session id suffix cross-talk across tabs. E.g. `ssh:data:{sid}`, `ssh:auth_prompt:{tabId}`, `ai:command_proposed:{tabId}`.
- **Command double-registration:** Every `#[tauri::command]` MUST be added to both its module file AND the `generate_handler!` list in `src-tauri/src/lib.rs` (R3). Missing one = frontend "command not found".
- **IPC channel policy:** CLI↔GUI embedded terminal uses OSC 7337 only (R2). Do not introduce new sockets/pipes/tauri events for that path; add a new OSC kind instead.
- **Platform branching:** Rust uses `#[cfg(target_os = "android")]` / `#[cfg(desktop)]`; frontend uses `app.isMobile` (UA sniff, set once at module load — NOT reactive to resize, P7). Do not runtime-probe.
- **Three-platform requirement:** Every new feature/UI change must explicitly consider desktop GUI, mobile GUI, and CLI (R10).
- **Secrets:** Never write secrets to DB plaintext; route through `SecretStore` (R5). Passphrase cache is process-only (`Zeroizing<String>`), never persisted.
- **CSP:** `tauri.conf.json` sets `"csp": null` (relaxed); `dragDropEnabled: false` (the app handles drops itself).
- **Circular imports:** None observed at the module level; the frontend shim is side-effect-only (`ipc-boot.ts`) and imported first in `src/main.ts`.

## Anti-Patterns

### Building global state inside a component

**What happens:** A developer puts `$state` + cross-page logic directly in a `.svelte` file.
**Why it's wrong:** Components remount/unmount; state is lost or duplicated. R8 is a merge-blocking rule.
**Do this instead:** Add private `let _x = $state(...)` + exported getter in `src/lib/stores/app.svelte.ts` (or a dedicated `*.svelte.ts` store). Verify with `rg 'export function .* { return _' src/lib/stores/app.svelte.ts`.

### Forgetting `flex:1; overflow-y:auto; min-height:0` on a tab root `<div>`

**What happens:** A root container placed directly in `.pane` omits `min-height:0`.
**Why it's wrong:** Flex children don't shrink without it; content overflows and the block is clipped with no scroll (R4).
**Do this instead:** Copy the triple from `HomeScreen.svelte` for any new tab root.

### Hardcoding a new IPC channel instead of OSC 7337

**What happens:** A developer adds a Unix socket / named pipe / Tauri event for CLI↔GUI communication.
**Why it's wrong:** Violates R2; the existing xterm-parser path already routes these safely.
**Do this instead:** Add a new OSC kind in `src/lib/osc/handler.ts` and emit `OSC 7337 ; <kind>:<data> ST` from the CLI.

### Renaming a Tauri command without grepping the frontend

**What happens:** A Rust `#[tauri::command]` is renamed; the frontend `invoke("old_name")` string is now a runtime error (P8).
**Why it's wrong:** `invoke()` takes a hardcoded string; there is no compile-time link.
**Do this instead:** `rg 'invoke\("' src/lib` and update every call site in the same change.

## Error Handling

**Strategy:** Typed `AppError` enum (`src-tauri/src/error.rs`) implementing `thiserror::Error`; every variant wraps a `CodedMsg { code, params }`. Commands return `AppResult<T>`. Tauri serializes the `Display` output (`__rssh_err__|{code,params}` JSON) to the frontend; `errMsg()` decodes the prefix and localizes via the i18n catalog (`error.<code>`).

**Patterns:**
- Rust: `AppError::config("code", json!({}))` / `AppError::ssh(...)` etc. Fail-fast on invariant violations (e.g. missing `credential_id` → `*_cred_not_found`).
- Frontend: `try { await invoke(...) } catch (e) { app.toast(errMsg(e)) }`. No global error boundary. Do NOT silently swallow (`.catch(() => {})`) except on cleanup paths.
- CLI: `format_lib_error()` in `src-tauri/src/bin/rssh/main.rs` unwraps the protocol prefix into `code(params)` text.
- Lock poisoning has a fixed i18n code `lock_poisoned`.

## Cross-Cutting Concerns

**Logging:** `env_logger` (`RUST_LOG`, default `info`) initialized once in `lib.rs::run()`. SSH verbose line logs are emitted as `ssh:data:{sid}` ANSI-grey lines when verbose is on. Frontend uses `console.*` (startup preheat failures warn, never toast).

**Validation:** Domain names (profile/forward/group) reject C0 controls and DEL via `models.rs::validate_name()` to prevent OSC 7337 injection. Schema constraints live in `db/schema.rs`.

**Authentication:** SSH auth (password/key/interactive/agent), private-key passphrase, and host-key TOFU each use a dedicated `oneshot` waiter map in `AppState` (`auth_waiters`, `passphrase_waiters`, `host_key_waiters`) keyed by tab id. Master-key passphrase is cached in-memory only (`passphrase_cache`, `Zeroizing<String>`). Secret backend selection is sticky and hard-fails rather than silently re-keying.

**i18n:** `src/lib/i18n/index.svelte.ts` exposes `t(key, params)` + `locale`. Catalogs: `locales/en.ts`, `locales/zh.ts`. Error strings flow through `error.<code>` keys.

**Sync:** `src-tauri/src/sync/config.rs` handles encrypted export/import + GitHub (`github.rs`) and WebDAV (`webdav.rs`) push/pull. The `save_to_remote` flag on each credential filters whether its secret is uploaded (P6: changing sync logic must audit both the push filter and the credential).

---

*Architecture analysis: 2026-07-08*
