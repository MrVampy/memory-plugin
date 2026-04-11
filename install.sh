#!/bin/bash
# Memory installer.
#
# Architecture: the system has exactly one custom tool — the `memory
# validate` CLI. Everything else (reads, writes, deletes, discovery) is
# done by coding agents using their native filesystem tools, with the
# validator as the single gate. There are no MCP servers, no hooks
# (outside the per-agent permission model), and no background daemons.
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
#
# Re-running this script is the canonical way to sync source edits into
# whichever agent caches expect them.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIKI_DIR="${MEMORY_HOME:-$HOME/.memory}/wiki"
BIN_DIR="$HOME/.local/bin"
NODE_DEPS_DIR="$SCRIPT_DIR/build/dev/javascript"

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

# --- 4. Per-agent skill installation -----------------------------------------

# --- Claude Code ---
CLAUDE_PLUGIN_DIR="$HOME/.claude/plugins/memory"
CLAUDE_CACHE_DIR="$HOME/.claude/plugins/cache/local/memory/0.1.0"

if [ -d "$HOME/.claude" ]; then
  echo "→ Installing Claude Code plugin (skills only)..."
  rm -rf "$CLAUDE_PLUGIN_DIR"
  mkdir -p "$CLAUDE_PLUGIN_DIR"
  cp -r "$SCRIPT_DIR/plugins/claude-code/.claude-plugin" "$CLAUDE_PLUGIN_DIR/"
  cp -r "$SCRIPT_DIR/plugins/skills" "$CLAUDE_PLUGIN_DIR/skills"

  if [ -d "$CLAUDE_CACHE_DIR" ]; then
    echo "  → syncing plugin cache..."
    rm -rf "$CLAUDE_CACHE_DIR"
    cp -r "$CLAUDE_PLUGIN_DIR" "$CLAUDE_CACHE_DIR"
  fi
fi

# --- Codex ---
CODEX_SKILLS_DIR="$HOME/.codex/skills"
CODEX_CONFIG_FILE="$HOME/.codex/config.toml"
MEMORY_HOME_PATH="${MEMORY_HOME:-$HOME/.memory}"

if [ -d "$HOME/.codex" ]; then
  # Clean up an obsolete hooks.json from a previous install.
  if [ -f "$HOME/.codex/hooks.json" ] && grep -q 'memory hook' "$HOME/.codex/hooks.json" 2>/dev/null; then
    if [ "$(grep -c 'memory hook' "$HOME/.codex/hooks.json")" = "1" ]; then
      echo "→ Removing obsolete Codex hooks.json..."
      rm "$HOME/.codex/hooks.json"
    fi
  fi

  echo "→ Installing Codex skills..."
  mkdir -p "$CODEX_SKILLS_DIR"
  for skill in create recall; do
    rm -rf "$CODEX_SKILLS_DIR/memory-$skill"
    cp -r "$SCRIPT_DIR/plugins/skills/$skill" "$CODEX_SKILLS_DIR/memory-$skill"
  done
  # Install maintain skill if it exists (will be added in a later commit).
  if [ -d "$SCRIPT_DIR/plugins/skills/maintain" ]; then
    rm -rf "$CODEX_SKILLS_DIR/memory-maintain"
    cp -r "$SCRIPT_DIR/plugins/skills/maintain" "$CODEX_SKILLS_DIR/memory-maintain"
  fi

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

  # Clean up obsolete [mcp_servers.memory] from a previous install.
  if [ -f "$CODEX_CONFIG_FILE" ] && grep -q "^\[mcp_servers\.memory\]" "$CODEX_CONFIG_FILE" 2>/dev/null; then
    echo "  ⚠  Codex config.toml still has [mcp_servers.memory] from a previous install."
    echo "     You can safely remove that section — the memory system no longer uses MCP."
  fi
fi

# --- OpenCode ---
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
OPENCODE_SKILLS_PATH="$SCRIPT_DIR/plugins/skills"

if [ -d "$OPENCODE_CONFIG_DIR" ]; then
  if [ -f "$OPENCODE_CONFIG_FILE" ]; then
    if grep -qF "$OPENCODE_SKILLS_PATH" "$OPENCODE_CONFIG_FILE" 2>/dev/null; then
      echo "→ OpenCode opencode.json already references the skills path — leaving alone."
    else
      echo "→ OpenCode opencode.json exists but doesn't reference the skills path."
      echo "  Add this manually to opencode.json:"
      echo "    \"skills\": { \"paths\": [\"$OPENCODE_SKILLS_PATH\"] }"
      echo "  And if you had a previous \"plugin\" or \"mcp\" entry pointing at memory,"
      echo "  remove it — the memory system no longer ships a plugin or MCP server."
    fi
  else
    echo "→ Creating $OPENCODE_CONFIG_FILE..."
    cat > "$OPENCODE_CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": ["$OPENCODE_SKILLS_PATH"]
  }
}
EOF
  fi
fi

echo ""
echo "✓ memory validator installed at $BIN_DIR/memory"
echo "✓ Wiki at $WIKI_DIR"
[ -d "$CLAUDE_PLUGIN_DIR" ] && echo "✓ Claude Code plugin at $CLAUDE_PLUGIN_DIR"
[ -d "$CODEX_SKILLS_DIR/memory-create" ] && echo "✓ Codex skills at $CODEX_SKILLS_DIR/memory-*"
[ -f "$CODEX_CONFIG_FILE" ] && grep -qF "$MEMORY_HOME_PATH" "$CODEX_CONFIG_FILE" 2>/dev/null && echo "✓ Codex sandbox writable_roots includes $MEMORY_HOME_PATH"
[ -f "$OPENCODE_CONFIG_FILE" ] && grep -qF "$OPENCODE_SKILLS_PATH" "$OPENCODE_CONFIG_FILE" 2>/dev/null && echo "✓ OpenCode skills path set in $OPENCODE_CONFIG_FILE"
echo ""
echo "If Claude Code is running, use /reload-plugins to apply changes."
