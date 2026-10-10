pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Loom agent cursors: a thin presentation of Loom's Agent Input service.
//
// Agents work on private displays, never on the user's desktop, so their
// pointers are drawn where they really are: inside small live previews of
// those displays. The preview stack is a click-through overlay (empty input
// mask); the only interactive surface is the controls panel the user opens
// explicitly (`qs -c caelestia ipc call loomAgents toggleControls`).
//
// The service writes $XDG_RUNTIME_DIR/loom/agent-cursors.json on change; this
// file is watched, never polled.
Scope {
    id: root

    property var settings: null

    readonly property bool enabled: settings ? settings.agentCursors : true
    readonly property real cursorOpacity: (settings ? settings.agentCursorOpacity : 90) / 100
    readonly property bool showLabels: settings ? settings.agentCursorLabels : true
    readonly property string animation: settings ? settings.agentCursorAnimation : "full"
    readonly property int tileWidth: settings ? settings.agentCursorTileWidth : 240
    readonly property string corner: settings ? settings.agentCursorPosition : "bottom-right"

    readonly property real motionScale: animation === "off" ? 0 : animation === "subtle" ? 0.6 : 1
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    readonly property string serviceCtl: `${Quickshell.env("HOME")}/.local/share/caelestia/plugins/loom/loom_agent_input.py`

    property var agents: []
    property bool controlsOpen: false
    property bool allHidden: false

    readonly property var shownAgents: agents.filter(a => a.active && !a.hidden && !root.allHidden)

    function ctl(command: string, payload: var): void {
        Quickshell.execDetached(["/usr/bin/python3", root.serviceCtl, "ctl", command, JSON.stringify(payload || {})]);
    }

    FileView {
        id: feed

        path: `${root.runtimeDir}/loom/agent-cursors.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.agents = Array.isArray(data.agents) ? data.agents : [];
            } catch (e) {
                root.agents = [];
            }
        }
        onLoadFailed: root.agents = []
    }

    IpcHandler {
        target: "loomAgents"

        function toggleControls(): void {
            root.controlsOpen = !root.controlsOpen;
        }
        function hideAll(): void {
            root.allHidden = true;
        }
        function showAll(): void {
            root.allHidden = false;
        }
        function pauseAll(): void {
            root.ctl("user-pause-all", {});
        }
        function resumeAll(): void {
            root.ctl("user-resume-all", {});
        }
        function list(): string {
            return JSON.stringify(root.agents.map(a => ({
                workspace: a.workspace, agent: a.agent, name: a.name, state: a.state, active: a.active
            })));
        }
    }

    // Only the focused physical monitor. Per-agent AI-* headless outputs are
    // never visible to the user, so nothing is drawn there.
    Variants {
        model: Quickshell.screens.filter(s => !String(s.name).startsWith("AI-"))

        PanelWindow {
            id: overlay

            required property ShellScreen modelData
            readonly property bool focusedScreen: (Hypr.focusedMonitor?.name ?? "") === modelData.name

            screen: modelData
            visible: root.enabled && focusedScreen && root.shownAgents.length > 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "loom-agent-cursors"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Empty input region: every click passes through to the user's windows.
            mask: Region {}

            anchors.bottom: root.corner.startsWith("bottom")
            anchors.top: root.corner.startsWith("top")
            anchors.right: root.corner.endsWith("right")
            anchors.left: root.corner.endsWith("left")
            margins.bottom: 18
            margins.top: 18
            margins.right: 18
            margins.left: 18

            implicitWidth: root.tileWidth
            implicitHeight: Math.max(1, stack.implicitHeight)

            Column {
                id: stack

                width: root.tileWidth
                spacing: 10

                Repeater {
                    model: root.shownAgents

                    AgentTile {}
                }
            }
        }
    }

    component AgentTile: Item {
        id: tile

        required property var modelData
        readonly property color tint: modelData.color || "#C9B8FF"
        readonly property real sx: width / Math.max(1, modelData.width)
        readonly property real sy: screenArea.height / Math.max(1, modelData.height)

        width: root.tileWidth
        height: screenArea.height + caption.height + 4
        opacity: root.cursorOpacity

        StyledClippingRect {
            id: screenArea

            width: parent.width
            height: Math.round(parent.width * tile.modelData.height / Math.max(1, tile.modelData.width))
            radius: 10
            color: Colours.palette.m3surfaceContainer
            border.width: 2
            border.color: Qt.alpha(tile.tint, 0.85)

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: tile.modelData.preview ? `file://${tile.modelData.preview}?${tile.modelData.previewSeq}` : ""
                cache: false
                asynchronous: true
                smooth: true
                fillMode: Image.Stretch
                visible: status === Image.Ready
            }

            // The agent's real pointer position on its private display.
            Item {
                id: pointer

                x: tile.modelData.x * tile.sx
                y: tile.modelData.y * tile.sy
                z: 2

                Behavior on x {
                    enabled: root.motionScale > 0
                    NumberAnimation {
                        duration: Math.max(80, tile.modelData.moveMs) * root.motionScale
                        easing.type: Easing.InOutCubic
                    }
                }
                Behavior on y {
                    enabled: root.motionScale > 0
                    NumberAnimation {
                        duration: Math.max(80, tile.modelData.moveMs) * root.motionScale
                        easing.type: Easing.InOutCubic
                    }
                }

                Rectangle {
                    id: ripple

                    width: 26
                    height: 26
                    radius: 13
                    x: -13
                    y: -13
                    color: "transparent"
                    border.width: 2
                    border.color: tile.tint
                    opacity: 0
                    scale: 0.3

                    ParallelAnimation {
                        id: rippleAnim

                        NumberAnimation { target: ripple; property: "scale"; from: 0.3; to: 1.4; duration: 380; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ripple; property: "opacity"; from: 0.9; to: 0; duration: 380; easing.type: Easing.OutCubic }
                    }
                }

                Shape {
                    width: 12
                    height: 17
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: tile.tint
                        strokeColor: Qt.darker(tile.tint, 2.4)
                        strokeWidth: 1.2
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M 0 0 L 0 14 L 3.6 10.6 L 6.4 16.4 L 8.6 15.4 L 5.9 9.7 L 10.8 9.7 Z" }
                    }
                }

                Rectangle {
                    visible: root.showLabels
                    // Flip inward near the tile's right/bottom edges so the tag is never clipped.
                    x: pointer.x + 12 + width > screenArea.width ? -width - 2 : 12
                    y: pointer.y + 12 + height > screenArea.height ? -height - 2 : 12
                    width: nameText.implicitWidth + 10
                    height: nameText.implicitHeight + 4
                    radius: height / 2
                    color: Qt.alpha(tile.tint, 0.92)

                    StyledText {
                        id: nameText

                        anchors.centerIn: parent
                        text: tile.modelData.name
                        font.pointSize: 7.5
                        font.weight: 600
                        color: Qt.darker(tile.tint, 3.2)
                    }
                }
            }

            property int lastClick: tile.modelData.clickSeq
            onLastClickChanged: if (root.motionScale > 0) rippleAnim.restart()

            Rectangle {
                visible: tile.modelData.state !== "ready"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                width: stateText.implicitWidth + 12
                height: stateText.implicitHeight + 4
                radius: height / 2
                color: tile.modelData.state === "crashed" ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

                StyledText {
                    id: stateText

                    anchors.centerIn: parent
                    text: tile.modelData.state
                    font.pointSize: 7.5
                    color: tile.modelData.state === "crashed" ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                }
            }
        }

        Row {
            id: caption

            anchors.top: screenArea.bottom
            anchors.topMargin: 4
            spacing: 6

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: tile.tint
            }

            StyledText {
                text: `${tile.modelData.name} · ${tile.modelData.label || tile.modelData.kind}`
                font.pointSize: 8
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
                width: root.tileWidth - 20
            }
        }
    }

    // Explicitly opened controls: the one interactive surface.
    PanelWindow {
        visible: root.controlsOpen
        screen: Quickshell.screens.find(s => s.name === (Hypr.focusedMonitor?.name ?? "")) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "loom-agent-controls"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.top: true
        anchors.right: true
        margins.top: 56
        margins.right: 18
        implicitWidth: 340
        implicitHeight: panel.implicitHeight

        StyledRect {
            id: panel

            width: parent.width
            implicitHeight: content.implicitHeight + 24
            radius: 16
            color: Colours.palette.m3surfaceContainer

            Column {
                id: content

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Row {
                    width: parent.width

                    StyledText {
                        width: parent.width - closeBtn.width
                        text: root.agents.length ? "AI graphical workspaces" : "No AI graphical workspaces"
                        font.pointSize: 10
                        font.weight: 600
                        color: Colours.palette.m3onSurface
                    }

                    ControlButton {
                        id: closeBtn
                        label: "Close"
                        onClicked: root.controlsOpen = false
                    }
                }

                Repeater {
                    model: root.agents

                    Column {
                        id: row

                        required property var modelData
                        width: content.width
                        spacing: 4

                        Row {
                            spacing: 6

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: row.modelData.color
                            }

                            StyledText {
                                text: `${row.modelData.name} · ${row.modelData.kind} · ${row.modelData.state}`
                                font.pointSize: 9
                                color: Colours.palette.m3onSurface
                            }
                        }

                        Row {
                            spacing: 6

                            ControlButton {
                                label: row.modelData.state === "paused" ? "Resume" : "Pause"
                                onClicked: root.ctl(row.modelData.state === "paused" ? "user-resume" : "user-pause", {
                                    workspace_id: row.modelData.workspace
                                })
                            }
                            ControlButton {
                                label: row.modelData.hidden ? "Show" : "Hide"
                                onClicked: root.ctl(row.modelData.hidden ? "user-show-agent" : "user-hide-agent", {
                                    agent_id: row.modelData.agent
                                })
                            }
                            ControlButton {
                                label: "Stop"
                                danger: true
                                onClicked: root.ctl("user-terminate", {
                                    workspace_id: row.modelData.workspace
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    component ControlButton: StyledRect {
        id: btn

        property string label
        property bool danger: false
        signal clicked

        implicitWidth: btnText.implicitWidth + 20
        implicitHeight: btnText.implicitHeight + 8
        radius: implicitHeight / 2
        color: danger ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

        StyledText {
            id: btnText

            anchors.centerIn: parent
            text: btn.label
            font.pointSize: 8.5
            color: btn.danger ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
        }

        StateLayer {
            radius: btn.radius
            onClicked: btn.clicked()
        }
    }
}
