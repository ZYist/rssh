# Domain Pitfalls

**Domain:** AI command broadcast in terminal multiplexer (RSSH)
**Researched:** 2026-07-08

## Critical Pitfalls

Mistakes that cause double-execution, data loss, or bricked remote devices.

### Pitfall 1: Double-execution via reentry on broadcast targets

**What goes wrong:** The existing `executeCommand` in `store.svelte.ts:464` is designed for a single tab. It registers a `tool_call_id` in `_runningExecutions` as its reentry guard. If broadcast naively calls `executeCommand` for each target tab, only the first call registers the tool_call_id — subsequent calls either collide on the same key (overwriting the listener/timer) or need distinct keys that don't exist in the backend's tool_call tracking.

**Why it happens:** `executeCommand` is coupled to the AI actor's tool_call lifecycle. The backend emits `ai:command_proposed` with one `tool_call_id` and expects exactly one `ai_command_result` callback. Broadcasting the command text to N terminals but trying to reuse `executeCommand` creates an N:1 mismatch — N PTY listeners racing to call `finish()`, but only the first `finish()` actually invokes `ai_command_result` (the rest hit `if (exec.resolved) return`). The other N-1 listeners and timers leak.

**Consequences:**
- Leaked event listeners on `ssh:data:<id>` / `pty:data:<id>` for broadcast targets accumulate until session close
- If the "primary" tab's sentinel arrives after a broadcast target's (network jitter), the AI receives output from the wrong machine
- `_runningExecutions.has(tool_call_id)` blocks the dialog's reentry guard for *all* tabs sharing that ID — panel close/reopen shows stale "Executing..." on broadcast targets forever

**Prevention:** Broadcast targets must NOT use `executeCommand`. They should use `broadcastToSessions(tabIds, text)` — a fire-and-forget `sendText` call per pane. Only the primary (AI-bound) tab runs through `executeCommand` with sentinel tracking. The broadcast path is: `approve()` → `executeCommand(primaryTab)` + `broadcastToSessions(otherTabs, cmd.full_cmd + enter)`. The AI receives output only from the primary tab, as designed in PROJECT.md.

**Detection:** If `_runningExecutions.size` grows unboundedly across sessions, or if `ai_command_result` is invoked multiple times for the same `tool_call_id` (backend logs warning), broadcast reentry is occurring.

**Which step should address it:** The broadcast dispatch logic — the single function that runs after user approval.

---

### Pitfall 2: Raw device (serial/telnet) broadcast without user-visible safeguards

**What goes wrong:** `broadcastToSessions` calls `sendText` on each pane. For serial/telnet panes, `sendText` routes through `streamSendText → streamSendBytes` which applies EOL transform and optional slow-send (5ms per byte). A broadcast to a serial device is irreversible the moment bytes hit the wire — there's no shell to Ctrl+C, no undo. A `reload` sent to a network switch's telnet console reboots the switch.

**Why it happens:** The existing broadcast editor (EditPane) has no special treatment for raw devices — it's a user-typed text field, so the user bears full responsibility. But AI broadcast adds a layer of automation: `danger_mode + auto_run_command` could auto-approve a command that gets broadcast to raw devices the user forgot they checked. The AI's POSIX-oriented command blacklist (`destructive / write_verb / interpreter`) doesn't know Cisco IOS commands like `reload`, `erase startup-config`, or `write erase`.

**Consequences:**
- Network equipment rebooted or wiped
- Serial-attached industrial equipment (PLC/firmware) receives malformed commands causing physical harm
- No Ctrl+C recovery path — `isRawDeviceKind` disables auto-approve for the *primary* tab but broadcast bypasses this check entirely since it calls `broadcastToSessions` directly

**Prevention:**
1. Raw device tabs must be excluded from broadcast targets by default (PROJECT.md already mandates this: "Raw device默认不参与广播 — 需要显式勾选确认")
2. When the user explicitly checks a raw-device tab for broadcast, show a one-time confirmation dialog explaining the risk
3. `auto_run_command` (danger_mode auto-approve) must NOT suppress the approval dialog when broadcast targets include raw devices — even if the primary tab is ssh/local
4. The broadcast target selector UI should visually distinguish raw-device tabs (different icon/color, "serial"/"telnet" badge)

**Detection:** If a raw-device tab ID appears in the broadcast target list without a corresponding user confirmation event in the audit log, the safeguard was bypassed.

**Which step should address it:** The broadcast target selector component and the approval-gate logic in `CommandConfirmDialog`.

---

### Pitfall 3: AI reads output from wrong terminal after broadcast

