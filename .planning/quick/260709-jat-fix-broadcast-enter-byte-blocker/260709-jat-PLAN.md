---
quick_id: 260709-jat
slug: fix-broadcast-enter-byte-blocker
description: Fix broadcast Enter-byte blocker — SSH/local sendText wrote LF instead of CR, so PowerShell/ConPTY targets never executed the broadcasted command (UAT phase-02 test 2).
mode: quick
created: 2026-07-09
source: .planning/phases/02-broadcast-dispatch-safety/02-UAT.md (Gaps, test 2)
---

# Quick Task 260709-jat — Fix Broadcast Enter-Byte Blocker

## Problem

Phase-02 UAT test 2 (BCAST-05/06, 场景 B) failed: with broadcast on + SSH targets,
Approving an AI command executes only on the main tab. Target tabs receive the
command text but it is **not submitted** — the user must press Enter manually on
every target, defeating the multi-machine sync value prop.

## Root Cause (verified in source)

The broadcast path and the main-tab path use different Enter bytes:

| Path | File:line | Enter byte |
|------|-----------|-----------|
| Main tab `executeCommand` | `src/lib/ai/store.svelte.ts:693` | `\r` (CR) |
| Broadcast call site | `src/lib/ai/CommandConfirmDialog.svelte:177` | `cmd.cmd + "\n"` (LF) |

`executeCommand` carries an explicit comment: *"ConPTY/PowerShell only accepts \r;
Unix cooked PTY translates \r → \n via ICRNL."* The broadcast path did not reuse
that rule. The broadcasted text reaches `TerminalPane.sendText`
(`src/lib/components/TerminalPane.svelte:626`), whose **SSH/local branch writes
raw** — no `\n`→`\r` conversion — unlike its sibling `pasteText` (line 644),
which already does `text.replace(/\r?\n/g, "\r")`. So PowerShell/ConPTY targets
get a trailing LF that does not submit.

Stream transports (serial/telnet) are unaffected: `sendText` routes them through
`normalizeOutgoing(text, streamOpts.inputNewline)` (`serial-transforms.ts:108`),
which already converts every line break to the device's EOL.

Note: the "command looks different on targets" the user also reported is **correct
by design** (BCAST-07) — targets get the bare command, the main tab gets the
sentinel-wrapped command. Not a defect; do not change.

## Fix (single root cause, centralized)

Centralize the PTY Enter rule in one tested helper so every SSH/local write path
(broadcast, snippet, paste) is correct:

### Task 1 — Add `normalizePtyOutgoing` helper + tests

- **files:**
  - `src/lib/terminal/serial-transforms.ts` — add `normalizePtyOutgoing(text): string`
    (`text.replace(/\r?\n/g, "\r")`) with a doc comment stating the ConPTY/PowerShell
    + ICRNL rule. Mirrors `normalizeOutgoing` naming.
  - `src/lib/terminal/serial-transforms.test.ts` — add a `describe("normalizePtyOutgoing")`
    block: trailing LF→CR, CRLF→single CR (no doubling), multi-line each→CR,
    lone CR preserved, no-newline unchanged, empty unchanged.
- **action:** add helper after `normalizeOutgoing`; add tests after its describe block.
- **verify:** `npx vitest run src/lib/terminal/serial-transforms.test.ts` green.
- **done:** helper exported, tests pass.

### Task 2 — Route SSH/local sendText + pasteText through the helper

- **files:**
  - `src/lib/components/TerminalPane.svelte`
    - import line 24: add `normalizePtyOutgoing` to the `serial-transforms.ts` import.
    - `sendText` (line 626) SSH/local branch: normalize before encoding —
      `const normalized = normalizePtyOutgoing(text);` then encode `normalized`.
      This is the bug fix.
    - `pasteText` (line 636): replace the inline `text.replace(/\r?\n/g, "\r")`
      with `normalizePtyOutgoing(text)` (DRY — identical behavior).
- **action:** edit the three sites.
- **verify:** `npx vitest run` (full suite, expect 391+ new green) + type check.
- **done:** broadcast/snippet/paste on SSH/local all submit via CR.

## Constraints

- Broadcast OFF behavior must be byte-identical to today (CLAUDE.md compatibility).
  The fix only changes the SSH/local newline→CR conversion that pasteText already
  performed; broadcast-OFF sends nothing through these paths.
- Do NOT alter the bare-command-on-targets design (BCAST-07).
- Call site `CommandConfirmDialog.svelte:177` stays `cmd.cmd + "\n"` — `sendText`
  now owns EOL translation, so the LF is normalized to CR at the seam. (No call-site
  change keeps the diff minimal and centralizes the rule.)

## Acceptance

- `npx vitest run` all green (incl. new `normalizePtyOutgoing` tests).
- Type check clean (`npx svelte-check` / `tsc --noEmit`).
- Resume `/gsd-verify-work 2` → re-run 场景 B → target tabs auto-execute.

## Out of Scope

- Fixing the broken global `gsd-tools` PATH shim (npm `tiger-flow` dangling ref) —
  noted separately; this task uses the working `$HOME/.claude/gsd-core/bin/gsd-tools.cjs`.
- Snippet-system audit beyond confirming it routes through `sendText` (it does).
