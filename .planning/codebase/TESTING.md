# Testing Patterns

**Analysis Date:** 2026-07-08

This repo has **two parallel test suites**, both run in CI as a hard gate before any build job:

- **Frontend:** Vitest 4.x, pure-logic / protocol-parsing / store-behavior tests. ~30 spec files in `src/lib/`.
- **Backend:** Rust inline `#[cfg(test)] mod tests` blocks, ~505 `#[test]` functions across 45 files. Heavy on DB-CRUD correctness, AI sanitization, crypto, and sync.

There is **no E2E suite** (no Playwright/Cypress/WebDriver). UI changes are verified manually via `npm run tauri dev` (AGENT.md Pr4 / Pr5). Note: `AGENT.md` still says "无 lint，无 unit test" in its Facts section — that line is **stale**; both vitest and `cargo test` exist and run in CI.

## Test Framework

**Frontend runner:**
- Vitest `^4.1.5` (devDependency in `package.json:37`)
- Config: `vitest.config.ts`
  ```typescript
  import { defineConfig } from "vitest/config";
  import { svelte } from "@sveltejs/vite-plugin-svelte";

  export default defineConfig({
    plugins: [svelte()],
    test: {
      include: ["src/**/*.test.ts"],
      environment: "node",
    },
  });
  ```
