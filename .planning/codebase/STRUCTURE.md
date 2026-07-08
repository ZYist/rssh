# Codebase Structure

**Analysis Date:** 2026-07-08

## Directory Layout

```
rssh/
├── src/                    # Frontend — Svelte 5 + xterm.js (Vite)
│   ├── App.svelte          # Root component (welcome, preheat, AppShell)
│   ├── main.ts             # Entry: boot IPC shim, theme, mount
│   ├── global.d.ts         # Ambient TS decls
│   ├── styles/             # global.css design tokens + shape presets
│   └── lib/                # All frontend code
│       ├── ai/             # AI panel components + store + helpers
│       ├── components/     # Svelte UI (AppShell, TerminalPane, screens, editors)
│       ├── i18n/           # t() + locale catalogs
│       ├── keyboard/       # keymap + shortcut registry
│       ├── osc/            # CLI<->GUI OSC 7337 handlers
│       ├── stores/         # global $state stores (app, ai, themes, transfers, toast)
│       ├── terminal/       # pure terminal logic (blocks, folds, highlight)
│       ├── themes/         # palettes + theme/terminal-font store
│       └── *.ts            # leaf modules (ipc-shim, pick/save-file, local-drop)
├── src-tauri/              # Backend — Rust (Tauri 2) shared lib + 3 binaries
│   ├── Cargo.toml          # crate: rssh_lib + bins rssh / rssh-cli / rssh-server
│   ├── tauri.conf.json     # Tauri bundle config
│   ├── build.rs            # tauri-build
│   ├── capabilities/       # Tauri v2 capability files (default.json)
│   ├── gen/                # generated (android, schemas) — do not hand-edit
│   ├── icons/              # app icons (per platform)
│   ├── bin/                # bundled runtime resources
│   └── src/
│       ├── main.rs         # GUI bin entry -> rssh_lib::run()
│       ├── server_main.rs  # headless server bin entry (JetBrains)
│       ├── server.rs       # WS server implementation (server feature)
│       ├── lib.rs          # rssh_lib: module root + generate_handler!
│       ├── state.rs        # AppState (global runtime tables)
│       ├── models.rs       # serde domain structs (Profile, Credential, ...)
│       ├── error.rs        # AppError + CodedMsg (i18n error protocol)
│       ├── emitter.rs      # Host abstraction (Tauri vs Headless)
│       ├── crypto.rs       # sync backup crypto (Argon2id + ChaCha20-Poly1305)
│       ├── ai/             # AI engine (commands, session, llm, sanitize, ...)
│       ├── commands/       # #[tauri::command] layer (one file per domain)
│       ├── db/             # rusqlite Db + per-table CRUD + schema
│       ├── migration/      # startup migrations (v1 unified secret storage)
│       ├── secret/         # SecretStore + master-key backends
│       ├── ssh/            # russh engine (client, sftp, forward, auth, ...)
│       ├── sync/           # config export/import + github/webdav
│       ├── terminal/       # pty / serial / telnet / recorder (desktop)
│       └── bin/rssh/       # CLI binary (feature cli): clap commands + helpers
├── idea-plugin/            # JetBrains plugin (Kotlin/Gradle) — wraps rssh-server
├── scripts/                # Windows .bat build helpers + dev-browser.mjs
├── docs/                   # marketing site + design docs + screenshots
├── .github/workflows/      # CI: release, pre-release, share-next, create-pod
├── package.json            # frontend deps + scripts (dev/build/test/tauri)
├── vite.config.ts          # Vite (es2021 target — xterm 6 esbuild workaround)
├── vitest.config.ts        # unit test config
├── svelte.config.js        # Svelte compiler options
├── tsconfig.json           # TS config
├── index.html              # Vite HTML entry
├── build-*.sh              # per-OS release build scripts (mac/linux/android)
├── AGENT.md                # repo navigation + hard rules for AI contributors
├── CONTRIBUTING.md         # contributor guide
└── README.md / README_zh.md
```

## Directory Purposes

