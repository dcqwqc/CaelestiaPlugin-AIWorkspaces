#!/usr/bin/env python3
"""No-screen regression tests for Loom lifecycle hooks."""
from __future__ import annotations
import importlib.util,unittest
from pathlib import Path
from unittest.mock import patch
PATH=Path(__file__).resolve().parents[1]/"scripts/loom_task_visibility.py"
spec=importlib.util.spec_from_file_location("loom_task_visibility",PATH)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Tests(unittest.TestCase):
    def test_reuse_existing(self):
        with patch.object(m,"call",return_value={"ok":True,"tasks":[{"id":"old"}]}) as req:
            result=m.start("Claude","claude-ab123","old")
            self.assertEqual(result["task_id"],"old")
            self.assertTrue(result["reused"])
            self.assertEqual(req.call_count,1)
    def test_create_new(self):
        def fake(name, args):
            if name=="loom_task_create":
                self.assertEqual(args["status"],"working")
                self.assertNotIn("progress",args)
                return {"ok":True,"task":{"id":"new"}}
            return {"ok":True,"tasks":[]}
        with patch.object(m,"call",side_effect=fake):
            result=m.start("codex","codex-ab123","missing")
            self.assertEqual(result["task_id"],"new")
            self.assertFalse(result["reused"])
    def test_never_overwrite_verified_done(self):
        with patch.object(m,"call",return_value={"ok":True,"tasks":[{"id":"x","status":"done"}]}) as req:
            result=m.finish("x",0)
            self.assertEqual(result["preserved_status"],"done")
            self.assertEqual(req.call_count,1)
    def test_success_means_waiting_not_done(self):
        def fake(name,args):
            if name=="loom_task_list":
                return {"ok":True,"tasks":[{"id":"x","status":"working","summary":"Tests running"}]}
            self.assertEqual(name,"loom_task_update")
            self.assertEqual(args["status"],"waiting")
            self.assertIn("Tests running",args["summary"])
            return {"ok":True}
        with patch.object(m,"call",side_effect=fake):
            self.assertEqual(m.finish("x",0)["status"],"waiting")
    def test_failure_blocked(self):
        def fake(name,args):
            if name=="loom_task_list":
                return {"ok":True,"tasks":[{"id":"x","status":"working"}]}
            self.assertEqual(args["status"],"blocked")
            return {"ok":True}
        with patch.object(m,"call",side_effect=fake):
            self.assertEqual(m.finish("x",17)["status"],"blocked")
    def test_lost_overlay_is_nonfatal(self):
        with patch.object(m,"call",return_value={"ok":False,"error":"offline"}):
            self.assertFalse(m.start("agy","s",None)["ok"])
            self.assertFalse(m.finish("missing",0)["ok"])
if __name__=="__main__":unittest.main(verbosity=2)