- The `svelte()` plugin is required so `.svelte.ts` modules using runes (e.g. `src/lib/i18n/index.svelte.ts`'s `let _locale = $state(...)`) can be imported under tests — without it `$state` is undefined and the import throws. The top-of-file comment in `vitest.config.ts` calls this out.
- `environment: "node"` (not jsdom): tests target pure logic, so there's no DOM. Browser globals (`window`, `localStorage`, `navigator`, `WebSocket`) are stubbed per-test where needed (see Mocking).

**Backend runner:**
- Built-in `cargo test`. No harness crate. Default feature set (`default = []`); `tempfile` is in `[dev-dependencies]` so it's available unconditionally without `--features cli` (`src-tauri/Cargo.toml:110-114`).

**Assertion libraries:**
- Frontend: Vitest's built-in `expect` (Jest-compatible API: `toBe`, `toEqual`, `toMatch`, `toHaveLength`, `toContain`, `toThrow`, `toHaveBeenCalledWith`, `mock.calls[0][0]`).
- Backend: standard `assert!` / `assert_eq!` macros. No `pretty_assertions` / `spectral`.

**Run commands:**
```bash
# Frontend
npm test                 # vitest run (single pass, CI mode) — = "vitest run"
npm run test:watch       # vitest (watch mode)

# Backend (run from src-tauri/)
cd src-tauri && cargo test              # all targets, default features
cd src-tauri && cargo test sanitize     # filter by module/test name substring
cd src-tauri && cargo test --features cli   # include cli-gated code paths

# Pre-commit self-check (AGENT.md Pr5)
npm run build            # vite frontend build (also a type-check via tsc)
cd src-tauri && cargo check
```

## Test File Organization

**Frontend location:** co-located, always. `foo.ts` is tested by `foo.test.ts` in the same directory. Examples:
- `src/lib/ai/tokens.ts` ↔ `src/lib/ai/tokens.test.ts`
- `src/lib/osc/handler.ts` ↔ `src/lib/osc/handler.test.ts`
- `src/lib/stores/app.svelte.ts` ↔ `src/lib/stores/app.svelte.test.ts`
- `src/lib/components/sidebar-ripple.ts` ↔ `src/lib/components/sidebar-ripple.test.ts`

**Frontend naming:** `<module>.test.ts`. No `.spec.ts` anywhere — don't introduce one.

**Backend location:** inline. Every test is inside a `#[cfg(test)] mod tests { use super::*; ... }` block at the bottom of the module it tests. Verified: `rg 'cfg\(test\)' src-tauri/src` finds 61 such blocks across `src-tauri/src/ai/*`, `src-tauri/src/db/*`, `src-tauri/src/commands/*`, `src-tauri/src/sync/*`, `src-tauri/src/migration/*`, `src-tauri/src/crypto.rs`, `src-tauri/src/error.rs`. No separate `tests/` integration directory.

**Structure:**
```
src/lib/
├── ai/
│   ├── format.ts            + format.test.ts
│   ├── shell-probe.ts       + shell-probe.test.ts
│   ├── tokens.ts            + tokens.test.ts
│   └── ... (pty-output, timeline)
├── i18n/index.svelte.ts     + index.test.ts
├── keyboard/{keymap,registry}.ts + .test.ts
├── osc/{handler,clipboard}.ts    + .test.ts
├── stores/{app,toast}.svelte.ts  + .svelte.test.ts
└── terminal/                 (block-content, block-to-image, command-blocks,
                               folds, highlight, serial-transforms, … + .test.ts)
```

## Test Structure

**Frontend suite organization:**
```typescript
import { describe, it, expect } from "vitest";
import { formatTokenCount } from "./tokens.ts";

describe("formatTokenCount", () => {
  it("renders small counts verbatim", () => {
    expect(formatTokenCount(0)).toBe("0");
    expect(formatTokenCount(999)).toBe("999");
  });

  it("compacts thousands with one decimal", () => {
    expect(formatTokenCount(1000)).toBe("1k");
    expect(formatTokenCount(1234)).toBe("1.2k");
  });
});
```
(`src/lib/ai/tokens.test.ts`)

Patterns observed:
- One top-level `describe` per public function / behavior group; nested `describe` for sub-features (`describe("open: handler")`, `describe("fwd: handler")` in `src/lib/osc/handler.test.ts`).
- `it("does X when Y", ...)` — sentences describe the observable outcome, not the implementation.
- Multiple `expect`s per `it` are fine when they pin the same behavior (table-ish cases like the rounding boundaries in `tokens.test.ts`).
- Regression tests are labeled in the title: `it("REGRESSION (Copilot): echo-only buffer must NOT look like cmd", ...)` (`src/lib/ai/shell-probe.test.ts:53`). Keep this convention when adding guards for a specific past bug.
- No `beforeAll` for shared mutable state — each test rebuilds state (see Mocking for module reset).

**Backend suite organization:**
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Db;
    // ... helpers, fixtures, then:

    #[test]
    fn insert_rejects_empty_credential_id() {
        let db = Db::open_in_memory().unwrap();
        let mut bad = mk("p1", "alpha");
        bad.credential_id = String::new();
        assert_eq!(
            insert(&db, &bad).unwrap_err().code(),
            "profile_credential_id_required"
        );
    }
}
```
(`src-tauri/src/db/profile.rs`)

Patterns observed:
- Module doc-comment (`//! ...`) at the top of `mod tests` stating the core contracts — see `src-tauri/src/commands/profile.rs:344`.
- `fn fixture() -> (Db, MemStore, TempDir)` helper returns everything a test needs in one call (`src-tauri/src/commands/sync.rs:267`, `src-tauri/src/commands/profile.rs:385`).
- Entity builders: `fn prof(id: &str, group: Option<&str>) -> Profile { ... }` — terse, named after the entity.
- Tests assert on the **i18n error code** (`err.code()`), not the Display string — this keeps tests locale-independent and matches the frontend's `errMsg()` lookup.
- Async tests use `#[tokio::test]` (not `#[test]` + block_on). Example: `src-tauri/src/sync/webdav.rs:260`.

## Mocking

**Frontend framework:** Vitest's built-in `vi` — `vi.mock`, `vi.hoisted`, `vi.fn`, `vi.stubGlobal`, `vi.useFakeTimers`, `vi.resetModules`.

