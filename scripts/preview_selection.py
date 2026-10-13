#!/usr/bin/env python3
"""Atomically publish which agent dot is hovered to the native bar popout."""
import json
import os
import sys
from pathlib import Path

def main():
    if len(sys.argv) != 3:
        return 2
    target = Path(sys.argv[1])
    workspace = sys.argv[2]
    if target.name != "preview-selection.json" or not workspace.startswith("gws-"):
        return 2
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = target.with_name(target.name + "." + str(os.getpid()) + ".tmp")
    temp.write_text(json.dumps({"workspace": workspace}, separators=(",", ":")) + "\n")
    os.replace(temp, target)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
