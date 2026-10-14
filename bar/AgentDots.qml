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

    // Mirror Caelestia's own Workspace.qml layout: a persistent workspace
    // indicator, with one MaterialIcon BELOW it for each open window. This is
    // not an agent-selected or app-selected replacement for the Pac-Man icon.
    function windowClass(window: var): string {
        return String(window.class || window.title || "");
    }

    function appIcon(window: var): string {
        const cls = windowClass(window);
        if (/zen|firefox|chrom|brave|vivaldi|librewolf|browser/i.test(cls))
            return Icons.getAppCategoryIcon("app.zen_browser.zen", "language");
        if (/terminal|ghostty|kitty|alacritty|foot|wezterm|konsole|xterm|tilix|urxvt|bash|fish|zsh/i.test(cls))
            return Icons.getAppCategoryIcon(cls, "terminal");
        return Icons.getAppCategoryIcon(cls, "terminal");
    }

    property int hoveredDotIndex: 0
    // Generic optional bar-entry contract for aligning native popouts.
    property real hoveredDotCenterY: 6 + dotSize / 2
    readonly property real popoutAnchorY: hoveredDotCenterY

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: shown ? dotColumn.implicitHeight + 12 : 0
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
        id: dotColumn
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        spacing: root.dotGap

        Repeater {
            model: root.visibleAgents

            Item {
                id: agentItem
                required property int index
                required property var modelData
                readonly property color agentTint: modelData.color || Colours.palette.m3primary
                readonly property color iconTint: Qt.darker(agentTint, 2.2)
                readonly property var windows: {
                    const list = Array.isArray(modelData.windows) ? modelData.windows : [];
                    const max = Config.bar.workspaces.maxWindowIcons;
                    return max > 0 ? list.slice(0, max) : list;
                }
                width: root.dotSize
                height: workspaceStack.implicitHeight

                Column {
                    id: workspaceStack
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Rectangle {
                        id: pacmanDot
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.dotSize
                        height: root.dotSize
                        radius: width / 2
                        color: agentItem.agentTint
                        antialiasing: true
                        border.width: 1
                        border.color: Qt.alpha(agentItem.iconTint, 0.40)

                        // Pac-Man is never replaced by an app icon. Match
                        // the normal workspace's primary indicator position.
                        Canvas {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.fillStyle = agentItem.iconTint.toString();
                                ctx.beginPath();
                                ctx.moveTo(7.5, 7.5);
                                ctx.arc(7.5, 7.5, 6.25, Math.PI * 0.22, Math.PI * 1.78, false);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }

                    Column {
                        id: appIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        Repeater {
                            model: agentItem.windows

                            // Identical widget/font contract to Caelestia's
                            // modules/bar/components/workspaces/Workspace.qml.
                            MaterialIcon {
                                required property var modelData
                                grade: 0
                                text: root.appIcon(modelData)
                                color: agentItem.iconTint
                            }
                        }
                    }
                }

                // Hovering the indicator OR its app icons selects this preview.
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) {
                        root.hoveredDotIndex = agentItem.index;
                        root.hoveredDotCenterY = agentItem.mapToItem(root, 0, root.dotSize / 2).y;
                        root.choose(agentItem.modelData);
                    }
                }

                TapHandler {
                    onTapped: {
                        root.choose(agentItem.modelData);
                        Quickshell.execDetached(["/usr/bin/python3", root.agentOpener,
                            String(agentItem.modelData.workspace)]);
                    }
                }
            }
        }
    }
}