**Mocking `invoke` (Tauri IPC):**
```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";

// vi.mock is hoisted before imports — must keep the real store module from
// evaluating (it touches navigator.userAgent at module top level, absent in node).
vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));
vi.mock("../stores/app.svelte.ts", () => ({
  addTab: vi.fn(),
}));

import { invoke } from "@tauri-apps/api/core";
import * as app from "../stores/app.svelte.ts";

beforeEach(() => {
  vi.clearAllMocks();
});

it("opens a tab when profile exists", async () => {
  (invoke as any).mockImplementation(async (cmd: string) => {
    if (cmd === "list_profiles") return [{ id: "p1", name: "MyHost", ... }];
    if (cmd === "get_credential") return { username: "alice", ... };
    throw new Error(`unexpected invoke ${cmd}`);
  });
  dispatch("open:myhost");
  await flush();           // let fire-and-forget async resolve
  expect(app.addTab).toHaveBeenCalledTimes(1);
});
```
(`src/lib/osc/handler.test.ts`)

Key vi patterns:
- **`vi.hoisted`** for values the mock factory needs before the real import runs:
  ```typescript
  const { settingsActive } = vi.hoisted(() => ({ settingsActive: vi.fn(() => false) }));
  vi.mock("../stores/app.svelte.ts", () => ({ settingsActive }));
  ```
  (`src/lib/keyboard/registry.test.ts:3`). Use this whenever the mock must share a reference with the test body.
- **`vi.stubGlobal`** to inject browser globals missing in the node env — `window`, `localStorage`, `navigator`, `WebSocket`, `location`. Always pair with `afterEach(() => vi.unstubAllGlobals())`. See `src/lib/ipc-shim.test.ts:47` and `src/lib/stores/app.svelte.test.ts:10`.
- **`vi.resetModules()` + dynamic `import()`** for module-level `$state` isolation. Module-level state (like `_tabs` in `app.svelte.ts`) persists across tests otherwise; re-importing fresh per test is the established reset pattern:
  ```typescript
  async function loadAppModule() {
    vi.resetModules();
    return import("./app.svelte.ts");
  }
  ```
  (`src/lib/stores/app.svelte.test.ts:26`, also in `toast.test.ts`).
- **Fake timers** for TTL / timeout logic: `beforeEach(() => vi.useFakeTimers()); afterEach(() => vi.useRealTimers());` then drive with `vi.advanceTimersByTime(ms)` (`src/lib/stores/toast.test.ts:8`).
- **Hand-rolled fakes** for complex external types — a `FakeWS` class to drive a WebSocket lifecycle (`src/lib/ipc-shim.test.ts:11`), a `fakeTerm()` implementing the xterm.js `Terminal` subset that `createCommandBlockTracker` touches (`src/lib/terminal/command-blocks.test.ts:22`). Fakes record calls (`sent: string[]`) and expose driver methods (`open()`, `deliver(obj)`).

**What to mock (frontend):**
- `@tauri-apps/api/core` `invoke` — always. No backend in node.
- Store modules the SUT imports — when you only want to assert it called `addTab`, not that the tab list updated.
- Browser globals absent in node (`localStorage`, `navigator`, `window`, `WebSocket`, `location`).
- The clock, when testing TTL / debounce / timeout behavior.

**What NOT to mock (frontend):**
- The SUT itself. Import the real module.
- Pure helpers (`formatTokenCount`, `classifyShell`, `rippleWidth`) — test them directly with no mocks. Most tests in `src/lib/ai/`, `src/lib/terminal/`, `src/lib/keyboard/` are zero-mock.

**Backend mocking:**
- **No `mockall` / `mock!`.** The pattern is to define a minimal in-process implementation of the trait being abstracted:
  ```rust
  #[derive(Default)]
  struct MemStore { inner: Mutex<HashMap<String, String>> }
  impl SecretStore for MemStore {
      fn get(&self, key: &str) -> AppResult<Option<String>> { ... }
      fn set(&self, key: &str, value: &str) -> AppResult<()> { ... }
      fn delete(&self, key: &str) -> AppResult<()> { ... }
      fn backend_name(&self) -> &'static str { "mem" }
  }
  ```
  (`src-tauri/src/commands/sync.rs:243`, duplicated in `src-tauri/src/commands/profile.rs:360`). When you add a new `SecretStore` consumer test, copy this `MemStore`.
