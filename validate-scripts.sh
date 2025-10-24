#!/bin/bash

# GDScript validation script
# Checks for parse errors in modified GDScript files before committing

set -e

echo "======================================"
echo "Validating GDScript files..."
echo "======================================"

# Find Godot executable
GODOT=""
if command -v godot &> /dev/null; then
    GODOT="godot"
elif command -v godot4 &> /dev/null; then
    GODOT="godot4"
elif [ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
    echo "ERROR: Godot executable not found!"
    echo "Please install Godot or set the path manually in this script."
    exit 1
fi

echo "Using Godot: $GODOT"
echo ""

# Get list of modified .gd files
MODIFIED_FILES=$(git diff --name-only HEAD | grep '\.gd$' || true)
STAGED_FILES=$(git diff --cached --name-only | grep '\.gd$' || true)
ALL_FILES=$(echo -e "$MODIFIED_FILES\n$STAGED_FILES" | sort -u | grep -v '^$' || true)

if [ -z "$ALL_FILES" ]; then
    echo "No GDScript files to validate."
    exit 0
fi

echo "Checking files:"
echo "$ALL_FILES"
echo ""

# Run Godot headless to check for errors
echo "Running Godot script check..."
$GODOT --headless --check-only --script-check 2>&1 | tee /tmp/godot-validation.log

# Check if there were any errors
if grep -q "ERROR\|Parse Error" /tmp/godot-validation.log; then
    echo ""
    echo "======================================"
    echo "VALIDATION FAILED!"
    echo "Fix the errors above before committing."
    echo "======================================"
    exit 1
else
    echo ""
    echo "======================================"
    echo "Validation passed!"
    echo "All GDScript files are error-free."
    echo "======================================"
    exit 0
fi
