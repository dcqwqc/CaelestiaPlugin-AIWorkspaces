#!/usr/bin/env python3
"""Open the selected agent via the existing special workspace on dot click only."""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

SERVICE = Path.home() / ".local/share/caelestia/plugins/loom/loom_agent_input.py"
SPECIAL = "special:loom-agents"

def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=8)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout

def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"gws-[0-9a-f]{12,24}", sys.argv[1]):
        return 2
    try:
        records = json.loads(run("/usr/bin/python3", str(SERVICE), "ctl", "list"))
        ws = next((w for w in records.get("workspaces", [])
                   if w.get("id") == sys.argv[1] and w.get("state") in {"ready", "paused"}), None)
        if not ws:
            return 3
        monitors = json.loads(run("hyprctl", "-j", "monitors"))
        physical = [m for m in monitors if not str(m.get("name", "")).startswith(("AI-", "QSW-"))]
        if not any((m.get("specialWorkspace") or {}).get("name") == SPECIAL for m in physical):
            run("hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("loom-agents")')
            time.sleep(0.15)
        if ws.get("backend") == "nested" and ws.get("nested_pid"):
            clients = json.loads(run("hyprctl", "-j", "clients"))
            client = next((c for c in clients if int(c.get("pid") or 0) == int(ws["nested_pid"])
                           and (c.get("workspace") or {}).get("name") == SPECIAL), None)
            if client:
                address = str(client["address"])
                if re.fullmatch(r"0x[0-9a-fA-F]+", address):
                    run("hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + address + '" })')
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as err:
        print("AI workspace could not be opened: " + str(err), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