**What goes wrong:** PROJECT.md states "AI只读当前标签输出". But if the user switches the active tab *during* command execution, `_activeTabId` changes. The AI session is bound to a specific `tab_id` (not the global active tab), so this is safe at the `executeCommand` level. However, a subtler issue: if the AI session's *own* `target_id` (SSH session) disconnects and reconnects mid-broadcast, `rebindTarget` updates `_sessionByTab[tab_id].target_id` to a new SSH session. Any in-flight `executeCommand` still has the OLD `target_session_id` in its closure — its PTY listener is on the dead session's event stream, the sentinel never arrives, and the 60s timeout fires.

**Why it happens:** `executeCommand` captures `target_session_id` at call time (line 469). `rebindTarget` (line 276) updates the store but doesn't terminate or re-wire in-flight executions. This is a pre-existing race, but broadcast amplifies it: more terminals = more chances that one reconnects during the execution window.

**Consequences:**
- Command execution always times out on the primary tab after a reconnect
- AI receives truncated/empty output with `timed_out: true`, misdiagnoses the situation
- The broadcast targets already executed the command successfully — the AI doesn't know

**Prevention:** In `rebindTarget`, check `_runningExecutions` for any exec targeting the old `target_session_id`. If found, either: (a) re-wire its listener to the new session's data event, or (b) terminate it with an explanatory message ("target reconnected mid-execution"). Option (b) is safer — the AI will retry.

**Detection:** If `ai_command_result` arrives with `timedOut: true` and the tab's `target_id` differs from the execution's `targetSessionId`, a rebind occurred mid-flight.

**Which step should address it:** The `rebindTarget` function enhancement (or a guard in the broadcast dispatch that skips recently-reconnected targets).

---

### Pitfall 4: Sentinel contamination across broadcast targets

**What goes wrong:** The AI command's `full_cmd` includes a sentinel suffix like `; echo __rssh_done_<uuid>:$?`. When broadcast sends this same `full_cmd` to all targets, every terminal prints the sentinel. If the user later scrolls through a broadcast target's terminal and the AI session is somehow pointed at that tab (e.g., user switches the AI panel binding), a stale sentinel in the scrollback could confuse output extraction.

More critically: if a future enhancement ever adds "read output from broadcast targets," the sentinel-bearing output from N terminals all carry the same sentinel string. `findSentinel` would match on the first one received — potentially interleaving output from different machines into a single result.

**Why it happens:** `full_cmd` is constructed by the backend with a single sentinel for the tool_call. Broadcasting the same string means the sentinel is no longer unique per-terminal.

**Consequences:**
- If output aggregation is ever added, the sentinel match produces garbage mixed output
- Audit logs show the same sentinel across multiple terminals — forensic confusion during incident review
- Minor: broadcast targets display the `echo __rssh_done_...` noise in their terminal (cosmetic but confusing)

**Prevention:**
- For the current design (AI reads only primary tab): broadcast targets should receive `cmd.cmd` (the human-readable command), NOT `cmd.full_cmd` (which includes sentinel + exit code echo). Only the primary tab gets `full_cmd`.
- Strip the sentinel suffix before broadcasting. The command to broadcast is everything before the `; echo __rssh_done_` trailer.
- This also avoids the cosmetic issue of sentinel garbage appearing in non-AI terminals.

**Detection:** If terminal scrollback on a non-primary tab contains `__rssh_done_` strings, sentinel stripping is broken.

**Which step should address it:** The broadcast dispatch function — it must select `cmd.cmd` (not `full_cmd`) for broadcast targets.

## Moderate Pitfalls

### Pitfall 5: Broadcast state lost on panel close/reopen

**What goes wrong:** The AI panel uses Svelte component lifecycle — closing and reopening the panel destroys and recreates `ChatPanel`. If broadcast mode state (toggle, selected targets) lives in component-local `$state`, it vanishes on panel toggle. The user enables broadcast, selects 5 targets, closes the panel to work in the terminal, reopens — all selections gone.

**Why it happens:** PROJECT.md identifies this: "广播状态持久化（tab 级别，切换 tab 后模式保持）". But the natural implementation instinct is to put UI toggles in component state.

**Prevention:** Broadcast state must live in `store.svelte.ts` (the AI store) or `app.svelte.ts`, keyed by `tab_id`. Specifically:
- `_broadcastEnabledByTab: Record<string, boolean>` — whether broadcast mode is on
- `_broadcastTargetsByTab: Record<string, Set<string>>` — which tabs are selected as targets

These survive panel close/reopen (same as `_chatByTab`, `_pendingByTab` etc. already do).

**Detection:** If `broadcastEnabled(tabId)` returns false after a panel close/reopen cycle despite being set before, state is component-local.

**Which step should address it:** The store design for broadcast state.

---

