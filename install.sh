#!/bin/bash
# Memory installer.
#
# 1. Builds the Gleam CLI bundle.
# 2. Installs the `memory` binary to ~/.local/bin so it's on PATH for any agent.
# 3. Detects installed coding agents and installs the matching plugin from
#    plugins/<agent>/. Agents not present on this machine are skipped.
#
# Re-running this script is the canonical way to sync source edits into
# whichever agent caches expect them.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIKI_DIR="$HOME/.memory/wiki"
BIN_DIR="$HOME/.local/bin"
NODE_DEPS_DIR="$SCRIPT_DIR/build/dev/javascript"

# --- 1. Build the Gleam project ----------------------------------------------

echo "→ Building Gleam project..."
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

# --- 4. Per-agent plugin installation ----------------------------------------

CLAUDE_PLUGIN_DIR="$HOME/.claude/plugins/memory"
CLAUDE_CACHE_DIR="$HOME/.claude/plugins/cache/local/memory/0.1.0"

if [ -d "$HOME/.claude" ]; then
  echo "→ Installing Claude Code plugin..."
  rm -rf "$CLAUDE_PLUGIN_DIR"
  mkdir -p "$CLAUDE_PLUGIN_DIR"
  cp -r "$SCRIPT_DIR/plugins/claude-code/.claude-plugin" "$CLAUDE_PLUGIN_DIR/"
  cp -r "$SCRIPT_DIR/plugins/claude-code/hooks" "$CLAUDE_PLUGIN_DIR/"
  # Skills are shared across agents — copy from plugins/skills/
  cp -r "$SCRIPT_DIR/plugins/skills" "$CLAUDE_PLUGIN_DIR/skills"

  if [ -d "$CLAUDE_CACHE_DIR" ]; then
    echo "  → syncing plugin cache..."
    rm -rf "$CLAUDE_CACHE_DIR"
    cp -r "$CLAUDE_PLUGIN_DIR" "$CLAUDE_CACHE_DIR"
  fi
fi

# --- Codex adapter ---
CODEX_HOOKS_FILE="$HOME/.codex/hooks.json"
CODEX_SKILLS_DIR="$HOME/.codex/skills"
CODEX_CONFIG_FILE="$HOME/.codex/config.toml"
MEMORY_HOME_PATH="$HOME/.memory"
if [ -d "$HOME/.codex" ]; then
  # hooks.json — install if absent, leave alone if already references memory.
  if [ -f "$CODEX_HOOKS_FILE" ]; then
    if ! grep -q '"memory hook recall' "$CODEX_HOOKS_FILE" 2>/dev/null; then
      echo "→ Codex detected — but $CODEX_HOOKS_FILE already exists."
      echo "  Skipping automatic install. Merge plugins/codex/hooks.json manually."
    else
      echo "→ Codex hooks.json already references memory — leaving alone."
    fi
  else
    echo "→ Installing Codex hooks.json..."
    cp "$SCRIPT_DIR/plugins/codex/hooks.json" "$CODEX_HOOKS_FILE"
  fi

  # Skills — install each skill into ~/.codex/skills/memory-<name>/
  echo "→ Installing Codex skills..."
  mkdir -p "$CODEX_SKILLS_DIR"
  for skill in create process recall; do
    rm -rf "$CODEX_SKILLS_DIR/memory-$skill"
    cp -r "$SCRIPT_DIR/plugins/skills/$skill" "$CODEX_SKILLS_DIR/memory-$skill"
  done

  # Sandbox writable_roots — Codex has no PermissionRequest hook, so we add
  # ~/.memory to writable_roots in config.toml. Only effective when
  # sandbox_mode = "workspace-write" — that's a separate user choice.
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
      echo "# Added by Memory installer — lets agents write to ~/.memory without prompting."
      echo "# Only effective when sandbox_mode = \"workspace-write\"."
      echo "[sandbox_workspace_write]"
      echo "writable_roots = [\"$MEMORY_HOME_PATH\"]"
    } >> "$CODEX_CONFIG_FILE"
  fi
fi

# --- OpenCode adapter ---
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
OPENCODE_PLUGIN_PATH="$SCRIPT_DIR/plugins/opencode/index.ts"
OPENCODE_SKILLS_PATH="$SCRIPT_DIR/plugins/skills"
if [ -d "$OPENCODE_CONFIG_DIR" ]; then
  if [ -f "$OPENCODE_CONFIG_FILE" ]; then
    if grep -qF "$OPENCODE_PLUGIN_PATH" "$OPENCODE_CONFIG_FILE" 2>/dev/null; then
      echo "→ OpenCode opencode.json already references memory plugin — leaving alone."
    else
      echo "→ OpenCode detected — but $OPENCODE_CONFIG_FILE already exists."
      echo "  Add this manually to your opencode.json:"
      echo "    \"plugin\": [\"file://$OPENCODE_PLUGIN_PATH\"],"
      echo "    \"skills\": { \"paths\": [\"$OPENCODE_SKILLS_PATH\"] }"
    fi
  else
    echo "→ Creating $OPENCODE_CONFIG_FILE..."
    cat > "$OPENCODE_CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": ["file://$OPENCODE_PLUGIN_PATH"],
  "skills": {
    "paths": ["$OPENCODE_SKILLS_PATH"]
  }
}
EOF
  fi
fi

echo ""
echo "✓ memory CLI installed at $BIN_DIR/memory"
echo "✓ Wiki at $WIKI_DIR"
[ -d "$CLAUDE_PLUGIN_DIR" ] && echo "✓ Claude Code plugin at $CLAUDE_PLUGIN_DIR"
[ -f "$CODEX_HOOKS_FILE" ] && grep -q '"memory hook recall' "$CODEX_HOOKS_FILE" 2>/dev/null && echo "✓ Codex hooks at $CODEX_HOOKS_FILE"
[ -d "$CODEX_SKILLS_DIR/memory-create" ] && echo "✓ Codex skills at $CODEX_SKILLS_DIR/memory-{create,process,recall}"
[ -f "$CODEX_CONFIG_FILE" ] && grep -qF "$MEMORY_HOME_PATH" "$CODEX_CONFIG_FILE" 2>/dev/null && echo "✓ Codex sandbox writable_roots includes $MEMORY_HOME_PATH"
[ -f "$OPENCODE_CONFIG_FILE" ] && grep -qF "$OPENCODE_PLUGIN_PATH" "$OPENCODE_CONFIG_FILE" 2>/dev/null && echo "✓ OpenCode plugin + skills referenced from $OPENCODE_CONFIG_FILE"
echo ""
echo "If Claude Code is running, use /reload-plugins to apply changes."
