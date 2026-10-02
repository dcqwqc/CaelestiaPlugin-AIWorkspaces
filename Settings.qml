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
}
