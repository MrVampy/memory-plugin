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

# Copy plugin manifest
cp -r .claude-plugin "$PLUGIN_DIR/"

# Copy skills
rm -rf "$PLUGIN_DIR/skills"
cp -r skills "$PLUGIN_DIR/"

# Copy hooks (scripts + hooks.json)
rm -rf "$PLUGIN_DIR/hooks"
cp -r hooks "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/hooks/"*.sh

# Copy compiled JS output as bin/ (includes all dependencies)
rm -rf "$PLUGIN_DIR/bin"
mkdir -p "$PLUGIN_DIR/bin"

# The CLI wrapper
cat > "$PLUGIN_DIR/bin/memory" << 'WRAPPER'
#!/bin/bash
PLUGIN_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
exec node "$PLUGIN_DIR/lib/memory/gleam@@private_main_v1.15.2.mjs" "$@"
WRAPPER
chmod +x "$PLUGIN_DIR/bin/memory"

# The compiled Gleam output
cp -r build/dev/javascript "$PLUGIN_DIR/lib"

# Install npm dependencies (js-yaml needed by yay on JS target)
cd "$PLUGIN_DIR/lib"
if [ ! -f package.json ]; then
  echo '{"type":"module","dependencies":{"js-yaml":"^4.1.0"}}' > package.json
fi
npm install --silent

echo "✓ Plugin installed to $PLUGIN_DIR"
echo "✓ Wiki directory at $WIKI_DIR"
echo ""
echo "Load with: claude --plugin-dir $PLUGIN_DIR"
echo "Or add as local marketplace: /plugin marketplace add $HOME/.claude/plugins"
