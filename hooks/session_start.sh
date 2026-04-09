#!/bin/bash
# SessionStart hook — inject wiki index into context

GLOBAL_WIKI="$HOME/.claude/.memory/wiki"
GLOBAL_INDEX="$GLOBAL_WIKI/INDEX.md"

# Read stdin (required but we don't need it)
cat > /dev/null

OUTPUT=""

# Inject global wiki index if it exists
if [ -f "$GLOBAL_INDEX" ]; then
  OUTPUT="**Wiki Index (global):**
$(cat "$GLOBAL_INDEX")"
fi

# Check for project wiki index
CWD="${CWD:-$(pwd)}"
PROJECT_INDEX="$CWD/.memory/wiki/INDEX.md"
if [ -f "$PROJECT_INDEX" ]; then
  OUTPUT="$OUTPUT

**Wiki Index (project):**
$(cat "$PROJECT_INDEX")"
fi

if [ -n "$OUTPUT" ]; then
  echo "$OUTPUT"
fi
