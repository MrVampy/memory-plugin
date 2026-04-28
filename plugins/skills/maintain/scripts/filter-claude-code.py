#!/usr/bin/env python3
"""Filter a Claude Code transcript to just user/assistant text content.

Usage:
  filter-claude-code.py <path> [--skip N]
  filter-claude-code.py [--skip N]          # reads from stdin

Output: filtered JSONL on stdout. Each line: {"role": "user"|"assistant", "content": [text, ...]}

--skip N skips the first N raw lines of the source before filtering. Used
by the maintenance pipeline to avoid reprocessing already-seen turns in an
append-only transcript. The skip is counted against raw input lines (not
filtered output lines), so it aligns with the line-count cursor stored in
~/.memory/processed/sessions/<id>.
"""
import argparse
import json
import sys

FILTER_PREFIXES = (
    "<system-reminder>",
    "<command-",
    "<local-command",
    "<task-notification>",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", nargs="?")
    parser.add_argument("--skip", type=int, default=0)
    args = parser.parse_args()

    stream = open(args.path, encoding="utf-8") if args.path else sys.stdin

    try:
        for i, raw_line in enumerate(stream):
            if i < args.skip:
                continue
            line = raw_line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type", "")
            if msg_type not in ("user", "assistant"):
                continue

            inner = msg.get("message") or {}
            role = inner.get("role", msg_type)
            content = inner.get("content", "")

            texts: list[str] = []
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") != "text":
                        continue
                    text = block.get("text", "") or ""
                    if any(text.startswith(p) for p in FILTER_PREFIXES):
                        continue
                    if text.strip():
                        texts.append(text)
            elif isinstance(content, str) and content.strip():
                if not any(content.startswith(p) for p in FILTER_PREFIXES):
                    texts.append(content)

            if texts:
                print(json.dumps({"role": role, "content": texts}, ensure_ascii=False))
    finally:
        if args.path:
            stream.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
