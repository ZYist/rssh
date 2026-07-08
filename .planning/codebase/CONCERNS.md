# Codebase Concerns

**Analysis Date:** 2026-07-08

## Tech Debt

### Single-Threaded SSH Worker (acknowledged, deliberate)

- Issue: ALL SSH sessions and their operations run on ONE dedicated OS thread (`rssh-ssh`) via a `current_thread` tokio runtime + `LocalSet`. This is explicitly acknowledged in `roadmap.md` line 3 and implemented in `src-tauri/src/ssh/client.rs:45-55` (`ssh_dispatcher`).
- Files: `src-tauri/src/ssh/client.rs` (dispatcher at line 45), `roadmap.md` (line 3)
- Impact: No parallelism across SSH sessions. Heavy operations (large SFTP transfers, port-forward traffic, multi-session AI diagnosis) serialize through one thread. Currently "no bottleneck" per the team, but blocks scaling to many concurrent heavy sessions.
- Why it exists: Workaround for Rust HRTB-Send elaboration bug `rust-lang#96865` — russh's internal `&Sender<Msg>` borrows can't satisfy Send, so futures must spawn on a non-Send runtime (`LocalSet::spawn_local`), which pins to one thread.
- Fix approach: Per `roadmap.md`, migrate to a thread pool. Must preserve the non-Send `LocalSet` property per worker (one LocalSet per pool thread) and carefully handle SFTP reconnect + Handle affinity (a Handle must be operated on the same thread/runtime that created it).

### Large Monolithic Files

- Issue: Several files exceed 1000 lines, concentrating unrelated concerns and making safe modification hard.
- Files (Rust):
  - `src-tauri/src/ai/sanitize.rs` (2514 lines) — redaction + truncation + blacklist + command-shape validation in one file
  - `src-tauri/src/ai/session/file_ops.rs` (1673 lines) — match_file/patch_file remote capability probing + ANSI-C quoting + 5-card approval orchestration
  - `src-tauri/src/server.rs` (1542 lines) — headless WS server with a giant dispatch match over every command
  - `src-tauri/src/ai/session.rs` (1340 lines) — AI actor core loop
  - `src-tauri/src/ai/commands.rs` (1285 lines) — all AI `#[tauri::command]` handlers
  - `src-tauri/src/sync/config.rs` (1115 lines) — merge-import for every entity type
- Files (Frontend):
  - `src/lib/components/TerminalPane.svelte` (1758 lines) — xterm setup + highlight injection + auth modals + slow-send + stream normalization
  - `src/lib/components/AppShell.svelte` (1336 lines) — tab dispatch + lifecycle + window events
  - `src/lib/components/AiSettings.svelte` (1198 lines)
  - `src/lib/components/SftpBrowser.svelte` (1093 lines)
- Impact: High cognitive load to modify; merge conflicts; hard to test in isolation.
- Fix approach: Extract by responsibility (e.g., split `sanitize.rs` into `redact.rs` + `blacklist.rs` + `truncate.rs` + `shape.rs`; split `TerminalPane.svelte` auth modal logic into a child component). One PR per split, no behavior change.

### No Lint / Format Tooling

- Issue: No ESLint, Prettier, Biome, or Rust clippy configuration enforced in CI. `AGENT.md` line 159 states "无 lint" (no lint).
- Files: no `.eslintrc*`, `.prettierrc*`, `eslint.config.*`, `biome.json`, `clippy.toml`, or `.clippy` config present. CI workflows (`.github/workflows/*.yml`) run `cargo test` + `npm run test` but no lint gate.
- Impact: Style drift, missed bug-class checks (unused vars, `any` proliferation, unsafe patterns). Inconsistent code style across contributors.
- Fix approach: Add `biome.json` (single tool covers TS/Svelte formatting + linting) or ESLint + Prettier; gate in CI. Add `cargo clippy -- -D warnings` to the release workflows' test job.

### Pinned RustCrypto Pre-Release Dependencies

- Issue: The SSH stack depends on RustCrypto `rc` (release candidate) crate versions that are explicitly pinned with `=` to prevent Cargo from resolving them to incompatible newer crates.
- Files: `src-tauri/Cargo.toml:36-44`
- Impact: These pins are fragile — a transitive update or a yanked rc release can break the build. The pinning is load-bearing (incompatible pkcs8 APIs across rc versions), so it cannot be relaxed carelessly. This is forced by `russh = "0.60.1"` depending on RustCrypto prerelease APIs.
- Fix approach: Track russh releases; when russh moves to stable RustCrypto crates, drop the `=` pins. Until then, treat any `cargo update` touching these crates as a manual review item (the `Cargo.lock` is committed and holds the exact resolved versions).

