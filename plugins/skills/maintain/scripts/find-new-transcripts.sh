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
# Records are emitted GLOBALLY OLDEST-FIRST — ascending by latest-content
# time (source mtime for file agents, MAX(time_created) for opencode). The
# maintenance runbook merges new content into existing wiki entries, so
# processing order is load-bearing: a newer session processed before an
# older one lands stale content on top of newer revisions and corrupts the
# wiki's chronology. Oldest-first means the wiki only ever grows forward in
# time. Downstream MUST NOT reorder.
#
# "Fully processed" is determined by comparing the stored cursor in
# ~/.memory/processed/sessions/<id> against the current size of the source.
# For file-based agents, a session is emitted only when its current line
# count exceeds the stored cursor — meaning there is genuinely new content
# to process. OpenCode sessions are emitted only when their latest message
# (MAX(time_created)) is newer than the stored cursor — the same
# "new content only" rule as the file agents (no dormant-session churn).
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

# Accumulate "<sortkey>\t<record>" here, then emit sorted oldest-first.
# sortkey is unix seconds. A temp file makes the ordering independent of
# the while-read loops below (they run in subshells under process subst,
# so they can't share a shell array).
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

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
    local key
    key=$(stat -c %Y "$source" 2>/dev/null || echo 0)
    printf "%s\t%s\t%s\t%s\t%s\n" "$key" "$agent" "$id" "$source" "$cursor" >> "$TMP"
  fi
}

emit_opencode() {
  local id="$1"
  local session_id="$2"
  local key="$3"        # sortkey (seconds)
  local max_ms="$4"     # MAX(time_created) for this session, unix-ms
  local cursor
  cursor=$(read_cursor "$id")
  # Emit only when there is genuinely new content past the cursor — the
  # session's latest message must be newer than the consumed cursor.
  # Without this, every dormant OpenCode session is re-emitted on every
  # tick and churns an empty diff forever (a session unused since April
  # should never show up as "pending").
  if [ "${max_ms:-0}" -gt "${cursor:-0}" ]; then
    printf "%s\t%s\t%s\t%s\t%s\n" "$key" "opencode" "$id" "$session_id" "$cursor" >> "$TMP"
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

# --- OpenCode: query SQLite for session ids + latest message time ---
# MAX(time_created) (unix-ms) → seconds yields a sortkey comparable to the
# file agents' mtime, so the global oldest-first sort interleaves correctly.
OPENCODE_DB="$HOME/.local/share/opencode/opencode.db"
if [ -f "$OPENCODE_DB" ]; then
  python3 - "$OPENCODE_DB" <<'PY' | while IFS=$'\t' read -r session_id tcreated_ms; do
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
try:
    for sid, t in db.execute(
        "SELECT session_id, MAX(time_created) FROM message "
        "GROUP BY session_id ORDER BY MAX(time_created)"):
        print(f"{sid}\t{t if t is not None else 0}")
finally:
    db.close()
PY
    [ -z "$session_id" ] && continue
    key=$(( ${tcreated_ms:-0} / 1000 ))
    emit_opencode "opencode-${session_id}.jsonl" "$session_id" "$key" "$tcreated_ms"
  done
fi

# Emit globally oldest-first (numeric sort on the sortkey), then strip it.
# Stable (-s) so equal-timestamp sessions keep per-agent discovery order.
sort -t$'\t' -s -k1,1n "$TMP" | cut -f2-
