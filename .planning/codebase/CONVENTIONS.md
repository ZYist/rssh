# Coding Conventions

**Analysis Date:** 2026-07-08

This is a Tauri 2 desktop/mobile app: **Svelte 5 (runes) + TypeScript** frontend in `src/`, **Rust** backend in `src-tauri/src/`. There is no ESLint/Prettier/Biome config in the repo; frontend style is enforced by review against the rules below, Rust style by `cargo fmt` + `cargo clippy`. The canonical, authoritative ruleset is `AGENT.md` (root) — sections R1–R10 and Pr1–Pr5. This document mirrors and elaborates what the code actually does.

## Naming Patterns

**Files (frontend):**
- Svelte components: `PascalCase.svelte` — e.g. `src/lib/components/AppShell.svelte`, `src/lib/ai/ChatPanel.svelte`.
- TypeScript modules: `kebab-case.ts` — e.g. `src/lib/ai/shell-probe.ts`, `src/lib/osc/handler.ts`, `src/lib/components/sidebar-ripple.ts`.
- Modules that use Svelte 5 runes (so they need the svelte Vite plugin to transform): suffix `.svelte.ts` — e.g. `src/lib/stores/app.svelte.ts`, `src/lib/i18n/index.svelte.ts`, `src/lib/ai/store.svelte.ts`. Plain `.ts` for pure-logic modules.
- Tests: co-located, `<module>.test.ts` next to `<module>.ts`.

**Files (Rust):**
- `snake_case.rs`, one module per file under `src-tauri/src/<domain>/`. Commands in `commands/`, DB access in `db/`, etc.

**Functions / variables (TypeScript):**
- `camelCase` for functions and locals.
- Store getters are verb phrases with **no** `get` prefix: `tabs()`, `activeTabId()`, `settingsActive()`, `sftpOpenForTab(tabId)`. See `src/lib/stores/app.svelte.ts:175`.
- Actions are imperative verbs: `addTab`, `closeTab`, `setActiveTab`, `moveTab`.

**Functions / variables (Rust):**
- `snake_case` for fns and fields, `PascalCase` for types. DB row helpers: `row_to_profile`. CRUD fns: `list`, `get`, `insert`, `update`, `delete` (in `src-tauri/src/db/*.rs`).

**Types:**
- `PascalCase` for interfaces, type aliases, enums: `Tab`, `Profile`, `SettingsPage`, `TabType` (frontend); `AppError`, `AppState`, `Profile`, `Forward` (Rust).
- String-literal unions preferred for closed sets: `export type TabType = "home" | "ssh" | "local" | "serial" | "telnet" | "forward" | "edit"` in `src/lib/stores/app.svelte.ts:16`.

**Constants:**
- `SCREAMING_SNAKE_CASE` for module-level magic values: `OSC_RSSH_ID = 7337` (`src/lib/osc/handler.ts:12`), `CMD_DISPLAY_MAX` (`src/lib/ai/format.ts:8`), `DEFAULT_TTL_MS` (`src/lib/stores/toast.svelte.ts:4`).

## Code Style

**Formatting (frontend):**
- No formatter configured. Indentation is 2 spaces in Svelte/TS (some files use 4 — inconsistent, but 2 dominates in `src/lib/stores/` and `src/lib/ai/`). Match the surrounding file.
- Double quotes for string literals throughout the frontend (`import { describe, it, expect } from "vitest"`).
- Trailing semicolons on statements.
- Semicolons omitted after `$state(...)` declarations only when the line is a simple assignment (mixed — follow the file).

**Formatting (Rust):**
- `cargo fmt` is the source of truth — 4-space indent, standard rustfmt layout. Run `cargo fmt` before commit (see `CONTRIBUTING.md` "Code Style").

**Linting:**
- Frontend: **none** (no eslint/prettier config). `AGENT.md` historically said "无 lint"; still true.
- Rust: `cargo clippy` is expected (per `CONTRIBUTING.md`). No `clippy.toml` / `#![deny(clippy::...)]` attributes seen — default warning level.

**TypeScript strictness:**
- `tsconfig.json` has `"strict": true`, `"noEmit": true`, `"isolatedModules": true`, `"target": "ES2021"`. Types are load-bearing — tests use precise literal types (e.g. `vi.fn((): false => false)` in `src/lib/keyboard/registry.test.ts:111` to match a `() => false | void` contract).
- `allowImportingTsExtensions: true` → **always write the `.ts` / `.svelte.ts` extension in relative imports**: `import { formatTokenCount } from "./tokens.ts"` (`src/lib/ai/tokens.test.ts:2`). Not optional.

## Import Organization

**Order (frontend):**
1. External packages first: `import { describe, it, expect } from "vitest"`, `import { invoke } from "@tauri-apps/api/core"`, `import { Terminal } from "@xterm/xterm"`, `import type { ITheme, IBufferCell } from "@xterm/xterm"`.
2. Then local modules by relative path: `import * as app from "../stores/app.svelte.ts"`, `import { t, errMsg } from "../i18n/index.svelte.ts"`.
3. Type-only imports use `import type { ... }` to respect `isolatedModules`.

