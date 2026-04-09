#!/bin/bash
# PostToolUse hook — validate wiki after writes to wiki files
# Receives JSON on stdin with tool_input.file_path

MEMORY_CLI="$HOME/.claude/plugins/memory/memory"
GLOBAL_WIKI="$HOME/.claude/.memory/wiki"

# Read stdin
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Check if the write was to a wiki file
if echo "$FILE_PATH" | grep -q "\.memory/wiki/.*\.md$"; then
  # Determine which wiki directory
  if echo "$FILE_PATH" | grep -q "$HOME/.claude/.memory/wiki"; then
    WIKI_DIR="$GLOBAL_WIKI"
  else
    # Project wiki — extract the .memory/wiki path
    WIKI_DIR=$(echo "$FILE_PATH" | sed 's|\(.*/\.memory/wiki\)/.*|\1|')
  fi

  # Run validator
  RESULT=$("$MEMORY_CLI" validate "$WIKI_DIR" 2>&1)
  EXIT_CODE=$?

  # Run index regeneration
  "$MEMORY_CLI" index "$WIKI_DIR" >/dev/null 2>&1

  # Output validation result as additional context
  if [ $EXIT_CODE -ne 0 ] || echo "$RESULT" | grep -q "✗"; then
    echo "$RESULT"
  fi
fi
