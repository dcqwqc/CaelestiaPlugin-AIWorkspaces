#!/usr/bin/env python3
"""Publish AI workspace presentation mode to native QuickShell panels.

Qt panel entry points and the plugin's custom controller run in separate QML
objects. This tiny atomic state file keeps them synchronized without polling
or writing to the regular Caelestia configuration.
"""
import json
import os
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) != 5:
        return 2
    dest = Path(sys.argv[1])
    mode = sys.argv[2]
    enabled = sys.argv[3] == "1"
    pinned = sys.argv[4] == "1"
    if mode not in {"integrated", "floating"} or dest.name != "preview-presentation.json":
        return 2
    dest.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = dest.with_name(f"{dest.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps({"mode": mode, "enabled": enabled, "pinned": pinned}, separators=(",", ":")) + "\n", encoding="utf-8")
    os.replace(tmp, dest)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
