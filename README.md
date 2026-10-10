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

## Loom agent cursors

When an agent works in one of Loom's isolated graphical workspaces (see
`docs/AGENT_INPUT.md` in CaelestiaPlugin-Loom), this plugin (Main.qml) shows a small
live preview of that agent's private display in a corner of the focused
monitor. The agent's pastel pointer sits at its real position, with a compact
name tag and click ripples. The layer is fully click-through (empty input
region), never takes keyboard focus, is not drawn on `AI-*` headless outputs,
and hides when agents go idle. There is no polling: it watches
`$XDG_RUNTIME_DIR/loom/agent-cursors.json`.

Settings: show/hide, labels, opacity, animation intensity, preview width,
corner. Controls (pause/resume/hide/stop per agent):

    qs -c caelestia ipc call loomAgents toggleControls
    qs -c caelestia ipc call loomAgents pauseAll | resumeAll | hideAll | showAll | list

When an agent session launched through `ai-workspace run` ends, its Loom
graphical workspaces are released automatically.