## Known Bugs

### `isMobile` Does Not Respond to Window Resize

- Symptoms: Mobile-specific UI branches (keybar, no right-click, narrow layout) are fixed at startup and never re-evaluate if a desktop user resizes narrow or a tablet rotates.
- Files: `src/lib/stores/app.svelte.ts` (top-level `const isMobile`), documented as P7 in `AGENT.md:202-204`.
- Trigger: Any window resize / orientation change after launch.
- Workaround: None automatic. Components that need responsive breakpoints must implement their own `$state` + `resize` listener rather than relying on `app.isMobile`.
- Fix approach: Add a reactive `$state` breakpoint (e.g. `mediaNarrow`) backed by a `matchMedia` listener in `app.svelte.ts` for layout concerns; keep `isMobile` as a platform (touch/UA) signal distinct from viewport width.

## Security Considerations

### No Content Security Policy

- Risk: `tauri.conf.json:24-26` sets `"csp": null`, meaning the Tauri webview enforces no CSP. Any injected content (malicious npm dependency, XSS via terminal highlight injection, AI-rendered markdown) runs without restriction.
- Files: `src-tauri/tauri.conf.json`
- Current mitigation: Markdown is sanitized via `dompurify` (`src/lib/ai/markdown.ts`); terminal highlight injection is regex-based. But defense-in-depth is absent at the webview boundary.
- Recommendations: Set a restrictive CSP (e.g. `default-src 'self'; script-src 'self'; connect-src 'self' ipc: http://ipc.localhost`) and test that the xterm/codemirror/markdown rendering still works. Tauri 2 supports nonce-based CSP.

### Headless WS Server Token in URL Query String

- Risk: The headless server (`src-tauri/src/server.rs:88-96`) authenticates WebSocket connections with a per-launch token passed as `?token=...` in the WS URL. Query strings can leak into server access logs, browser history, and (without `noreferrer`) the `Referer` header on outbound navigation.
- Files: `src-tauri/src/server.rs:135-153` (token check), `src/lib/ipc-shim.ts:37` (client constructs `ws://...?token=...`)
- Current mitigation: Binds to `127.0.0.1` only (loopback, no remote access); `ipc-shim.ts:168` opens external URLs with `noopener,noreferrer` to avoid leaking the token via Referer. The comment at `server.rs:135-136` documents that browsers can't set WS headers, forcing the query-string approach.
- Recommendations: Token rotation is implicit (per-launch). Consider a short-lived single-use handshake (first message carries the token, then the server drops it) to reduce the query-string exposure window. Ensure no rssh code path logs the full WS URL.

### AI Auto-Execution (danger_mode) Default Behavior

- Risk: When `ai_danger_mode` is on, `run_command` and `match_file` tools auto-approve by default (`src-tauri/src/ai/commands.rs:55-56`, `1009`), meaning LLM-proposed commands run in the user's terminal without per-command confirmation.
- Files: `src-tauri/src/ai/commands.rs`, `src-tauri/src/ai/session.rs`
- Current mitigation: Commands are NOT executed silently in the backend — they are pasted into the user's interactive terminal with a sentinel (`session.rs:1-9`), so the user sees them. A command blacklist (`src-tauri/src/ai/command_blacklist.rs`, fail-closed) blocks destructive commands regardless of danger_mode. Output is redacted (`src-tauri/src/ai/sanitize.rs`) before reaching the LLM.
- Recommendations: The default-on auto-approval for `run_command` under danger_mode is a meaningful risk surface. Ensure the UI makes danger_mode state highly visible (the `DangerModeToggle.svelte` exists). Consider gating danger_mode behind an explicit per-session opt-in rather than a persisted global toggle.

### GitHub PAT in Config Sync

- Risk: GitHub config sync (`src-tauri/src/sync/github.rs`) uses a PAT stored in the secret store. If `save_to_remote` is enabled on a credential, its secret is included in the synced JSON (base64-encoded, optionally encrypted via `crypto.rs` if a backup password is set).
- Files: `src-tauri/src/sync/github.rs`, `src-tauri/src/sync/config.rs`, `src-tauri/src/commands/sync.rs`
- Current mitigation: Credentials have a per-row `save_to_remote` flag (AGENT.md P6); sync filters on it. Backup encryption uses Argon2id + ChaCha20-Poly1305 (`src-tauri/src/crypto.rs`) with explicit pinned KDF parameters.
- Recommendations: Ensure the UI clearly flags which credentials will be uploaded before a `config push`. Warn loudly if a backup password is not set (plaintext secrets would be base64-only).

