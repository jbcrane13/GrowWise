#!/usr/bin/env sh
# Install git hooks for GrowWise
# Usage: ./scripts/install-hooks.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing git hooks..."

# Copy the pre-commit-quality hook
if [ -f "$SCRIPT_DIR/hooks/pre-commit-quality" ]; then
    cp "$SCRIPT_DIR/hooks/pre-commit-quality" "$HOOKS_DIR/pre-commit-quality"
else
    echo "WARNING: pre-commit-quality not found"
fi
chmod +x "$HOOKS_DIR/pre-commit-quality" 2>/dev/null || true

# Copy the pre-push-quality hook
if [ -f "$SCRIPT_DIR/hooks/pre-push-quality" ]; then
    cp "$SCRIPT_DIR/hooks/pre-push-quality" "$HOOKS_DIR/pre-push-quality"
else
    echo "WARNING: pre-push-quality not found"
fi
chmod +x "$HOOKS_DIR/pre-push-quality" 2>/dev/null || true

# Update the main pre-commit hook to chain quality checks
if grep -q "pre-commit-quality" "$HOOKS_DIR/pre-commit" 2>/dev/null; then
    echo "  pre-commit already chains quality hooks"
else
    cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env sh
# GrowWise chained pre-commit hook
# Runs: beads sync → quality checks (SwiftLint + SwiftFormat)

HOOK_DIR="$(dirname "$0")"

# 1. Run beads hook (issue tracking sync)
if [ -f "$HOOK_DIR/pre-commit-beads" ]; then
    "$HOOK_DIR/pre-commit-beads" "$@" || exit 1
fi

# 2. Run quality checks
if [ -f "$HOOK_DIR/pre-commit-quality" ]; then
    "$HOOK_DIR/pre-commit-quality" "$@" || exit 1
fi
EOF
    chmod +x "$HOOKS_DIR/pre-commit"
    echo "  Updated pre-commit hook"
fi

# Update the main pre-push hook to chain quality checks
if grep -q "pre-push-quality" "$HOOKS_DIR/pre-push" 2>/dev/null; then
    echo "  pre-push already chains quality hooks"
else
    cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/usr/bin/env sh
# GrowWise chained pre-push hook
# Runs: beads sync → build verification

HOOK_DIR="$(dirname "$0")"

# 1. Run beads hook
if command -v bd >/dev/null 2>&1; then
    export BD_GIT_HOOK=1
    bd hooks run pre-push "$@"
    _bd_exit=$?; if [ $_bd_exit -ne 0 ]; then exit $_bd_exit; fi
fi

# 2. Run build verification
if [ -f "$HOOK_DIR/pre-push-quality" ]; then
    "$HOOK_DIR/pre-push-quality" "$@" || exit 1
fi
EOF
    chmod +x "$HOOKS_DIR/pre-push"
    echo "  Updated pre-push hook"
fi

echo "✓ Git hooks installed"
echo ""
echo "Pre-commit runs: beads sync → SwiftLint → SwiftFormat"
echo "Pre-push runs: beads sync → build verification"