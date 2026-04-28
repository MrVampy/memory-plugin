#!/usr/bin/env python3
"""Filter a Codex transcript to just user/assistant text content.

Usage:
  filter-codex.py <path> [--skip N]
  filter-codex.py [--skip N]          # reads from stdin

Codex JSONL shape: {timestamp, type, payload}
  type="response_item" with payload.type="message" → a message we care about
  payload.role = user|assistant|developer (skip developer)
  payload.content = list of blocks with type=input_text|output_text|reasoning (skip reasoning)

Output: filtered JSONL on stdout. Each line: {"role": "user"|"assistant", "content": [text, ...]}

--skip N skips the first N raw lines of the source before filtering. Used
by the maintenance pipeline to avoid reprocessing already-seen turns.
"""
import argparse
import json
import sys

FILTER_PREFIXES = (
    "<environment_context>",
    "<permissions instructions>",
    "<system-reminder>",
    "<command-",
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

            if msg.get("type") != "response_item":
                continue
            payload = msg.get("payload") or {}
            if payload.get("type") != "message":
                continue

            role = payload.get("role")
            if role not in ("user", "assistant"):
                continue

            content = payload.get("content", [])
            if not isinstance(content, list):
                continue

            texts: list[str] = []
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") not in ("input_text", "output_text"):
                    continue
                text = block.get("text", "") or ""
                if any(text.startswith(p) for p in FILTER_PREFIXES):
                    continue
                if text.strip():
                    texts.append(text)

            if texts:
                print(json.dumps({"role": role, "content": texts}, ensure_ascii=False))
    finally:
        if args.path:
            stream.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
