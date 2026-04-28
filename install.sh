#!/bin/bash
# Memory installer.
#
# Architecture: the system has exactly one custom tool — the `memory
# validate` CLI. Everything else (reads, writes, deletes, discovery) is
# done by coding agents using their native filesystem tools, with the
# validator as the single gate. There are no MCP servers, no hooks
# (outside the per-agent permission model), and no background daemons.
#
# Usage:
#   bash install.sh [--cron-project PATH]
#
# What this installer does:
#   1. Builds the Gleam validator.
#   2. Symlinks the `memory` binary to ~/.local/bin so it's on PATH.
#   3. Creates the wiki directory at ~/.memory/wiki/ (or $MEMORY_HOME/wiki).
#   4. Installs the three skills (recall, create, maintain) to each
#      detected coding agent's skill directory.
#   5. For Codex: adds ~/.memory to sandbox writable_roots so the create
#      and maintain skills can write without permission prompts.
#   6. For OpenCode: writes a minimal opencode.json that points at the
#      skill directory.
#   7. If --cron-project is given, registers an hourly memory-maintenance
#      cron task in <project>/.claude/scheduled_tasks.json. Claude Code's
#      cron scheduler is per-project, so this must be a project you open
#      regularly for the maintenance to run.
#
# Re-running this script is the canonical way to sync source edits into
# whichever agent caches expect them.

set -e

# --- Arguments ---------------------------------------------------------------

CRON_PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cron-project)
      CRON_PROJECT="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,30p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash install.sh [--cron-project PATH]" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIKI_DIR="${MEMORY_HOME:-$HOME/.memory}/wiki"
BIN_DIR="$HOME/.local/bin"
NODE_DEPS_DIR="$SCRIPT_DIR/build/dev/javascript"

# --- Prerequisites -----------------------------------------------------------
#
# Check required tools up front so the user gets a clear error instead of
# a cryptic build failure halfway through.

check_command() {
  local cmd="$1"
  local purpose="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "✗ Missing required command: $cmd" >&2
    echo "  Needed for: $purpose" >&2
    return 1
  fi
}

MISSING=0
check_command gleam   "building the validator (gleam build --target javascript)" || MISSING=1
check_command node    "running the compiled JS validator" || MISSING=1
check_command npm     "installing js-yaml, the yay YAML library's runtime dep" || MISSING=1
check_command python3 "maintain skill scripts + install.sh cron state management" || MISSING=1
if [ $MISSING -ne 0 ]; then
  echo "" >&2
  echo "Install the missing prerequisites and re-run bash install.sh" >&2
  exit 1
fi

# --- 1. Build the Gleam project ----------------------------------------------

echo "→ Building Gleam validator..."
cd "$SCRIPT_DIR"
gleam build --target javascript

# Make sure js-yaml (yay's runtime dep) is available next to the bundle
if [ ! -d "$NODE_DEPS_DIR/node_modules" ]; then
  echo "→ Installing js-yaml runtime dep..."
  cd "$NODE_DEPS_DIR"
  if [ ! -f package.json ]; then
    echo '{"type":"module","dependencies":{"js-yaml":"^4.1.0"}}' > package.json
  fi
  npm install --silent
  cd "$SCRIPT_DIR"
fi

# --- 2. Install the memory binary on PATH ------------------------------------

echo "→ Installing memory binary to $BIN_DIR..."
mkdir -p "$BIN_DIR"
ln -sf "$SCRIPT_DIR/bin/memory" "$BIN_DIR/memory"
chmod +x "$SCRIPT_DIR/bin/memory"

if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  echo "  ⚠  $BIN_DIR is not on PATH. Add this to your shell rc:"
  echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# --- 3. Ensure the wiki directory exists -------------------------------------

mkdir -p "$WIKI_DIR"

# --- Helpers -----------------------------------------------------------------
#
# AGENTS.md is the Codex- and OpenCode-equivalent of Claude Code's SessionStart
# hook: a static file auto-loaded into every session. We append the plugin's
# reminder block between marker comments so re-runs are idempotent and the
# user's other AGENTS.md content is preserved.

