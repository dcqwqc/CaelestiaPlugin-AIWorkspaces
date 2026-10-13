#!/usr/bin/env python3
"""Idempotently place the AI color-dot entry after Caelestia workspaces.

Only modifies bar.entries; other user config is retained. Not run by default
while the shell is active; explicit install/deploy step only.
"""
import json
import os
import sys
import tempfile
from pathlib import Path


def install(path: Path) -> bool:
    doc = json.loads(path.read_text(encoding="utf-8"))
    entries = doc.setdefault("bar", {}).setdefault("entries", [])
    if not isinstance(entries, list):
        raise ValueError("bar.entries is not an array")
    if not any(isinstance(e, dict) and e.get("id") == "workspaces" for e in entries):
        raise ValueError("cannot find workspaces entry; refusing to guess position")
    current = [e for e in entries if isinstance(e, dict) and e.get("id") == "aiAgentDots"]
    all_without = [e for e in entries if not (isinstance(e, dict) and e.get("id") == "aiAgentDots")]
    idx = next(i for i, e in enumerate(all_without) if e.get("id") == "workspaces")
    all_without.insert(idx + 1, {"enabled": True, "id": "aiAgentDots"})
    if entries == all_without:
        return False
    doc["bar"]["entries"] = all_without
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     prefix=".ai-bar-", delete=False) as f:
        json.dump(doc, f, indent=4, ensure_ascii=False)
        f.write("\n")
        staged = Path(f.name)
    os.chmod(staged, path.stat().st_mode & 0o777)
    os.replace(staged, path)
    return True


if __name__ == "__main__":
    dest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".config/caelestia/shell.json"
    try:
        print("installed" if install(dest) else "already configured")
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Could not configure bar entry: {exc}", file=sys.stderr)
        raise SystemExit(1)