### Pitfall 6: Broadcast targets include closed/disconnected tabs

**What goes wrong:** User selects 5 tabs as broadcast targets. Later, 2 of those tabs are closed or their SSH connections drop. If the broadcast dispatch doesn't prune stale targets, `broadcastToSessions` calls `_terminalControls.get(tabId)?.sendText(text)` — the `?.` silently no-ops for closed tabs (controls unregistered), but for disconnected-but-open tabs, `sendText` checks `if (!text || disconnected || !sessionId) return` inside TerminalPane and silently drops. The user thinks the command went to 5 machines; it went to 3.

**Why it happens:** `broadcastToSessions` is fire-and-forget by design (line 466-473). It doesn't return success/failure per target. The UI has no feedback channel to show "2 targets skipped."

**Consequences:**
- Silent partial broadcast — machines drift out of sync (the exact problem broadcast mode is meant to solve)
- User's mental model ("all machines ran the command") doesn't match reality
- No error shown — the failure is invisible

**Prevention:**
1. Before dispatching, filter `broadcastTargets` against `connectedSessions()` — only include tabs with a live session
2. If any targets were pruned, show a toast/notification: "2 targets skipped (disconnected)"
3. Optionally auto-prune the target selection when a session disconnects (via the `unregisterSession` path in `app.svelte.ts:432`)
4. In the broadcast target selector UI, visually mark disconnected sessions (grey out, strikethrough)

**Detection:** Compare the set of broadcast target IDs at dispatch time against `_sessions` entries. Any mismatch = stale target.

**Which step should address it:** The broadcast target selector's reactive pruning + the dispatch function's pre-flight check.

---

### Pitfall 7: Slow-send serial devices delay broadcast completion indefinitely

**What goes wrong:** Serial ports with `slow_send: true` transmit one byte every 5ms. A 200-character command takes 1 second per device. Broadcasting to 10 slow-send serial ports: `broadcastToSessions` fires 10 concurrent `sendText` calls, each of which enters the slow-send `setTimeout` chain in `streamSendBytes`. These chains run independently (good — no serial blocking), but the AI's primary execution has already fired its timeout timer. If the primary tab is also serial with slow-send, the command might not even finish transmitting before timeout fires.

**Why it happens:** `executeCommand`'s timeout (`proposed.timeout_s * 1000`) starts immediately after `invoke(writeCmd)` resolves — but for slow-send, the `invoke` only queues the first byte. The real transmission takes `text.length * 5ms` additional time. The timeout doesn't account for transmission delay.

**Consequences:**
- AI receives timeout on serial primary tab for long commands
- Broadcast targets are still transmitting (byte-by-byte) when the AI has already moved on to its next action
- If the next AI action is another command, the previous broadcast hasn't finished — interleaved bytes on the wire

**Prevention:**
- For the primary (AI-bound) tab: if it's a raw device, the timeout should be extended by `full_cmd.length * 5 / 1000` seconds for slow-send devices. Or better: raw devices already use user-driven completion (submit button), so the timeout is just a safety backstop — make it generous (120s+).
- For broadcast targets: this is fire-and-forget by design. The slow-send queue is per-pane and already handles sequencing internally. But ensure the broadcast dispatch doesn't send a *second* broadcast before the first finishes transmitting — add a "broadcast in flight" guard per target, or simply accept the interleave (user's problem if they broadcast faster than transmission).

**Detection:** If audit logs show `timed_out: true` frequently on serial/telnet primary tabs, the timeout likely doesn't account for transmission delay.

**Which step should address it:** The timeout calculation for raw-device primary tabs (existing issue amplified by broadcast).

---

### Pitfall 8: `danger_mode` auto-approve bypasses broadcast awareness

**What goes wrong:** `CommandConfirmDialog.onMount` checks `autoApproveAllowed(settings, cmd.kind)` and calls `approve()` immediately. The approval function doesn't know about broadcast — it just runs `executeCommand` for the primary tab. If broadcast dispatch is hooked into `approve()`, auto-approve now silently broadcasts to all targets without any human seeing the command. The user enabled danger_mode for single-tab convenience, not for unattended multi-machine execution.

**Why it happens:** Danger mode's threat model assumes single-target: "if the command is bad, the AI will see the error and adjust." With broadcast, a bad command hits N machines simultaneously — there's no "adjust after seeing the error" path for the N-1 non-primary targets.

**Consequences:**
- Destructive command (e.g., `rm -rf /tmp/cache` where the AI meant to type a different path) simultaneously executes on all broadcast targets
- No chance to intervene — auto-approve fires on mount, broadcast dispatches immediately
- Damage multiplied by N instead of confined to 1

