---
status: complete
quick_id: 260709-jat
slug: fix-broadcast-enter-byte-blocker
description: Fix broadcast Enter-byte blocker — SSH/local sendText wrote LF instead of CR, so PowerShell/ConPTY targets never executed the broadcasted command (02-UAT test 2).
date: 2026-07-09
commit: 1e137e0
source_gap: .planning/phases/02-broadcast-dispatch-safety/02-UAT.md (test 2)
---

# Quick Task 260709-jat — Fix Broadcast Enter-Byte Blocker

## Outcome

Fixed. Broadcasted commands now auto-execute on SSH/local targets (incl.
PowerShell/ConPTY). Verification: `npx vitest run` → **396 passed** (was 391;
+5 new), `npx tsc --noEmit` → exit 0.

## Root Cause (recap)

`executeCommand` (main tab, `store.svelte.ts:693`) appends `\r` with a comment
"ConPTY/PowerShell only accepts \r". The broadcast call site
(`CommandConfirmDialog.svelte:177`) appended `\n`, and `sendText`'s SSH/local
branch (`TerminalPane.svelte:626`) wrote it **raw** — no `\n`→`\r` conversion —
so PowerShell targets got a trailing LF that does not submit. Stream targets
(serial/telnet) were already correct via `normalizeOutgoing`.

## Changes

| File | Change |
|------|--------|
| `src/lib/terminal/serial-transforms.ts` | +`normalizePtyOutgoing(text)` (`\r?\n`→`\r`) with doc stating the ConPTY/PowerShell + ICRNL rule. |
| `src/lib/terminal/serial-transforms.test.ts` | +`describe("normalizePtyOutgoing")` — 5 tests (trailing LF→CR, CRLF no-doubling, multi-line, lone-CR preserved, no-newline/empty unchanged). |
| `src/lib/components/TerminalPane.svelte` | `sendText` SSH/local branch normalizes via helper (the fix; also covers snippet path). `pasteText` reuses the same helper (DRY). Doc comment corrected (was "write raw"). |

Single atomic code commit: `1e137e0`.

## Design Choice

Centralized the PTY Enter rule in one tested helper rather than patching the
call site, so **every** SSH/local write path (broadcast, snippet, paste) is
correct from one source of truth. The call site stays `cmd.cmd + "\n"` —
`sendText` now owns EOL translation at the seam. Broadcast-OFF behavior is
byte-identical (these paths carry nothing when off); the bare-command-on-targets
design (BCAST-07) is unchanged.

## Verification

- `npx vitest run` → 396 passed (31 files). New tests green.
- `npx tsc --noEmit` → exit 0.
- **Manual re-test pending:** resume `/gsd-verify-work 2` → re-run 场景 B
  (BCAST-05/06) to confirm target tabs auto-execute, then continue tests 3 & 5.

## Scope Notes

- Executed inline as orchestrator (planner + executor) rather than spawning
  subagents: the fix was fully diagnosed upstream in 02-UAT, trivial (1 helper +
  2 call sites), and the global `gsd-tools` PATH shim is broken (dangling
  `tiger-flow` ref) which would have broken an executor's commit step. Used the
  working `$HOME/.claude/gsd-core/bin/gsd-tools.cjs` directly.
- Did not alter `CommandConfirmDialog.svelte` (call-site `\n` is now correct by
  virtue of the sendText seam) — kept diff minimal and centralized.
- Out of scope: repairing the broken global `gsd-tools` PATH shim.
