"""Stable regressions for the live workspace mini-card's QML contract."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Main.qml").read_text()
SETTINGS = (ROOT / "Settings.qml").read_text()


class PreviewCardTests(unittest.TestCase):
    def test_pin_survives_agent_cursor_idle(self):
        self.assertIn("property bool agentCursorPinned: true", SETTINGS)
        self.assertIn("(a.active || root.pinned) && !a.hidden", MAIN)
        self.assertIn("onPinnedChanged:", MAIN)

    def test_still_respects_explicit_hide(self):
        self.assertIn("!a.hidden && !root.allHidden", MAIN)

    def test_floating_and_top_left_dock_position_persist(self):
        for name in ["agentCursorDocked", "agentCursorFloatingX", "agentCursorFloatingY"]:
            self.assertIn("property ", SETTINGS)
            self.assertIn(name, SETTINGS)
        self.assertIn("root.docked ? 16", MAIN)
        self.assertIn("root.docked ? 60", MAIN)
        self.assertIn("onDragRequested:", MAIN)
        self.assertIn("signal dragRequested(real dx, real dy)", MAIN)

    def test_pointer_uses_same_scaled_content_origin(self):
        self.assertIn("sx: screenArea.width / Math.max(1, tile.agent.width || 1)", MAIN)
        self.assertIn("sy: screenArea.height / Math.max(1, tile.agent.height || 1)", MAIN)
        self.assertIn("showTag: false", MAIN)

    def test_title_is_elided_and_has_no_old_bottom_strip(self):
        self.assertIn("text: tile.agent.name ||", MAIN)
        self.assertIn("elide: Text.ElideRight", MAIN)
        self.assertIn("MaterialIcon", MAIN)
        self.assertNotIn("mask: Region {}", MAIN)

    def test_ipc_controls_present(self):
        for name in ("previewState", "pinPreviews", "unpinPreviews", "dockTopLeft", "undock", "resetPreviewPosition"):
            self.assertIn("function " + name + "(", MAIN)


if __name__ == "__main__":
    unittest.main()
