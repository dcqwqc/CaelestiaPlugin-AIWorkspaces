# Caelestia AI Workspaces

Per-agent GUI isolation for Hyprland and Caelestia.

Every local AI session can get its own dynamically-created headless monitor and
named workspace. The AI can launch or restart GUI test apps, take screenshots,
and inspect its work without switching the user's physical workspace or stealing
keyboard focus.

## Model

A normal user workspace stays on the physical display. Each agent gets its own
pair such as:

    AI-claude-a1b2c3  ->  ai-claude-a1b2c3
    AI-codex-09f311   ->  ai-codex-09f311

Multiple agents therefore render concurrently without sharing one scratchpad.

## CLI

    ai-workspace run --provider claude -- claude
    ai-workspace run --provider codex -- codex
    ai-workspace gui npm run dev
    ai-workspace screenshot
    ai-workspace status
    ai-workspace list
    ai-workspace close

The agent receives AI_SESSION_ID, AI_WORKSPACE, AI_MONITOR,
AI_ORIGIN_WORKSPACE and AI_ORIGIN_MONITOR.

Nested agents inherit the parent session instead of creating more monitors.

## Automatic Fish integration

When enabled, the plugin installs lightweight Fish wrappers for Codex, Claude
Code and Agy. Settings in Nexus -> Plugins -> AI Workspaces control which
providers are automatically isolated.

Set Default AI desktop mode to current to keep new agents on the normal desktop
without uninstalling the plugin.

## Safety

GUI launches use silent placement, no-initial-focus and activation suppression.
The helper never focuses the AI output to inspect it.

During cleanup only windows resident on the private AI workspace are closed
before its virtual monitor is removed, preventing AI windows from spilling onto
the user's desktop.

## Install

Clone the repository to:

    ~/.local/share/caelestia/plugins/ai-workspaces

Then enable dcqwqc/aiworkspaces in Nexus -> Plugins.

## Licence

GPL-3.0-or-later.

## Loom MCP task visibility

The existing **Loom** desktop companion is the task display. For each newly
created private AI session, the launcher now creates or reuses a pinned Loom
Working card, passes its stable ID through `LOOM_TASK_ID`, and checks the
card when the child process exits. If the process exits successfully without
verified completion, the card remains **waiting for review**, not falsely
Done. If the process fails, the card is blocked. If the agent itself already
marked it done or blocked, the launcher preserves that state.

To resume a known work item without duplicating its card, export an existing
`LOOM_TASK_ID` before launching the agent. The universal
`loom-task-visibility` AI System skill teaches agents to update the same
card. A missing Loom connection never prevents the agent from running.

This hook applies to agents launched through `ai-workspace run` with an
isolated workspace; it does **not** automatically cover direct binary
execution, ChatGPT web sessions, or remote agents that bypass the launcher.
The `loomTaskVisibility` setting defaults to true and can be disabled in
the plugin's configuration if needed.

## AI workspace circles beneath the normal workspace dots (v0.4)

The plugin registers a real `bar-entry` (`aiAgentDots`) and matching native
`bar-popout` instead of the former top-left shell-panel.

- One **22 px workspace-colored circle** per active or pinned graphical agent,
  stacked vertically below the normal workspace indicators. A subtle outline
  encloses an automatically selected app icon: Pac-Man-shaped Celestia for a
  private idle desktop, browser/globe for Zen or other browsers, terminal for
  Ghostty/Kitty/etc. The background remains the agent's assigned color. The
  focused app is detected within the isolated graphical workspace; agents do
  not specify their icons.
- **Hover** a specific dot to see that agent's live screenshot and its
  corresponding pointer immediately to the right, in the existing QuickShell
  bar popout. The thumbnail uses a single 24 px rounded clip plus a faint
  agent-tinted outline, avoiding square corners from nested clipping. Hover alone never switches workspaces or focus.
- **Click** a dot to show `special:loom-agents` and focus that nested agent's
  corresponding host window. Xvfb sessions use the viewer fallback.
- Inactive agents remain visible when pinned; hidden/released/crashed agents
  disappear. The old movable floating mode remains an explicit opt-in.

The hovered workspace ID is written atomically to
`$XDG_RUNTIME_DIR/loom/preview-selection.json`, which the popout watches.
No polling loop or extra overlay window is introduced.

### Install / deploy

```sh
python3 ~/.local/share/caelestia/plugins/ai-workspaces/scripts/install_bar_entry.py
```

The installer preserves other user settings and idempotently inserts the
`aiAgentDots` entry directly after `workspaces` in
`~/.config/caelestia/shell.json`.

For *exact hovered-circle vertical alignment*, a tiny optional host patch is
included as `patches/bar-agent-popout-anchor.patch`. In
`~/.config/quickshell/caelestia`, run `git apply --check` on the patch before
applying it. Without this enhancement, native popouts still work but anchor at
the middle of the dot stack. Mirai has the host patch applied.

This still uses the Loom screenshot feed; it is not a fully continuous video
stream, and mouse movement may update between captured frames.

### QuickShell IPC

```sh
qs -c caelestia ipc --any-display call loomAgents previewState
qs -c caelestia ipc --any-display call loomAgents setPreviewMode integrated
qs -c caelestia ipc --any-display call loomAgents setPreviewMode floating
qs -c caelestia ipc --any-display call loomAgents pinPreviews
qs -c caelestia ipc --any-display call loomAgents unpinPreviews
```

