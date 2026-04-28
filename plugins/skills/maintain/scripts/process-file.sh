#!/bin/bash
# Filter the new portion of a single transcript to ~/.memory/raw/sessions/
# and stage a cursor sidecar for commit during Phase 3.
#
# Usage:
#   process-file.sh <agent> <id> <source> [cursor]
#
#   agent   claude-code | codex | opencode
#   id      filename-safe identifier (ends in .jsonl)
#   source  path to source file (claude-code/codex) or session_id (opencode)
#   cursor  previously-processed cursor (default 0)
#             - claude-code/codex: line count of source already consumed
#             - opencode: unix-ms time_created of the last message consumed
#
# Writes up to two files in ~/.memory/raw/sessions/:
#   <id>         — filtered JSONL of the diff (only if the diff was non-empty)
#   <id>.cursor  — NEW cursor value (plain integer). ALWAYS written, even
#                  when the content diff is empty, so Phase 3 can commit
#                  the advance to processed/sessions/<id> and the next
#                  tick won't re-read the same lines.
#
# On success: prints the path of the staged content file on stdout (or
# exits 0 silently with no stdout if the diff had no user/assistant
# content). The cursor sidecar is always present on success.
# On failure: prints an error to stderr, exits non-zero.

set -e

AGENT="$1"
ID="$2"
SOURCE="$3"
CURSOR="${4:-0}"

if [ -z "$AGENT" ] || [ -z "$ID" ] || [ -z "$SOURCE" ]; then
  echo "Usage: process-file.sh <agent> <id> <source> [cursor]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
RAW_DIR="$MEMORY_HOME/raw/sessions"
mkdir -p "$RAW_DIR"

OUT="$RAW_DIR/$ID"
CURSOR_OUT="$RAW_DIR/$ID.cursor"

case "$AGENT" in
  claude-code)
    python3 "$SCRIPT_DIR/filter-claude-code.py" --skip "$CURSOR" "$SOURCE" > "$OUT"
    NEW_CURSOR=$(wc -l < "$SOURCE" | tr -d ' ')
    ;;
  codex)
    python3 "$SCRIPT_DIR/filter-codex.py" --skip "$CURSOR" "$SOURCE" > "$OUT"
    NEW_CURSOR=$(wc -l < "$SOURCE" | tr -d ' ')
    ;;
  opencode)
    CURSOR_TMP=$(mktemp)
    python3 "$SCRIPT_DIR/extract-opencode.py" --since "$CURSOR" --cursor-out "$CURSOR_TMP" "$SOURCE" > "$OUT"
    NEW_CURSOR=$(cat "$CURSOR_TMP" | tr -d '[:space:]')
    rm -f "$CURSOR_TMP"
    ;;
  *)
    echo "Unknown agent: $AGENT" >&2
    exit 1
    ;;
esac

# Always write the cursor sidecar, even if the content diff is empty.
# Phase 3 reads this and commits it to processed/sessions/<id>.
printf "%s\n" "${NEW_CURSOR:-$CURSOR}" > "$CURSOR_OUT"

# If the filter produced no new user/assistant content, drop the empty
# content file but keep the cursor sidecar so Phase 3 can still advance
# the marker.
if [ ! -s "$OUT" ]; then
  rm "$OUT"
  exit 0
fi

echo "$OUT"
