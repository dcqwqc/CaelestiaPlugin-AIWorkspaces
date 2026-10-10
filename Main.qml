pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services
import qs.utils

// AI Workspaces root: session bootstrap/GC for per-agent Hyprland desktops,
// plus Loom agent cursors, a thin presentation of Loom's Agent Input service.
//
// The overlay lives in this file rather than a separate entry point because
// Qt caches plugin directory listings: a newly added QML file is not found by
// hot reload until the whole shell restarts, which would also restart Loom.
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

    readonly property string helper: Paths.toLocalFile(Qt.resolvedUrl("scripts/ai-workspace"))

    Process {
        id: bootstrap
        command: [root.helper, "bootstrap"]
        running: true
    }

    Process {
        id: gcProc
        command: [root.helper, "gc"]
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            if (!gcProc.running)
                gcProc.running = true;
        }
    }

    readonly property bool enabled: settings ? settings.agentCursors : true
    readonly property real cursorOpacity: (settings ? settings.agentCursorOpacity : 90) / 100
    readonly property bool showLabels: settings ? settings.agentCursorLabels : true
    readonly property string animation: settings ? settings.agentCursorAnimation : "full"
    readonly property int tileWidth: settings ? settings.agentCursorTileWidth : 240
    readonly property string corner: settings ? settings.agentCursorPosition : "bottom-right"

    readonly property real motionScale: animation === "off" ? 0 : animation === "subtle" ? 0.6 : 1
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    readonly property string serviceCtl: `${Quickshell.env("HOME")}/.local/share/caelestia/plugins/loom/loom_agent_input.py`

    // Agent state from the service. Delegates are keyed by workspace id and the
    // id lists are only reassigned when their contents change, so tiles (and
    // their running cursor animations) survive every feed update.
    property var agents: []
    property var agentById: ({})
    property var shownIds: []
    property var viewerIds: []
    property bool viewerOpen: false
    property int liveSeq: 0
    property bool controlsOpen: false
    property bool allHidden: false
    onAllHiddenChanged: recompute()

    function sameList(a: var, b: var): bool {
        return a.length === b.length && a.every((v, i) => v === b[i]);
    }

    function recompute(): void {
        const shown = agents.filter(a => a.active && !a.hidden && !root.allHidden).map(a => a.workspace);
        if (!sameList(shown, shownIds))
            shownIds = shown;
        // Nested-Hyprland agents are their own native windows on special:loom-agents;
        // the streamed viewer is only for agents on the Xvfb fallback.
        const viewing = agents.filter(a => a.state !== "crashed" && a.backend !== "nested").map(a => a.workspace);
        if (!sameList(viewing, viewerIds))
            viewerIds = viewing;
    }

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
            let list = [];
            try {
                const data = JSON.parse(text());
                list = Array.isArray(data.agents) ? data.agents : [];
                root.viewerOpen = !!data.viewerOpen;
                root.liveSeq = data.liveSeq || 0;
            } catch (e) {}
            const by = {};
            for (const a of list)
                by[a.workspace] = a;
            root.agentById = by;
            root.agents = list;
            root.recompute();
        }
        onLoadFailed: {
            root.agents = [];
            root.agentById = {};
            root.recompute();
        }
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

    // Small click-through previews on the focused physical monitor. Hidden
    // while the full-screen viewer is open (it already shows everything).
    Variants {
        model: Quickshell.screens.filter(s => !String(s.name).startsWith("AI-"))

        PanelWindow {
            id: overlay

            required property ShellScreen modelData
            readonly property bool focusedScreen: (Hypr.focusedMonitor?.name ?? "") === modelData.name

            screen: modelData
            visible: root.enabled && focusedScreen && !root.viewerOpen && root.shownIds.length > 0
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
                    model: root.shownIds

                    AgentTile {}
                }
            }
        }
    }

    component AgentTile: Item {
        id: tile

        required property string modelData
        readonly property var agent: root.agentById[modelData] || ({})
        readonly property color tint: agent.color || "#C9B8FF"

        width: root.tileWidth
        height: screenArea.height + caption.height + 4
        opacity: root.cursorOpacity

        Rectangle {
            id: screenArea

            width: parent.width
            height: Math.round(parent.width * (tile.agent.height || 800) / Math.max(1, tile.agent.width || 1280))
            radius: 10
            clip: true
            color: Colours.palette.m3surfaceContainer
            border.width: 2
            border.color: Qt.alpha(tile.tint, 0.85)

            LiveImage {
                anchors.fill: parent
                anchors.margins: 2
                source: tile.agent.preview ? `file://${tile.agent.preview}?${tile.agent.previewSeq}` : ""
            }

            PathPointer {
                agent: tile.agent
                sx: screenArea.width / Math.max(1, tile.agent.width || 1)
                sy: screenArea.height / Math.max(1, tile.agent.height || 1)
                arrowScale: 1
                bounds: Qt.size(screenArea.width, screenArea.height)
            }

            StateBadge {
                agent: tile.agent
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
                text: `${tile.agent.name || ""} · ${tile.agent.label || tile.agent.kind || ""}`
                font.pointSize: 8
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
                width: root.tileWidth - 20
            }
        }
    }

    // The agent's pointer, animated along the exact curved path the service
    // drives the real pointer through (published per move as `path`), so it
    // moves like a hand rather than gliding in a straight line.
    component PathPointer: Item {
        id: ptr

        property var agent: ({})
        property real sx: 1
        property real sy: 1
        property real arrowScale: 1
        property size bounds: Qt.size(0, 0)
        property var path: []
        property real t: 1
        readonly property color tint: agent.color || "#C9B8FF"
        readonly property point pos: pointAt(t, agent.x, agent.y)

        function pointAt(t: real, fx: real, fy: real): point {
            const p = path;
            if (!p || p.length < 2 || t >= 1)
                return Qt.point(fx || 0, fy || 0);
            const f = Math.max(0, t) * (p.length - 1);
            const i = Math.floor(f);
            const r = f - i;
            const a = p[i];
            const b = p[Math.min(i + 1, p.length - 1)];
            return Qt.point(a[0] + (b[0] - a[0]) * r, a[1] + (b[1] - a[1]) * r);
        }

        property int moveSeq: agent.moveSeq || 0
        onMoveSeqChanged: {
            path = agent.path || [];
            const ms = (agent.moveMs || 0) * root.motionScale;
            if (ms < 16 || path.length < 2) {
                walk.stop();
                t = 1;
                return;
            }
            walk.duration = ms;
            walk.restart();
        }

        property int clicks: agent.clickSeq || 0
        onClicksChanged: if (root.motionScale > 0) ripple.play()

        NumberAnimation {
            id: walk

            target: ptr
            property: "t"
            from: 0
            to: 1
            easing.type: Easing.Linear  // the path samples already carry the hand's speed profile
        }

        x: pos.x * sx
        y: pos.y * sy
        z: 2

        Rectangle {
            id: ripple

            function play(): void {
                rippleAnim.restart();
            }

            width: 26 * ptr.arrowScale
            height: width
            radius: width / 2
            x: -width / 2
            y: -height / 2
            color: "transparent"
            border.width: 2 * ptr.arrowScale
            border.color: ptr.tint
            opacity: 0

            ParallelAnimation {
                id: rippleAnim

                NumberAnimation { target: ripple; property: "scale"; from: 0.3; to: 1.4; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 0.9; to: 0; duration: 380; easing.type: Easing.OutCubic }
            }
        }

        Shape {
            width: 12
            height: 17
            scale: ptr.arrowScale
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: ptr.tint
                strokeColor: Qt.darker(ptr.tint, 2.4)
                strokeWidth: 1.2
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 0 0 L 0 14 L 3.6 10.6 L 6.4 16.4 L 8.6 15.4 L 5.9 9.7 L 10.8 9.7 Z" }
            }
        }

        Rectangle {
            visible: root.showLabels
            readonly property real off: 12 * ptr.arrowScale
            // Flip inward near the right/bottom edges so the tag is never clipped.
            x: ptr.x + off + width > ptr.bounds.width ? -width - 2 : off
            y: ptr.y + off + height > ptr.bounds.height ? -height - 2 : off
            width: nameText.implicitWidth + 10 * ptr.arrowScale
            height: nameText.implicitHeight + 4 * ptr.arrowScale
            radius: height / 2
            color: Qt.alpha(ptr.tint, 0.92)

            StyledText {
                id: nameText

                anchors.centerIn: parent
                text: ptr.agent.name || ""
                font.pointSize: 7.5 * Math.min(1.4, ptr.arrowScale)
                font.weight: 600
                color: Qt.darker(ptr.tint, 3.2)
            }
        }
    }

    // Double-buffered image: the next frame decodes off the UI thread into the
    // hidden buffer and is swapped in only when ready, so frames never flash
    // and never stall the shell.
    component LiveImage: Item {
        id: live

        property string source
        property int fillMode: Image.Stretch
        property bool aFront: true

        onSourceChanged: (aFront ? imgB : imgA).source = source

        Image {
            id: imgA

            anchors.fill: parent
            asynchronous: true
            cache: false
            smooth: true
            fillMode: live.fillMode
            visible: live.aFront && status === Image.Ready
            onStatusChanged: if (status === Image.Ready && !live.aFront) live.aFront = true
        }

        Image {
            id: imgB

            anchors.fill: parent
            asynchronous: true
            cache: false
            smooth: true
            fillMode: live.fillMode
            visible: !live.aFront && status === Image.Ready
            onStatusChanged: if (status === Image.Ready && live.aFront) live.aFront = false
        }
    }

    component StateBadge: Rectangle {
        property var agent: ({})

        visible: (agent.state || "ready") !== "ready"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 6
        width: stateText.implicitWidth + 12
        height: stateText.implicitHeight + 4
        radius: height / 2
        color: agent.state === "crashed" ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

        StyledText {
            id: stateText

            anchors.centerIn: parent
            text: parent.agent.state || ""
            font.pointSize: 7.5
            color: parent.agent.state === "crashed" ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
        }
    }

    // Full-screen live view of every agent workspace (special:loom-agents,
    // SUPER+A; fullscreen via the window rule in hypr-user.lua). The service
    // streams frames only while that special workspace is open. View only:
    // input here never reaches an agent's display.
    FloatingWindow {
        id: viewer

        readonly property int n: root.viewerIds.length
        readonly property int cols: Math.min(n, Math.max(3, Math.ceil(Math.sqrt(n))))
        readonly property int rows: Math.max(1, Math.ceil(n / Math.max(1, cols)))
        readonly property real gap: n > 1 ? 6 : 0

        title: "Loom Agents"
        visible: root.enabled && n > 0
        color: "black"
        implicitWidth: 1280
        implicitHeight: 800

        Repeater {
            model: root.viewerIds

            AgentStage {
                required property string modelData
                required property int index
                readonly property int row: Math.floor(index / viewer.cols)
                readonly property int inRow: Math.min(viewer.cols, viewer.n - row * viewer.cols)
                readonly property int col: index - row * viewer.cols

                agent: root.agentById[modelData] || ({})
                width: (viewer.width - viewer.gap * (inRow - 1)) / inRow
                height: (viewer.height - viewer.gap * (viewer.rows - 1)) / viewer.rows
                x: col * (width + viewer.gap)
                y: row * (height + viewer.gap)
            }
        }
    }

    component AgentStage: Item {
        id: stage

        property var agent: ({})
        readonly property color tint: agent.color || "#C9B8FF"
        readonly property real aw: Math.max(1, agent.width || 1280)
        readonly property real ah: Math.max(1, agent.height || 800)
        // Fill edge to edge when the shapes nearly match (the default 16:10
        // display on a 16:10 panel); letterbox only for a real mismatch.
        readonly property bool stretch: Math.abs((width / Math.max(1, height)) / (aw / ah) - 1) < 0.06
        readonly property real fx: stretch ? width / aw : Math.min(width / aw, height / ah)
        readonly property real fy: stretch ? height / ah : fx

        clip: true

        Item {
            id: screen

            x: (stage.width - stage.aw * stage.fx) / 2
            y: (stage.height - stage.ah * stage.fy) / 2
            width: stage.aw * stage.fx
            height: stage.ah * stage.fy

            LiveImage {
                anchors.fill: parent
                readonly property string frame: root.viewerOpen && stage.agent.live ? stage.agent.live : (stage.agent.preview || "")
                source: frame ? `file://${frame}?${root.liveSeq}-${stage.agent.previewSeq}` : ""
            }

            PathPointer {
                agent: stage.agent
                sx: stage.fx
                sy: stage.fy
                arrowScale: 1.7
                bounds: Qt.size(screen.width, screen.height)
            }
        }

        StateBadge {
            agent: stage.agent
        }

        // Caption floats over the picture instead of reserving a strip.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: capRow.implicitWidth + 20
            height: capRow.implicitHeight + 8
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.45)

            Row {
                id: capRow

                anchors.centerIn: parent
                spacing: 8

                Rectangle { width: 9; height: 9; radius: 4.5; anchors.verticalCenter: parent.verticalCenter; color: stage.tint }
                StyledText {
                    text: `${stage.agent.name || ""} · ${stage.agent.label || stage.agent.kind || ""}${root.viewerOpen && stage.agent.live ? " · live" : ""}`
                    font.pointSize: 9.5
                    color: "white"
                }
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
