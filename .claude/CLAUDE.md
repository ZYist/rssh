<!-- GSD:project-start source:PROJECT.md -->

## Project

**AI Broadcast Mode**

RSSH 的 AI 面板新增"广播模式"开关。开启后，AI 只与当前活跃标签交互（读取输出、做诊断），但所提议的命令在用户批准后会自动同步发送给所有用户勾选的终端标签。适用于同时管理多台相同配置机器的运维场景。

**Core Value:** AI 对一台机器做诊断/操作，操作指令自动同步到其它同类机器——减少重复操作，保持多机一致性。

### Constraints

- **Tech stack**: Svelte 5 + Tauri — 前端状态用 `$state`/`$derived` runes
- **兼容性**: 广播模式关闭时行为必须与当前完全一致，不能影响现有 AI 流程
- **性能**: 广播发送应并行，不能串行等待每个终端执行完
- **安全性**: Raw device 标签默认不参与广播（需显式勾选），避免误操作

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- **Rust** (edition 2021) — Backend engine in `src-tauri/`. All SSH/SFTP/PTY/serial/AI/sync logic. Entry points: `src-tauri/src/main.rs` (GUI), `src-tauri/src/server_main.rs` (headless server), `src-tauri/src/bin/rssh/main.rs` (CLI).
- **TypeScript** — Frontend in `src/` (Svelte 5 components + stores). Entry: `src/main.ts`.
- **Svelte 5** — UI markup language in `src/lib/components/*.svelte` and `src/App.svelte` (uses runes `$state`, `$derived`).
- **Kotlin** (JVM) — JetBrains/IntelliJ plugin in `idea-plugin/src/main/kotlin/sh/rssh/idea/`. Gradle-built; spawns `rssh-server` and hosts the web UI in a JCEF tool window.
- **Shell / Batch** — Platform build scripts: `build-android.sh`, `build-linux.sh`, `build-mac.sh` (root), `scripts/build-*.bat` (Windows helpers).

## Runtime

- **Node.js** >= 20 (frontend dev/build; required for all platforms per `CONTRIBUTING.md`)
- **Rust stable** via rustup (backend; android targets `aarch64-linux-android`, `armv7-linux-androideabi`)
- **JDK 17** (Android builds only — Eclipse Temurin recommended)
- Native runtimes: WKWebView (macOS/iOS), WebView2 (Windows), WebKitGTK 4.1 (Linux), Android System WebView, JCEF (JetBrains plugin)
- **npm** (comes bundled with Node) — `package.json` + `package-lock.json`
- **Cargo** — Rust crates via `src-tauri/Cargo.toml` + `src-tauri/Cargo.lock`
- **Gradle** (wrapper bundled) — IntelliJ plugin in `idea-plugin/`
- Lockfiles: all present and committed (`package-lock.json`, `Cargo.lock`, `idea-plugin/gradle/`)

## Frameworks

- **Tauri 2** — desktop+mobile app shell; IPC bridge between Rust and the webview. `src-tauri/src/lib.rs` wires ~150 `#[tauri::command]` handlers. Config: `src-tauri/tauri.conf.json`.
- **Svelte 5** — reactive UI (runes mode). Compiled by `@sveltejs/vite-plugin-svelte`.
- **Vite 6** — frontend bundler/dev server. Config: `vite.config.ts` (port 1420, es2021 build target — see the xterm 6 esbuild downlevel note).
- **Vitest 4** — TS unit tests; config in `vitest.config.ts`. Pattern: `src/**/*.test.ts`, node environment, svelte plugin enabled (needed for `.svelte.ts` runes).
- **Rust `cargo test`** — unit tests in-module (`#[cfg(test)] mod tests`), in-memory SQLite via `Db::open_in_memory()`. Dev-dep `mockito` for HTTP mocking.
- `npm run dev` — Vite dev server (frontend only)
- `npm run tauri dev` — hot-reload full app (frontend + Rust) — the canonical dev command
- `npm run build` → `vite build` → `dist/`
- `npm run tauri build` → bundles in `src-tauri/target/release/bundle/`
- `npx tauri android init/dev/build --apk` — Android
- Rust build features: `cli` (CLI binary), `server` (headless ws server), `custom-protocol`

