import Caelestia.Plugins

SettingsObject {
    property string defaultMode: "isolated"
    SettingMeta on defaultMode {
        label: "Default AI desktop mode"
        description: "Isolated gives each AI its own hidden monitor/workspace. Current leaves the AI on your normal desktop."
        icon: "desktop_windows"
        inputType: SettingMeta.SplitButton
        options: ["isolated", "current"]
    }

    property string resolution: "1920x1080"
    SettingMeta on resolution {
        label: "Virtual desktop resolution"
        description: "Resolution used for each dynamically-created AI monitor."
        icon: "aspect_ratio"
        inputType: SettingMeta.SplitButton
        options: ["1280x720", "1600x900", "1920x1080", "2560x1440"]
    }

    property int maxSessions: 32
    SettingMeta on maxSessions {
        label: "Maximum isolated sessions"
        description: "Prevents a broken launcher from creating unlimited virtual monitors."
        icon: "group_work"
        inputType: SettingMeta.SpinBox
        min: 1
        max: 128
        step: 1
    }

    property bool cleanupOnExit: true
    SettingMeta on cleanupOnExit {
        label: "Clean up when an AI exits"
        description: "Close that AI's GUI windows and remove its virtual monitor when the agent process ends."
        icon: "delete_sweep"
        inputType: SettingMeta.Switch
    }

    property int cleanupGraceSeconds: 2
    SettingMeta on cleanupGraceSeconds {
        label: "Cleanup grace period"
        description: "Seconds AI GUI apps get to close normally before their window processes are terminated."
        icon: "timer"
        inputType: SettingMeta.SpinBox
        min: 0
        max: 15
        step: 1
    }

    property bool autoWrapCodex: true
    SettingMeta on autoWrapCodex {
        label: "Automatically isolate Codex"
        description: "Interactive Codex sessions started from Fish get a private AI desktop."
        icon: "terminal"
        inputType: SettingMeta.Switch
    }

    property bool autoWrapClaude: true
    SettingMeta on autoWrapClaude {
        label: "Automatically isolate Claude"
        description: "Interactive Claude Code sessions started from Fish get a private AI desktop."
        icon: "terminal"
        inputType: SettingMeta.Switch
    }

    property bool autoWrapAgy: true
    SettingMeta on autoWrapAgy {
        label: "Automatically isolate Agy"
        description: "Interactive Antigravity/Agy sessions started from Fish get a private AI desktop."
        icon: "terminal"
        inputType: SettingMeta.Switch
    }

    property bool notify: false
    SettingMeta on notify {
        label: "Session notifications"
        description: "Show a notification when an isolated AI desktop is created or removed."
        icon: "notifications"
        inputType: SettingMeta.Switch
    }

    property bool agentCursors: true
    SettingMeta on agentCursors {
        label: "Show AI agent cursors"
        description: "Small click-through previews of each active agent's private display with its pointer. Hidden while agents are idle."
        icon: "arrow_selector_tool"
        inputType: SettingMeta.Switch
    }

    property bool agentCursorLabels: true
    SettingMeta on agentCursorLabels {
        label: "Agent name labels"
        description: "Show a compact name tag next to each agent pointer."
        icon: "label"
        inputType: SettingMeta.Switch
    }

    property int agentCursorOpacity: 90
    SettingMeta on agentCursorOpacity {
        label: "Agent cursor opacity"
        description: "Opacity of the agent previews and pointers, in percent."
        icon: "opacity"
        inputType: SettingMeta.SpinBox
        min: 30
        max: 100
        step: 5
    }

    property string agentCursorAnimation: "full"
    SettingMeta on agentCursorAnimation {
        label: "Agent cursor animation"
        description: "Pointer motion and click feedback intensity."
        icon: "animation"
        inputType: SettingMeta.SplitButton
        options: ["full", "subtle", "off"]
    }

    property int agentCursorTileWidth: 240
    SettingMeta on agentCursorTileWidth {
        label: "Agent preview width"
        description: "Width of each agent preview in logical pixels."
        icon: "width"
        inputType: SettingMeta.SpinBox
        min: 160
        max: 400
        step: 20
    }

    property string agentCursorPosition: "bottom-right"
    SettingMeta on agentCursorPosition {
        label: "Agent preview corner"
        description: "Screen corner for the agent previews on the focused monitor."
        icon: "picture_in_picture"
        inputType: SettingMeta.SplitButton
        options: ["bottom-right", "top-right", "bottom-left", "top-left"]
    }
}
