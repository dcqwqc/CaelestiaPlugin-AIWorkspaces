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
