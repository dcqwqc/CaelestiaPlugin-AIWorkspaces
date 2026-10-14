pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// True bar entry, immediately after the normal five workspace dots.
// Agent-colored circular app indicators, one per private graphical workspace.
Item {
    id: root
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    readonly property string selectionWriter: Paths.toLocalFile(Qt.resolvedUrl("../scripts/preview_selection.py"))
    readonly property string agentOpener: Paths.toLocalFile(Qt.resolvedUrl("../scripts/open_agent_workspace.py"))
    property var agents: []
    property bool pinned: true
    property bool previewsEnabled: true
    property string mode: "integrated"
    readonly property var visibleAgents: agents.filter(a => pinned || a.active)
    readonly property int dotSize: 22
    readonly property int dotGap: 7

    // Agent names do NOT pick the icon. The private workspace's focused app
    // does; use the workspace kind as a stable fallback during startup.
    function appIcon(agent: var): string {
        const app = String(agent.appClass || agent.appTitle || "").toLowerCase();
        const kind = String(agent.kind || "").toLowerCase();
        if (/terminal|ghostty|kitty|alacritty|foot|wezterm|konsole|xterm|tilix|urxvt|gnome-terminal|bash|fish|zsh/.test(app))
            return "terminal";
        if (/zen|firefox|chrom|brave|vivaldi|librewolf|browser|web/.test(app) || kind === "browser")
            return "language";
        if (app && app !== "desktop")
            return Icons.getAppCategoryIcon(agent.appClass || app, "desktop_windows");
        return "desktop";
    }
    property int hoveredDotIndex: 0
    // Generic optional bar-entry contract for aligning native popouts.
    readonly property real popoutAnchorY: 6 + dotSize / 2 +
        Math.max(0, hoveredDotIndex) * (dotSize + dotGap)

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: shown ? (visibleAgents.length * dotSize + Math.max(0, visibleAgents.length - 1) * dotGap + 12) : 0
    readonly property bool shown: mode === "integrated" && previewsEnabled && visibleAgents.length > 0
    visible: shown

    function choose(agent: var): void {
        if (!agent || !agent.workspace)
            return;
        Quickshell.execDetached(["/usr/bin/python3", selectionWriter, runtimeDir + "/loom/preview-selection.json", String(agent.workspace)]);
    }

    FileView {
        path: root.runtimeDir + "/loom/preview-presentation.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const v = JSON.parse(text());
                root.mode = v.mode === "floating" ? "floating" : "integrated";
                root.pinned = v.pinned !== false;
                root.previewsEnabled = v.enabled !== false;
            } catch (e) {}
        }
    }

    FileView {
        path: root.runtimeDir + "/loom/agent-cursors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const v = JSON.parse(text());
                root.agents = (Array.isArray(v.agents) ? v.agents : [])
                    .filter(a => !a.hidden && a.state !== "crashed");
            } catch (e) {
                root.agents = [];
            }
        }
        onLoadFailed: root.agents = []
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        spacing: root.dotGap

        Repeater {
            model: root.visibleAgents

            Rectangle {
                id: dot
                required property int index
                required property var modelData
                readonly property string iconName: root.appIcon(modelData)
                readonly property color agentTint: modelData.color || Colours.palette.m3primary
                readonly property color iconTint: Qt.darker(agentTint, 2.35)
                width: root.dotSize
                height: root.dotSize
                radius: width / 2
                color: agentTint
                antialiasing: true
                border.width: 1
                border.color: Qt.alpha(iconTint, 0.48)

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: dot.iconName !== "desktop"
                    text: dot.iconName
                    color: dot.iconTint
                    font.pointSize: 12
                    grade: 0
                }

                // The idle/private desktop symbol is a tiny Pac-Man-shaped
                // Celestia icon, not a random per-agent label.
                Canvas {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    visible: dot.iconName === "desktop"
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = dot.iconTint.toString();
                        ctx.beginPath();
                        ctx.moveTo(7, 7);
                        ctx.arc(7, 7, 6.1, Math.PI * 0.22, Math.PI * 1.78, false);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                // Hover opens the existing native bar popout. Only selecting
                // the source agent is ours; the shell controls show/hide.
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) {
                        root.hoveredDotIndex = dot.index;
                        root.choose(dot.modelData);
                    }
                }

                // The special workspace hosts nested agent desktops.
                // User click, not hover, is the only action that opens it.
                TapHandler {
                    onTapped: {
                        root.choose(dot.modelData);
                        Quickshell.execDetached(["/usr/bin/python3", root.agentOpener,
                            String(dot.modelData.workspace)]);
                    }
                }
            }
        }
    }
}
