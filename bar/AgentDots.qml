pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    // Follow the native active workspace indicator dimensions, rather than
    // maintaining an unrelated 22px circle.
    readonly property int dotSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small
    readonly property int dotGap: Math.floor(Tokens.spacing.extraSmall)

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
    property real hoveredDotCenterY: Tokens.padding.small + dotSize / 2
    readonly property real popoutAnchorY: hoveredDotCenterY

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: shown ? dotColumn.implicitHeight + Tokens.padding.small * 2 : 0
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
        anchors.topMargin: Tokens.padding.small
        spacing: root.dotGap

        Repeater {
            model: root.visibleAgents

            Item {
                id: agentItem
                required property int index
                required property var modelData
                readonly property color agentTint: modelData.color || Colours.palette.m3primary
                readonly property var windows: {
                    // QML repeater delegates wrap JSON arrays as QVariantList
                    // objects: JSON.stringify works, Array.isArray is false.
                    // Normalise to a real JS array before handing it to the
                    // nested Repeater, otherwise ALL app icons disappear.
                    const decoded = JSON.parse(JSON.stringify(modelData.windows ?? []));
                    const list = Array.isArray(decoded) ? decoded : [];
                    const max = Config.bar.workspaces.maxWindowIcons;
                    return max > 0 ? list.slice(0, max) : list;
                }
                width: Tokens.sizes.bar.innerWidth
                height: agentPill.implicitHeight

                // A SINGLE rounded, agent-colored capsule encloses the
                // persistent Pac-Man AND every window icon, just like the
                // normal workspace's ActiveIndicator overlay. No orphan icons
                // sit below an isolated color dot.
                StyledRect {
                    id: agentPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                    // Exactly the size of native ActiveIndicator / Workspace.size:
                    // one workspace row, with extra padding only when app icons exist.
                    implicitHeight: workspaceStack.implicitHeight +
                        (agentItem.windows.length > 0 && Config.bar.workspaces.showWindows ? Tokens.padding.extraSmall : 0)
                    radius: Tokens.rounding.full
                    color: agentItem.agentTint
                    clip: true

                    ColumnLayout {
                        id: workspaceStack
                        anchors.centerIn: parent
                        spacing: 0

                        // This is intentionally the SAME StyledText glyph, font,
                        // line height, and text color as the native Workspace
                        // and its ActiveIndicator. No approximate Canvas art.
                        StyledText {
                            id: indicator
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                            animate: true
                            text: Config.bar.workspaces.activeLabel || Config.bar.workspaces.occupiedLabel || "󰮯"
                            color: Colours.palette.m3onPrimary
                            verticalAlignment: Qt.AlignVCenter
                            font.family: Tokens.font.workspaces
                        }

                        Loader {
                            id: windows
                            asynchronous: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillHeight: true
                            Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10
                            visible: active
                            active: agentItem.windows.length > 0 && Config.bar.workspaces.showWindows

                            sourceComponent: Column {
                                spacing: 0

                                Repeater {
                                    model: agentItem.windows

                                    MaterialIcon {
                                        required property var modelData
                                        grade: 0
                                        text: root.appIcon(modelData)
                                        color: Colours.palette.m3onPrimary
                                    }
                                }
                            }
                        }
                    }
                }

                // Hovering the indicator OR its app icons selects this preview.
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) {
                        root.hoveredDotIndex = agentItem.index;
                        root.hoveredDotCenterY = agentItem.mapToItem(root, 0, agentPill.implicitHeight / 2).y;
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