## Key Dependencies

- `russh = 0.60.1` — pure-Rust SSH2 client. Pinned crypto prereleases (`ecdsa`, `ed25519`, `pkcs8`, `rsa` `=rc.x`) to keep pkcs8 API stable — do NOT let Cargo bump these (see comments in `Cargo.toml`).
- `russh-sftp = 2` — SFTP subsystem over russh channels
- `rusqlite = 0.31` (feature `bundled`) — SQLite with statically linked C library, no system sqlite needed. WAL mode + 5s busy_timeout for cross-process (GUI/CLI/server) sharing.
- `tauri = 2` + `tauri-plugin-opener/dialog/fs = 2` — app shell + native dialogs/fs/url opener
- `reqwest = 0.12` (features `json`, `rustls-tls`, `stream`) — the ONLY HTTP client. Used by LLM, GitHub, WebDAV, update check. Uses rustls (no OpenSSL link).
- `tokio = 1` (features `sync`, `macros`, `net`, `io-util`, `rt`, `process`, `time`) — async runtime
- `keyring = 3` — platform-specific feature per OS: `apple-native` (macOS), `windows-native` (Windows), `sync-secret-service`+`crypto-rust` (Linux). Excluded on Android → falls back to file master key.
- `@xterm/xterm = 6.0.0` — terminal emulator (pinned exactly; addons `addon-fit`, `addon-search`, `addon-web-links`, `addon-unicode11`, `addon-image`)
- `@tauri-apps/api = ^2` — IPC (`invoke`, `listen`). One seam for all backend calls; see `src/lib/ipc-shim.ts` for the headless fallback.
- `codemirror = ^6` + `@codemirror/theme-one-dark` + `@codemirror/legacy-modes` — code editor (snippets, config views)
- `marked = ^18` + `dompurify = ^3` — markdown rendering for AI chat output (sanitized client-side)
- `serde` / `serde_json` — all IPC + DB serialization
- `thiserror = 2` — error enums (see `src-tauri/src/error.rs`)
- `uuid = 1` (v4) — entity IDs
- `chrono = 0.4` — timestamps
- `argon2 = 0.5`, `chacha20poly1305 = 0.10`, `getrandom = 0.2`, `zeroize = 1` — crypto stack for config-backup encryption and master-key envelope (see `src-tauri/src/crypto.rs`, `src-tauri/src/secret/`)
- `regex = 1`, `regex-syntax = 0.8` — redaction rules (zero-width match rejection in `src-tauri/src/ai/redact_rules.rs`)
- `portable-pty = 0.8` — local terminal (desktop only, excluded on Android)
- `serialport = 4.9.0` — serial console (desktop only; Linux links libudev)
- `arboard = 3` — clipboard (desktop only)
- `tree-sitter = 0.26.9` + `tree-sitter-bash = 0.25.1` — AI shell-output / patch-file parsing
- `glob = 0.3` — `Include` expansion when parsing `~/.ssh/config` (issue #96)
- `dirs = 5` — `~/.rssh` data dir resolution
- `tokio-tungstenite = 0.24` (feature-gated `server`) — WebSocket transport for headless server
- `include_dir = 0.7` (feature-gated `server`) — embeds `dist/` into `rssh-server` binary
- `clap = 4` (feature-gated `cli`) — CLI arg parsing

## Configuration

- No `.env` files. The project does not use a dotenv-style config. Secrets/API keys live in the encrypted DB `secrets` table (via `HybridStore`), not env vars.
- Notable env vars consumed at runtime (all optional, for tuning/compat):
- `src-tauri/tauri.conf.json` — Tauri bundle config (productName `RSSH`, identifier `com.rssh.app`, frontendDist `../dist`, devUrl `:1420`)
- `src-tauri/capabilities/default.json` — Tauri 2 permissions: `core:default`, `opener:default`, `dialog:default`, `fs:default`, `fs:allow-write-text-file`, window set-title/always-on-top
- `package.json` — npm scripts + frontend deps
- `vite.config.ts`, `vitest.config.ts`, `tsconfig.json`, `svelte.config.js`
- `src-tauri/gen/android/` — Android build files (incl. `key.properties` for signing)
- Build config files: `src-tauri/build.rs`, `vite.config.ts`, `tsconfig.json`, `svelte.config.js`, `idea-plugin/build.gradle.kts`
- Linux build needs system libs: `libgtk-3-dev libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev libudev-dev` (per `CONTRIBUTING.md` + `.github/workflows/release.yml`)
- Windows needs Visual Studio Build Tools (C++ workload)
- macOS needs Xcode Command Line Tools

## Platform Requirements

- Node >= 20 + Rust stable (all platforms)
- Linux: GTK/webkit2gtk/libudev dev headers (above)
- Windows: VS Build Tools C++
- macOS: Xcode CLT
- Android: JDK 17 + Android SDK/NDK + rust targets
- Desktop: Tauri-bundled native installers — macOS `.dmg` (aarch64 + x86_64), Linux `.deb`/`.rpm`/`.AppImage`, Windows `.msi`/`.exe`. Output: `src-tauri/target/release/bundle/`.
- Mobile: Android `.apk` (universal). iOS unsupported (no ID; "build yourself").
- JetBrains plugin: per-OS zip containing `rssh-server` + Kotlin plugin, installed via "Install Plugin from Disk".
- Data dir: `~/.rssh/` (desktop) or `app_data_dir` (Android) — holds `rssh.db`, `master.key` (headless/Android), `snippets.json`.
- Reads `~/.ssh/config` + `~/.ssh/known_hosts` (shared with OpenSSH — import + host-key verification).

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Svelte components: `PascalCase.svelte` — e.g. `src/lib/components/AppShell.svelte`, `src/lib/ai/ChatPanel.svelte`.
- TypeScript modules: `kebab-case.ts` — e.g. `src/lib/ai/shell-probe.ts`, `src/lib/osc/handler.ts`, `src/lib/components/sidebar-ripple.ts`.
- Modules that use Svelte 5 runes (so they need the svelte Vite plugin to transform): suffix `.svelte.ts` — e.g. `src/lib/stores/app.svelte.ts`, `src/lib/i18n/index.svelte.ts`, `src/lib/ai/store.svelte.ts`. Plain `.ts` for pure-logic modules.
- Tests: co-located, `<module>.test.ts` next to `<module>.ts`.
- `snake_case.rs`, one module per file under `src-tauri/src/<domain>/`. Commands in `commands/`, DB access in `db/`, etc.
- `camelCase` for functions and locals.
- Store getters are verb phrases with **no** `get` prefix: `tabs()`, `activeTabId()`, `settingsActive()`, `sftpOpenForTab(tabId)`. See `src/lib/stores/app.svelte.ts:175`.
- Actions are imperative verbs: `addTab`, `closeTab`, `setActiveTab`, `moveTab`.
- `snake_case` for fns and fields, `PascalCase` for types. DB row helpers: `row_to_profile`. CRUD fns: `list`, `get`, `insert`, `update`, `delete` (in `src-tauri/src/db/*.rs`).
- `PascalCase` for interfaces, type aliases, enums: `Tab`, `Profile`, `SettingsPage`, `TabType` (frontend); `AppError`, `AppState`, `Profile`, `Forward` (Rust).
- String-literal unions preferred for closed sets: `export type TabType = "home" | "ssh" | "local" | "serial" | "telnet" | "forward" | "edit"` in `src/lib/stores/app.svelte.ts:16`.
- `SCREAMING_SNAKE_CASE` for module-level magic values: `OSC_RSSH_ID = 7337` (`src/lib/osc/handler.ts:12`), `CMD_DISPLAY_MAX` (`src/lib/ai/format.ts:8`), `DEFAULT_TTL_MS` (`src/lib/stores/toast.svelte.ts:4`).

## Code Style

- No formatter configured. Indentation is 2 spaces in Svelte/TS (some files use 4 — inconsistent, but 2 dominates in `src/lib/stores/` and `src/lib/ai/`). Match the surrounding file.
- Double quotes for string literals throughout the frontend (`import { describe, it, expect } from "vitest"`).
- Trailing semicolons on statements.
- Semicolons omitted after `$state(...)` declarations only when the line is a simple assignment (mixed — follow the file).
- `cargo fmt` is the source of truth — 4-space indent, standard rustfmt layout. Run `cargo fmt` before commit (see `CONTRIBUTING.md` "Code Style").
- Frontend: **none** (no eslint/prettier config). `AGENT.md` historically said "无 lint"; still true.
- Rust: `cargo clippy` is expected (per `CONTRIBUTING.md`). No `clippy.toml` / `#![deny(clippy::...)]` attributes seen — default warning level.
- `tsconfig.json` has `"strict": true`, `"noEmit": true`, `"isolatedModules": true`, `"target": "ES2021"`. Types are load-bearing — tests use precise literal types (e.g. `vi.fn((): false => false)` in `src/lib/keyboard/registry.test.ts:111` to match a `() => false | void` contract).
- `allowImportingTsExtensions: true` → **always write the `.ts` / `.svelte.ts` extension in relative imports**: `import { formatTokenCount } from "./tokens.ts"` (`src/lib/ai/tokens.test.ts:2`). Not optional.

## Import Organization

## Error Handling

- All fallible backend code returns `AppResult<T>` (= `Result<T, AppError>`).
- `AppError` is a `thiserror::Error` enum. Every business variant wraps a `CodedMsg { code, params }`.
- `CodedMsg::Display` serializes to the wire format `__rssh_err__|{"code":"...","params":{...}}` so the frontend can translate.
- **Every error must carry an i18n code.** There is intentionally no "raw string error" escape hatch (see the header comment in `src-tauri/src/error.rs:5`). Construct errors with the helper constructors:
- `From<rusqlite::Error>` and `From<std::io::Error>` are implemented, so `?` propagates them as `AppError::Database` / `AppError::Io` automatically.
- `#[tauri::command]` fns return `Result<T, AppError>`; Tauri serializes the error via `Display` → frontend receives the `__rssh_err__|...` string.
- Wrap every `invoke(...)` in try/catch and surface failures via `toast.error(errMsg(e))` or `toast.error(`${t("toast.error.save")}: ${errMsg(e)}`)`.
- `errMsg()` (`src/lib/i18n/index.svelte.ts:68`) unwraps the `__rssh_err__|` prefix and looks up `error.<code>` in the locale catalog; plain strings pass through.
- Pattern repeated across editors/managers:
- One-liner fire-and-forget form: `void invoke(cmd, {...}).catch((e) => toast.error(errMsg(e)))` (`src/lib/components/AppShell.svelte:743`).

## Logging

- `console.warn("[<domain>] <what> failed:", e)` for non-fatal background failures (e.g. `src/main.ts:30` `console.warn("[ai] settings preheat failed:", e)`).
- `console.error(...)` for truly unexpected failures (`src/lib/components/AppShell.svelte:43`).
- `console.debug(...)` for skippable diagnostics (`src/App.svelte:57`).
- Tag prefix convention: `[ai]`, `[app]`, `[sync]` — domain in brackets.

## Comments

## Function Design

- Store getters return the `$state` value (reactive snapshot) — `function tabs() { return _tabs; }`.
- Mutators return `void` (they assign to `$state`); the change is observed via getters.
- Pure formatters return their output directly.
- Rust: `AppResult<T>` for anything fallible; bare `T` only when infallible.

## Module Design

- Named exports only. No default exports except Svelte components (`export default` in `App.svelte`, `AppShell.svelte`, etc.) and the `main.ts` mount default.
- Store modules use the **private-state + getter-function** pattern (AGENT.md R8):
- Cross-cutting state lives in `src/lib/stores/app.svelte.ts` only. Do not build global state inside a component (R8).
- Use `$state`, `$derived`, `$effect`, `$props` only.
- Event handlers are `onclick={fn}`, `oninput={...}` — **never** `on:click`, `$:`, or `export let`. `AGENT.md` R7 explicitly says reject these on review.
- Runes work in `.svelte` and `.svelte.ts` files (transformed by `@sveltejs/vite-plugin-svelte`, which `vitest.config.ts` also enables so i18n's `$state` imports don't crash tests).
- Rust: `#[cfg(target_os = "android")]`, `#[cfg(unix)]`, `#[cfg(not(target_os = "android"))]`. See `src-tauri/Cargo.toml:83-102` for the target-specific dependency split.
- Frontend: `app.isMobile` (one-time `navigator.userAgent` sniff, a `const` — does not react to resize, R9/P7). Use it for mobile-only UI branches; do not runtime-probe the platform otherwise.

## CSS Conventions

- Theme tokens are the single source of truth in `src/styles/global.css` (`:root` block): `--bg`, `--surface`, `--accent`, `--error`, `--success`, `--text`, `--space-*`, `--radius-*`, `--density`, etc.
- **Use the tokens, never raw hex** (AGENT.md Pr3). Raw hex breaks theme switching (dark/light/neumorphism/flat/material shapes).
- Reuse existing utility classes (`.neu-*`, `.btn*`, `.surface-raised`, `.toast-*`) before adding new ones.
- Shape presets live in `src/styles/shapes/{neumorphism,flat,material}.css`, activated via `[data-shape="..."]`.
- Tab/pane root containers must follow the R4 three-piece: `flex: 1; overflow-y: auto; min-height: 0;` (omit `min-height: 0` → flex child won't shrink, overflow breaks).
- Icons are hand-drawn SVG; **no emoji** in the UI (Pr3).

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **One frontend, three hosts.** The frontend imports `@tauri-apps/api` everywhere; `src/lib/ipc-shim.ts` installs a fake `__TAURI_INTERNALS__` over a WebSocket when the real webview global is absent (browser / JetBrains JCEF). Desktop behavior is unchanged.
- **Three binaries share `rssh_lib`.** `rssh` (GUI), `rssh-cli` (feature `cli`), `rssh-server` (feature `server`, JetBrains-only, lives outside `src/bin/` to dodge the Tauri bundler). All link `src-tauri/src/lib.rs`.
- **Svelte 5 runes only.** `$state` / `$derived` / `$effect` / `$props`; `onclick={fn}`. No legacy `$:` / `export let` / `on:click`.
- **Centralized frontend state.** All cross-page reactive state lives in `src/lib/stores/*.svelte.ts` as private `_x = $state(...)` plus exported getter functions. Never export raw `$state`, never build global state inside a component.
- **Sticky secret backend.** Master-key backend (keychain vs file) is probed once, persisted in `db.settings`, and never silently flipped — a flip would make existing ciphertext unreadable.
- **Coded error protocol.** Every `AppError` serializes to `__rssh_err__|{"code","params"}`. The frontend `errMsg()` decodes the prefix and localizes via the i18n catalog. There is no plain-string escape hatch.

## Layers

- Purpose: render tabs, terminals, settings, AI panel; handle user input.
- Location: `src/lib/components/*.svelte`, `src/lib/ai/*.svelte`, `src/lib/components/welcome/`
- Contains: Svelte 5 components; the tab dispatcher (`AppShell.svelte`); `TerminalPane.svelte` (~79KB, single-file terminal with highlight injection + auth modals).
- Depends on: `src/lib/stores/*.svelte.ts`, `src/lib/ai/store.svelte.ts`, `@tauri-apps/api` (invoke/listen).
- Used by: `src/App.svelte` root.
- Purpose: own global reactive state; pure helpers (terminal parsing, OSC, keyboard, themes, i18n).
- Location: `src/lib/stores/`, `src/lib/ai/`, `src/lib/terminal/`, `src/lib/osc/`, `src/lib/keyboard/`, `src/lib/themes/`, `src/lib/i18n/`, plus leaf `src/lib/*.ts` (`ipc-shim.ts`, `pick-file.ts`, `save-file.ts`, `local-drop.ts`).
- Contains: `$state`-backed stores with getter exports; pure functions paired with `*.test.ts`.
- Depends on: `@tauri-apps/api/core`, each other.
- Used by: components.
- Purpose: `#[tauri::command]` functions the frontend invokes by string name.
- Location: `src-tauri/src/commands/*.rs` (one file per domain: `profile`, `session`, `sftp`, `forward`, `sync`, `settings`, `pty`, `serial`, `telnet`, `window`, `ai::*`).
- Contains: argument parsing, calls into db/ssh/secret, returns `AppResult<T>`.
- Depends on: `state.rs` (`AppState`), `db/`, `ssh/`, `secret/`, `ai/`, `emitter.rs`.
- Used by: frontend via `invoke("name")`; MUST be registered in `src-tauri/src/lib.rs` `generate_handler!`.
- Purpose: the real work — SSH, SFTP, forward, PTY, serial, telnet, AI, sync, crypto.
- Location: `src-tauri/src/ssh/`, `src-tauri/src/terminal/`, `src-tauri/src/ai/`, `src-tauri/src/sync/`, `src-tauri/src/crypto.rs`.
- Contains: long-running async sessions keyed by tab id; auth flows via oneshot channels.
- Depends on: `russh`, `russh-sftp`, `portable-pty`, `serialport`, `reqwest`, `db/`, `secret/`.
- Used by: command layer, CLI helpers, headless server.
- Purpose: SQLite + platform keychain.
- Location: `src-tauri/src/db/`, `src-tauri/src/secret/`, `src-tauri/src/migration/`.
- Contains: `Db` (Mutex<Connection>) with per-table CRUD modules; `SecretStore` trait with `HybridStore` (ChaCha20-Poly1305 over DB) + keychain/file master-key backends.
- Depends on: `rusqlite` (bundled, WAL), `keyring` (platform), `chacha20poly1305`, `argon2`.
- Used by: command layer, CLI (`db::*` + `secret_store` direct), engine layer.
- Purpose: `rssh` / `rssh-cli` terminal commands.
- Location: `src-tauri/src/bin/rssh/main.rs` + `commands/` (add/edit/rm/ls/open/config/completions) + `helpers/` (cred, ssh_builder, tui) + `ctx.rs`.
- Contains: clap dispatch; reads/writes DB and `SecretStore` directly (no Tauri). On Linux with no subcommand + a display server, forks the GUI binary.
- Depends on: `rssh_lib::{db, secret}`.
- Used by: end users from a terminal; the GUI's embedded terminal talks back via OSC 7337.

## Data Flow

### Primary Request Path — SSH connect + data

### CLI ↔ embedded-GUI flow (OSC 7337)

### AI diagnose flow

- Backend: `AppState` (`src-tauri/src/state.rs`) is a single Tauri-managed struct of `Mutex<HashMap<...>>` tables. It is shared (Arc) across windows; clone windows inherit the same handle (`window.__rssh_clone`). On `WindowEvent::Destroyed`, only sessions owned by that window label are closed (`commands::lifecycle::close_window_sessions`).
- Frontend: Svelte 5 runes in `src/lib/stores/app.svelte.ts` (tabs, settings nav, profiles, toasts) and `src/lib/ai/store.svelte.ts` (per-tab AI sessions + chat timeline). Theme state in `src/lib/themes/store.svelte.ts`; transfer queue in `transfers.svelte.ts`.

## Key Abstractions

- Purpose: let the engine emit events and reach `AppState` identically whether it runs under Tauri or the headless WS server.
- Examples: `src-tauri/src/emitter.rs` (`Host::Tauri`, `Host::Headless`); engine call sites use `host.state()` / `host.emit()`.
- Pattern: enum dispatch wrapping `tauri::AppHandle` vs a sink closure + `Arc<AppState>`.
- Purpose: one struct holding every live session map and waiter map, managed by Tauri.
- Examples: `src-tauri/src/state.rs` — `sessions`, `pty_sessions`, `serial_sessions`, `telnet_sessions`, `sftp_sessions`, `active_forwards`, `auth_waiters`, `passphrase_waiters`, `host_key_waiters`, `passphrase_cache`, `ai_sessions`, `window_sessions`, `window_groups`.
- Pattern: `Mutex<HashMap<String, Handle>>`; per-window cleanup via `window_sessions` (window_label → session ids).
- Purpose: each open pane is a tab; type dispatches the renderer.
- Examples: `src/lib/stores/app.svelte.ts` `Tab` interface; dispatched in `AppShell.svelte` (`home` → `HomeScreen`; terminal types → `TerminalPane`; `forward` → `ForwardPane`; `edit` → `EditPane`).
- Pattern: id forms are `home` (literal), `<type>:<uuid>` (ssh/local/edit), `fwd:<forward_id>:<timestamp>`.
- Purpose: uniform get/set across platforms; never store secrets in DB plaintext.
- Examples: `src-tauri/src/secret/mod.rs` trait; `HybridStore` (ChaCha20-Poly1305 ciphertext in `secrets` table) + `master_key.rs` (keychain or `<data_dir>/master.key`).
- Pattern: master-key envelope encryption; sticky backend marker in `db.settings`.
- Purpose: `Mutex<Connection>` exposed only through domain methods; `lock()` is `pub(in crate::db)`.
- Examples: `src-tauri/src/db/mod.rs`; per-table modules (`profile.rs`, `credential.rs`, ...); `with_transaction` / `with_exclusive_lock` for cross-process safety (GUI + CLI + server all write the same file).
- Pattern: WAL + `busy_timeout=5000`; in-memory test helper `open_in_memory()`.
- Purpose: every error carries a stable `code` + `params` for frontend localization.
- Examples: `src-tauri/src/error.rs`; frontend decodes the `__rssh_err__|{...}` Display output.
- Pattern: `thiserror` enum; `CodedMsg` newtype; `AppResult<T>` return type on all commands.

## Entry Points

- Location: `src-tauri/src/main.rs` → `rssh_lib::run()` (`src-tauri/src/lib.rs`).
- Triggers: user launches the app; Linux CLI forks it when no subcommand + display present.
- Responsibilities: init logger, apply Linux/Wayland compat env, register Tauri plugins (opener/dialog/fs), wire `on_window_event` (per-window session cleanup + move-together window groups), `setup` (open DB, open secret store, run migrations, scan shells, manage `AppState`), and the `generate_handler!` command registry.
- Location: `src-tauri/src/bin/rssh/main.rs` (feature `cli`).
- Triggers: `rssh ls`, `rssh open <name>`, `rssh add/edit/rm`, `rssh config ...`.
- Responsibilities: clap parse → open `~/.rssh/rssh.db` + secret store directly → dispatch to `commands::*`; format `AppError` into CLI-readable strings; Linux GUI-shadow self-launch.
- Location: `src-tauri/src/server_main.rs` → `src-tauri/src/server.rs` (feature `server`).
- Triggers: JetBrains plugin starts it; exposes the full UI over a token-authenticated WebSocket.
- Responsibilities: serve the embedded `../dist` frontend; bridge `invoke`/events over WS; reuse `rssh_lib` engine via `Host::Headless`.
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

### Forgetting `flex:1; overflow-y:auto; min-height:0` on a tab root `<div>`

### Hardcoding a new IPC channel instead of OSC 7337

### Renaming a Tauri command without grepping the frontend

## Error Handling

- Rust: `AppError::config("code", json!({}))` / `AppError::ssh(...)` etc. Fail-fast on invariant violations (e.g. missing `credential_id` → `*_cred_not_found`).
- Frontend: `try { await invoke(...) } catch (e) { app.toast(errMsg(e)) }`. No global error boundary. Do NOT silently swallow (`.catch(() => {})`) except on cleanup paths.
- CLI: `format_lib_error()` in `src-tauri/src/bin/rssh/main.rs` unwraps the protocol prefix into `code(params)` text.
- Lock poisoning has a fixed i18n code `lock_poisoned`.

## Cross-Cutting Concerns

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
