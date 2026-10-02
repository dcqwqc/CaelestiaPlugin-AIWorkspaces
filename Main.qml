import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Item {
    id: root
    width: 0
    height: 0
    visible: false

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
}
