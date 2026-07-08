# Technology Stack

**Analysis Date:** 2026-07-08

## Languages

**Primary:**
- **Rust** (edition 2021) — Backend engine in `src-tauri/`. All SSH/SFTP/PTY/serial/AI/sync logic. Entry points: `src-tauri/src/main.rs` (GUI), `src-tauri/src/server_main.rs` (headless server), `src-tauri/src/bin/rssh/main.rs` (CLI).
- **TypeScript** — Frontend in `src/` (Svelte 5 components + stores). Entry: `src/main.ts`.
- **Svelte 5** — UI markup language in `src/lib/components/*.svelte` and `src/App.svelte` (uses runes `$state`, `$derived`).

**Secondary:**
- **Kotlin** (JVM) — JetBrains/IntelliJ plugin in `idea-plugin/src/main/kotlin/sh/rssh/idea/`. Gradle-built; spawns `rssh-server` and hosts the web UI in a JCEF tool window.
- **Shell / Batch** — Platform build scripts: `build-android.sh`, `build-linux.sh`, `build-mac.sh` (root), `scripts/build-*.bat` (Windows helpers).

## Runtime

**Environment:**
- **Node.js** >= 20 (frontend dev/build; required for all platforms per `CONTRIBUTING.md`)
- **Rust stable** via rustup (backend; android targets `aarch64-linux-android`, `armv7-linux-androideabi`)
- **JDK 17** (Android builds only — Eclipse Temurin recommended)
- Native runtimes: WKWebView (macOS/iOS), WebView2 (Windows), WebKitGTK 4.1 (Linux), Android System WebView, JCEF (JetBrains plugin)

**Package Manager:**
- **npm** (comes bundled with Node) — `package.json` + `package-lock.json`
- **Cargo** — Rust crates via `src-tauri/Cargo.toml` + `src-tauri/Cargo.lock`
- **Gradle** (wrapper bundled) — IntelliJ plugin in `idea-plugin/`
- Lockfiles: all present and committed (`package-lock.json`, `Cargo.lock`, `idea-plugin/gradle/`)

## Frameworks

**Core:**
- **Tauri 2** — desktop+mobile app shell; IPC bridge between Rust and the webview. `src-tauri/src/lib.rs` wires ~150 `#[tauri::command]` handlers. Config: `src-tauri/tauri.conf.json`.
- **Svelte 5** — reactive UI (runes mode). Compiled by `@sveltejs/vite-plugin-svelte`.
- **Vite 6** — frontend bundler/dev server. Config: `vite.config.ts` (port 1420, es2021 build target — see the xterm 6 esbuild downlevel note).

**Testing:**
- **Vitest 4** — TS unit tests; config in `vitest.config.ts`. Pattern: `src/**/*.test.ts`, node environment, svelte plugin enabled (needed for `.svelte.ts` runes).
- **Rust `cargo test`** — unit tests in-module (`#[cfg(test)] mod tests`), in-memory SQLite via `Db::open_in_memory()`. Dev-dep `mockito` for HTTP mocking.

**Build/Dev:**
- `npm run dev` — Vite dev server (frontend only)
- `npm run tauri dev` — hot-reload full app (frontend + Rust) — the canonical dev command
- `npm run build` → `vite build` → `dist/`
- `npm run tauri build` → bundles in `src-tauri/target/release/bundle/`
- `npx tauri android init/dev/build --apk` — Android
- Rust build features: `cli` (CLI binary), `server` (headless ws server), `custom-protocol`

## Key Dependencies

**Critical (Rust):**
- `russh = 0.60.1` — pure-Rust SSH2 client. Pinned crypto prereleases (`ecdsa`, `ed25519`, `pkcs8`, `rsa` `=rc.x`) to keep pkcs8 API stable — do NOT let Cargo bump these (see comments in `Cargo.toml`).
- `russh-sftp = 2` — SFTP subsystem over russh channels
- `rusqlite = 0.31` (feature `bundled`) — SQLite with statically linked C library, no system sqlite needed. WAL mode + 5s busy_timeout for cross-process (GUI/CLI/server) sharing.
- `tauri = 2` + `tauri-plugin-opener/dialog/fs = 2` — app shell + native dialogs/fs/url opener
- `reqwest = 0.12` (features `json`, `rustls-tls`, `stream`) — the ONLY HTTP client. Used by LLM, GitHub, WebDAV, update check. Uses rustls (no OpenSSL link).
- `tokio = 1` (features `sync`, `macros`, `net`, `io-util`, `rt`, `process`, `time`) — async runtime
- `keyring = 3` — platform-specific feature per OS: `apple-native` (macOS), `windows-native` (Windows), `sync-secret-service`+`crypto-rust` (Linux). Excluded on Android → falls back to file master key.

