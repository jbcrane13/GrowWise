#!/usr/bin/env sh
# Install quality git hooks for GrowWise
# Usage: ./scripts/install-hooks.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing quality git hooks..."

if [ -f "$SCRIPT_DIR/hooks/pre-commit-quality" ]; then
    cp "$SCRIPT_DIR/hooks/pre-commit-quality" "$HOOKS_DIR/pre-commit-quality"
    chmod +x "$HOOKS_DIR/pre-commit-quality"
else
    echo "WARNING: pre-commit-quality not found"
fi

if [ -f "$SCRIPT_DIR/hooks/pre-push-quality" ]; then
    cp "$SCRIPT_DIR/hooks/pre-push-quality" "$HOOKS_DIR/pre-push-quality"
    chmod +x "$HOOKS_DIR/pre-push-quality"
else
    echo "WARNING: pre-push-quality not found"
fi

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env sh
# GrowWise pre-commit quality checks
HOOK_DIR="$(dirname "$0")"
if [ -f "$HOOK_DIR/pre-commit-quality" ]; then
    "$HOOK_DIR/pre-commit-quality" "$@" || exit 1
fi
EOF
chmod +x "$HOOKS_DIR/pre-commit"

cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/usr/bin/env sh
# GrowWise pre-push build verification
HOOK_DIR="$(dirname "$0")"
if [ -f "$HOOK_DIR/pre-push-quality" ]; then
    "$HOOK_DIR/pre-push-quality" "$@" || exit 1
fi
EOF
chmod +x "$HOOKS_DIR/pre-push"

echo "✓ Quality git hooks installed"
echo ""
echo "Pre-commit runs: SwiftLint → SwiftFormat"
echo "Pre-push runs: build verification"