**`src/lib/components/`:**
- Purpose: All Svelte UI components — the tab shell, terminal pane, every settings/editor/manager screen, mobile keybar, modals.
- Contains: ~50 `.svelte` files plus co-located `*.test.ts` (`sidebar-ripple.test.ts`).
- Key files: `AppShell.svelte` (tab dispatcher, 56KB), `TerminalPane.svelte` (terminal, 79KB), `HomeScreen.svelte`, `SettingsLayout.svelte`, `AiSettings.svelte` (47KB), `AppearanceSettings.svelte`, `SyncScreen.svelte`, `SftpBrowser.svelte`.

**`src/lib/components/welcome/`:**
- Purpose: First-launch cinematic welcome (scene-based).
- Contains: `Scene*.svelte` (Ai, Blocks, Cli, Sync, Intro, Cta), `MockCursor`, `NextButton`.

**`src/lib/stores/`:**
- Purpose: Global reactive state (Svelte 5 runes). Private `_x = $state(...)` + exported getter functions.
- Key files: `app.svelte.ts` (tabs, settings nav, profiles, forwards, toasts, 33KB), `ai/store` lives in `src/lib/ai/`, `transfers.svelte.ts`, `toast.svelte.ts`, `updates.svelte.ts`, `keymap.svelte.ts`.

**`src/lib/ai/`:**
- Purpose: AI ops panel — chat UI, command confirmation, audit, and the per-tab AI store.
- Key files: `store.svelte.ts` (42KB, per-tab sessions + timeline + listeners), `ChatPanel.svelte`, `CommandConfirmDialog.svelte`, `AuditPanel.svelte`, `types.ts`, `shell-probe.ts`, `pty-output.ts`, `timeline.ts`, `format.ts`, `markdown.ts`, `tokens.ts`.

**`src/lib/terminal/`:**
- Purpose: Pure terminal post-processing logic — command-block detection, folding, highlight decorations, serial transforms, touch scroll, viewport snapshots, block-to-image export.
- Pattern: every helper module has a paired `*.test.ts`.

**`src/lib/osc/`:**
- Purpose: Decode CLI↔GUI OSC 7337 escape sequences inside xterm's parser.
- Key files: `handler.ts` (`registerRsshOscHandlers`), `clipboard.ts` (OSC clipboard bridge).

**`src/lib/keyboard/`:**
- Purpose: Global keyboard shortcut system.
- Key files: `registry.ts` (`attachShortcuts`), `keymap.ts` (key definitions + formatting).

**`src/lib/i18n/`:**
- Purpose: Localization.
- Key files: `index.svelte.ts` (`t()`, `locale`), `locales/en.ts`, `locales/zh.ts` (~56KB each).

**`src/lib/themes/`:**
- Purpose: UI + terminal theming.
- Key files: `store.svelte.ts` (theme state + persistence), `palettes.ts` (UI palette presets), `term-palettes.ts` (ANSI 16-color palettes), `term-font.ts`.

**`src/styles/`:**
- Purpose: Global design tokens + shape presets.
- Key files: `global.css` (`--bg`, `--accent`, `--raised`, `--pressed`, `.neu-*` / `.btn*` classes), `shapes/{neumorphism,material,flat}.css`.

**`src-tauri/src/commands/`:**
- Purpose: The `#[tauri::command]` layer — one file per domain. Frontend calls these by string name.
- Key files: `profile.rs` (CRUD + ssh config import, 23KB), `session.rs` (ssh connect/write/auth), `sftp.rs` (18KB), `forward.rs`, `sync.rs` (25KB, export/import + github/webdav), `window.rs` (22KB, multi-window + groups), `settings.rs`, `pty.rs`, `serial.rs`, `telnet.rs`, `lifecycle.rs` (`reconcile_sessions`, `close_window_sessions`), `cli.rs` (install/status), `external.rs`, `update.rs`, `group.rs`, `mod.rs`.

