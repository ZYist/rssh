# Milestones

## v1.0 AI Broadcast Mode (Shipped: 2026-07-09)

**Phases completed:** 2 phases, 3 plans, 6 tasks
**Closeout type:** verified_closeout (both phases `verification_status: passed`; UAT Phase 1 5/5 + Phase 2 5/5; 0 verification overrides)
**Git:** tag `v1.0` · range `9b6f07e..HEAD` · 32 files (+2888/−843)

**Key accomplishments:**

- 在 ai/store.svelte.ts 落地 per-tab 广播状态机（BroadcastState + 9 getter/mutator + stopSession teardown），并从 EditPane 抽取 BroadcastTargetSelector 受控组件，EditPane 改造后 Broadcast(N) 立即发送与 hover 预览零行为回归
- 在 ChatPanel 工具栏插入广播开关（accent 激活态 + 目标计数徽标）与可折叠目标条，接线 ai store 的 per-tab 广播状态（Plan 01-01 已就位），补 D-11 prune $effect 与 en/zh 10 个 i18n key —— Phase 1 全部 4 条 Success Criteria 达成，广播 OFF 时 ChatPanel 与改造前像素一致
- 接通 AI 审批命令的广播分发——approve 先 fire-and-forget 广播 raw cmd.cmd 到所有勾选目标再执行主标签；raw device 广播目标降级自动批准为人工 dialog；terminate 对称向所有目标发 Ctrl+C；sendText SSH/local 路径补 invoke reject 捕获。

**In-milestone fix:** broadcast Enter-byte blocker (PowerShell/ConPTY targets received LF, never auto-executed) — normalized PTY outgoing `\n`→`\r` via `normalizePtyOutgoing` in quick `260709-jat` (commit `1e137e0`, +5 unit tests). Surfaced by Phase 2 UAT; not catchable by structural verification.

---
