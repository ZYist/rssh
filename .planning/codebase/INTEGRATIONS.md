# External Integrations

**Analysis Date:** 2026-07-08

## APIs & External Services

**LLM Providers (BYOK — bring your own key):**

All LLM calls are hand-rolled `reqwest` HTTP streaming with a custom SSE parser (`src-tauri/src/ai/llm/mod.rs:142-231`). Zero SDK dependencies. Dispatch in `build_client` (`ai/llm/mod.rs:120-137`). Provider choice + model + endpoint + API key persisted per-user (see Auth & Identity below).

- **Anthropic Messages API** — AI triage backend
  - Client: `src-tauri/src/ai/llm/anthropic.rs`
  - Default endpoint: `https://api.anthropic.com/v1/messages`
  - Models endpoint: `https://api.anthropic.com/v1/models`
  - Protocol header: `anthropic-version: 2023-06-01`
  - Auth: `x-api-key: <key>` (stored as secret `setting:ai_anthropic_key`)
  - Custom endpoint overridable via settings.

- **OpenAI Chat Completions** — shared OpenAI-compatible protocol impl in `ai/llm/protocol.rs`
  - Client: `src-tauri/src/ai/llm/openai.rs`
  - Default base: `https://api.openai.com/v1`
  - Auth: `Authorization: Bearer <key>` (secret `setting:ai_openai_key`)
  - `/models` enumerated live from provider.

- **OpenAI-compatible vendors** (reuse `protocol.rs`):
  - **DeepSeek** — `src-tauri/src/ai/llm/deepseek.rs`; base `https://api.deepseek.com/v1`; models e.g. `deepseek-chat`, `deepseek-reasoner` (reasoning chain echoed back per vendor spec).
  - **GLM / 智谱 BigModel** — `src-tauri/src/ai/llm/glm.rs`; base `https://open.bigmodel.cn/api/paas/v4`; `/models` NOT exposed → hardcoded `KNOWN_MODELS` list (`glm-4.6`, `glm-4-plus`, `glm-4-air`, `glm-4-airx`, `glm-4-flash`, `glm-4-long`).
  - Any other OpenAI-compatible endpoint works via the `openai-compatible` provider (custom endpoint + key).

Adding a new vendor: ~40-line file specifying endpoint + default model + `list_models`, then one dispatch line in `build_client` (per the doc comment in `ai/llm/mod.rs:10`).

LLM tools exposed to all providers (schema in `src-tauri/src/ai/tools.rs`): `run_command`, `load_skill`, `download_file`, `analyze_locally`, `match_file`, `patch_file`. Output is sanitized/redacted locally before being sent back to the model (`src-tauri/src/ai/sanitize.rs`, `src-tauri/src/ai/redact_rules.rs`).

**GitHub:**
- **Config sync** — encrypted backup of profiles/credentials/etc to a user-owned repo via the Contents API.
  - Client: `src-tauri/src/sync/github.rs`
  - API base: `https://api.github.com`
  - File: `rssh_backup.json` at repo root
  - Endpoints: `GET/PUT /repos/{owner}/{repo}/contents/rssh_backup.json?ref={branch}` (PUT includes `sha` for update)
  - Auth: `Authorization: Bearer <PAT>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `User-Agent: RSSH`
  - PAT stored as secret `setting:github_token`. Repo slug + branch in `settings` table.
- **Update check** — latest release tag polling.
  - Client: `src-tauri/src/commands/update.rs`
  - Hits HTML page `https://github.com/{repo}/releases/latest` (NOT the JSON API — deliberately avoids the 60 req/h unauthenticated API limit; parses tag from the 302 redirect `Location` header). Repo hardcoded `shihuili1218/rssh` in `src/lib/stores/updates.svelte.ts:4`. Checks 10s after startup then every 6h.

**WebDAV:**
- **Config sync** — alternative encrypted backup target.
  - Client: `src-tauri/src/sync/webdav.rs`
  - File: `rssh_backup.enc` at the user-provided base URL
  - Methods: `GET` (pull), `PUT` (push); HTTP/HTTPS only (validated), no userinfo/query/fragment allowed in URL.
  - Auth: HTTP Basic (`username`, `password`)
  - 30s timeout; 401/403 mapped to `webdav_auth_failed`. Error bodies streamed + truncated to 2048 bytes.

