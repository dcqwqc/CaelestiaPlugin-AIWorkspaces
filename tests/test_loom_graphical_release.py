#!/usr/bin/env python3
"""No-screen tests for releasing Loom graphical workspaces when a session ends."""
from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
import socket
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / "scripts/ai-workspace"
loader = importlib.machinery.SourceFileLoader("ai_workspace", str(PATH))
spec = importlib.util.spec_from_loader("ai_workspace", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class ReleaseTests(unittest.TestCase):
    def test_sends_release_owner_for_the_session(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("XDG_RUNTIME_DIR")) as tmp:
            path = os.path.join(tmp, "s.sock")
            srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            srv.bind(path)
            srv.listen(1)
            seen = {}

            def serve():
                conn, _ = srv.accept()
                with conn:
                    data = b""
                    while chunk := conn.recv(4096):
                        data += chunk
                    seen.update(json.loads(data))
                    conn.sendall(json.dumps({"ok": True, "released": ["gws-1"]}).encode())

            t = threading.Thread(target=serve)
            t.start()
            with patch.dict(os.environ, {"LOOM_AGENT_INPUT_SOCKET": path}):
                result = m.release_loom_graphical("claude-ab12")
            t.join(2)
            srv.close()
        self.assertEqual(seen, {"command": "release-owner", "ai_session": "claude-ab12"})
        self.assertEqual(result["released"], ["gws-1"])

    def test_missing_service_never_fails_the_launcher(self):
        with patch.dict(os.environ, {"LOOM_AGENT_INPUT_SOCKET": "/nonexistent/loom.sock"}):
            self.assertEqual(m.release_loom_graphical("claude-ab12"), {"ok": False, "reason": "unavailable"})

    def test_policy_forbids_shared_seat_input(self):
        self.assertIn("loom_gui_", m.POLICY)
        self.assertIn("never inject input into this Hyprland session", m.POLICY)


if __name__ == "__main__":
    unittest.main()


class LaunchQuotingTests(unittest.TestCase):
    def test_non_ascii_arguments_stay_valid_lua(self):
        sent = []
        state = {"id": "s", "workspace": "ai-s", "monitor": "AI-s", "originWorkspace": "1", "originMonitor": "eDP-1"}
        with patch.object(m, "hypr_eval", side_effect=sent.append), patch.object(m, "make_ai_workspace_visible"):
            m.launch_gui(state, ["zenity", "--title", "Tabby Work · ✓"])
        self.assertIn("Tabby Work · ✓", sent[0])  # Lua has no \\uXXXX escapes
        self.assertNotIn("\\u00b7", sent[0])
