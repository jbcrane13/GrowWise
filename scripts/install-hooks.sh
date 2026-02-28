#!/usr/bin/env sh
# Install quality check git hooks for GrowWise
# This script chains SwiftLint/SwiftFormat quality checks with the existing beads hook.
#
# Usage: ./scripts/install-hooks.sh

set -e

HOOK_DIR="$(git rev-parse --git-dir)/hooks"
SCRIPTS_HOOK="scripts/hooks/pre-commit-quality"

# Verify tools are available
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "ERROR: swiftlint not found. Install with: brew install swiftlint"
    exit 1
fi

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "ERROR: swiftformat not found. Install with: brew install swiftformat"
    exit 1
fi

# Install the quality pre-commit hook
# The beads hook already exists — we wrap it to also run quality checks
CURRENT_HOOK="$HOOK_DIR/pre-commit"
QUALITY_HOOK="$HOOK_DIR/pre-commit-quality"

# Copy quality hook script
cp "$SCRIPTS_HOOK" "$QUALITY_HOOK"
chmod +x "$QUALITY_HOOK"

# If the current pre-commit is a beads shim, wrap it
if grep -q "bd-shim\|beads" "$CURRENT_HOOK" 2>/dev/null; then
    echo "Detected beads pre-commit hook — creating chained wrapper..."
    mv "$CURRENT_HOOK" "$HOOK_DIR/pre-commit-beads"

    cat > "$CURRENT_HOOK" << 'EOF'
#!/usr/bin/env sh
# GrowWise chained pre-commit hook
# Runs: beads export → quality checks (SwiftLint + SwiftFormat)

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
    chmod +x "$CURRENT_HOOK"
    echo "Chained hook installed at $CURRENT_HOOK"
else
    echo "Installing quality hook at $CURRENT_HOOK"
    cp "$SCRIPTS_HOOK" "$CURRENT_HOOK"
    chmod +x "$CURRENT_HOOK"
fi

echo ""
echo "Quality hooks installed successfully."
echo "  - SwiftLint will run on every commit"
echo "  - SwiftFormat will verify formatting on every commit"