**Path aliases:** None. All imports are relative (`./`, `../`). No `@/` alias, no `paths` in `tsconfig.json`.

**Barrel files:** None. Modules import specific files directly (`./handler.ts`, `./registry.ts`). Do not add `index.ts` re-export aggregators.

**Side-effect imports:** `src/main.ts:3` uses `import "./lib/ipc-boot.ts"` (must run before any store import); comment it as such.

## Error Handling

**Rust — the canonical path (`src-tauri/src/error.rs`):**
- All fallible backend code returns `AppResult<T>` (= `Result<T, AppError>`).
- `AppError` is a `thiserror::Error` enum. Every business variant wraps a `CodedMsg { code, params }`.
- `CodedMsg::Display` serializes to the wire format `__rssh_err__|{"code":"...","params":{...}}` so the frontend can translate.
- **Every error must carry an i18n code.** There is intentionally no "raw string error" escape hatch (see the header comment in `src-tauri/src/error.rs:5`). Construct errors with the helper constructors:
  ```rust
  AppError::not_found("profile_not_found", serde_json::json!({ "id": id }))
  AppError::config("name_has_control_char", serde_json::json!({}))
  AppError::ssh("ssh_connect_failed", json!({ "host": "h" }))
  ```
  (`src-tauri/src/db/profile.rs:37`, `src-tauri/src/error.rs:278`).
- `From<rusqlite::Error>` and `From<std::io::Error>` are implemented, so `?` propagates them as `AppError::Database` / `AppError::Io` automatically.
- `#[tauri::command]` fns return `Result<T, AppError>`; Tauri serializes the error via `Display` → frontend receives the `__rssh_err__|...` string.

**Frontend — the canonical path:**
- Wrap every `invoke(...)` in try/catch and surface failures via `toast.error(errMsg(e))` or `toast.error(`${t("toast.error.save")}: ${errMsg(e)}`)`.
- `errMsg()` (`src/lib/i18n/index.svelte.ts:68`) unwraps the `__rssh_err__|` prefix and looks up `error.<code>` in the locale catalog; plain strings pass through.
- Pattern repeated across editors/managers:
  ```typescript
  try {
      await invoke("create_credential", { credential });
  } catch (e: any) {
      toast.error(`${t("toast.error.save")}: ${errMsg(e)}`);
  }
  ```
  (`src/lib/components/CredentialEditor.svelte:75`, `GroupManager.svelte:74`, `HighlightManager.svelte:69`, …).
- One-liner fire-and-forget form: `void invoke(cmd, {...}).catch((e) => toast.error(errMsg(e)))` (`src/lib/components/AppShell.svelte:743`).

**Do NOT silently swallow errors.** `AGENT.md` Pr2: `.catch(() => {})` is forbidden unless the path is a confirmed cleanup/teardown. The codebase still has a few bare `catch {}` on localStorage reads (`src/App.svelte:45`, `src/lib/stores/app.svelte.ts` `loadStringArray`) — those are deliberate because the in-memory state is already correct and failure only degrades persistence; they are commented as such. When adding new code, default to surfacing the error.

**Frontend defensive guards (module-load paths):** localStorage / navigator may be absent (vitest node env, non-app hosts). Guard with `typeof localStorage !== "undefined"` / `typeof navigator !== "undefined"` rather than letting module import throw — see `src/lib/i18n/index.svelte.ts:21` and `src/lib/stores/app.svelte.ts:10`.

## Logging

**Framework:** `console` on the frontend; `log` + `env_logger` on the Rust backend (`Cargo.toml:28-29`).

**Frontend patterns:**
- `console.warn("[<domain>] <what> failed:", e)` for non-fatal background failures (e.g. `src/main.ts:30` `console.warn("[ai] settings preheat failed:", e)`).
- `console.error(...)` for truly unexpected failures (`src/lib/components/AppShell.svelte:43`).
- `console.debug(...)` for skippable diagnostics (`src/App.svelte:57`).
- Tag prefix convention: `[ai]`, `[app]`, `[sync]` — domain in brackets.

**Rust patterns:** use the `log` crate macros (`info!`, `warn!`, `error!`, `debug!`). `env_logger` initializes from `RUST_LOG`.

**User-facing failures** always go through `toast.*` (frontend) or `AppError` codes (backend), never raw `console.log` to the user.

## Comments

**When to comment:** This codebase comments heavily on *why*, not *what*. Multi-line block comments explain the non-obvious invariant, the bug a line prevents, or the tradeoff. See the rationale block at the top of `src/lib/stores/app.svelte.ts:122` (SFTP per-tab design), the `safeSetItem` doc comment (`app.svelte.ts:150`), and the long comment in `vite.config.ts:9` explaining the xterm/esbuild es2021 target.

**Language:** Comments are bilingual — English for the doc/rationale, Chinese (中文) for inline asides, reviewer notes, and "why this changed" notes. Both are accepted; match the surrounding file. Examples: `src/lib/osc/handler.ts:30` (Chinese inline), `src/lib/i18n/index.svelte.ts:1` (Chinese module doc).

