<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { EditorView, basicSetup } from "codemirror";
  import { keymap } from "@codemirror/view";
  import { EditorState } from "@codemirror/state";
  import { indentWithTab } from "@codemirror/commands";
  import { HighlightStyle, StreamLanguage, syntaxHighlighting } from "@codemirror/language";
  import { shell } from "@codemirror/legacy-modes/mode/shell";
  import { tags as t } from "@lezer/highlight";
  import * as app from "../stores/app.svelte.ts";
  import BroadcastTargetSelector from "./BroadcastTargetSelector.svelte";
  import SessionPreviewPopover from "./SessionPreviewPopover.svelte";
  import { pickBroadcastText } from "../terminal/broadcast-text.ts";

  let { tabId }: { tabId: string } = $props();

  let editorEl: HTMLDivElement;
  let view: EditorView;

  let sessions = $derived(app.connectedSessions());
  let selectedTabIds = $state<Set<string>>(new Set());

  $effect(() => {
    const activeIds = new Set(sessions.map(s => s.tabId));
    const pruned = [...selectedTabIds].filter(id => activeIds.has(id));
    if (pruned.length !== selectedTabIds.size) selectedTabIds = new Set(pruned);
  });

  function toggle(tid: string) {
    const next = new Set(selectedTabIds);
    if (next.has(tid)) next.delete(tid);
    else next.add(tid);
    selectedTabIds = next;
  }

  function selectAll() { selectedTabIds = new Set(sessions.map(s => s.tabId)); }
  function selectNone() { selectedTabIds = new Set(); }

  // Hover preview: track which thumbnail the mouse is over + its on-screen box,
  // so the popover can anchor to it. Cleared on mouseleave. The signature takes
  // the anchor element directly (the shared BroadcastTargetSelector forwards
  // e.currentTarget as the anchor from its own onmouseenter) — zero behavior
  // change vs the pre-refactor inline handler.
  let hoveredTabId = $state<string | null>(null);
  let hoverAnchor = $state<DOMRect | null>(null);
  function onHover(tid: string, anchor: HTMLElement) {
    hoveredTabId = tid;
    hoverAnchor = anchor.getBoundingClientRect();
  }
  function clearHover() { hoveredTabId = null; hoverAnchor = null; }

  function broadcast() {
    const ranges = view.state.selection.ranges.map(r => ({ from: r.from, to: r.to }));
    const text = pickBroadcastText(view.state.doc.toString(), ranges);
    if (!text.trim() || selectedTabIds.size === 0) return;
    app.broadcastToSessions([...selectedTabIds], text + "\n");
  }

  // 主题：背景 / 前景 / 光标 / 选区都走终端配色 CSS 变量 —— 用户在 Appearance 里
  // 切终端配色，编辑器实时跟着变，零重新挂载。divider/gutter 等次要元素用 color-mix
  // 从 --term-fg 派生，避免引入 UI palette 的 --bg / --surface（那样会跟编辑区主色冲突）。
  const editorTheme = EditorView.theme({
    "&": {
      height: "100%",
      backgroundColor: "var(--term-bg)",
      color: "var(--term-fg)",
    },
    ".cm-scroller": { overflow: "auto", fontFamily: "monospace" },
    ".cm-content": { caretColor: "var(--term-cursor)" },
    ".cm-gutters": {
      backgroundColor: "var(--term-bg)",
      color: "var(--term-bright-black)",
      borderRight: "1px solid color-mix(in srgb, var(--term-fg) 12%, transparent)",
    },
    ".cm-activeLineGutter": {
      backgroundColor: "color-mix(in srgb, var(--term-fg) 10%, transparent)",
      color: "var(--term-fg)",
    },
    ".cm-activeLine": {
      backgroundColor: "color-mix(in srgb, var(--term-fg) 5%, transparent)",
    },
    "&.cm-focused .cm-cursor": { borderLeftColor: "var(--term-cursor)" },
    "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": {
      backgroundColor: "var(--term-sel)",
    },
  });

  // 语法 token 映射到 ANSI 16 色 —— 类比 vim/less 在终端里跑的高亮逻辑，
  // 选色直接借鉴各家终端约定：comment→灰、string→绿、keyword→紫、number→黄、operator→青。
  // 这样用户切 Solarized Light 时 token 也跟着变浅 → 浑然一体。
  const termHighlight = HighlightStyle.define([
    { tag: t.comment,                       color: "var(--term-bright-black)", fontStyle: "italic" },
    { tag: t.lineComment,                   color: "var(--term-bright-black)", fontStyle: "italic" },
    { tag: t.blockComment,                  color: "var(--term-bright-black)", fontStyle: "italic" },
    { tag: t.docComment,                    color: "var(--term-bright-black)", fontStyle: "italic" },
    { tag: t.string,                        color: "var(--term-green)" },
    { tag: t.special(t.string),             color: "var(--term-bright-green)" },
    { tag: t.regexp,                        color: "var(--term-bright-green)" },
    { tag: [t.number, t.integer, t.float],  color: "var(--term-yellow)" },
    { tag: [t.bool, t.null, t.atom],        color: "var(--term-yellow)" },
    { tag: [t.keyword, t.controlKeyword, t.moduleKeyword, t.modifier],
                                            color: "var(--term-magenta)", fontWeight: "600" },
    { tag: t.operator,                      color: "var(--term-cyan)" },
    { tag: t.punctuation,                   color: "var(--term-fg)" },
    { tag: t.bracket,                       color: "var(--term-fg)" },
    { tag: t.variableName,                  color: "var(--term-red)" },
    { tag: t.definition(t.variableName),    color: "var(--term-red)" },
    { tag: t.function(t.variableName),      color: "var(--term-blue)" },
    { tag: t.propertyName,                  color: "var(--term-blue)" },
    { tag: t.attributeName,                 color: "var(--term-cyan)" },
    { tag: t.typeName,                      color: "var(--term-bright-yellow)" },
    { tag: t.namespace,                     color: "var(--term-bright-yellow)" },
    { tag: t.meta,                          color: "var(--term-bright-black)" },
    { tag: t.invalid,                       color: "var(--term-bright-red)", fontWeight: "600" },
  ]);

  onMount(() => {
    view = new EditorView({
      state: EditorState.create({
        doc: "",
        extensions: [
          basicSetup,
          keymap.of([indentWithTab]),
          StreamLanguage.define(shell),
          syntaxHighlighting(termHighlight),
          editorTheme,
          EditorView.lineWrapping,
        ],
      }),
      parent: editorEl,
    });
    view.focus();
  });

  onDestroy(() => { view?.destroy(); });
