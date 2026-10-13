"""Regression checks for the shell-integrated AI preview default.

These are static contract tests. They do not substitute for an on-device
Quickshell load test or interactive acceptance testing on Mirai.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Main.qml").read_text(encoding="utf-8")
PANEL = (ROOT / "ui/Panel.qml").read_text(encoding="utf-8")
SETTINGS = (ROOT / "Settings.qml").read_text(encoding="utf-8")
MANIFEST = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
PUBLISHER = (ROOT / "scripts/preview_presentation.py").read_text(encoding="utf-8")


class NativePreviewDockTests(unittest.TestCase):
    def test_integrated_is_new_default_even_with_legacy_floating_settings(self):
        self.assertIn('property string agentCursorPresentation: "integrated"', SETTINGS)
        self.assertIn('settings?.agentCursorPresentation ?? "integrated"', MAIN)
        self.assertIn('root.presentation === "floating"', MAIN)

    def test_native_shell_panel_is_registered(self):
        panels = [e for e in MANIFEST["entryPoints"] if e["type"] == "shell-panel"]
        self.assertEqual(len(panels), 1)
        self.assertEqual(panels[0]["source"], "ui/Panel.qml")
        self.assertEqual(panels[0]["properties"]["alignment"], "left")
        self.assertEqual(panels[0]["properties"]["edge"], "top")

    def test_native_panel_does_not_create_separate_overlay_surface(self):
        self.assertIn("readonly property bool panelVisible:", PANEL)
        self.assertIn("readonly property bool hasFullscreen:", PANEL)
        self.assertIn("!hasFullscreen", PANEL)
        self.assertIn("presentation === \"integrated\"", PANEL)
        self.assertNotIn("PanelWindow {", PANEL)
        self.assertNotIn("WlrLayershell.layer", PANEL)

    def test_collapsed_default_and_safe_noninteractive_preview(self):
        self.assertIn("property bool expanded: false", PANEL)
        self.assertIn("panelWidth: expanded ? 270 : 72", PANEL)
        self.assertIn("HoverHandler {", PANEL)
        self.assertIn('root.command("setPreviewMode", "floating")', PANEL)
        self.assertIn("Image.PreserveAspectFit", PANEL)

    def test_visibility_state_syncs_atomically(self):
        self.assertIn("onPresentationChanged: publishPresentation()", MAIN)
        self.assertIn("onPinnedChanged:", MAIN)
        self.assertIn("onAllHiddenChanged:", MAIN)
        self.assertIn("os.replace(tmp, dest)", PUBLISHER)
        self.assertIn("root.previewsEnabled = data.enabled !== false", PANEL)
        self.assertIn("root.pinned = data.pinned !== false", PANEL)

    def test_explicit_floating_hides_for_fullscreen(self):
        self.assertIn("WlrLayershell.layer: WlrLayer.Top", MAIN)
        self.assertIn("&& focusedScreen && !hasFullscreen", MAIN)
        self.assertIn('root.settings.agentCursorPresentation = "integrated"', MAIN)


if __name__ == "__main__":
    unittest.main()
