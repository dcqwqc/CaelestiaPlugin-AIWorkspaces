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

    def test_collapsed_state_is_only_one_solid_dot_per_agent(self):
        self.assertIn("Repeater {", DOTS)
        self.assertIn("model: root.visibleAgents", DOTS)
        self.assertIn("color: modelData.color", DOTS)
        self.assertIn("radius: width / 2", DOTS)
        self.assertIn("property bool pinned: true", DOTS)
        self.assertNotIn("smart_toy", DOTS)
        self.assertNotIn("Text {", DOTS)
        self.assertNotIn("StyledText", DOTS)
        self.assertNotIn("PanelWindow", DOTS)

    def test_hover_selects_workspace_but_click_only_opens_special(self):
        self.assertIn("root.choose(dot.modelData);", DOTS)
        self.assertIn("onHoveredChanged: if (hovered)", DOTS)
        self.assertIn("onTapped:", DOTS)
        self.assertIn("root.agentOpener", DOTS)
        self.assertNotIn("root.agentOpener", DOTS.split("TapHandler")[0])
        self.assertIn('SPECIAL = "special:loom-agents"', OPENER)
        self.assertIn("nested_pid", OPENER)
        self.assertIn("hl.dsp.focus", OPENER)

    def test_preview_is_native_to_existing_shell_popout(self):
        self.assertIn("StyledClippingRect", PREVIEW)
        self.assertIn("Image.PreserveAspectFit", PREVIEW)
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
        self.assertIn("root.hoveredDotIndex = dot.index", DOTS)
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