**`src-tauri/src/ssh/`:**
- Purpose: russh-based SSH engine.
- Key files: `client.rs` (33KB, connect + PTY + data + auth chain), `sftp.rs` (34KB), `forward.rs` (24KB), `auth.rs` (23KB, keyboard-interactive + oneshot waiters), `config.rs` (`~/.ssh/config` parsing with Include glob), `bastion.rs` (ProxyJump chains), `known_hosts.rs`, `prompt.rs`.

**`src-tauri/src/ai/`:**
- Purpose: AI diagnose engine — session orchestration, LLM protocol, redaction, command execution, audit.
- Key files: `session.rs` (62KB, DiagnoseSession actor), `commands.rs` (52KB, every `ai_*` command), `sanitize.rs` (97KB, payload shape validation + redaction), `shell.rs` (remote shell probe + ShellKind), `tools.rs`, `redact_rules.rs`, `command_blacklist.rs`, `audit.rs`, `skills.rs`, `llm/` (`anthropic.rs`, `openai.rs`, `glm.rs`, `deepseek.rs`, `protocol.rs`, `mod.rs`), `session/file_ops.rs` (69KB), `prompts/general.md`.

**`src-tauri/src/db/`:**
- Purpose: SQLite access. `Db` wraps `Mutex<Connection>`; per-table modules expose domain methods. `lock()` is `pub(in crate::db)` — commands never touch rusqlite directly.
- Key files: `mod.rs` (Db, WAL, transactions, `data_dir()`), `schema.rs` (24KB, table DDL + migrate), `profile.rs`, `credential.rs`, `forward.rs`, `group.rs`, `serial_profile.rs`, `telnet_profile.rs`, `highlight.rs`, `snippet.rs`, `settings.rs`, `secret.rs`, `ai_*.rs` (conversation, skill, redact_rule, command_blacklist).

**`src-tauri/src/secret/`:**
- Purpose: Secret storage abstraction — master-key envelope encryption.
- Key files: `mod.rs` (SecretStore trait + `open()` sticky backend selection), `hybrid_store.rs` (ChaCha20-Poly1305 over DB), `master_key.rs` (KeyringMasterKey / FileMasterKey), `keyring_store.rs`, `db_store.rs`, `crypto.rs`.

**`src-tauri/src/sync/`:**
- Purpose: Encrypted config backup/sync.
- Key files: `config.rs` (43KB, export/import + github + webdav orchestration), `github.rs`, `webdav.rs`.

**`src-tauri/src/terminal/`:**
- Purpose: Desktop transports (excluded on Android).
- Key files: `pty.rs` (portable-pty local shell), `serial.rs` (serialport), `telnet.rs` (31KB, all-platform plain TCP), `recorder.rs` (asciicast v2 recording).

**`src-tauri/src/migration/`:**
- Purpose: One-shot startup migrations, marker-tracked via `db.settings`.
- Key files: `mod.rs` (run_migrations dispatcher), `v1_unified_secret_storage.rs` (23KB, legacy plaintext/keychain secrets → master-key envelope).

**`src-tauri/src/bin/rssh/`:**
- Purpose: The `rssh-cli` binary (feature `cli`). Reads/writes DB directly — NOT through the Tauri command layer.
- Key files: `main.rs` (clap + Linux GUI-shadow), `ctx.rs` (`CliCtx { db, data_dir, secret_store }`), `commands/{ls,open,add,edit,rm,config,completions}.rs`, `helpers/{cred,ssh_builder,tui}.rs`.

**`idea-plugin/`:**
- Purpose: JetBrains plugin shell. Kotlin/Gradle; launches and embeds `rssh-server` (headless) in a tool window, loading the same frontend over WS.
- Contains: `build.gradle.kts`, `src/main/kotlin/`, `src/main/resources/`.

## Key File Locations

**Entry Points:**
- `src/main.ts`: Frontend entry — boots IPC shim, theme, mounts `App.svelte`.
- `src/App.svelte`: Root component — welcome screen + `AppShell`.
- `src-tauri/src/main.rs`: GUI binary → `rssh_lib::run()`.
- `src-tauri/src/lib.rs`: Library entry — module root, plugin setup, `AppState` manage, `generate_handler!` command registry.
- `src-tauri/src/bin/rssh/main.rs`: CLI binary entry (feature `cli`).
- `src-tauri/src/server_main.rs`: Headless server binary entry (feature `server`).

