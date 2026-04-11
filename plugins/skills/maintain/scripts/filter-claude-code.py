#!/usr/bin/env python3
"""Filter a Claude Code transcript to just user/assistant text content.

Usage:
  filter-claude-code.py <path>   # reads the file
  filter-claude-code.py          # reads from stdin

Output: filtered JSONL on stdout. Each line: {"role": "user"|"assistant", "content": [text, ...]}
"""
import json
import sys

FILTER_PREFIXES = (
    "<system-reminder>",
    "<command-",
    "<local-command",
    "<task-notification>",
)


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else None
    stream = open(path, encoding="utf-8") if path else sys.stdin

    try:
        for line in stream:
            line = line.strip()
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
        if path:
            stream.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