**SSH (the core transport):**
- Pure-Rust SSH2 client via `russh 0.60.1` (`src-tauri/src/ssh/`). No external `ssh` binary required.
- Auth methods (`src-tauri/src/ssh/auth.rs`): password, private key, keyboard-interactive; ProxyJump/bastion chains (`ssh/bastion.rs`).
- Host keys: verified against `~/.ssh/known_hosts` (`ssh/known_hosts.rs`), prompts on unknown host key.
- Port forwarding: local + remote + dynamic (`ssh/forward.rs`), with live byte counters.
- SFTP subsystem via `russh-sftp 2` (`src-tauri/src/ssh/sftp.rs`) — list, upload, download, mkdir, rename, remove, stat, recursive walk.
- `~/.ssh/config` import with `Include` glob expansion (`ssh/config.rs`, issue #96).
- Runs on a dedicated `rssh-ssh` worker thread driving a `current_thread` tokio runtime + `LocalSet` (see `ssh/client.rs:31-50` — dodges russh HRTB-Send limitation).

**Serial console (desktop only):**
- `serialport = 4.9.0` in `src-tauri/src/terminal/serial.rs`. Linux links libudev at build time. Excluded on Android.

**Telnet:**
- Plain TCP telnet transport, `src-tauri/src/terminal/telnet.rs` (all platforms, no native deps).

## Data Storage

**Databases:**
- **SQLite** (embedded, `rusqlite` bundled) — the single source of truth.
  - Path: `~/.rssh/rssh.db` (desktop) / `app_data_dir/rssh.db` (Android)
  - Connection: `src-tauri/src/db/mod.rs:31` — `PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;` (WAL lets GUI/CLI/server share the file without writer blocking; busy_timeout handles cross-process contention).
  - Schema version: 22 (migrated idempotently in `db/schema.rs:migrate`).
  - Tables: `credentials`, `profiles`, `settings`, `forwards`, `highlights`, `groups`, `secrets` (encrypted blob store), `snippets` (also mirrored to `~/.rssh/snippets.json`), `ai_skills`, `ai_redact_rules`, `ai_command_blacklist`, `ai_conversations`, `serial_profiles`, `telnet_profiles`.
  - Access pattern: `Db` wraps `Mutex<Connection>`; domain methods live in `db/*.rs` submodules; `with_transaction` / `with_exclusive_lock` for atomic multi-write and cross-process critical sections.

**File Storage:**
- Local filesystem at `~/.rssh/`: `rssh.db`, `snippets.json`, `master.key` (headless/Android keychain fallback).
- Session recordings: asciicast v2 format, written by `src-tauri/src/terminal/recorder.rs`; paths surfaced via `commands::settings::list_recordings` / `read_recording`.
- SFTP downloads / local file picks via `tauri-plugin-dialog` + `tauri-plugin-fs` (desktop) or `content://` URIs (Android) — see `commands::sftp`.
- CLI binary staged at `src-tauri/bin/` and bundled as a Tauri resource.

**Caching:**
- In-process only: SSH passphrase cache (`state.passphrase_cache`), remote-shell probe cache (`state.ai_remote_shell_cache`). No external cache service (no Redis/Memcached).

## Authentication & Identity

**App-side (RSSH users):**
- No central identity provider / user accounts. The app is local-first; the "user" is whoever runs the binary.

**Secret storage (unified architecture, `src-tauri/src/secret/mod.rs`):**
- Master-key envelope encryption: secrets are `ChaCha20-Poly1305` ciphertext in the `secrets` DB table; the 32-byte master key is held in the OS keychain (when available) or in `<data_dir>/master.key` (headless server / Android).
- Key namespacing (`secret/mod.rs:32-38`):
  - `cred:<credential_id>:secret` — credential password or private-key PEM
  - `setting:github_token` — GitHub PAT
  - `setting:ai_<provider>_key` — LLM API keys
- Backend selection is **sticky** (persisted in `settings.master_key_backend`): first-launch probes keychain availability; subsequent launches never flip backend silently (would orphan ciphertext). Keychain failure on a keyring-pinned install is a hard fail, not a silent fallback.
- Platform keychain via `keyring = 3`: macOS `apple-native`, Windows `windows-native`, Linux `sync-secret-service` + `crypto-rust` (D-Bus Secret Service). Android has no keyring backend → file master key.

**Config-backup encryption (`src-tauri/src/crypto.rs`):**
- Wire format v2: `base64(version[1] || salt[16] || nonce[12] || ciphertext_with_tag)`.
- KDF: Argon2id with **pinned** params (OWASP 2024 baseline: 19 MiB / 2 iter / 1 lane) — NOT `Argon2::default()` to avoid cross-version drift. Bumping params requires a v3 bump.
- AEAD: ChaCha20-Poly1305. `getrandom` for salt+nonce. `zeroize` for in-memory passphrase cache.

**SSH auth:** password / private key (with optional passphrase, cached in-process only) / keyboard-interactive; bastion ProxyJump chains. Known-host verification against OpenSSH's `~/.ssh/known_hosts`.

**External service auth:** all bearer/basic tokens are user-supplied (BYOK), stored as secrets (above). RSSH has no server-side credentials of its own.

## Monitoring & Observability

**Error Tracking:**
- None external (no Sentry/Datadog). Errors flow through the typed `AppError` enum (`src-tauri/src/error.rs`) with stable string error codes (e.g. `github_push_failed`, `webdav_auth_failed`, `llm_unknown_provider`) and `serde_json::Value` params, surfaced to the frontend and rendered in toasts.

**Logs:**
- Rust: `env_logger` (init at startup, default level `info`, override via `RUST_LOG`). Comments/logs are frequently bilingual (Chinese + English) throughout `src-tauri/`.
- Frontend: browser `console.*`; no structured logger.

## CI/CD & Deployment

**Hosting:**
- Self-hosted desktop/mobile binaries distributed via GitHub Releases (no server-side hosting — the product runs entirely on the client, except user-configured LLM/sync endpoints).

**CI Pipeline:**
- **GitHub Actions** — `.github/workflows/`:
  - `release.yml` — triggered by `v*` tags. Test gate (`ubuntu-22.04`): `npm ci` → `npm test` (Vitest) → `cargo test`. Then matrix builds: macOS (aarch64 + x86_64 via `macos-latest` + `macos-14`), Linux (deb/rpm/AppImage), Windows (msi + setup.exe), Android (universal apk). Version synced into `package.json` / `tauri.conf.json` / `Cargo.toml` from the git tag.
  - `pre-release.yml` — pre-release/draft flow.
  - `share-next.yml`, `create-pod.yml` — ancillary.
- Rust caching via `Swatinem/rust-cache@v2` (workspace `src-tauri`); Node via `actions/setup-node@v4` with `cache: npm`.

**Distribution artifacts:** `rssh-{version}-{os}-{arch}.{ext}` naming (per `CONTRIBUTING.md:204`). JetBrains plugin zips are per-OS (each bundles the OS-specific `rssh-server`).

## Environment Configuration

**Required env vars:**
- None at runtime. All persistent config lives in the SQLite `settings` table (plaintext behavior prefs) or `secrets` table (encrypted values). The app is fully functional with zero env vars set.

**Optional / tuning env vars (see STACK.md "Configuration" for the full list):**
- `RUST_LOG`, `RSSH_DISABLE_WAYLAND_COMPAT`, `RSSH_KEEP_GBM_BACKEND`, `RSSH_APP`, `TAURI_DEV_HOST`, `SHELL`, `DISPLAY`/`WAYLAND_DISPLAY`.

**Secrets location:**
- User-supplied API keys / PATs / WebDAV creds → encrypted in `secrets` table, master key in OS keychain (or `<data_dir>/master.key`).
- SSH credentials → same `secrets` table under `cred:*` keys.
- No `.env` files; no secrets in env vars. `.gitignore` excludes `.claude/`, `.codex/`, build dirs.

## Webhooks & Callbacks

**Incoming:**
- None. RSSH initiates all outbound connections (LLM, GitHub, WebDAV, SSH). No inbound HTTP listener in the desktop/CLI app.

- **Headless server (feature `server`)** opens ONE loopback TCP port for the JetBrains plugin / browser mode: serves the embedded UI over HTTP and the IPC protocol over WebSocket on the same port, guarded by a per-launch token printed to stdout. Bound to `127.0.0.1` only — not a public webhook endpoint. See `src-tauri/src/server.rs`, `src/lib/ipc-shim.ts`.

**Outgoing:**
- LLM streaming POST (SSE) → user-configured provider endpoint
- GitHub REST (`api.github.com`) for sync + update check
- WebDAV PUT/GET → user-configured WebDAV server
- SSH/Telnet/Serial → user-configured hosts/ports (the primary function of the app)
- No outbound analytics, telemetry, or crash-reporting calls.

---

*Integration audit: 2026-07-08*
