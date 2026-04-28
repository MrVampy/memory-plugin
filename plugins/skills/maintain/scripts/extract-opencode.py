#!/usr/bin/env python3
"""Extract an OpenCode session from its SQLite store into filtered JSONL.

Usage:
  extract-opencode.py <session_id> [--since TIMESTAMP] [--cursor-out PATH]

Output: filtered JSONL on stdout. Each line: {"role": "user"|"assistant", "content": [text, ...]}

--since TIMESTAMP    only extract messages with time_created > TIMESTAMP
                     (the unix-ms stored in the message table). Default: 0.
--cursor-out PATH    after extraction, write the max time_created seen
                     (as a single integer) to PATH. If no new messages
                     matched, writes the --since value unchanged so the
                     cursor is still committable.

OpenCode schema:
  message table: (id, session_id, time_created, time_updated, data)
    data JSON has: role, time, agent, model, ...
  part table:    (id, message_id, session_id, time_created, time_updated, data)
    data JSON has: type, text?, ...
"""
import argparse
import json
import os
import sqlite3
import sys

FILTER_PREFIXES = (
    "<environment_context>",
    "<system-reminder>",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("session_id")
    parser.add_argument("--since", type=int, default=0)
    parser.add_argument("--cursor-out", dest="cursor_out", default=None)
    args = parser.parse_args()

    db_path = os.path.expanduser("~/.local/share/opencode/opencode.db")
    if not os.path.exists(db_path):
        print(f"OpenCode DB not found: {db_path}", file=sys.stderr)
        return 1

    max_seen = args.since

    db = sqlite3.connect(db_path)
    try:
        messages = list(
            db.execute(
                "SELECT id, time_created, data FROM message "
                "WHERE session_id = ? AND time_created > ? ORDER BY time_created",
                (args.session_id, args.since),
            )
        )

        for msg_id, time_created, msg_data_json in messages:
            if time_created > max_seen:
                max_seen = time_created
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

    if args.cursor_out:
        with open(args.cursor_out, "w") as f:
            f.write(f"{max_seen}\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
