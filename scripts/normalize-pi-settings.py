#!/usr/bin/env python3
"""Git clean filter: drop pi's own runtime state from its settings file.

pi writes `lastChangelogVersion` into ~/.pi/agent/settings.json, which is a
symlink into this repo. Removing it here keeps that write out of every diff
while deliberate preference edits stay visible.
"""

from __future__ import annotations

import json
import sys


def main() -> None:
    raw = sys.stdin.read()
    try:
        settings = json.loads(raw)
    except json.JSONDecodeError:
        # Never hide a malformed file, and never make a partially written one
        # look clean while the application is still writing it.
        sys.stdout.write(raw)
        return

    if not isinstance(settings, dict):
        sys.stdout.write(raw)
        return

    settings.pop("lastChangelogVersion", None)
    json.dump(settings, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