AGENTS_MD_BEGIN="<!-- memory-plugin:begin -->"
AGENTS_MD_END="<!-- memory-plugin:end -->"
AGENTS_MD_SNIPPET="$SCRIPT_DIR/plugins/agents-md-snippet.md"

upsert_agents_md_snippet() {
  local target_file="$1"
  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  local tmp
  tmp=$(mktemp)
  awk -v b="$AGENTS_MD_BEGIN" -v e="$AGENTS_MD_END" '
    $0 == b { skip=1; next }
    $0 == e { skip=0; next }
    !skip
  ' "$target_file" > "$tmp"

  if [ -s "$tmp" ]; then
    echo "" >> "$tmp"
  fi
  {
    echo "$AGENTS_MD_BEGIN"
    cat "$AGENTS_MD_SNIPPET"
    echo "$AGENTS_MD_END"
  } >> "$tmp"

  mv "$tmp" "$target_file"
}

# --- 4. Per-agent skill installation -----------------------------------------

# --- Claude Code ---
CLAUDE_PLUGIN_DIR="$HOME/.claude/plugins/memory"
CLAUDE_CACHE_DIR="$HOME/.claude/plugins/cache/local/memory/0.1.0"

if [ -d "$HOME/.claude" ]; then
  echo "→ Installing Claude Code plugin..."
  rm -rf "$CLAUDE_PLUGIN_DIR"
  mkdir -p "$CLAUDE_PLUGIN_DIR"
  cp -r "$SCRIPT_DIR/plugins/claude-code/.claude-plugin" "$CLAUDE_PLUGIN_DIR/"
  cp -r "$SCRIPT_DIR/plugins/claude-code/hooks"          "$CLAUDE_PLUGIN_DIR/hooks"
  cp -r "$SCRIPT_DIR/plugins/claude-code/scripts"        "$CLAUDE_PLUGIN_DIR/scripts"
  cp -r "$SCRIPT_DIR/plugins/skills"                     "$CLAUDE_PLUGIN_DIR/skills"
  chmod +x "$CLAUDE_PLUGIN_DIR/scripts/"*.sh 2>/dev/null || true

  # Substitute %%SKILL_DIR%% in the maintain skill with the absolute
  # install path so the dispatcher can spawn the subagent with correct paths.
  sed -i "s|%%SKILL_DIR%%|$CLAUDE_PLUGIN_DIR/skills/maintain|g" \
    "$CLAUDE_PLUGIN_DIR/skills/maintain/SKILL.md"

  if [ -d "$CLAUDE_CACHE_DIR" ]; then
    echo "  → syncing plugin cache..."
    rm -rf "$CLAUDE_CACHE_DIR"
    cp -r "$CLAUDE_PLUGIN_DIR" "$CLAUDE_CACHE_DIR"
  fi

  # Disable Claude Code's built-in auto-memory so the plugin's wiki is the
  # sole memory source (no split-brain). Only touches user settings.json;
  # project-scope settings are the user's call.
  CLAUDE_USER_SETTINGS="$HOME/.claude/settings.json"
  if command -v jq >/dev/null 2>&1; then
    if [ -f "$CLAUDE_USER_SETTINGS" ]; then
      # `//` coerces on falsy, so `.x // "unset"` returns "unset" even when x=false.
      # Use has() + explicit branch to tell "explicitly false" apart from missing.
      current=$(jq -r 'if has("autoMemoryEnabled") then (.autoMemoryEnabled|tostring) else "unset" end' "$CLAUDE_USER_SETTINGS")
      if [ "$current" != "false" ]; then
        echo "→ Disabling Claude Code autoMemoryEnabled in $CLAUDE_USER_SETTINGS..."
        tmp=$(mktemp)
        jq '.autoMemoryEnabled = false' "$CLAUDE_USER_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_USER_SETTINGS"
      else
        echo "→ Claude Code autoMemoryEnabled already false — leaving alone."
      fi
    else
      echo "→ Creating $CLAUDE_USER_SETTINGS with autoMemoryEnabled disabled..."
      echo '{"autoMemoryEnabled": false}' | jq . > "$CLAUDE_USER_SETTINGS"
    fi
  else
    echo "  ⚠  jq not installed — skipped disabling Claude Code autoMemoryEnabled."
    echo "     Set \"autoMemoryEnabled\": false in $CLAUDE_USER_SETTINGS manually."
  fi
