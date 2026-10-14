pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

// Native Caelestia bar popout; positioned by Bar.checkPopout immediately
// to the right of the currently hovered agent dot stack.
Item {
    id: root
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
    property var agents: []
    property string selectedWorkspace: ""
    readonly property var agent: agents.find(a => a.workspace === selectedWorkspace) ?? agents[0] ?? ({})
    readonly property color tint: agent.color || Colours.palette.m3primary
    readonly property int previewWidth: 300
    // Match the generous radius of the shell's native popout surround.
    // The screenshot must be clipped by ONE rounded mask only.
    readonly property int previewHeight: Math.max(120, Math.min(230,
        Math.round(previewWidth * Math.max(1, agent.height || 800) / Math.max(1, agent.width || 1280))))

    implicitWidth: previewWidth
    implicitHeight: previewHeight

    FileView {
        path: root.runtimeDir + "/loom/preview-selection.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.selectedWorkspace = String(JSON.parse(text()).workspace ?? "");
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

    StyledClippingRect {
        id: preview
        anchors.fill: parent
        radius: 24
        color: Colours.palette.m3surfaceContainer

        Item {
            id: frame
            anchors.fill: parent
            readonly property string url: root.agent.preview ?
                "file://" + root.agent.preview + "?" + (root.agent.previewSeq || 0) : ""
            property bool frontA: true
            onUrlChanged: {
                if (frontA)
                    bufferB.source = url;
                else
                    bufferA.source = url;
            }
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

        Rectangle {
            anchors.fill: parent
            radius: preview.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.tint, 0.34)
            z: 3
        }

        Item {
            readonly property real aw: Math.max(1, root.agent.width || 1280)
            readonly property real ah: Math.max(1, root.agent.height || 800)
            readonly property real factor: Math.min(preview.width / aw, preview.height / ah)
            x: (preview.width - aw * factor) / 2 + (root.agent.x || 0) * factor
            y: (preview.height - ah * factor) / 2 + (root.agent.y || 0) * factor
            z: 2

            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Shape {
                width: 12
                height: 17
                ShapePath {
                    fillColor: root.tint
                    strokeColor: Qt.darker(root.tint, 2.1)
                    strokeWidth: 1
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 0 0 L 0 14 L 3.6 10.6 L 6.4 16.4 L 8.6 15.4 L 5.9 9.7 L 10.8 9.7 Z" }
                }
            }
        }
    }
}