## Performance Bottlenecks

### Single-Thread SSH Serialization

- Problem: All SSH I/O (sessions, SFTP, forwards) serializes through one `current_thread` runtime on the `rssh-ssh` thread.
- Files: `src-tauri/src/ssh/client.rs:45-55`
- Cause: Deliberate workaround for russh non-Send futures (see Tech Debt section).
- Improvement path: Thread pool with per-thread LocalSet (see roadmap.md line 3). Must preserve Handle/runtime affinity.

### SFTP AI Download Hard Limit

- Problem: AI-initiated SFTP downloads are capped at 100 MB (`src-tauri/src/ai/session.rs:51`, `MAX_DOWNLOAD_MB = 100`). Larger artifacts require manual scp + `analyze_locally`.
- Files: `src-tauri/src/ai/session.rs`
- Cause: Deliberate — prevents the LLM from silently pulling GB-scale files over a single SSH channel (documented as "hostile to the user").
- Improvement path: None intended; this is a designed safety bound, not a bug. Users with large artifacts use the explicit `analyze_locally` tool.

## Fragile Areas

### `reconcile_sessions` Multi-Window Hazard

- Files: `src-tauri/src/commands/lifecycle.rs:15-122`, `src/lib/components/AppShell.svelte:182`, documented as P1 in `AGENT.md:165-171`.
- Why fragile: Calling `reconcile_sessions(activeIds=[])` reaps EVERY non-alive session process-wide. Clone windows (opened via `open_tab_in_new_window`) share `AppState.sessions` with their parent, so an empty list on a clone kills the parent's sessions. Correctness depends on the `window.__rssh_clone` flag check in the frontend BEFORE calling reconcile.
- Safe modification: Any change to window-clone detection (`__rssh_clone`), startup flow, or the `reconcile_sessions` signature must be tested with multiple windows open. Never relax the clone-skip guard.
- Test coverage: No automated test covers the multi-window clone scenario (`commands/lifecycle.rs` has no `#[test]`).

### Terminal Highlight ANSI Injection

- Files: `src/lib/components/TerminalPane.svelte` (highlight decoration logic), documented as P3 in `AGENT.md:182-185`.
- Why fragile: User-configured keyword regexes are injected as ANSI 24-bit escape sequences into the PTY stdin stream via a stateful lexer. A naive `string.replace` would corrupt existing ANSI sequences. Modifying the lexer state machine without understanding it breaks colored output.
- Safe modification: Read the existing stateful highlight decoration code fully before touching it. Preserve all existing ANSI pass-through behavior. Test with a session that emits its own colors (e.g. `ls --color`).
- Test coverage: `src/lib/terminal/highlight.test.ts` and `highlight-decorations.test.ts` exist for the pure decoration logic, but the live PTY-stream injection path in `TerminalPane.svelte` is untested.

### Keyboard-Interactive Auth Waiter Leak

- Files: `src-tauri/src/state.rs:34-40` (`auth_waiters`, `passphrase_waiters`, `host_key_waiters`), documented as P4 in `AGENT.md:187-190`.
- Why fragile: SSH keyboard-interactive auth uses oneshot channels stored in `AppState.auth_waiters`. If a tab is closed mid-prompt without cleanup, the waiter entry leaks and the oneshot Sender is dropped without send, leaving the receiver hanging.
- Safe modification: Tab-close paths (`TerminalPane.svelte:1416-1444`) must call the corresponding `_cancel` commands (`ssh_auth_cancel`, `ssh_passphrase_cancel`, `ssh_host_key_cancel`) which remove the waiter. Any new auth-prompt flow must add a matching cancel + cleanup.
- Test coverage: No automated test for the waiter cleanup path.

### CLI Bypasses Tauri Command Layer

- Files: `src-tauri/src/bin/rssh/` (entire CLI), documented as P5 in `AGENT.md:192-195`.
- Why fragile: The CLI reads/writes the DB and SecretStore directly, NOT through `#[tauri::command]` handlers. When command-layer logic changes (validation, side effects, secret key naming), the CLI does not automatically follow.
- Safe modification: Any schema change (`db/schema.rs`), SecretStore key-naming change (`secret/mod.rs` account conventions), or validation logic MUST be audited against the CLI path in parallel.
- Test coverage: The CLI binary has no dedicated tests (it requires `--features cli` and is excluded from default `cargo test`).