**JSDoc/TSDoc:** Used on exported library-style functions and types, especially in pure-logic modules: `src/lib/ai/format.ts`, `src/lib/ai/tokens.ts`, `src/lib/sftp-name.ts`, `src/lib/stores/toast.svelte.ts`. Use `/** ... */` with `@param`-style prose. Not used on every function — UI glue in components is usually uncommented or uses inline `//`.

**Rust doc comments:** `///` on public items, `//!` for module-level docs. Chinese inline comments are common in test modules (e.g. `src-tauri/src/commands/profile.rs:344`).

**Self-check headers:** `AGENT.md` Pr5 is the pre-commit checklist — reference it when writing new code.

## Function Design

**Size:** Small, single-purpose. The store files are long (`app.svelte.ts` ~1000+ lines) but each exported function is short (`addTab`, `moveTab`, `closeTab` are 5–15 lines). Pure logic helpers (`formatTokenCount`, `remoteUploadName`, `rippleWidth`) are 5–20 lines and independently testable.

**Parameters:** Object parameters for commands/entities (`Profile`, `Credential`); positional for narrow helpers. Rust DB fns take `&Db` first, then the entity/id.

**Return values:**
- Store getters return the `$state` value (reactive snapshot) — `function tabs() { return _tabs; }`.
- Mutators return `void` (they assign to `$state`); the change is observed via getters.
- Pure formatters return their output directly.
- Rust: `AppResult<T>` for anything fallible; bare `T` only when infallible.

## Module Design

**Exports (frontend):**
- Named exports only. No default exports except Svelte components (`export default` in `App.svelte`, `AppShell.svelte`, etc.) and the `main.ts` mount default.
- Store modules use the **private-state + getter-function** pattern (AGENT.md R8):
  ```typescript
  let _tabs = $state<Tab[]>([...]);
  let _activeTabId = $state("home");
  export function tabs() { return _tabs; }
  export function activeTabId() { return _activeTabId; }
  ```
  **Never export a bare `$state` object.** All writes go through exported mutator functions. See `src/lib/stores/app.svelte.ts:110` and `src/lib/stores/toast.svelte.ts:6`.
- Cross-cutting state lives in `src/lib/stores/app.svelte.ts` only. Do not build global state inside a component (R8).

**Svelte 5 runes (R7 — enforced, violations are reject-merge):**
- Use `$state`, `$derived`, `$effect`, `$props` only.
- Event handlers are `onclick={fn}`, `oninput={...}` — **never** `on:click`, `$:`, or `export let`. `AGENT.md` R7 explicitly says reject these on review.
- Runes work in `.svelte` and `.svelte.ts` files (transformed by `@sveltejs/vite-plugin-svelte`, which `vitest.config.ts` also enables so i18n's `$state` imports don't crash tests).

**Platform branching (R9):**
- Rust: `#[cfg(target_os = "android")]`, `#[cfg(unix)]`, `#[cfg(not(target_os = "android"))]`. See `src-tauri/Cargo.toml:83-102` for the target-specific dependency split.
- Frontend: `app.isMobile` (one-time `navigator.userAgent` sniff, a `const` — does not react to resize, R9/P7). Use it for mobile-only UI branches; do not runtime-probe the platform otherwise.

**Rust `#[tauri::command]` registration (R3):** Every command must be added to the `generate_handler!` macro in `src-tauri/src/lib.rs` **as well as** defined in `commands/*.rs`. Missing the registration → frontend `invoke("name")` fails at runtime with "command not found".

**Tauri event naming (R1):** Emit/listen with `<domain>:<event>:<sessionId>` (three-part, session-scoped). Bare global events cross-talk between tabs. Verify with `rg 'emit\(' src-tauri/src`.

**Secret handling (R5):** Never write secrets to the DB in plaintext. Use `SecretStore` (`src-tauri/src/secret/`); the DB row stores the credential metadata, the secret goes to keychain (macOS/Windows/Linux) or DB-fallback (Android) through the one abstraction.

## CSS Conventions

- Theme tokens are the single source of truth in `src/styles/global.css` (`:root` block): `--bg`, `--surface`, `--accent`, `--error`, `--success`, `--text`, `--space-*`, `--radius-*`, `--density`, etc.
- **Use the tokens, never raw hex** (AGENT.md Pr3). Raw hex breaks theme switching (dark/light/neumorphism/flat/material shapes).
- Reuse existing utility classes (`.neu-*`, `.btn*`, `.surface-raised`, `.toast-*`) before adding new ones.
- Shape presets live in `src/styles/shapes/{neumorphism,flat,material}.css`, activated via `[data-shape="..."]`.
- Tab/pane root containers must follow the R4 three-piece: `flex: 1; overflow-y: auto; min-height: 0;` (omit `min-height: 0` → flex child won't shrink, overflow breaks).
- Icons are hand-drawn SVG; **no emoji** in the UI (Pr3).

---

*Convention analysis: 2026-07-08*