</script>

<div class="edit-pane">
  <div class="editor-area" bind:this={editorEl}></div>

  <div class="session-panel">
    <div class="panel-header">Target Sessions</div>

    <BroadcastTargetSelector
      sessions={sessions}
      selectedIds={selectedTabIds}
      onToggle={toggle}
      onSelectAll={selectAll}
      onSelectNone={selectNone}
      onHover={onHover}
      onHoverLeave={clearHover}
    />

    <button
      class="broadcast-btn"
      disabled={selectedTabIds.size === 0}
      onclick={broadcast}
    >
      Broadcast ({selectedTabIds.size})
    </button>
  </div>

  {#if hoveredTabId && hoverAnchor}
    <SessionPreviewPopover tabId={hoveredTabId} anchor={hoverAnchor} />
  {/if}
</div>

<style>
  .edit-pane {
    display: flex;
    height: 100%;
    width: 100%;
  }

  .editor-area {
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  .editor-area :global(.cm-editor) {
    height: 100%;
  }

  .session-panel {
    width: 200px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-left: 1px solid var(--divider);
    background: var(--bg);
    padding: 12px;
    gap: 8px;
  }

  .panel-header {
    font-size: 13px;
    font-weight: 700;
    color: var(--text);
    padding-bottom: 4px;
    border-bottom: 1px solid var(--divider);
  }

  .broadcast-btn {
    margin-top: auto;
    padding: 10px;
    border: none;
    border-radius: var(--radius-sm);
    background: var(--accent);
    color: var(--white);
    font-family: inherit;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: opacity 0.15s;
  }
  .broadcast-btn:hover { opacity: 0.9; }
  .broadcast-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>