### Tauri Command & Event Name Contracts

- Files: All `invoke("...")` callsites in `src/lib/**`, all `#[tauri::command]` in `src-tauri/src/commands/`, documented as P8 / R1 / R3 in `AGENT.md`.
- Why fragile: Command names (`invoke("ssh_connect")`) and event names (`ssh:data:<tabId>`) are hardcoded strings on both sides with no compile-time link. Renaming a Rust command without updating every frontend invoke string = runtime "command not found". The event three-part naming (`<domain>:<event>:<sessionId>`) is a hard convention to prevent multi-tab cross-talk.
- Safe modification: R3 (double-register in `generate_handler!`), R1 (grep `<domain>:` before renaming events). The `lib.rs` `generate_handler!` list (lines 163-352) is the single source of truth for registered commands.

## Scaling Limits

### Per-Process Session Map Growth

- Current capacity: `AppState` (`src-tauri/src/state.rs`) holds unbounded `HashMap`s for sessions, SFTP, forwards, PTY, serial, telnet, AI sessions. No explicit cap on open sessions/tabs.
- Limit: Bounded by OS file descriptors (SSH channels each hold sockets + PTY master/slave fds). The headless server already guards fd exhaustion at accept (`server.rs:101-112`). On desktop, a user opening dozens of heavy sessions could hit per-process fd limits.
- Scaling path: No tab/session cap enforced. If needed, add a configurable max-sessions setting with a clear error when exceeded.

## Dependencies at Risk

### russh + RustCrypto rc Pinned Cluster

- Risk: `russh = "0.60.1"` forces a cluster of RustCrypto `rc` (release candidate) crate versions to be pinned with `=` (`Cargo.toml:36-44`). These are pre-stable APIs.
- Impact: Build fragility on any `cargo update`; cannot relax pins without russh moving to stable RustCrypto. A yanked rc crate would break fresh builds until russh releases.
- Migration plan: Watch for russh releases that adopt stable RustCrypto crates; bump russh and drop the `=` pins together. Until then, rely on the committed `Cargo.lock` for reproducible builds.

### Tauri 2 Ecosystem (relatively new)

- Risk: Tauri 2.x (`tauri = "2"`) and its plugins (`tauri-plugin-opener`, `tauri-plugin-dialog`, `tauri-plugin-fs`) are specified with major-version-only ranges. Minor/patch updates within Tauri 2 have shipped breaking capability/permission changes historically.
- Impact: An unattended `cargo update` of the Tauri cluster could change capability semantics (e.g. the `fs:allow-write-text-file` permission in `capabilities/default.json`).
- Migration plan: Keep Tauri cluster updates as deliberate, manually-tested changes. The `Cargo.lock` pins exact versions.

## Missing Critical Features

### No Idle / Inactivity Lock

- Problem: No automatic session lock after inactivity. An unlocked workstation exposes live SSH terminals.
- Files: Listed in `roadmap.md:5` ("无活动锁定密码").
- Blocks: Compliance scenarios requiring session timeout; physical-security hardening.

### No Read-Only Session Mode

- Problem: No way to open an SSH session in a read-only (observe-only) mode that blocks input.
- Files: Listed in `roadmap.md:6`.
- Blocks: Safe shared-screen / audit observation; junior-operator scenarios.

### Host Key / known_hosts Visualization

- Problem: known_hosts entries are managed opaquely (TOFU prompt in terminal, `ssh-keygen -R` equivalent in `known_hosts.rs`). No UI to review trusted hosts.
- Files: Listed in `roadmap.md:2`. Implementation exists at `src-tauri/src/ssh/known_hosts.rs` (path resolution + `remove_host`), but no frontend screen consumes it.

## Test Coverage Gaps

### Core AI Orchestration (untested)

- What's not tested: `src-tauri/src/ai/session.rs` (1340 lines — the AI actor dialogue loop, tool-call dispatch, command-rejection flow) has ZERO `#[test]` functions.
- Files: `src-tauri/src/ai/session.rs`
- Risk: The command-paste sentinel mechanism, blacklist enforcement path, and tool-result→LLM feedback loop are the highest-stakes AI behavior and have no regression guard.
- Priority: High — this is where a blacklist-bypass or sentinel-corruption bug would hide.

### Headless WS Server (untested)

