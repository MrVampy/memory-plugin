#!/bin/bash
# Find transcripts not yet processed across all three coding agents.
#
# Outputs one record per line, tab-separated:
#   <agent>\t<id>\t<source>
#
# where:
#   agent  = claude-code | codex | opencode
#   id     = filename-safe identifier ending in .jsonl
#   source = path to source file (claude-code/codex) or session_id (opencode)
#
# "Already processed" is determined by the presence of a file with the
# matching <id> in ~/.memory/processed/sessions/. Idempotent — running
# twice produces zero output the second time.
#
# Uses python3 for the OpenCode SQLite query (stdlib, universal).

set -e

MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
PROCESSED_DIR="$MEMORY_HOME/processed/sessions"
mkdir -p "$PROCESSED_DIR"

emit_if_new() {
  local agent="$1"
  local id="$2"
  local source="$3"
  if [ ! -e "$PROCESSED_DIR/$id" ]; then
    printf "%s\t%s\t%s\n" "$agent" "$id" "$source"
  fi
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
    emit_if_new "claude-code" "$id" "$path"
  done < <(find "$HOME/.claude/projects" -name "*.jsonl" -type f 2>/dev/null)
fi

# --- Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl ---
if [ -d "$HOME/.codex/sessions" ]; then
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    id="codex-$(basename "$path")"
    emit_if_new "codex" "$id" "$path"
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
    emit_if_new "opencode" "$id" "$session_id"
  done
fi
