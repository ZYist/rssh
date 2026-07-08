<script lang="ts">
  import type { SessionInfo } from "../stores/app.svelte.ts";
  import { t } from "../i18n/index.svelte.ts";
  import AppIcon from "./AppIcon.svelte";
  import { tabIconName } from "./app-icon";

  // 受控组件（D-01）：自身零内部 runes 状态、零副作用 effect，所有状态经 props 进、
  // 所有变更经回调出。宿主负责过滤主标签（D-05）与持久化选中集合（EditPane 本地一次性
  // 发送语义 / ai store per-tab 广播状态，两者不同寿命，故 selectedIds 由宿主注入）。
  //
  // onHover / onHoverLeave 是可选 prop（W2 零回归）：EditPane 传入以保留其既有
  // hover→SessionPreviewPopover 预览行为；ChatPanel（Plan 01-02）不传 → 天然无
  // hover（Q1 RESOLVED，D-04 不给 AI 面板加额外特性）。
  let {
    sessions,
    selectedIds,
    onToggle,
    onSelectAll,
    onSelectNone,
    onHover = undefined,
    onHoverLeave = undefined,
  }: {
    sessions: SessionInfo[];
    selectedIds: Set<string>;
    onToggle: (tabId: string) => void;
    onSelectAll: () => void;
    onSelectNone: () => void;
    onHover?: (tabId: string, anchor: HTMLElement) => void;
    onHoverLeave?: () => void;
  } = $props();
</script>

{#if sessions.length === 0}
  <div class="empty-hint">{t("ai.broadcast.empty")}</div>
{:else}
  <div class="session-list">
    {#each sessions as s (s.tabId)}
      <button
        type="button"
        class="session-item"
        class:selected={selectedIds.has(s.tabId)}
        aria-pressed={selectedIds.has(s.tabId)}
        onclick={() => onToggle(s.tabId)}
        onmouseenter={onHover ? ((e: MouseEvent) => onHover(s.tabId, e.currentTarget as HTMLElement)) : undefined}
        onmouseleave={onHoverLeave ?? undefined}
        title={s.label}
      >
        <span class="session-meta">
          <span class="session-type"><AppIcon name={tabIconName(s.type)} size={13} /></span>
          <span class="session-label">{s.label}</span>
        </span>
      </button>
    {/each}
  </div>
  <div class="select-actions">
    <button class="link-btn" onclick={onSelectAll}>{t("ai.broadcast.select_all")}</button>
    <button class="link-btn" onclick={onSelectNone}>{t("ai.broadcast.select_none")}</button>
  </div>
{/if}

<style>
  .empty-hint {
    font-size: 12px;
    color: var(--text-dim);
    padding: 8px 0;
  }

  .session-list {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .session-item {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 3px 8px;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: inherit;
    font-size: 12px;
    color: var(--text-sub);
    background: none;
    text-align: left;
    transition: background 0.1s, border-color 0.1s, box-shadow 0.1s;
  }
  .session-item:hover { background: var(--surface); color: var(--text); }

  /* Selected = the codebase's halo language (see TerminalPane .block-halo):
     a solid accent edge carries the signal, the outer glow is just gravy — so
     selection stays legible even where WKWebView weakens box-shadow blur. */
  .session-item.selected {
    color: var(--text);
    border-color: var(--accent);
    background: color-mix(in srgb, var(--accent) 12%, transparent);
    box-shadow: 0 0 0 1px var(--accent),
                0 0 12px -2px color-mix(in srgb, var(--accent) 65%, transparent);
  }

  .session-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
  }

  .session-type {
    font-size: 10px;
    font-weight: 700;
    color: var(--accent);
    min-width: 28px;
  }

  .session-label {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .select-actions {
    display: flex;
    gap: 8px;
    padding: 4px 0;
  }

  .link-btn {
    background: none;
    border: none;
    color: var(--accent);
    font-size: 12px;
    font-family: inherit;
    cursor: pointer;
    padding: 0;
  }
  .link-btn:hover { text-decoration: underline; }
</style>
