#!/usr/bin/env python3
"""Normalize application-owned runtime state for Git's clean filters."""

from __future__ import annotations

import json
import sys


def normalize_pi_settings() -> None:
    raw = sys.stdin.read()
    try:
        settings = json.loads(raw)
    except json.JSONDecodeError:
        # Do not hide a malformed file or make an application's atomic write
        # look clean while it is incomplete.
        sys.stdout.write(raw)
        return

    if not isinstance(settings, dict):
        sys.stdout.write(raw)
        return

    settings.pop("lastChangelogVersion", None)
    json.dump(settings, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def normalize_fcitx_profile() -> None:
    raw = sys.stdin.buffer.read()
    if raw:
        raw = raw.rstrip(b"\n") + b"\n"
    sys.stdout.buffer.write(raw)


def main() -> None:
    try:
        mode = sys.argv[1]
    except IndexError:
        raise SystemExit("usage: normalize-runtime-config.py <pi-settings|fcitx-profile>")

    if mode == "pi-settings":
        normalize_pi_settings()
    elif mode == "fcitx-profile":
        normalize_fcitx_profile()
    else:
        raise SystemExit(f"unknown normalization mode: {mode}")


if __name__ == "__main__":
    main()
