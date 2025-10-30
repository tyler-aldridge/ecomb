#!/usr/bin/env python3
"""
Recalculate all beat_position values in Lesson1Data.json using Bar/Beat as source of truth.
Formula: beat_position = (bar - 1) * ticks_per_bar + (beat - 1) * subdivision
For 4/4: ticks_per_bar = 8, subdivision = 2
For whole notes: add +12 offset so bottom touches hitzone top at original Bar/Beat time
"""

import json

# Time signature info for 4/4
beats_per_bar = 4
subdivision = 2
ticks_per_bar = beats_per_bar * subdivision  # 8

def bar_beat_to_position(bar, beat):
    """Convert Bar/Beat notation to beat_position (HIT time)."""
    beat_num = 0.0

    # Parse beat notation
    if isinstance(beat, str):
        if beat.endswith('a'):
            # AND note: "1a", "2a", etc.
            base_beat = int(beat[:-1])
            beat_num = float(base_beat) + 0.5
        else:
            beat_num = float(beat)
    else:
        beat_num = float(beat)

    # Calculate beat position using NEW formula (audio position 0.0 = beat 0)
    base_pos = (bar - 1) * ticks_per_bar + (int(beat_num) - 1) * subdivision

    # Add 1 tick for AND notes
    if beat_num != int(beat_num):
        base_pos += 1

    return int(base_pos)

# Load JSON
with open('/home/user/ecomb/scripts/battle/data/Lesson1Data.json', 'r') as f:
    data = json.load(f)

# Recalculate all beat_positions
whole_note_offset = 12  # +12 beats so bottom touches hitzone top at Bar/Beat time
changes_count = 0

for note in data['notes']:
    bar = note['bar']
    beat = note['beat']
    note_type = note.get('note', 'quarter')

    # Calculate base position from Bar/Beat (source of truth)
    base_position = bar_beat_to_position(bar, beat)

    # Apply offset for whole notes (bottom-touch alignment)
    # All other notes use center alignment (no offset)
    if note_type == 'whole':
        new_position = base_position + whole_note_offset
    else:
        new_position = base_position

    # Track changes
    old_position = note.get('beat_position', -1)
    if old_position != new_position:
        print(f"Bar {bar} Beat {beat} ({note_type}): {old_position} → {new_position}")
        changes_count += 1

    note['beat_position'] = new_position

print(f"\nTotal changes: {changes_count}")
print(f"Total notes processed: {len(data['notes'])}")

# Save with nice formatting
with open('/home/user/ecomb/scripts/battle/data/Lesson1Data.json', 'w') as f:
    json.dump(data, f)

print("\n✓ All beat_positions recalculated using Bar/Beat as source of truth")
print("✓ Whole notes: +12 offset (bottom-touch alignment)")
print("✓ All other notes: center alignment (no offset)")
