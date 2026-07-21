#!/usr/bin/env python3
"""Merge waybar-module.jsonc snippet(s) into ~/.config/waybar/UserModules."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments so json.loads accepts JSONC."""
    out: list[str] = []
    i = 0
    in_string = False
    escape = False
    while i < len(text):
        ch = text[i]
        if in_string:
            out.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt == "/":
                i += 2
                while i < len(text) and text[i] not in "\n\r":
                    i += 1
                continue
            if nxt == "*":
                i += 2
                while i + 1 < len(text) and not (text[i] == "*" and text[i + 1] == "/"):
                    i += 1
                i = min(i + 2, len(text))
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def load_object(path: Path) -> dict:
    raw = path.read_text(encoding="utf-8").strip()
    if not raw:
        return {}
    if not raw.startswith("{"):
        raw = "{\n" + raw.rstrip(",\n") + "\n}"
    cleaned = strip_jsonc(raw)
    cleaned = re.sub(r",\s*}", "}", cleaned)
    cleaned = re.sub(r",\s*]", "]", cleaned)
    data = json.loads(cleaned)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected top-level object")
    return data


def dump_user_modules(data: dict) -> str:
    body = json.dumps(data, indent=4, ensure_ascii=False)
    # Match JaKooLit / HyprFlux style: opening brace on its own line.
    return "{\n" + body[1:-1].strip() + "\n}\n"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: merge-waybar-user-modules.py <snippet.jsonc> [more...]", file=sys.stderr)
        return 2

    dest = Path.home() / ".config/waybar/UserModules"
    dest.parent.mkdir(parents=True, exist_ok=True)

    merged: dict = {}
    if dest.exists():
        try:
            merged = load_object(dest)
        except (json.JSONDecodeError, ValueError) as exc:
            print(f"warn: could not parse existing UserModules: {exc}", file=sys.stderr)
            merged = {}

    for arg in sys.argv[1:]:
        snippet = Path(arg)
        if not snippet.is_file():
            print(f"error: missing snippet: {snippet}", file=sys.stderr)
            return 1
        try:
            chunk = load_object(snippet)
        except (json.JSONDecodeError, ValueError) as exc:
            print(f"error: {snippet}: {exc}", file=sys.stderr)
            return 1
        merged.update(chunk)

    dest.write_text(dump_user_modules(merged), encoding="utf-8")
    print(f"merged {len(merged)} module key(s) -> {dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
