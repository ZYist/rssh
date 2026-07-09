# Phase 2: Broadcast Dispatch & Safety - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 2-Broadcast Dispatch & Safety
**Areas discussed:** 分发时机与并行, danger+raw 安全门, 终止对称性, 失败处理态度

---

## 分发时机与并行

| Option | Description | Selected |
|--------|-------------|----------|
| 先广播再 await 主执行 | approve() 里先 broadcastToSessions(targets, cmd.cmd+"\n")（fire-and-forget），再 await executeCommand。主与目标天然并行，重入安全。 | ✓ |
| 主执行结束后再广播 | 等 executeCommand resolve（可长达 timeout_s 秒）才分发。违背 BCAST-06。 | |
| 你决定 | 按侦察推荐记为 Discretion。 | |

**User's choice:** 先广播再 await 主执行
**Notes:** broadcastToSessions 是同步 for 循环、fire-and-forget，本身不阻塞；放在 await executeCommand 之前即满足 BCAST-06 并行。广播在 executeCommand 重入位（`_runningExecutions`）之前，approve 的 executing 锁 + `_ackedToolCalls` 足够防重复广播。广播字段用 `cmd.cmd + "\n"`，绝不用含 sentinel 的 `full_cmd`。

---

## danger+raw 安全门

| Option | Description | Selected |
|--------|-------------|----------|
| 任一 raw 目标→强制人工 | 自动批准前置检查：targets 含 raw device 则降级为 dialog。源于既有 raw 安全约束。 | ✓ |
| 完全跟随 danger_mode | raw 目标也静默自动广播，严格符合 BCAST-08 字面。 | |
| 你决定 | 按侦察推荐记为 Discretion。 | |

**User's choice:** 任一 raw 目标→强制人工
**Notes:** 当前 `!isRawDeviceKind` 只挡主标签；raw 对 `reload`/`erase` 类命令黑名单失效（CONCERNS.md）。此确认是既有 raw 安全约束的延伸，非广播开关本身引入，与 BCAST-08 不冲突。仅在"广播开启 + targets 含 raw"时触发；广播关闭或无 raw 目标时自动批准行为不变（兼容性约束）。

---

## 终止对称性

| Option | Description | Selected |
|--------|-------------|----------|
| 对称终止 | terminate 时向主标签和所有广播目标都发 \x03。符合广播语义，安全一致。 | ✓ |
| 只终止主标签 | 保持现状。语义割裂，目标继续跑已广播命令。 | |
| 你决定 | 按侦察推荐记为 Discretion。 | |

**User's choice:** 对称终止
**Notes:** `\x03` 是中断非执行，对所有目标（含 raw）无差别安全，不触发 raw 安全门。实现风险：`sendText` 注释称控制序列不应通过此处、raw 过 `normalizeOutgoing`；`\x03` 发送原语需 researcher 核实（可能需绕过 normalizeOutgoing 直写）。

---

## 失败处理态度

| Option | Description | Selected |
|--------|-------------|----------|
| 无可见反馈，fire-and-forget | 符合 v2 边界。代码层吞 invoke reject + console.warn 修未处理 rejection 卫生，不弹 UI。 | ✓ |
| 最小 toast 反馈 | 违背 REQUIREMENTS v2（toast 是 v2 deferred）。 | |
| 你决定 | 按侦察推荐记为 Discretion。 | |

**User's choice:** 无可见反馈，fire-and-forget
**Notes:** `broadcastToSessions` 当前无 try/catch、invoke reject 冒泡为未处理 rejection。Phase 2 接入审批路径后会暴露噪音。吞 reject + `console.warn("[broadcast] ...")` 修代码卫生（CONVENTIONS：非致命 background 用 console.warn），但不加任何用户可见反馈（toast/审计/断线检测属 v2）。不用空 `.catch(() => {})`（Pr2 禁）。

---

## Claude's Discretion

- 广播分发在 `approve()` 内的代码组织（抽 helper vs inline）—— planner 决定
- 终止广播 `\x03` 的发送原语 —— researcher 核实 `normalizeOutgoing` 对 `\x03` 行为后定
- raw 安全门检查的精确落点（`autoApproveAllowed` 内 vs `onMount` 前 guard）—— planner 选最小侵入处
- `approve()` 失败审计漏洞 —— Phase 2 不修（超出范围）

## Deferred Ideas

见 CONTEXT.md `<deferred>`：raw 默认排除、toast 反馈、断线检测、审计日志、全局抑制 auto-approve、approve 失败审计漏洞修复 —— 均 v2 或超范围。