**Prevention:**
1. When broadcast mode is enabled with targets selected, auto-approve should be DISABLED regardless of `danger_mode` settings. Always require manual approval for broadcast commands.
2. Alternatively: show a brief "Broadcasting to N targets" interstitial (2s countdown) even in danger mode, giving the user a chance to abort.
3. At minimum: the `autoApproveAllowed` function in `CommandConfirmDialog` should check `if (broadcastEnabled && broadcastTargets.length > 0) return false`.

**Detection:** If the audit log shows `command_executed` entries with no preceding user-interaction timestamp gap (< 100ms from proposed to executed) while broadcast mode is on, auto-approve is not gated.

**Which step should address it:** The `autoApproveAllowed` function in `CommandConfirmDialog.svelte`.

## Minor Pitfalls

### Pitfall 9: Broadcast target selector UX creates false confidence

**What goes wrong:** User checks all 8 tabs in the broadcast selector. Two are telnet to network switches, one is serial to a PLC. The command `systemctl restart nginx` makes sense for the 5 SSH linux boxes but is gibberish (or worse) on the network equipment. User approves without noticing the target list includes non-Linux devices.

**Prevention:**
- Group targets by type in the selector UI (SSH targets first, then a visual separator, then raw devices with a warning badge)
- Show the tab type next to each entry: `[SSH] web-01`, `[Telnet] core-switch-1`
- Consider a "same-type only" filter preset (most common use case is N identical linux servers)

**Which step should address it:** The broadcast target selector component design.

---

### Pitfall 10: Keyboard lock state confusion during broadcast

**What goes wrong:** `_keyboardLockedByTab` is set per-tab when a command is executing (line 842-843 in store). This locks the active terminal's keyboard input so the user can't type while the AI command runs. But broadcast targets have no corresponding keyboard lock — the user can switch to a broadcast target tab and type into it while the broadcast command is still in flight (especially with slow-send). Typed characters interleave with the broadcast command.

**Prevention:**
- During broadcast execution, set `_keyboardLockedByTab` for ALL broadcast targets, not just the primary
- Release the lock on broadcast targets after a short delay (can't use sentinel — they don't have one), or when the primary tab's execution completes
- Or: accept the interleave risk (user switching tabs mid-broadcast is their own problem) and document it

**Which step should address it:** The keyboard lock logic during broadcast dispatch.

---

### Pitfall 11: Audit trail doesn't record broadcast targets

**What goes wrong:** The existing audit log records `command_executed` with the primary tab's output. If a broadcast command causes an incident on a non-primary target, the audit log has no record that the command was broadcast, or to which targets. Forensic analysis after an incident is incomplete.

**Prevention:**
- Add a new `AuditKind` variant: `{ type: "command_broadcast"; targets: string[]; cmd: string }`
- Emit it from the broadcast dispatch, after the primary tab's `command_proposed` entry
- Include target tab labels (not just IDs) for human readability

**Which step should address it:** The broadcast dispatch function (frontend-side audit enhancement) or a backend audit event.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Broadcast toggle + target selector UI | State lost on panel toggle (Pitfall 5) | Store state in `store.svelte.ts`, not component |
| Broadcast dispatch after approval | Double-execution via `executeCommand` reuse (Pitfall 1) | Use `broadcastToSessions` for non-primary targets |
| Broadcast dispatch after approval | Sentinel in broadcast targets (Pitfall 4) | Send `cmd.cmd` not `cmd.full_cmd` to broadcast |
| Broadcast dispatch after approval | Auto-approve not gated (Pitfall 8) | Disable auto-approve when broadcast active |
| Raw device target selection | Unprotected raw-device broadcast (Pitfall 2) | Default-exclude + confirmation dialog |
| Integration with existing AI flow | Stale/disconnected targets (Pitfall 6) | Prune against `connectedSessions()` at dispatch |
| Testing / edge cases | Reconnect during broadcast (Pitfall 3) | Guard or terminate in-flight exec on rebind |

## Sources

- `src/lib/ai/store.svelte.ts` — executeCommand reentry guard, _runningExecutions Map, rebindTarget
- `src/lib/ai/CommandConfirmDialog.svelte` — _ackedToolCalls module-level Set, autoApproveAllowed, isRawDeviceKind gate
- `src/lib/stores/app.svelte.ts` — broadcastToSessions, SessionEntry registry, _terminalControls Map
- `src/lib/ai/types.ts` — AiTargetKind, isRawDeviceKind predicate
- `src/lib/components/TerminalPane.svelte` — sendText/streamSendBytes slow-send path, session registration
- `src/lib/components/EditPane.svelte` — existing broadcast editor pattern (fire-and-forget broadcastToSessions)
- `.planning/PROJECT.md` — requirements and constraints
