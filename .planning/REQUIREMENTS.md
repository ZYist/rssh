# Requirements — AI Broadcast Mode

## v1 Requirements

### Broadcast UI

- [x] **BCAST-01**: AI 面板工具栏显示广播模式 toggle 按钮，点击切换开/关状态
- [x] **BCAST-02**: 广播模式开启后，显示目标选择器，列出所有已打开的终端标签
- [x] **BCAST-03**: 用户可勾选/取消勾选任意终端标签作为广播目标
- [x] **BCAST-04**: 广播 toggle 和目标选择状态为 per-tab 级别，保存在 AI store 中

### Broadcast Dispatch

- [x] **BCAST-05**: 用户 Approve 命令后，主标签执行 executeCommand（带 sentinel），广播目标通过 broadcastToSessions 接收 cmd.cmd + "\n"
- [x] **BCAST-06**: 广播分发与主标签执行并行，不阻塞主标签的输出收集
- [x] **BCAST-07**: AI 只读取主标签（当前活跃标签）的执行输出，广播目标静默执行

### Approval Flow

- [x] **BCAST-08**: 审批流程跟随现有 danger_mode / auto_run_command 设置，广播模式不引入额外审批逻辑

## v2 Requirements (Deferred)

- 广播模式下抑制 auto-approve（安全增强）
- Raw device（Serial/Telnet）默认排除广播目标
- 广播执行后的 toast 反馈提示
- 目标选择器持久化（跨 session 保持）
- 断线/失联目标自动检测和 toast 提示
- 广播事件写入审计日志

## Out of Scope

- 汇总所有终端输出返回给 AI — 信息量过大，AI 上下文会爆
- 不同标签执行不同命令 — 不是广播的语义
- 后端（Rust/Tauri）修改 — 纯前端实现，复用现有 broadcastToSessions

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| BCAST-01 | Phase 1 | Complete |
| BCAST-02 | Phase 1 | Complete |
| BCAST-03 | Phase 1 | Complete |
| BCAST-04 | Phase 1 | Complete (Plan 01-01) |
| BCAST-05 | Phase 2 | Complete |
| BCAST-06 | Phase 2 | Complete |
| BCAST-07 | Phase 2 | Complete |
| BCAST-08 | Phase 2 | Complete |

---
*Last updated: 2026-07-08 after Plan 01-01 execution (BCAST-04 complete)*
