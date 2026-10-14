"""Regressions for the agent-color dots in Caelestia's vertical bar.

The native bar/popout contracts are checked statically; live hover/focus
behavior additionally requires an interactive Mirai compositor test.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Main.qml").read_text()
DOTS = (ROOT / "bar/AgentDots.qml").read_text()
PREVIEW = (ROOT / "bar/AgentPreview.qml").read_text()
SETTINGS = (ROOT / "Settings.qml").read_text()
MANIFEST = json.loads((ROOT / "manifest.json").read_text())
PUBLISHER = (ROOT / "scripts/preview_presentation.py").read_text()
OPENER = (ROOT / "scripts/open_agent_workspace.py").read_text()
SELECTOR = ROOT / "scripts/preview_selection.py"


class AgentBarTests(unittest.TestCase):
    def test_new_default_keeps_explicit_legacy_floating_option(self):
        self.assertIn('property string agentCursorPresentation: "integrated"', SETTINGS)
        self.assertIn('settings?.agentCursorPresentation ?? "integrated"', MAIN)
        self.assertIn('root.presentation === "floating"', MAIN)

    def test_native_bar_entry_and_matching_popout(self):
        entries = MANIFEST["entryPoints"]
        self.assertFalse(any(e["type"] == "shell-panel" for e in entries))
        bars = [e for e in entries if e["type"] == "bar-entry"]
        popouts = [e for e in entries if e["type"] == "bar-popout"]
        self.assertEqual(len(bars), 1)
        self.assertEqual(len(popouts), 1)
        self.assertEqual(bars[0]["properties"]["name"], "aiAgentDots")
        self.assertEqual(popouts[0]["properties"]["entry"], "aiAgentDots")
        self.assertEqual(bars[0]["source"], "bar/AgentDots.qml")
        self.assertEqual(popouts[0]["source"], "bar/AgentPreview.qml")

    def test_indicator_always_contains_pacman_and_all_app_icons(self):
        self.assertIn("model: root.visibleAgents", DOTS)
        self.assertIn("agentTint: modelData.color", DOTS)
        self.assertIn("color: agentItem.agentTint", DOTS)
        self.assertIn("radius: Tokens.rounding.full", DOTS)
        self.assertIn("readonly property int dotSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small", DOTS)
        self.assertIn("implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small", DOTS)
        self.assertIn("implicitHeight: workspaceStack.implicitHeight +", DOTS)
        self.assertIn("agentItem.windows.length > 0 && Config.bar.workspaces.showWindows ? Tokens.padding.extraSmall : 0", DOTS)
        self.assertIn("StyledRect {", DOTS)
        self.assertIn("clip: true", DOTS)
        self.assertIn("id: agentPill", DOTS)
        self.assertIn("color: agentItem.agentTint", DOTS)
        self.assertIn("Layout.topMargin: -Tokens.sizes.bar.innerWidth / 10", DOTS)
        self.assertNotIn("id: pacmanDot", DOTS)
        self.assertNotIn("border.width:", DOTS)
        self.assertNotIn("border.color:", DOTS)
        self.assertNotIn("Canvas {", DOTS)
        self.assertIn("StyledText {", DOTS)
        self.assertIn('text: Config.bar.workspaces.activeLabel || Config.bar.workspaces.occupiedLabel || "󰮯"', DOTS)
        self.assertIn("font.family: Tokens.font.workspaces", DOTS)
        self.assertIn("color: Colours.palette.m3onPrimary", DOTS)
        self.assertIn("verticalAlignment: Qt.AlignVCenter", DOTS)
        self.assertIn("Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small", DOTS)
        self.assertIn("active: agentItem.windows.length > 0 && Config.bar.workspaces.showWindows", DOTS)
        self.assertNotIn('visible: dot.iconName === "desktop"', DOTS)
        self.assertIn("JSON.parse(JSON.stringify(modelData.windows ?? []))", DOTS)
        self.assertIn("const list = Array.isArray(decoded) ? decoded : []", DOTS)
        self.assertIn("Config.bar.workspaces.maxWindowIcons", DOTS)
        self.assertIn("model: agentItem.windows", DOTS)
        self.assertIn("MaterialIcon {", DOTS)
        self.assertIn("grade: 0", DOTS)
        self.assertIn("text: root.appIcon(modelData)", DOTS)
        self.assertNotIn("font.pointSize:", DOTS)
        self.assertNotIn("smart_toy", DOTS)
        self.assertNotIn("PanelWindow", DOTS)

    def test_hover_selects_workspace_but_click_only_opens_special(self):
        self.assertIn("root.choose(agentItem.modelData);", DOTS)
        self.assertIn("onHoveredChanged: if (hovered)", DOTS)
        self.assertIn("onTapped:", DOTS)
        self.assertIn("root.agentOpener", DOTS)
        self.assertNotIn("root.agentOpener", DOTS.split("TapHandler")[0])
        self.assertIn('SPECIAL = "special:loom-agents"', OPENER)
        self.assertIn("nested_pid", OPENER)
        self.assertIn("hl.dsp.focus", OPENER)

    def test_preview_is_native_to_existing_shell_popout(self):
        self.assertIn("StyledClippingRect", PREVIEW)
        self.assertIn("radius: 30", PREVIEW)
        self.assertIn("overscan: 5", PREVIEW)
        self.assertIn("radius: preview.radius", PREVIEW)
        self.assertEqual(PREVIEW.count("clip: true"), 0)
        self.assertIn("Image.PreserveAspectCrop", PREVIEW)
        self.assertIn("anchors.margins: -frame.overscan", PREVIEW)
        self.assertIn("root.selectedWorkspace", PREVIEW)
        self.assertIn("agents.find(a => a.workspace === selectedWorkspace)", PREVIEW)
        self.assertIn("preview-selection.json", PREVIEW)
        self.assertNotIn("PanelWindow", PREVIEW)
        self.assertNotIn("WlrLayershell", PREVIEW)

    def test_preview_settings_stay_in_sync(self):
        self.assertIn("onPresentationChanged: publishPresentation()", MAIN)
        self.assertIn("onPinnedChanged:", MAIN)
        self.assertIn("os.replace(tmp, dest)", PUBLISHER)
        self.assertIn("root.mode = v.mode", DOTS)

    def test_preview_aligns_to_hovered_agent_dot(self):
        self.assertIn("property int hoveredDotIndex: 0", DOTS)
        self.assertIn("readonly property real popoutAnchorY:", DOTS)
        self.assertIn("root.hoveredDotIndex = agentItem.index", DOTS)
        self.assertIn("root.hoveredDotCenterY = agentItem.mapToItem", DOTS)
        patch = (ROOT / "patches/bar-agent-popout-anchor.patch").read_text()
        self.assertIn("popoutAnchorY", patch)
        self.assertIn("plugin bar entry", patch.lower())

    def test_idempotent_bar_entry_installer(self):
        from scripts.install_bar_entry import install
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "shell.json"
            path.write_text(json.dumps({"bar": {"entries": [
                {"id": "logo", "enabled": True},
                {"id": "workspaces", "enabled": True},
                {"id": "spacer", "enabled": True},
                {"id": "activeWindow", "enabled": True}]},
                "other": {"keep": "untouched"}}))
            self.assertTrue(install(path))
            self.assertFalse(install(path))
            data = json.loads(path.read_text())
            self.assertEqual([e["id"] for e in data["bar"]["entries"]],
                             ["logo", "workspaces", "aiAgentDots", "spacer", "activeWindow"])
            self.assertEqual(data["other"], {"keep": "untouched"})

    def test_selection_is_atomic_and_validated(self):
        with tempfile.TemporaryDirectory() as d:
            selection = Path(d) / "preview-selection.json"
            for ws in ("gws-0123456789ab", "gws-fedcba987654"):
                cp = subprocess.run([sys.executable, str(SELECTOR), str(selection), ws],
                                    capture_output=True, text=True)
                self.assertEqual(cp.returncode, 0, cp.stderr)
                self.assertEqual(json.loads(selection.read_text())["workspace"], ws)
            cp = subprocess.run([sys.executable, str(SELECTOR), str(selection), "invalid"],
                                capture_output=True, text=True)
            self.assertEqual(cp.returncode, 2)
            self.assertEqual(json.loads(selection.read_text())["workspace"], "gws-fedcba987654")

    def test_bad_click_argument_must_fail_closed(self):
        cp = subprocess.run([sys.executable, str(ROOT / "scripts/open_agent_workspace.py"),
                             "invalid-agent-id"], capture_output=True, text=True)
        self.assertEqual(cp.returncode, 2)

    def test_floating_preview_remains_opt_in_and_fullscreen_safe(self):
        self.assertIn("WlrLayershell.layer: WlrLayer.Top", MAIN)
        self.assertIn("&& focusedScreen && !hasFullscreen", MAIN)
        self.assertIn('root.settings.agentCursorPresentation = "integrated"', MAIN)


if __name__ == "__main__":
    unittest.main()
