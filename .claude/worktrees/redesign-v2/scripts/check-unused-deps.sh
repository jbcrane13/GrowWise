#!/usr/bin/env sh
# Check for unused Swift Package Manager dependencies
# Scans all source files and reports packages with no import sites.
#
# Usage: ./scripts/check-unused-deps.sh
# CI:    Called by .github/workflows/deps.yml

set -e

PACKAGE_DIR="${1:-GrowWisePackage}"
SOURCE_DIRS="$PACKAGE_DIR/Sources"

if [ ! -f "$PACKAGE_DIR/Package.swift" ]; then
  echo "ERROR: Package.swift not found in $PACKAGE_DIR"
  exit 1
fi

echo "Checking for unused SPM dependencies in $PACKAGE_DIR..."

# Extract declared dependency product names from Package.swift
# Matches: .product(name: "SomeName", ...)
DECLARED=$(grep -oE 'name:\s*"[^"]+"' "$PACKAGE_DIR/Package.swift" \
  | grep -oE '"[^"]+"' \
  | tr -d '"' \
  | sort -u)

if [ -z "$DECLARED" ]; then
  echo "No external dependency products found in Package.swift."
  exit 0
fi

UNUSED_COUNT=0
USED_COUNT=0

for DEP in $DECLARED; do
  # Check if any Swift source file imports this dependency
  IMPORT_COUNT=$(grep -r "import $DEP" "$SOURCE_DIRS" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$IMPORT_COUNT" -eq 0 ]; then
    echo "UNUSED: $DEP (no 'import $DEP' found in $SOURCE_DIRS)"
    UNUSED_COUNT=$((UNUSED_COUNT + 1))
  else
    USED_COUNT=$((USED_COUNT + 1))
  fi
done

echo ""
echo "Results: $USED_COUNT used, $UNUSED_COUNT potentially unused"

if [ "$UNUSED_COUNT" -gt 0 ]; then
  echo "Review unused dependencies — they may be transitive or use a different import name."
  exit 0  # Warning only, not a hard failure (transitive deps may not have direct imports)
fi

echo "All declared dependencies have import sites."
