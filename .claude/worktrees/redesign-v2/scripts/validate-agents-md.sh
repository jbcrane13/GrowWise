#!/usr/bin/env sh
# Validates that AGENTS.md references are consistent with the actual codebase.
# Checks: file paths, config files, directory structure, tool configs.
# Exit code 1 if any critical reference is broken.
#
# Usage: ./scripts/validate-agents-md.sh

set -e

AGENTS_FILE="AGENTS.md"
ERRORS=0
WARNINGS=0

if [ ! -f "$AGENTS_FILE" ]; then
    echo "ERROR: $AGENTS_FILE not found"
    exit 1
fi

echo "Validating AGENTS.md references..."
echo ""

# --- 1. Validate file path references ---
# Extract backtick-quoted paths that look like file/directory references
echo "=== File & Directory References ==="

check_path() {
    local path="$1"
    local context="$2"
    # Skip paths that are clearly not filesystem refs
    case "$path" in
        *"@"*|*"("*|*"{"*|*.self|*"#"*) return ;;
        *.swift|*.yml|*.yaml|*.json|*.md|*.plist|*.example)
            if [ ! -f "$path" ]; then
                echo "  ERROR: File not found: $path"
                echo "    Context: $context"
                ERRORS=$((ERRORS + 1))
            else
                echo "  OK: $path"
            fi
            ;;
    esac
}

# Check explicitly referenced config files
for config in .swiftlint.yml .swiftformat .env.example; do
    case "$config" in
        .env.example)
            # .env.example is optional
            if grep -q "$config" "$AGENTS_FILE" 2>/dev/null; then
                if [ ! -f "$config" ]; then
                    echo "  WARNING: Referenced config not found: $config"
                    WARNINGS=$((WARNINGS + 1))
                else
                    echo "  OK: $config"
                fi
            fi
            ;;
        *)
            if grep -q "$config" "$AGENTS_FILE" 2>/dev/null; then
                if [ ! -f "$config" ]; then
                    echo "  ERROR: Referenced config not found: $config"
                    ERRORS=$((ERRORS + 1))
                else
                    echo "  OK: $config"
                fi
            fi
            ;;
    esac
done

# Extract file paths from AGENTS.md that look like Swift/config file references
# Matches patterns like: `GrowWisePackage/Sources/.../File.swift`
REFERENCED_FILES=$(grep -oE '`[A-Za-z0-9_./-]+\.(swift|yml|yaml|json|md|plist)`' "$AGENTS_FILE" \
    | tr -d '`' \
    | grep '/' \
    | sort -u)

