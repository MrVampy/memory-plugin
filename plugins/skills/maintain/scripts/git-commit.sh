#!/bin/bash
# Commit wiki changes to a local git repo at ~/.memory/wiki/.git.
#
# Self-initializing: creates the repo on first run with an initial commit
# of the current wiki state. On subsequent runs, stages all changes and
# commits with the provided message (or a default timestamp-based one).
#
# Scope: only ~/.memory/wiki/ is versioned. The state directories
# (raw/, processed/, .maintenance-state/) stay out — they're ephemeral
# bookkeeping, not knowledge.
#
# Usage:
#   git-commit.sh [message]
#
# Exits 0 on success (including no-op when there's nothing to commit).
# Exits non-zero on git errors.

set -e

MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
WIKI="$MEMORY_HOME/wiki"

if [ ! -d "$WIKI" ]; then
  echo "wiki not found at $WIKI" >&2
  exit 1
fi

MSG="${1:-maintenance commit $(date -u +%Y-%m-%dT%H:%M:%SZ)}"

cd "$WIKI"

# Ensure a usable git identity exists. Prefer whatever's already in the
# user's global config; only install a local fallback if nothing is set.
ensure_identity() {
  if ! git config user.email >/dev/null 2>&1; then
    git config user.email "memory-maintenance@localhost"
  fi
  if ! git config user.name >/dev/null 2>&1; then
    git config user.name "Memory Maintenance"
  fi
}

if [ ! -d .git ]; then
  git init -q -b main
  ensure_identity
  git add -A
  git commit -q -m "initial wiki snapshot"
  echo "initialized wiki repo and created initial commit"
  exit 0
fi

ensure_identity

git add -A
if git diff --cached --quiet; then
  echo "no changes to commit"
  exit 0
fi

git commit -q -m "$MSG"
echo "committed: $MSG"