- **HTTP mocking with `mockito`** (`[dev-dependencies] mockito = "1.7.2"`). Used for WebDAV sync:
  ```rust
  #[tokio::test]
  async fn push_succeeds_on_201() {
      let mut server = mockito::Server::new_async().await;
      let _m = server.mock("PUT", "/rssh_backup.enc")
          .with_status(201)
          .create_async().await;
      let sync = WebDavSync::from_settings(&server.url(), "u", "p").unwrap();
      sync.push("payload").await.unwrap();
  }
  ```
  (`src-tauri/src/sync/webdav.rs:260`). Use the `_async` variants inside `#[tokio::test]`.
- **Filesystem isolation with `tempfile::TempDir`** — `tempfile` is a dev-dependency; tests that touch disk create a `TempDir` and let it drop. `Db::open(dir.path())` opens a real SQLite file inside the tempdir (`src-tauri/src/commands/profile.rs:386`).
- **SQLite in-memory:** `Db::open_in_memory()` for DB-layer tests that don't need filesystem behavior (`src-tauri/src/db/profile.rs`, `src-tauri/src/ai/redact_rules.rs:113`). Schema migrations run on open.

## Fixtures and Factories

**Frontend test data:** Inline literals per-test. No shared `fixtures/` directory, no factory library. Example:
```typescript
const THEME: ITheme = { foreground: "#eeeeee", background: "#111111", black: "#000000", ... };
function makeCell(opts: Partial<{ fgDefault: boolean; fgColor: number; ... }>) { ... }
```
(`src/lib/terminal/block-to-image.test.ts:11`, `:72`). Build the object inline; for varied inputs use a small local builder (`ev(partial)` in `src/lib/keyboard/keymap.test.ts:27`).

**Backend test data:**
- Per-module `fn mk(id: &str, name: &str) -> Profile` / `fn prof(...)` / `fn entry(...)` builders.
- `fn fixture()` returning `(Db, MemStore, TempDir)` — copy-paste this shape into new command-layer test modules.

## Coverage

**Requirements:** **None enforced.** No `--coverage` flag, no thresholds, no coverage report upload in CI. The vitest `test` config in `vitest.config.ts` does not enable coverage; `package.json` has no `test:coverage` script.

**What's covered in practice (well-tested):**
- Pure frontend logic: formatters (`tokens`, `format`), parsers (`shell-probe`, `osc/handler`, `osc/clipboard`), keyboard matching (`keymap`, `registry`), terminal block/image/highlight transforms, SFTP naming, IPC shim wire frames.
- Frontend stores: `app.svelte.ts` (tab MRU, closeTab, drag-reorder), `toast.svelte.ts` (TTL, dismiss).
- Backend: every `db/*.rs` module has CRUD validation tests (reject empty `credential_id`, reject control chars in names, etc.); `ai/sanitize.rs` (69 tests) and `ai/session/file_ops.rs` (68 tests) are exhaustively tested; `crypto.rs`, `sync/webdav.rs`, `error.rs` all have focused suites.
- **Drift guards**: tests that fail when two things that must stay in sync drift — e.g. `seed_matches_default_rules` in `src-tauri/src/ai/redact_rules.rs:111` asserts the DB seed equals `sanitize::default_rules()`. Follow this pattern when you have "unavoidable duplication" (the comment there explains the philosophy).

**What's NOT covered (known gaps):**
- **No UI/component tests.** Svelte components (`.svelte` files) are not unit-tested; there's no `@testing-library/svelte` dependency. UI correctness relies on manual `npm run tauri dev` verification (AGENT.md Pr4).
- **No SSH / PTY / SFTP transport tests.** Live network IO isn't exercised. The `russh` client (`src-tauri/src/ssh/`), PTY (`src-tauri/src/terminal/pty.rs`), and SFTP (`src-tauri/src/ssh/sftp.rs`) have no tests.
- **No Tauri command integration tests.** The `#[tauri::command]` wrappers in `src-tauri/src/commands/*.rs` are tested by calling the underlying private `do_*` / `db::*` functions directly, not by spinning up the Tauri runtime.
- **No end-to-end / smoke tests** of the packaged app.