**Configuration:**
- `src-tauri/tauri.conf.json`: Tauri bundle/window/security config.
- `src-tauri/Cargo.toml`: Rust crate, features (`cli`, `server`), platform-conditional deps.
- `package.json`: Frontend deps + scripts (`dev`, `build`, `test`, `tauri`).
- `vite.config.ts`: Vite build (es2021 target for xterm 6).
- `vitest.config.ts`: Unit test config.
- `svelte.config.js` / `tsconfig.json`: Svelte/TS options.
- `src-tauri/capabilities/default.json`: Tauri v2 capability grants.

**Core Logic:**
- `src-tauri/src/state.rs`: `AppState` — all live session/waiter tables.
- `src-tauri/src/models.rs`: serde domain structs + `validate_name`.
- `src-tauri/src/error.rs`: `AppError` / `CodedMsg` i18n error protocol.
- `src-tauri/src/emitter.rs`: `Host` abstraction (Tauri vs Headless).
- `src/lib/stores/app.svelte.ts`: Central frontend state + `Tab`/type definitions.
- `src/lib/ipc-shim.ts`: Off-Tauri WebSocket IPC emulation.

**Testing:**
- Frontend: co-located `*.test.ts` next to each module (vitest). Examples: `src/lib/stores/app.svelte.test.ts`, `src/lib/terminal/command-blocks.test.ts`, `src/lib/osc/handler.test.ts`.
- Backend: `#[cfg(test)]` modules inside `.rs` files; `Db::open_in_memory()` helper (`src-tauri/src/db/mod.rs`); `mockito` dev-dependency for HTTP.

## Naming Conventions

**Files (frontend):**
- Components: `PascalCase.svelte` (`AppShell.svelte`, `TerminalPane.svelte`, `CommandConfirmDialog.svelte`).
- Stores/logic: `kebab-case.ts` (`ipc-shim.ts`, `pick-file.ts`) or `kebab-case.svelte.ts` when it holds `$state` (`app.svelte.ts`, `store.svelte.ts`).
- Tests: `<module>.test.ts` co-located with the module.

**Files (backend):**
- Modules: `snake_case.rs` (`ssh/client.rs`, `commands/profile.rs`).
- Test modules: inline `#[cfg(test)] mod <name>_tests`.

**Directories:**
- One word, lowercase, singular for domains (`ssh`, `ai`, `db`, `secret`, `sync`); plural for collections (`commands`, `stores`, `components`).

**Identifiers:**
- Rust: snake_case functions/fields, PascalCase types (`AppState`, `SessionHandle`). State getter style: verb phrases without `get` prefix.
- TypeScript: camelCase functions/variables, PascalCase types/components. State getters: `tabs()`, `activeTab()`, `settingsActive()`.
- Error messages: user-facing strings are localized (Chinese default catalog); codes are snake_case (`name_has_control_char`).

**Tab IDs:**
- `home` (literal, unique, not closeable).
- `ssh` / `local` / `serial` / `telnet` / `edit`: `<type>:<uuid>` (via `crypto.randomUUID()`).
- `forward`: `fwd:<forward_id>:<timestamp>`.

**Tauri events:** `<domain>:<event>:<sessionId>` — e.g. `ssh:data:{tabId}`, `ssh:auth_prompt:{tabId}`, `ai:command_proposed:{tabId}`.

**Tauri commands:** snake_case function name = the exact `invoke("<name>")` string the frontend uses.

## Where to Add New Code

**New Tauri command (RPC):**
1. Write the `#[tauri::command]` fn in the relevant `src-tauri/src/commands/<domain>.rs` (create the file + add `mod <domain>;` to `commands/mod.rs` if new).
2. Register it in the `generate_handler!` macro in `src-tauri/src/lib.rs` (R3 — missing it = frontend "command not found").
3. Call it from the frontend with `invoke("<snake_name>", { args })`.
4. If it emits events, use `<domain>:<event>:<tabId>` naming (R1).