fi

# --- Codex ---
CODEX_SKILLS_DIR="$HOME/.codex/skills"
CODEX_CONFIG_FILE="$HOME/.codex/config.toml"
MEMORY_HOME_PATH="${MEMORY_HOME:-$HOME/.memory}"

if [ -d "$HOME/.codex" ]; then
  echo "→ Installing Codex skills..."
  mkdir -p "$CODEX_SKILLS_DIR"
  for skill in create recall; do
    rm -rf "$CODEX_SKILLS_DIR/memory-$skill"
    cp -r "$SCRIPT_DIR/plugins/skills/$skill" "$CODEX_SKILLS_DIR/memory-$skill"
  done
  # Install maintain skill with SKILL_DIR substitution so the dispatcher
  # can spawn the subagent with correct absolute paths.
  rm -rf "$CODEX_SKILLS_DIR/memory-maintain"
  cp -r "$SCRIPT_DIR/plugins/skills/maintain" "$CODEX_SKILLS_DIR/memory-maintain"
  sed -i "s|%%SKILL_DIR%%|$CODEX_SKILLS_DIR/memory-maintain|g" \
    "$CODEX_SKILLS_DIR/memory-maintain/SKILL.md"

  # Sandbox writable_roots — needed for the create skill to write to
  # ~/.memory/wiki/ without permission prompts when Codex runs with
  # sandbox_mode = "workspace-write".
  if [ -f "$CODEX_CONFIG_FILE" ] && grep -qF "$MEMORY_HOME_PATH" "$CODEX_CONFIG_FILE" 2>/dev/null; then
    echo "→ Codex config.toml already references $MEMORY_HOME_PATH — leaving alone."
  elif [ -f "$CODEX_CONFIG_FILE" ] && grep -q "^\[sandbox_workspace_write\]" "$CODEX_CONFIG_FILE" 2>/dev/null; then
    echo "→ Codex config.toml has [sandbox_workspace_write] but no $MEMORY_HOME_PATH."
    echo "  Add this path to writable_roots manually:"
    echo "    writable_roots = [..., \"$MEMORY_HOME_PATH\"]"
  else
    echo "→ Adding $MEMORY_HOME_PATH to Codex sandbox writable_roots..."
    {
      [ -f "$CODEX_CONFIG_FILE" ] && echo ""
      echo "# Added by Memory installer — lets the create skill write to ~/.memory"
      echo "# without prompting. Only effective when sandbox_mode = \"workspace-write\"."
      echo "[sandbox_workspace_write]"
      echo "writable_roots = [\"$MEMORY_HOME_PATH\"]"
    } >> "$CODEX_CONFIG_FILE"
  fi

  # Codex has no SessionStart hook equivalent — AGENTS.md is the canonical
  # way to inject a persistent instruction into every session.
  echo "→ Writing memory reminder block to $HOME/.codex/AGENTS.md..."
  upsert_agents_md_snippet "$HOME/.codex/AGENTS.md"

  # Belt-and-suspenders: Codex's native `memories` feature is default-off, but
  # pin it to false so a future default flip doesn't introduce split-brain.
  if [ -f "$CODEX_CONFIG_FILE" ] && grep -q "^\[features\]" "$CODEX_CONFIG_FILE" 2>/dev/null && grep -qE "^[[:space:]]*memories[[:space:]]*=" "$CODEX_CONFIG_FILE" 2>/dev/null; then
    echo "→ Codex config.toml already declares features.memories — leaving alone."
  else
    echo "→ Pinning Codex features.memories = false (wiki plugin is sole memory)..."
    {
      [ -f "$CODEX_CONFIG_FILE" ] && echo ""
      echo "# Added by Memory installer — the wiki at ~/.memory is the sole memory"
      echo "# source; disable Codex's native memories feature to prevent split-brain."
      echo "[features]"
      echo "memories = false"
      echo ""
      echo "[memories]"
      echo "use_memories = false"
      echo "generate_memories = false"
    } >> "$CODEX_CONFIG_FILE"
  fi