## Test Types

**Unit tests (frontend):** Vitest, node env, zero or stubbed dependencies. Fast (<1s each). The dominant test type.

**Unit tests (backend):** `cargo test`, inline `#[cfg(test)] mod tests`. Fast. Test the function in isolation; DB tests use `open_in_memory` or a tempdir.

**Integration tests (backend):** Also `cargo test`, but touching more of the stack — e.g. `src-tauri/src/commands/sync.rs` tests call `build_payload` (real DB + real `MemStore` + real serialization) and `src-tauri/src/sync/webdav.rs` tests hit a `mockito` HTTP server. These live in the same `mod tests` block; there's no formal split.

**E2E tests:** **Not used.** No Playwright/Cypress/WebDriver. The closest thing is the `scripts/dev-browser.mjs` dev runner and manual verification.

## Common Patterns

**Async testing (frontend):**
```typescript
// Let fire-and-forget async handlers resolve before asserting.
async function flush() {
  await new Promise((r) => setTimeout(r, 0));
  await new Promise((r) => setTimeout(r, 0));
}

it("opens a tab when profile exists", async () => {
  dispatch("open:myhost");
  await flush();
  expect(app.addTab).toHaveBeenCalledTimes(1);
});
```
(`src/lib/osc/handler.test.ts:36`). The double-`setTimeout(0)` drains microtasks + one macrotask; needed because the OSC handler is fire-and-forget.

**Async testing (backend):**
```rust
#[tokio::test]
async fn pull_returns_body_on_200() {
    let mut server = mockito::Server::new_async().await;
    let _m = server.mock("GET", "/rssh_backup.enc")
        .with_status(200).with_body("encrypted-data")
        .create_async().await;
    let sync = WebDavSync::from_settings(&server.url(), "u", "p").unwrap();
    assert_eq!(sync.pull().await.unwrap(), "encrypted-data");
}
```

**Error testing (frontend):**
```typescript
it("does not throw on a malformed percent-escape", () => {
  expect(() => remoteUploadName("content://x/%E0%A4%A")).not.toThrow();
});
```
(`src/lib/sftp-name.test.ts:29`)

**Error testing (backend) — assert on the i18n code, not the message:**
```typescript
let err = save(&db, &RedactRuleRecord { pattern: "(unclosed".into(), ... }).unwrap_err();
assert_eq!(err.code(), "redact_invalid_regex");
assert!(!list(&db).unwrap().iter().any(|r| r.id == "user-bad"));
```
(`src-tauri/src/ai/redact_rules.rs:130`). Asserting on `err.code()` (not `err.to_string()`) keeps tests locale-independent and resilient to copy changes.

**Cleanup / teardown:**
- Frontend: `afterEach(() => vi.unstubAllGlobals())`, `vi.clearAllMocks()` in `beforeEach`, `vi.useRealTimers()` in `afterEach`. The `FakeWS.instances` array is reset in `beforeEach` (`src/lib/ipc-shim.test.ts:48`).
- Backend: `TempDir` dropped at end of test → filesystem cleaned. `Db::open_in_memory()` is per-test, so no cross-test state. `Mockito` server is dropped at end of `#[tokio::test]`.

**CI integration:** `.github/workflows/release.yml` and `.github/workflows/pre-release.yml` both run a `test` job on `ubuntu-22.04` that executes `npm test` and `cd src-tauri && cargo test`. Every `build-desktop` and `build-android` job has `needs: test` — a failing test blocks all artifact builds. The Linux runner installs `libgtk-3-dev libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev libudev-dev` because `cargo test` compiles the whole Tauri crate and needs webkit2gtk to link.

---

*Testing analysis: 2026-07-08*
