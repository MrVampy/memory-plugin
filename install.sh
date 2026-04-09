#!/bin/bash
# Build and install the memory plugin to ~/.claude/plugins/memory/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$HOME/.claude/plugins/memory"
WIKI_DIR="$HOME/.claude/.memory/wiki"

echo "Building Gleam project..."
cd "$SCRIPT_DIR"
gleam build --target javascript

echo "Installing plugin..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$WIKI_DIR"

# Copy entire compiled JS output (includes all dependencies)
rm -rf "$PLUGIN_DIR/bin"
cp -r build/dev/javascript "$PLUGIN_DIR/bin"

# Install npm dependencies (js-yaml needed by yay on JS target)
cd "$PLUGIN_DIR/bin"
if [ ! -f package.json ]; then
  echo '{"type":"module","dependencies":{"js-yaml":"^4.1.0"}}' > package.json
fi
npm install --silent
cd "$SCRIPT_DIR"

# Copy skill and CLI wrapper
cp plugin/skill.md "$PLUGIN_DIR/skill.md"
cp plugin/memory "$PLUGIN_DIR/memory"
chmod +x "$PLUGIN_DIR/memory"

# Copy hooks if they exist
if [ -d plugin/hooks ]; then
  cp -r plugin/hooks "$PLUGIN_DIR/"
fi

echo "✓ Plugin installed to $PLUGIN_DIR"
echo "✓ Wiki directory at $WIKI_DIR"
echo ""
echo "Run with: node $PLUGIN_DIR/bin/memory/memory.mjs validate|index [path]"
