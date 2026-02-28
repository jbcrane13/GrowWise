#!/usr/bin/env bash
# GrowWise devcontainer post-create setup
# Installs tooling available in the Swift Linux container.
# Note: Xcode/iOS Simulator are not available in containers.
# Use this environment for: lint, format, swift test, CI scripting.

set -e

echo "Setting up GrowWise development environment..."

# Install SwiftLint (Linux binary)
if ! command -v swiftlint &>/dev/null; then
  echo "Installing SwiftLint..."
  SWIFTLINT_VERSION="0.57.0"
  curl -L "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/swiftlint_linux.zip" \
    -o /tmp/swiftlint.zip
  unzip -q /tmp/swiftlint.zip -d /tmp/swiftlint
  sudo mv /tmp/swiftlint/swiftlint /usr/local/bin/swiftlint
  rm -rf /tmp/swiftlint /tmp/swiftlint.zip
  echo "SwiftLint $(swiftlint version) installed."
fi

# Install jscpd for duplicate code detection
if ! command -v jscpd &>/dev/null; then
  echo "Installing jscpd..."
  npm install -g jscpd --silent
fi

# Install bd (beads) for issue tracking
if ! command -v bd &>/dev/null; then
  echo "Note: Install beads manually: https://github.com/nicholasgasior/beads"
  echo "  brew install beads  (on macOS)"
fi

# Install git hooks
chmod +x scripts/install-hooks.sh scripts/hooks/pre-commit-quality
echo "Run './scripts/install-hooks.sh' to activate quality pre-commit hooks."

echo ""
echo "Environment ready. Available commands:"
echo "  cd GrowWisePackage && swift test        # Run tests"
echo "  swiftlint lint --config .swiftlint.yml  # Lint"
echo "  ./scripts/check-unused-deps.sh          # Check unused SPM deps"
echo "  bd show                                 # View open issues"
