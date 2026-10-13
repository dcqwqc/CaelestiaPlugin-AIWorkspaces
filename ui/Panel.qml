pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

// A native shell-panel entry point: Caelestia owns the background, borders,
// shadow and input region. The collapsed tab is the default, not an overlay.
Item {
    id: root
    property ShellScreen screen: null

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    property string presentation: "integrated"
    property var agents: []
    property bool expanded: false
    readonly property var agent: agents.length ? agents[0] : ({})
    readonly property color accent: agent.color || Colours.palette.m3primary
    readonly property real imageAspect: Math.max(1, agent.height || 800) / Math.max(1, agent.width || 1280)
    readonly property int previewHeight: Math.max(90, Math.min(164, Math.round((panelWidth - 20) * imageAspect)))
    readonly property int panelWidth: expanded ? 270 : 72
    readonly property int panelHeight: expanded ? previewHeight + 66 : 42
    readonly property bool focusedScreen: !!screen && (Hypr.focusedMonitor?.name ?? "") === screen.name
    readonly property bool hasFullscreen: {
        if (!screen)
            return false;
        const monitor = Hypr.monitorFor(screen);
        const special = monitor?.lastIpcObject.specialWorkspace?.name ?? "";
        const workspace = special ? Hypr.workspaces.values.find(w => w.name === special) : monitor?.activeWorkspace;
        return workspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    // ShellPanels.qml consumes these properties and draws a native joined
    // panel; there is no independent always-on-top Wayland overlay surface.
    readonly property bool panelVisible: screen !== null && focusedScreen
        && !hasFullscreen && presentation === "integrated" && agents.length > 0
    readonly property bool panelInputEnabled: true
    readonly property real panelDeformAmount: 0
    readonly property real panelEdgeOffset: 0
    readonly property int panelMotionDuration: 190

    implicitWidth: panelWidth
    implicitHeight: panelHeight

    function command(action: string, argument: string): void {
        const args = ["qs", "-c", "caelestia", "ipc", "--any-display", "call", "loomAgents", action];
        if (argument)
            args.push(argument);
        Quickshell.execDetached(args);
    }

    FileView {
        path: `${root.runtimeDir}/loom/preview-presentation.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.presentation = data.mode === "floating" ? "floating" : "integrated";
            } catch (error) {
                root.presentation = "integrated";
            }
        }
    }

    FileView {
        path: `${root.runtimeDir}/loom/agent-cursors.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.agents = (Array.isArray(data.agents) ? data.agents : [])
                    .filter(a => !a.hidden && a.state !== "crashed");
            } catch (error) {
                root.agents = [];
            }
        }
        onLoadFailed: root.agents = []
    }

    Timer {
        id: closeDelay
        interval: 220
        onTriggered: {
            if (!hoverArea.containsMouse)
                root.expanded = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: Colours.palette.m3surfaceContainer
        border.width: 0

        Rectangle {
            x: 8
            y: 9
            width: 3
            height: root.expanded ? 20 : root.height - 18
            radius: 1.5
            color: root.accent
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        onEntered: {
            closeDelay.stop();
            root.expanded = true;
        }
        onExited: closeDelay.restart()
        onClicked: if (!root.expanded) root.expanded = true
    }

    Row {
        x: 18
        y: 8
        width: root.width - 26
        height: 25
        spacing: 6

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "smart_toy"
            color: root.accent
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: root.expanded ? Math.max(30, root.width - 112) : 24
            text: root.expanded ? (root.agent.name || "AI Workspace") : String(root.agents.length)
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pointSize: 9
            color: Colours.palette.m3onSurface
            font.weight: 600
        }
    }

    Item {
        visible: root.expanded
        x: root.width - 62
        y: 6
        width: 26
        height: 30

        MaterialIcon {
            anchors.centerIn: parent
            text: "open_in_new"
            color: Colours.palette.m3onSurfaceVariant
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.command("setPreviewMode", "floating")
        }
    }

    Item {
        visible: root.expanded
        x: root.width - 33
        y: 6
        width: 25
        height: 30

        MaterialIcon {
            anchors.centerIn: parent
            text: "close"
            color: Colours.palette.m3onSurfaceVariant
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = false
        }
    }

    Item {
        id: preview
        visible: root.expanded
        x: 10
        y: 39
        width: root.width - 20
        height: root.previewHeight
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Colours.palette.m3surface
        }

        Item {
            id: frame
            anchors.fill: parent
            clip: true

            readonly property string url: root.agent.preview
                ? "file://" + root.agent.preview + "?" + (root.agent.previewSeq || 0)
                : ""
            property bool frontA: true
            onUrlChanged: (frontA ? bufferB : bufferA).source = url

            Image {
                id: bufferA
                anchors.fill: parent
                asynchronous: true
                cache: false
                smooth: true
                fillMode: Image.PreserveAspectFit
                visible: frame.frontA && status === Image.Ready
                onStatusChanged: if (status === Image.Ready && !frame.frontA) frame.frontA = true
            }
            Image {
                id: bufferB
                anchors.fill: parent
                asynchronous: true
                cache: false
                smooth: true
                fillMode: Image.PreserveAspectFit
                visible: !frame.frontA && status === Image.Ready
                onStatusChanged: if (status === Image.Ready && frame.frontA) frame.frontA = false
            }
        }

        // The visual cursor never accepts pointer input. The source image is
        // centered with PreserveAspectFit; account for letterboxing.
        Item {
            readonly property real aw: Math.max(1, root.agent.width || 1280)
            readonly property real ah: Math.max(1, root.agent.height || 800)
            readonly property real scaleFactor: Math.min(preview.width / aw, preview.height / ah)
            readonly property real offsetX: (preview.width - aw * scaleFactor) / 2
            readonly property real offsetY: (preview.height - ah * scaleFactor) / 2
            x: offsetX + Math.max(0, root.agent.x || 0) * scaleFactor
            y: offsetY + Math.max(0, root.agent.y || 0) * scaleFactor
            z: 2
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            Shape {
                width: 12
                height: 17
                ShapePath {
                    fillColor: root.accent
                    strokeColor: Qt.darker(root.accent, 2.0)
                    strokeWidth: 1.0
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 0 0 L 0 14 L 3.6 10.6 L 6.4 16.4 L 8.6 15.4 L 5.9 9.7 L 10.8 9.7 Z" }
                }
            }
        }
    }

    StyledText {
        visible: root.expanded
        x: 13
        y: root.previewHeight + 42
        width: root.width - 26
        text: root.agent.label || root.agent.kind || ""
        elide: Text.ElideRight
        maximumLineCount: 1
        font.pointSize: 8
        color: Colours.palette.m3onSurfaceVariant
    }
}
