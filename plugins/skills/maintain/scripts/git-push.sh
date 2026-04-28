#!/bin/bash
# Push the wiki to its configured remote, if any.
#
# Runs after git-commit.sh in the maintenance workflow. Safely no-ops
# when no remote is configured — users who never wire up a remote
# (or who opt out by removing it) aren't broken.
#
# Network/auth failures are treated as non-fatal: we log and exit 0 so a
# bad network day doesn't abort the whole maintenance run. The commit
# still lives in the local repo and will be pushed on the next run when
# connectivity returns.
#
# Scope: only ~/.memory/wiki/, same as git-commit.sh.

set -e

MEMORY_HOME="${MEMORY_HOME:-$HOME/.memory}"
WIKI="$MEMORY_HOME/wiki"

if [ ! -d "$WIKI/.git" ]; then
  echo "wiki has no local git repo — skipping push"
  exit 0
fi

cd "$WIKI"

if ! git remote | grep -qx origin; then
  echo "no 'origin' remote configured — skipping push"
  exit 0
fi

# Only push the current branch. If it has no upstream, set it on first push.
BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
  echo "detached HEAD — skipping push"
  exit 0
fi

if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  # Upstream exists — fast-forward push.
  if git push -q origin "$BRANCH" 2>&1; then
    echo "pushed $BRANCH to origin"
  else
    echo "⚠ push failed (network/auth?) — commit stays local, will retry next run"
  fi
else
  # First push on this branch — set upstream.
  if git push -q --set-upstream origin "$BRANCH" 2>&1; then
    echo "pushed $BRANCH to origin (upstream set)"
  else
    echo "⚠ push failed (network/auth?) — commit stays local, will retry next run"
  fi
fi