**Critical (Frontend):**
- `@xterm/xterm = 6.0.0` — terminal emulator (pinned exactly; addons `addon-fit`, `addon-search`, `addon-web-links`, `addon-unicode11`, `addon-image`)
- `@tauri-apps/api = ^2` — IPC (`invoke`, `listen`). One seam for all backend calls; see `src/lib/ipc-shim.ts` for the headless fallback.
- `codemirror = ^6` + `@codemirror/theme-one-dark` + `@codemirror/legacy-modes` — code editor (snippets, config views)
- `marked = ^18` + `dompurify = ^3` — markdown rendering for AI chat output (sanitized client-side)

**Infrastructure (Rust):**
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

**Environment:**
- No `.env` files. The project does not use a dotenv-style config. Secrets/API keys live in the encrypted DB `secrets` table (via `HybridStore`), not env vars.
- Notable env vars consumed at runtime (all optional, for tuning/compat):
  - `RUST_LOG` — overrides default `info` log level (`src-tauri/src/lib.rs:63`)
  - `RSSH_DISABLE_WAYLAND_COMPAT`, `RSSH_KEEP_GBM_BACKEND`, `WEBKIT_DISABLE_DMABUF_RENDERER`, `WAYLAND_DISPLAY`, `XDG_SESSION_TYPE` — Linux Wayland/GTK compat (`lib.rs:25-56`)
  - `RSSH_APP` — marks CLI-launched-from-GUI context (`src-tauri/src/bin/rssh/commands/open.rs:13`)
  - `DISPLAY` / `WAYLAND_DISPLAY` — CLI detects headless (`bin/rssh/main.rs:89`)
  - `SHELL`, `SystemRoot`, `PATH` — local shell discovery (`terminal/pty.rs`)
  - `TAURI_DEV_HOST` — Vite dev host override (`vite.config.ts:4`)

**Key configs required:**
- `src-tauri/tauri.conf.json` — Tauri bundle config (productName `RSSH`, identifier `com.rssh.app`, frontendDist `../dist`, devUrl `:1420`)
- `src-tauri/capabilities/default.json` — Tauri 2 permissions: `core:default`, `opener:default`, `dialog:default`, `fs:default`, `fs:allow-write-text-file`, window set-title/always-on-top
- `package.json` — npm scripts + frontend deps
- `vite.config.ts`, `vitest.config.ts`, `tsconfig.json`, `svelte.config.js`
- `src-tauri/gen/android/` — Android build files (incl. `key.properties` for signing)

**Build:**
- Build config files: `src-tauri/build.rs`, `vite.config.ts`, `tsconfig.json`, `svelte.config.js`, `idea-plugin/build.gradle.kts`
- Linux build needs system libs: `libgtk-3-dev libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev libudev-dev` (per `CONTRIBUTING.md` + `.github/workflows/release.yml`)
- Windows needs Visual Studio Build Tools (C++ workload)
- macOS needs Xcode Command Line Tools

## Platform Requirements

**Development:**
- Node >= 20 + Rust stable (all platforms)
- Linux: GTK/webkit2gtk/libudev dev headers (above)
- Windows: VS Build Tools C++
- macOS: Xcode CLT
- Android: JDK 17 + Android SDK/NDK + rust targets

**Production:**
- Desktop: Tauri-bundled native installers — macOS `.dmg` (aarch64 + x86_64), Linux `.deb`/`.rpm`/`.AppImage`, Windows `.msi`/`.exe`. Output: `src-tauri/target/release/bundle/`.
- Mobile: Android `.apk` (universal). iOS unsupported (no ID; "build yourself").
- JetBrains plugin: per-OS zip containing `rssh-server` + Kotlin plugin, installed via "Install Plugin from Disk".
- Data dir: `~/.rssh/` (desktop) or `app_data_dir` (Android) — holds `rssh.db`, `master.key` (headless/Android), `snippets.json`.
- Reads `~/.ssh/config` + `~/.ssh/known_hosts` (shared with OpenSSH — import + host-key verification).

---

*Stack analysis: 2026-07-08*
