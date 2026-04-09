#!/bin/bash
# SessionEnd hook — archive session transcript

RAW_DIR="$HOME/.claude/.memory/raw/sessions"

# Read stdin to get session data
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null)

if [ -n "$SESSION_ID" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  mkdir -p "$RAW_DIR"
  cp "$TRANSCRIPT" "$RAW_DIR/${SESSION_ID}.jsonl"
fi