**New SSH/terminal transport or session type:**
1. Engine: add to `src-tauri/src/ssh/` (or `src-tauri/src/terminal/` for PTY/serial/telnet-style).
2. State: add a `Mutex<HashMap<String, Handle>>` to `AppState` in `src-tauri/src/state.rs` and initialize it in `lib.rs::setup`.
3. Commands: add connect/write/resize/close in `src-tauri/src/commands/`.
4. Platform gating: desktop-only → `#[cfg(not(target_os = "android"))]` on the command + registration line.
5. Frontend: add a `TabType` variant in `src/lib/stores/app.svelte.ts`; dispatch it in `AppShell.svelte` (terminal types render `TerminalPane`).

**New settings screen:**
1. Add a `SettingsPage` variant to the union in `src/lib/stores/app.svelte.ts`.
2. Create the `.svelte` component in `src/lib/components/`.
3. Wire navigation in `src/lib/components/SettingsLayout.svelte`.
4. Persist values via `get_setting` / `set_setting` commands (`src-tauri/src/commands/settings.rs` + `db/settings.rs`).

**New global frontend state:**
1. Add `let _x = $state(...)` + exported getter/setter in `src/lib/stores/app.svelte.ts` (R8 — never build it inside a component).
2. For AI-specific state, use `src/lib/ai/store.svelte.ts`.
3. For a self-contained domain, create a new `src/lib/stores/<name>.svelte.ts` and export functions only.

**New DB table:**
1. DDL + migrate step in `src-tauri/src/db/schema.rs`.
2. CRUD module in `src-tauri/src/db/<table>.rs` + `pub mod <table>;` in `db/mod.rs`.
3. Mirror the struct in `src-tauri/src/models.rs` (serde for the frontend).
4. If the CLI must read/write it, add the path in `src-tauri/src/bin/rssh/` (P5 — CLI does not go through the command layer).
5. If synced, consider `save_to_remote` filtering in `src-tauri/src/sync/config.rs`.

**New i18n keys:**
- Add to BOTH `src/lib/i18n/locales/en.ts` and `locales/zh.ts`. Error codes map to `error.<code>`.

**New utility (pure logic):**
- Frontend: `src/lib/<name>.ts` with a paired `<name>.test.ts`.
- Backend: a function/module under `src-tauri/src/` with an inline `#[cfg(test)]` block; use `Db::open_in_memory()` for DB-touching tests.

**New build/packaging helper:**
- Windows: `scripts/*.bat` (build-dev, build-exe, build-frontend, build-release).
- macOS/Linux/Android: root `build-*.sh`.

## Special Directories

**`src-tauri/gen/`:**
- Purpose: Tauri-generated code (Android project, JSON schemas).
- Generated: Yes.
- Committed: Partially (Android scaffolding).

**`src-tauri/target/` / `node_modules/` / `dist/`:**
- Purpose: Build artifacts (Rust, npm, Vite output).
- Generated: Yes.
- Committed: No (gitignored).

**`docs/`:**
- Purpose: Marketing/docs site (GitHub Pages via `docs/CNAME`) + design markdown (`ai-diagnose-design.md`, `article_*.md`) + screenshots/gifs.
- Generated: No.
- Committed: Yes.

**`idea-plugin/`:**
- Purpose: Separate Gradle/Kotlin project that bundles `rssh-server`. Built independently of the Tauri app; shares the data dir (`~/.rssh`) at runtime.

**`scripts/`:**
- Purpose: Windows build convenience `.bat` files + `dev-browser.mjs` (run frontend in a plain browser against a dev server, exercising the IPC shim).

**`~/.rssh/` (runtime, not in repo):**
- Purpose: Data dir on desktop — holds `rssh.db`, `master.key` (file backend), `rssh.db-wal`. Android uses `app_data_dir` instead. All three binaries (GUI/CLI/server) read/write this same location.

---

*Structure analysis: 2026-07-08*
