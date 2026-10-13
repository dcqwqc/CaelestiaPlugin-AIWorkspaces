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

## AI workspaces: native preview dock (v0.3)

The default preview is **integrated**, not floating. A 72-pixel compact AI
tab joins Caelestia's existing top-left shell-panel frame. Hover to expand
the live workspace thumbnail and task name; move the pointer away to collapse.
It does not create an independent overlay and does not appear above fullscreen
apps. Its border/shadow are owned by the native Caelestia ShellPanels host.

The expanded preview includes a pin state, a detach control and a close
(collapsing) control. Detach is explicit: it switches presentation to
**floating**, which preserves the old draggable card and its saved position.
Use the floating card's dock control to return to the small native tab.
The tab stays available for an idle agent while previews are pinned.

Select the default in Nexus → Plugins → AIWorkspaces → Settings:
**AI preview presentation: integrated / floating**. Existing floating
corner and size settings apply only to the explicit floating mode.
The former `agentCursorDocked` setting is retained for older profiles but
no longer controls the native presentation.

The plugin controller and native panel share only the two narrow pieces of
state they need via an atomically written JSON file at
`$XDG_RUNTIME_DIR/loom/preview-presentation.json`. The agent image/pointer
data still comes from `loom/agent-cursors.json`. This does not change the
screenshot capture rate or guarantee a continuous real-time video stream.

### QuickShell IPC

```sh
qs -c caelestia ipc --any-display call loomAgents previewState
qs -c caelestia ipc --any-display call loomAgents setPreviewMode integrated
qs -c caelestia ipc --any-display call loomAgents setPreviewMode floating
qs -c caelestia ipc --any-display call loomAgents pinPreviews
qs -c caelestia ipc --any-display call loomAgents unpinPreviews
qs -c caelestia ipc --any-display call loomAgents toggleControls
```

### Verification needed before deployment/merge

- On Mirai, confirm the native shell-panel entry point loads without
  QML warnings and the 72-pixel tab joins the bar without covering apps.
- Hover/collapse and the detach → float → dock cycle work across reloads.
- Confirm fullscreen hides the panel; inactive/pinned agents remain listed.
- Visually inspect pointer placement at more than one aspect ratio.
- Run Python tests and check Quickshell logs. Static tests alone are not
  evidence of successful display.

