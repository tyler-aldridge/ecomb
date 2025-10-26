#!/bin/bash

echo "=== VERIFYING RHYTHM TUTORIAL FIXES ==="
echo ""

FILE="scripts/gameplay/battles/RhythmTutorial.gd"

if [ ! -f "$FILE" ]; then
    echo "✗ File not found: $FILE"
    exit 1
fi

echo "Checking for fixes..."
echo ""

# Check GOOD_WINDOW
if grep -q "const GOOD_WINDOW = 300.0" "$FILE"; then
    echo "✓ Hit detection fix: GOOD_WINDOW = 300.0 (CORRECT)"
else
    echo "✗ Hit detection fix: MISSING - should be 300.0"
    grep "GOOD_WINDOW" "$FILE" || echo "  (GOOD_WINDOW constant not found at all!)"
fi

# Check trainer lambda capture
if grep -q "var ts = trainer_sprite.*# Capture for lambda" "$FILE"; then
    echo "✓ Lambda fix #1: trainer_sprite captured as 'ts' (CORRECT)"
else
    echo "✗ Lambda fix #1: MISSING - trainer_sprite not captured"
fi

# Check label lambda capture
if grep -q "var lbl = label" "$FILE"; then
    echo "✓ Lambda fix #2: label captured as 'lbl' (CORRECT)"
else
    echo "✗ Lambda fix #2: MISSING - label not captured"
fi

# Check note lambda capture
if grep -q "var n = note" "$FILE" && grep -q "# Capture note in local variable for lambda" "$FILE"; then
    echo "✓ Lambda fix #3: note captured as 'n' (CORRECT)"
else
    echo "✗ Lambda fix #3: MISSING - note not captured in fade_out_note"
fi

echo ""
echo "=== RESULT ==="
if grep -q "const GOOD_WINDOW = 300.0" "$FILE" && \
   grep -q "var ts = trainer_sprite" "$FILE" && \
   grep -q "var lbl = label" "$FILE" && \
   grep -q "var n = note" "$FILE"; then
    echo "✓✓✓ ALL FIXES PRESENT - File is correct!"
    echo ""
    echo "If you're still seeing errors:"
    echo "1. Close Godot COMPLETELY (Cmd+Q)"
    echo "2. Reopen Godot"
    echo "3. Run the level again"
else
    echo "✗✗✗ FIXES MISSING - File needs update!"
    echo ""
    echo "Run this to force update:"
    echo "  curl -sf 'https://raw.githubusercontent.com/tyler-aldridge/ecomb/claude/optimize-godot-prototype-011CURQh5Jnuij8LBS6J8y1N/scripts/gameplay/battles/RhythmTutorial.gd' -o scripts/gameplay/battles/RhythmTutorial.gd"
fi
