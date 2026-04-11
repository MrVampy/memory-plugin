#!/bin/bash
# Filter a single transcript to ~/.memory/raw/sessions/.
#
# The maintain skill's subagent consumes the filtered JSONL from there,
# extracts knowledge into the wiki, then moves the file to
# ~/.memory/processed/sessions/ to mark it done.
#
# Usage:
#   process-file.sh <agent> <id> <source>
#
#   agent   claude-code | codex | opencode
#   id      filename-safe identifier (ends in .jsonl)
#   source  path to source file (claude-code/codex) or session_id (opencode)
#
# On success: prints the path of the staged file on stdout, exits 0.
# On empty filter (no user/assistant content): exits 0 silently with no output.
# On failure: prints an error to stderr, exits non-zero.

set -e

AGENT="$1"
ID="$2"
SOURCE="$3"

if [ -z "$AGENT" ] || [ -z "$ID" ] || [ -z "$SOURCE" ]; then
  echo "Usage: process-file.sh <agent> <id> <source>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
RAW_DIR="$MEMORY_HOME/raw/sessions"
mkdir -p "$RAW_DIR"

OUT="$RAW_DIR/$ID"

case "$AGENT" in
  claude-code)
    python3 "$SCRIPT_DIR/filter-claude-code.py" "$SOURCE" > "$OUT"
    ;;
  codex)
    python3 "$SCRIPT_DIR/filter-codex.py" "$SOURCE" > "$OUT"
    ;;
  opencode)
    python3 "$SCRIPT_DIR/extract-opencode.py" "$SOURCE" > "$OUT"
    ;;
  *)
    echo "Unknown agent: $AGENT" >&2
    exit 1
    ;;
esac

# If the filter produced nothing (empty file), delete it and exit silently.
# Caller should treat this as a no-op but still mark the transcript as
# seen — handled by the workflow in references/workflow.md.
if [ ! -s "$OUT" ]; then
  rm "$OUT"
  exit 0
fi

echo "$OUT"
