#!/bin/bash
# Stop hook — validate wiki and regenerate index after each turn

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
MEMORY_CLI="$PLUGIN_ROOT/bin/memory"
GLOBAL_WIKI="$HOME/.claude/.memory/wiki"

# Read stdin (required)
cat > /dev/null

# Only run if wiki directory exists and has entries
if [ -d "$GLOBAL_WIKI" ] && ls "$GLOBAL_WIKI"/*.md >/dev/null 2>&1; then
  # Run validator
  RESULT=$("$MEMORY_CLI" validate "$GLOBAL_WIKI" 2>&1)

  # Regenerate index
  "$MEMORY_CLI" index "$GLOBAL_WIKI" >/dev/null 2>&1

  # Only output if there are errors
  if echo "$RESULT" | grep -q "✗"; then
    echo "$RESULT"
  fi
fi

# Also check project wiki if it exists
CWD="${CWD:-$(pwd)}"
PROJECT_WIKI="$CWD/.memory/wiki"
if [ -d "$PROJECT_WIKI" ] && ls "$PROJECT_WIKI"/*.md >/dev/null 2>&1; then
  RESULT=$("$MEMORY_CLI" validate "$PROJECT_WIKI" 2>&1)
  "$MEMORY_CLI" index "$PROJECT_WIKI" >/dev/null 2>&1

  if echo "$RESULT" | grep -q "✗"; then
    echo "$RESULT"
  fi
fi
