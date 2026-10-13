pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// True bar entry, immediately after the normal five workspace dots.
// Its entire idle presentation is a vertical stack of solid color circles.
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
    readonly property int dotSize: 14
    readonly property int dotGap: 8
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
                width: root.dotSize
                height: root.dotSize
                radius: width / 2
                color: modelData.color || Colours.palette.m3primary
                antialiasing: true

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