- What's not tested: `src-tauri/src/server.rs` (1542 lines — WS handshake, token auth, command dispatch for every entity type) has ZERO tests.
- Files: `src-tauri/src/server.rs`
- Risk: The dispatch match must stay in sync with `lib.rs::generate_handler!` (R3). A missing arm = silent "unknown command" failure in the IDEA plugin / browser path only.
- Priority: Medium — IDEA plugin users affected; desktop GUI unaffected.

### SSH/PTY/Terminal Transport Layer (mostly untested)

- What's not tested: `src-tauri/src/terminal/pty.rs` (391 lines), `src-tauri/src/ssh/known_hosts.rs`, `src-tauri/src/ssh/prompt.rs`, `src-tauri/src/ssh/mod.rs` have no tests. `src-tauri/src/ssh/client.rs` and `ssh/forward.rs` have tests but the connection/dispatch path is not covered.
- Files: `src-tauri/src/terminal/pty.rs`, `src-tauri/src/ssh/known_hosts.rs`, `src-tauri/src/ssh/client.rs`
- Risk: known_hosts line-rewriting logic (`remove_host`) mirrors russh's line-numbering convention by hand — a drift in russh's commenting/skip rules would silently delete wrong entries.
- Priority: Medium — known_hosts corruption is a security-adjacent data-loss risk.

### LLM Provider Clients (mostly untested)

- What's not tested: `src-tauri/src/ai/llm/openai.rs`, `glm.rs`, `deepseek.rs`, `protocol.rs` have no tests. Only `anthropic.rs` and `llm/mod.rs` have tests. The shared `protocol.rs` (SSE parsing, request serialization) is the actual wire path for 3 of 4 providers.
- Files: `src-tauri/src/ai/llm/protocol.rs`, `openai.rs`, `glm.rs`, `deepseek.rs`
- Risk: SSE parser regression would break streaming for all non-Anthropic providers.
- Priority: Medium.

### Secret Store Backends (partially untested)

- What's not tested: `src-tauri/src/secret/db_store.rs` and `keyring_store.rs` have no tests. `hybrid_store.rs`, `master_key.rs`, `crypto.rs`, `mod.rs` do have tests.
- Files: `src-tauri/src/secret/db_store.rs`, `src-tauri/src/secret/keyring_store.rs`
- Risk: DB ciphertext read/write path is the actual secret persistence layer on all platforms (HybridStore encrypts then DbStore writes).
- Priority: Medium — the crypto and hybrid layers are tested, but the DB row mapping is not.

### Commands Module (mostly untested)

- What's not tested: Only 4 of ~15 command modules have tests (`profile.rs`, `settings.rs`, `sync.rs`, `window.rs`). Untested: `session.rs`, `sftp.rs`, `forward.rs`, `pty.rs`, `serial.rs`, `telnet.rs`, `lifecycle.rs`, `cli.rs`, `external.rs`, `group.rs`, `update.rs`.
- Files: `src-tauri/src/commands/*.rs`
- Risk: The `#[tauri::command]` handlers are thin wrappers over DB/engine calls (which ARE tested), so risk is moderate. But `lifecycle.rs` reconciliation logic is high-risk (see Fragile Areas).
- Priority: Medium for `lifecycle.rs`; Low for thin CRUD wrappers.

### Frontend Coverage (~30% file coverage)

- What's not tested: 31 test files cover ~104 source files. Major untested components: `TerminalPane.svelte` (1758 lines), `AppShell.svelte` (1336), `SftpBrowser.svelte` (1093), `AiSettings.svelte` (1198), `ChatPanel.svelte` (666), `SyncScreen.svelte` (582).
- Files: `src/lib/components/*.svelte` (most untested), `src/lib/ai/store.svelte.ts` (964 lines, untested)
- Risk: UI logic (tab lifecycle, event wiring, OSC decode→store) is the most regression-prone frontend surface and is entirely uncovered except through pure-function unit tests of extracted modules.
- Priority: Medium — the pure logic is well-extracted and tested; the Svelte component glue is not.

### No E2E / Integration Tests

- What's not tested: No end-to-end test drives the app (launch, connect to a mock SSH server, run a command, verify terminal output). No integration test exercises the Tauri command → DB → SecretStore round-trip. `AGENT.md` line 159 and Pr5 prescribe "跑 dev 点过" (manually click through dev mode) as the verification method.
- Files: None — no e2e framework present.
- Risk: Cross-layer regressions (frontend invoke wiring, event-name contracts, command registration) are caught only by manual testing.
- Priority: Medium — high value but high setup cost (Tauri e2e is non-trivial).

---

*Concerns audit: 2026-07-08*
