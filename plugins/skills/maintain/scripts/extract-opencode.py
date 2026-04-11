#!/usr/bin/env python3
"""Extract an OpenCode session from its SQLite store into filtered JSONL.

Usage:
  extract-opencode.py <session_id>

Output: filtered JSONL on stdout. Each line: {"role": "user"|"assistant", "content": [text, ...]}

OpenCode schema:
  message table: (id, session_id, time_created, time_updated, data)
    data JSON has: role, time, agent, model, ...
  part table:    (id, message_id, session_id, time_created, time_updated, data)
    data JSON has: type, text?, ...
"""
import json
import os
import sqlite3
import sys

FILTER_PREFIXES = (
    "<environment_context>",
    "<system-reminder>",
)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract-opencode.py <session_id>", file=sys.stderr)
        return 1

    session_id = sys.argv[1]
    db_path = os.path.expanduser("~/.local/share/opencode/opencode.db")
    if not os.path.exists(db_path):
        print(f"OpenCode DB not found: {db_path}", file=sys.stderr)
        return 1

    db = sqlite3.connect(db_path)
    try:
        messages = list(
            db.execute(
                "SELECT id, data FROM message WHERE session_id = ? ORDER BY time_created",
                (session_id,),
            )
        )

        for msg_id, msg_data_json in messages:
            try:
                msg_data = json.loads(msg_data_json)
            except json.JSONDecodeError:
                continue

            role = msg_data.get("role")
            if role not in ("user", "assistant"):
                continue

            parts = list(
                db.execute(
                    "SELECT data FROM part WHERE message_id = ? ORDER BY time_created",
                    (msg_id,),
                )
            )

            texts: list[str] = []
            for (part_data_json,) in parts:
                try:
                    part_data = json.loads(part_data_json)
                except json.JSONDecodeError:
                    continue
                if part_data.get("type") != "text":
                    continue
                text = part_data.get("text", "") or ""
                if any(text.startswith(p) for p in FILTER_PREFIXES):
                    continue
                if not text.strip():
                    continue
                texts.append(text)

            if texts:
                print(
                    json.dumps({"role": role, "content": texts}, ensure_ascii=False)
                )
    finally:
        db.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
