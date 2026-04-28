#!/bin/bash
# Find transcripts with new content across all three coding agents.
#
# Outputs one record per line, tab-separated:
#   <agent>\t<id>\t<source>\t<cursor>
#
# where:
#   agent   = claude-code | codex | opencode
#   id      = filename-safe identifier ending in .jsonl
#   source  = path to source file (claude-code/codex) or session_id (opencode)
#   cursor  = previously-processed position (0 for new sessions)
#             - claude-code/codex: line count of source already consumed
#             - opencode: unix-ms time_created of the last message consumed
#
# "Fully processed" is determined by comparing the stored cursor in
# ~/.memory/processed/sessions/<id> against the current size of the source.
# For file-based agents, a session is emitted only when its current line
# count exceeds the stored cursor — meaning there is genuinely new content
# to process. OpenCode sessions are always emitted and the extractor
# decides via the --since cursor whether anything new exists.
#
# The marker file ~/.memory/processed/sessions/<id> contains a single
# integer on its first line (legacy empty markers are treated as cursor=0
# for file-based agents, which triggers a full rescan — safe because
# extraction is idempotent via "extend existing entries" rules).
#
# Uses python3 for the OpenCode SQLite query (stdlib, universal).

set -e

MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
PROCESSED_DIR="$MEMORY_HOME/processed/sessions"
mkdir -p "$PROCESSED_DIR"

read_cursor() {
  local marker="$PROCESSED_DIR/$1"
  if [ -s "$marker" ]; then
    local v
    v=$(head -n1 "$marker" | tr -d '[:space:]')
    # Only accept integer markers; anything else means "legacy/unknown" → 0.
    case "$v" in
      ''|*[!0-9]*) echo 0 ;;
      *)           echo "$v" ;;
    esac
  else
    echo 0
  fi
}

emit_if_new_file() {
  local agent="$1"
  local id="$2"
  local source="$3"
  local cursor
  cursor=$(read_cursor "$id")
  local lines
  lines=$(wc -l < "$source" 2>/dev/null | tr -d ' ')
  [ -z "$lines" ] && lines=0
  if [ "$cursor" -lt "$lines" ]; then
    printf "%s\t%s\t%s\t%s\n" "$agent" "$id" "$source" "$cursor"
  fi
}

emit_opencode() {
  local id="$1"
  local session_id="$2"
  local cursor
  cursor=$(read_cursor "$id")
  printf "%s\t%s\t%s\t%s\n" "opencode" "$id" "$session_id" "$cursor"
}

# --- Claude Code: ~/.claude/projects/<project>/<session-id>.jsonl ---
# Only top-level session transcripts (at the project root). Skip
# ~/.claude/projects/<project>/<session-id>/subagents/*.jsonl because
# the subagent's outputs are already summarized in the parent session.
if [ -d "$HOME/.claude/projects" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    # Skip files inside a subagents/ subdirectory
    case "$path" in
      */subagents/*) continue ;;
    esac
    id="claude-code-$(basename "$path")"
    emit_if_new_file "claude-code" "$id" "$path"
  done < <(find "$HOME/.claude/projects" -name "*.jsonl" -type f 2>/dev/null)
fi

# --- Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl ---
if [ -d "$HOME/.codex/sessions" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    id="codex-$(basename "$path")"
    emit_if_new_file "codex" "$id" "$path"
  done < <(find "$HOME/.codex/sessions" -name "*.jsonl" -type f 2>/dev/null)
fi

# --- OpenCode: query SQLite for session ids ---
OPENCODE_DB="$HOME/.local/share/opencode/opencode.db"
if [ -f "$OPENCODE_DB" ]; then
  python3 - "$OPENCODE_DB" <<'PY' | while IFS= read -r session_id; do
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
try:
    for (sid,) in db.execute("SELECT DISTINCT session_id FROM message ORDER BY time_created"):
        print(sid)
finally:
    db.close()
PY
    [ -z "$session_id" ] && continue
    id="opencode-${session_id}.jsonl"
    emit_opencode "$id" "$session_id"
  done
fi