for ref_file in $REFERENCED_FILES; do
    # Try the path as-is first
    if [ -f "$ref_file" ]; then
        echo "  OK: $ref_file"
    # Try prefixing with GrowWisePackage/Sources/ for short paths
    elif [ -f "GrowWisePackage/Sources/$ref_file" ]; then
        echo "  OK: $ref_file (found at GrowWisePackage/Sources/$ref_file)"
    else
        # Check if it's a relative path reference (e.g., GrowWiseFeature/Views/)
        FOUND=$(find . -path "*/$ref_file" -not -path "./.build/*" -not -path "./.git/*" 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            echo "  OK: $ref_file (resolved to $FOUND)"
        else
            echo "  ERROR: Referenced file not found: $ref_file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

echo ""

# --- 2. Validate directory structure ---
echo "=== Directory Structure ==="

for dir in \
    "GrowWise" \
    "GrowWisePackage/Sources/GrowWiseModels" \
    "GrowWisePackage/Sources/GrowWiseServices" \
    "GrowWisePackage/Sources/GrowWiseFeature" \
    "GrowWisePackage/Sources/GrowWiseFeature/Design" \
    "GrowWisePackage/Sources/GrowWiseFeature/Views" \
    "GrowWisePackage/Sources/GrowWiseFeature/Views/Garden" \
    "GrowWisePackage/Sources/GrowWiseFeature/Components" \
    "GrowWisePackage/Sources/GrowWiseFeature/OnboardingFlow" \
    "GrowWisePackage/Sources/GrowWiseFeature/Main" \
    "GrowWisePackage/Tests/GrowWiseModelsTests" \
    "GrowWisePackage/Tests/GrowWiseServicesTests" \
    "GrowWisePackage/Tests/GrowWiseFeatureTests" \
    "docs"; do
    if [ ! -d "$dir" ]; then
        echo "  ERROR: Referenced directory not found: $dir"
        ERRORS=$((ERRORS + 1))
    else
        echo "  OK: $dir/"
    fi
done

echo ""

# --- 3. Validate CI workflow references ---
echo "=== CI Workflow References ==="

for workflow in \
    ".github/workflows/ci.yml" \
    ".github/workflows/deploy.yml"; do
    if grep -q "$(basename "$workflow")" "$AGENTS_FILE" 2>/dev/null; then
        if [ ! -f "$workflow" ]; then
            echo "  ERROR: Referenced workflow not found: $workflow"
            ERRORS=$((ERRORS + 1))
        else
            echo "  OK: $workflow"
        fi
    fi
done

echo ""

# --- 4. Validate Package.swift targets match AGENTS.md claims ---
echo "=== Package Targets ==="

PACKAGE_FILE="GrowWisePackage/Package.swift"
if [ -f "$PACKAGE_FILE" ]; then
    for target in GrowWiseFeature GrowWiseModels GrowWiseServices; do
        if grep -q "name: \"$target\"" "$PACKAGE_FILE"; then
            echo "  OK: Target $target exists in Package.swift"
        else
            echo "  ERROR: Target $target referenced in AGENTS.md but not in Package.swift"
            ERRORS=$((ERRORS + 1))
        fi
    done

    for test_target in GrowWiseFeatureTests GrowWiseModelsTests GrowWiseServicesTests; do
        if grep -q "name: \"$test_target\"" "$PACKAGE_FILE"; then
            echo "  OK: Test target $test_target exists in Package.swift"
        else
            echo "  WARNING: Test target $test_target referenced in AGENTS.md but not in Package.swift"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
else
    echo "  ERROR: Package.swift not found at $PACKAGE_FILE"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# --- 5. Validate tool availability claims ---
echo "=== Tool Configuration ==="

# Check SwiftLint config has rules mentioned in AGENTS.md
if [ -f ".swiftlint.yml" ]; then
    if grep -q "cyclomatic_complexity" .swiftlint.yml; then
        echo "  OK: SwiftLint cyclomatic_complexity rule configured"
    else
        echo "  WARNING: AGENTS.md references cyclomatic_complexity but rule not in .swiftlint.yml"
        WARNINGS=$((WARNINGS + 1))
    fi
    if grep -q "file_length" .swiftlint.yml; then
        echo "  OK: SwiftLint file_length rule configured"
    else
        echo "  WARNING: file_length rule not in .swiftlint.yml"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check SwiftFormat config exists
if [ -f ".swiftformat" ]; then
    echo "  OK: .swiftformat config present"
else
    echo "  ERROR: AGENTS.md references .swiftformat but file not found"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# --- 6. Check for referenced doc files ---
echo "=== Documentation References ==="

for doc_ref in \
    "docs/architecture/CLAUDE.md" \
    "docs/architecture/ADR.md" \
    "docs/product/gardening-app-prd.md"; do
    if grep -q "$doc_ref" "$AGENTS_FILE" 2>/dev/null; then
        if [ ! -f "$doc_ref" ]; then
            echo "  WARNING: Referenced doc not found: $doc_ref"
            WARNINGS=$((WARNINGS + 1))
        else
            echo "  OK: $doc_ref"
        fi
    fi
done

echo ""

# --- Summary ---
echo "==============================="
echo "Validation complete"
echo "  Errors:   $ERRORS"
echo "  Warnings: $WARNINGS"
echo "==============================="

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "FAIL: $ERRORS error(s) found. AGENTS.md references are out of sync with the codebase."
    exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "PASS with warnings: $WARNINGS warning(s). Consider updating AGENTS.md."
fi

exit 0