fi

# --- OpenCode ---
#
# OpenCode previously pointed at the source plugins/skills/ directory via
# opencode.json's skills.paths. That kept dev edits live but prevented us
# from doing install-time path substitution for the maintain skill. So
# we now copy the skills to ~/.config/opencode/skills/memory-*/ (same
# pattern as Codex) and opencode.json points at the copied location.
# Re-run install.sh to sync source edits.
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
OPENCODE_SKILLS_DIR="$OPENCODE_CONFIG_DIR/skills"

if [ -d "$OPENCODE_CONFIG_DIR" ]; then
  echo "→ Installing OpenCode skills..."
  mkdir -p "$OPENCODE_SKILLS_DIR"
  for skill in create recall; do
    rm -rf "$OPENCODE_SKILLS_DIR/memory-$skill"
    cp -r "$SCRIPT_DIR/plugins/skills/$skill" "$OPENCODE_SKILLS_DIR/memory-$skill"
  done
  # Install maintain skill with SKILL_DIR substitution.
  rm -rf "$OPENCODE_SKILLS_DIR/memory-maintain"
  cp -r "$SCRIPT_DIR/plugins/skills/maintain" "$OPENCODE_SKILLS_DIR/memory-maintain"
  sed -i "s|%%SKILL_DIR%%|$OPENCODE_SKILLS_DIR/memory-maintain|g" \
    "$OPENCODE_SKILLS_DIR/memory-maintain/SKILL.md"

  if [ -f "$OPENCODE_CONFIG_FILE" ]; then
    if grep -qF "$OPENCODE_SKILLS_DIR" "$OPENCODE_CONFIG_FILE" 2>/dev/null; then
      echo "→ OpenCode opencode.json already references the skills path — leaving alone."
    else
      echo "→ OpenCode opencode.json exists but doesn't reference the skills path."
      echo "  Add this manually to opencode.json:"
      echo "    \"skills\": { \"paths\": [\"$OPENCODE_SKILLS_DIR\"] }"
    fi
  else
    echo "→ Creating $OPENCODE_CONFIG_FILE..."
    cat > "$OPENCODE_CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": ["$OPENCODE_SKILLS_DIR"]
  }
}
EOF
  fi

  # OpenCode auto-loads ~/.config/opencode/AGENTS.md as persistent instructions.
  # Same role as Claude Code's SessionStart hook and Codex's AGENTS.md.
  echo "→ Writing memory reminder block to $OPENCODE_CONFIG_DIR/AGENTS.md..."
  upsert_agents_md_snippet "$OPENCODE_CONFIG_DIR/AGENTS.md"
fi

# --- Scheduled maintenance cron (Claude Code only, per-project) --------------
#
# Claude Code's cron scheduler reads <project-root>/.claude/scheduled_tasks.json
# — there's no user-global or walk-up fallback. If --cron-project is given,
# register (or update) the memory-maintenance task in that project's file.
# If not given, skip and print instructions for manual setup.

if [ -n "$CRON_PROJECT" ]; then
  if [ ! -d "$CRON_PROJECT" ]; then
    echo "✗ --cron-project $CRON_PROJECT does not exist" >&2
    exit 1
  fi
  CRON_PROJECT_ABS=$(cd "$CRON_PROJECT" && pwd)
  CRON_FILE="$CRON_PROJECT_ABS/.claude/scheduled_tasks.json"
  mkdir -p "$(dirname "$CRON_FILE")"

  echo "→ Registering memory-maintenance cron in $CRON_FILE..."
  python3 - "$CRON_FILE" <<'PY'
import json, os, sys, time

path = sys.argv[1]

tasks = []
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f) or {}
        tasks = data.get("tasks") or []
        if not isinstance(tasks, list):
            tasks = []
    except (json.JSONDecodeError, OSError):
        tasks = []

# Find any existing memory-maintenance task so we can preserve createdAt
# and lastFiredAt across re-installs (only the prompt/cron/recurring get
# refreshed from the installer).
existing = next(
    (t for t in tasks if isinstance(t, dict) and t.get("id") == "memory-maintenance"),
    None,
)
tasks = [t for t in tasks if isinstance(t, dict) and t.get("id") != "memory-maintenance"]

