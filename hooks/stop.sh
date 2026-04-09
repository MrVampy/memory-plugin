#!/bin/bash
# Stop hook — validate wiki, regenerate index, inject updated index into context

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
MEMORY_CLI="$PLUGIN_ROOT/bin/memory"
GLOBAL_WIKI="$HOME/.claude/.memory/wiki"

# Read stdin (required)
cat > /dev/null

OUTPUT=""

# Only run if wiki directory exists and has entries
if [ -d "$GLOBAL_WIKI" ] && ls "$GLOBAL_WIKI"/*.md >/dev/null 2>&1; then
  # Run validator
  RESULT=$("$MEMORY_CLI" validate "$GLOBAL_WIKI" 2>&1)

  # Regenerate index
  "$MEMORY_CLI" index "$GLOBAL_WIKI" >/dev/null 2>&1

  # Output errors if any
  if echo "$RESULT" | grep -q "✗"; then
    OUTPUT="$RESULT"$'\n\n'
  fi

  # Inject updated index
  if [ -f "$GLOBAL_WIKI/INDEX.md" ]; then
    OUTPUT="${OUTPUT}**Wiki Index (global, updated):**
$(cat "$GLOBAL_WIKI/INDEX.md")"
  fi
fi

# Also check project wiki if it exists
CWD="${CWD:-$(pwd)}"
PROJECT_WIKI="$CWD/.memory/wiki"
if [ -d "$PROJECT_WIKI" ] && ls "$PROJECT_WIKI"/*.md >/dev/null 2>&1; then
  RESULT=$("$MEMORY_CLI" validate "$PROJECT_WIKI" 2>&1)
  "$MEMORY_CLI" index "$PROJECT_WIKI" >/dev/null 2>&1

  if echo "$RESULT" | grep -q "✗"; then
    OUTPUT="${OUTPUT}"$'\n'"$RESULT"$'\n\n'
  fi

  if [ -f "$PROJECT_WIKI/INDEX.md" ]; then
    OUTPUT="${OUTPUT}
**Wiki Index (project, updated):**
$(cat "$PROJECT_WIKI/INDEX.md")"
  fi
fi

if [ -n "$OUTPUT" ]; then
  echo "$OUTPUT"
fi
