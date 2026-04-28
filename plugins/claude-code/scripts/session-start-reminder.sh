#!/usr/bin/env bash
# SessionStart hook for the memory plugin.
#
# Emits JSON with hookSpecificOutput.additionalContext so Claude Code injects
# a reminder at session start: there's a persistent typed wiki at
# ~/.memory/wiki/, and the agent should invoke the memory:recall skill (or
# grep the wiki directly) on any task that could benefit from prior user
# context — instead of relying on weights alone.
#
# The namespace list is generated dynamically from the live wiki so the
# injected context reflects what's actually there.
set -euo pipefail

WIKI_DIR="${MEMORY_HOME:-$HOME/.memory}/wiki"

namespaces=""
if [ -d "$WIKI_DIR" ]; then
  namespaces=$(
    find "$WIKI_DIR" -maxdepth 1 -name '*.md' -type f -printf '%f\n' 2>/dev/null \
      | awk -F. '{print $1}' \
      | sort -u \
      | paste -sd' ' -
  )
fi

jq -cn --arg ns "$namespaces" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: (
      "PERSISTENT MEMORY AVAILABLE: The user has a typed wiki at ~/.memory/wiki/ " +
      "containing prior decisions, preferences, user profile, and project context — " +
      "things NOT in your weights. Before responding to any task that could touch " +
      "these topics (user identity, preferences, prior decisions, project history, " +
      "technical context), invoke the memory:recall skill OR grep ~/.memory/wiki/ " +
      "directly with your native tools. Namespaces present: " + $ns + ". " +
      "Reads are free — the cost of skipping is acting on incomplete context."
    )
  }
}'