updated = {
    "id": "memory-maintenance",
    "cron": "0 * * * *",
    "prompt": (
        "[SYSTEM CRON TICK - memory maintenance]\n\n"
        "Invoke the memory:maintain skill — it will dispatch the work to "
        "a background subagent. You should not do maintenance work "
        "yourself in this session. Follow the skill's dispatcher "
        "instructions and return to the user's work immediately."
    ),
    "createdAt": existing.get("createdAt") if existing else int(time.time() * 1000),
    "recurring": True,
    "permanent": True,
}
if existing and "lastFiredAt" in existing:
    updated["lastFiredAt"] = existing["lastFiredAt"]

tasks.append(updated)

with open(path, "w") as f:
    json.dump({"tasks": tasks}, f, indent=2)
    f.write("\n")
PY
else
  echo "→ --cron-project not specified; scheduled maintenance is NOT enabled."
  echo "  To enable hourly background memory maintenance, re-run with:"
  echo "    bash install.sh --cron-project <path-to-claude-code-project-you-open-regularly>"
  echo "  The cron only fires when Claude Code is running in that project."
fi

echo ""
echo "✓ memory validator installed at $BIN_DIR/memory"
echo "✓ Wiki at $WIKI_DIR"
[ -d "$CLAUDE_PLUGIN_DIR" ] && echo "✓ Claude Code plugin at $CLAUDE_PLUGIN_DIR"
[ -f "$CLAUDE_PLUGIN_DIR/hooks/hooks.json" ] && echo "✓ Claude Code SessionStart hook registered via plugin"
[ -d "$CODEX_SKILLS_DIR/memory-create" ] && echo "✓ Codex skills at $CODEX_SKILLS_DIR/memory-*"
[ -f "$CODEX_CONFIG_FILE" ] && grep -qF "$MEMORY_HOME_PATH" "$CODEX_CONFIG_FILE" 2>/dev/null && echo "✓ Codex sandbox writable_roots includes $MEMORY_HOME_PATH"
[ -f "$HOME/.codex/AGENTS.md" ] && grep -qF "$AGENTS_MD_BEGIN" "$HOME/.codex/AGENTS.md" 2>/dev/null && echo "✓ Codex AGENTS.md contains memory reminder block"
[ -f "$OPENCODE_CONFIG_FILE" ] && grep -qF "$OPENCODE_SKILLS_DIR" "$OPENCODE_CONFIG_FILE" 2>/dev/null && echo "✓ OpenCode skills at $OPENCODE_SKILLS_DIR/memory-*"
[ -f "$OPENCODE_CONFIG_DIR/AGENTS.md" ] && grep -qF "$AGENTS_MD_BEGIN" "$OPENCODE_CONFIG_DIR/AGENTS.md" 2>/dev/null && echo "✓ OpenCode AGENTS.md contains memory reminder block"
[ -n "$CRON_PROJECT" ] && [ -f "$CRON_FILE" ] && echo "✓ Hourly maintenance cron registered in $CRON_FILE"
echo ""

# --- Final verification: run the validator ----------------------------------
#
# Smoke test — if the validator runs and reports a clean wiki, the install is
# functional. A fresh install with an empty wiki will report "0 entries, 0 errors".

echo "→ Verifying install..."
if VALIDATE_OUT="$("$SCRIPT_DIR/bin/memory" validate 2>&1)"; then
  echo "  $VALIDATE_OUT"
  echo ""
  echo "✓ Install complete."
else
  echo "✗ Validator smoke test failed:" >&2
  echo "$VALIDATE_OUT" >&2
  echo "" >&2
  echo "The install finished but the validator isn't working. Check the error" >&2
  echo "above and try 'memory validate' manually to debug." >&2
  exit 1
fi

if [ -n "$CRON_PROJECT" ]; then
  echo ""
  echo "The cron only fires when Claude Code is running in $CRON_PROJECT_ABS."
  echo "Open (or restart) Claude Code there to start the scheduler."
fi
echo ""
echo "If Claude Code is already running, use /reload-plugins to pick up the new skills."
