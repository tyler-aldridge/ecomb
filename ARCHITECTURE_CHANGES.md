# Rhythm Game Architecture Refactor - Industry Standard Implementation

## Summary
This refactor implements industry-standard rhythm game timing architecture based on DSP (Digital Signal Processing) time as the single source of truth. This replaces the previous frame-dependent velocity-based system with a self-correcting position interpolation system.

## Core Architectural Changes

### 1. **Conductor.gd - DSP Time Authority**
**Location:** `scripts/ui/battle/Conductor.gd`

**Changes:**
- **Changed base class:** `AudioStreamPlayer` → `Node`
- **Music player:** Now a child `AudioStreamPlayer` node instead of extending it
- **Removed:** Beat signals (frame-rate dependent)
- **Added:** DSP time polling with validation
- **Exposed:** `song_pos_in_beats` as a variable for polling (not signals)
- **Added:** Web platform validation to handle corrupted timing values
- **Improved:** Pause/resume handling with proper state management

**Key Benefits:**
- Frame-rate independent timing
- Self-correcting (no drift over time)
- Handles frame drops gracefully
- Web platform compatible with validation

**API Changes:**
```gdscript
# OLD (signal-based)
conductor.beat.connect(_on_beat)

# NEW (polling-based)
var current_beat = conductor.song_pos_in_beats
```

---

### 2. **Note.gd - Position Interpolation**
**Location:** `scripts/ui/battle/Note.gd`

**Changes:**
- **Removed:** Velocity-based movement (`position.y += speed * delta`)
- **Added:** Position interpolation from beat progress
- **Formula:** `position.y = lerp(spawn_y, target_y, progress)`
- **Progress:** `1.0 - (beats_until_hit / beats_shown_in_advance)`

**Key Benefits:**
- Self-correcting on every frame
- No accumulation errors
- Frame drops immediately corrected
- Works identically at any framerate (30fps, 60fps, 144fps)

**API Changes:**
```gdscript
# OLD (velocity setup)
note.setup_velocity(lane, beat_pos, type, conductor, spawn_y, target_y, fall_time)

# NEW (interpolation setup)
note.setup_interpolation(lane, note_beat, type, conductor, spawn_y, target_y, beats_advance)
```

---

### 3. **Lesson1Battle.gd - Polling-Based Spawning**
**Location:** `scripts/battle/levels/Lesson1Battle.gd`

**Changes:**
- **Removed:** Beat signal connection
- **Added:** `spawn_notes_polling()` - checks conductor every frame
- **Added:** `process_events_polling()` - handles dialogue/triggers
- **Added:** `spawn_note_interpolation()` - spawns with new system
- **Uses:** While loops to catch up if frames dropped

**Key Benefits:**
- No signal overhead
- Catches up automatically on frame drops
- Direct polling is more reliable
- Events trigger precisely when they should

**Code Pattern:**
```gdscript
func _physics_process(_delta):
    if conductor:
        spawn_notes_polling()

func spawn_notes_polling():
    var current_beat = conductor.song_pos_in_beats
    while next_note_index < sorted_notes.size():
        var note_beat = sorted_notes[next_note_index].beat_position
        if note_beat <= current_beat + BattleManager.FALL_BEATS:
            spawn_note_interpolation(note_data)
            next_note_index += 1
        else:
            break
```

---

### 4. **DataImporter.gd - Timing Utilities**
**Location:** `scripts/autoload/DataImporter.gd`

**New Utility Class:**
- Converts bar/beat notation to ticks
- Converts ticks to floating-point beats
- Validates timing data
- Supports MIDI PPQ conversion (for future Logic Pro import)

**Usage:**
```gdscript
var ticks = DataImporter.bar_beat_to_ticks(8, 1, 4, 2)  # Bar 8 Beat 1 in 4/4
var beats = DataImporter.ticks_to_beats(56, 2)  # Convert 56 ticks to beats
```

---

### 5. **CalibrationScene.gd - Pre-Game Timing**
**Location:** `scripts/ui/CalibrationScene.gd`

**New Scene:**
- Pre-game calibration only (never mid-game)
- Visual metronome at 120 BPM
- Player taps in rhythm
- Calculates average offset
- Saves to GameManager
- Removes outliers (>150ms)

**Industry Standard Approach:**
- Calibrate once before gameplay
- Never adjust mid-game (causes visual discontinuity)
- Let player recalibrate from settings menu

---

## Data Format (No Changes Required)

The current tick-based format is **compatible** with the new system:

```json
{
  "bar": 8,
  "beat": 1,
  "beat_position": 56,
  "note": "whole"
}
```

**Why it works:**
- `beat_position` is in ticks (subdivision units)
- Conductor's `song_pos_in_beats` is also in ticks
- Direct comparison: `note_beat <= current_beat + advance`

**Future format (for reference):**
```json
{
  "beat": 23.5,
  "lane": 2,
  "type": "tap"
}
```

---

## Testing Checklist

### Frame Rate Independence
- [ ] Run at 30fps - timing should be perfect
- [ ] Run at 60fps - timing identical to 30fps
- [ ] Run at 144fps - timing identical
- [ ] Run uncapped - no variation despite framerate changes

### Error Recovery
- [ ] Induce lag spike (load heavy file) - notes recover immediately
- [ ] Drop frames artificially - no desync
- [ ] Pause mid-song - notes freeze in place
- [ ] Resume - notes continue smoothly

### Drift Testing
- [ ] Play 5+ minute song - less than 50ms drift at end
- [ ] Compare to external metronome

### Web Platform
- [ ] Scene transitions don't break audio
- [ ] Pause/resume works correctly
- [ ] Timing values never exceed 1000 seconds
- [ ] No backwards time movement

---

## Migration Guide for Other Battle Scenes

If you have other battle scenes besides Lesson1Battle:

### Step 1: Update Conductor References
```gdscript
# Remove signal connection
# conductor.beat.connect(_on_beat)  # DELETE THIS

# Add polling in _physics_process
func _physics_process(_delta):
    if conductor:
        spawn_notes_polling()
```

### Step 2: Implement Polling Spawn
```gdscript
func spawn_notes_polling():
    var current_beat = conductor.song_pos_in_beats
    while next_note_index < sorted_notes.size():
        var note_data = sorted_notes[next_note_index]
        if note_data.beat_position <= current_beat + advance:
            spawn_note_interpolation(note_data)
            next_note_index += 1
        else:
            break
```

### Step 3: Update Note Spawning
```gdscript
# OLD
note.setup_velocity(lane, beat, type, conductor, spawn_y, target_y, fall_time)

# NEW
note.setup_interpolation(lane, beat, type, conductor, spawn_y, target_y, beats_advance)
```

---

## Backward Compatibility

### Legacy Support Maintained
- `conductor.stream` property (getter/setter)
- `conductor.playing` property (getter)
- `conductor.stream_paused` property (getter/setter)
- `conductor.seconds_per_beat` property (getter/setter)
- `conductor.song_position_in_beats_float` (tick-based)
- `conductor.song_position_in_beats` (integer ticks)
- `note.setup_velocity()` (converts to interpolation)

### Removed (No Longer Needed)
- `conductor.beat` signal
- `conductor.measure` signal
- `_report_beat()` function
- Velocity-based note movement

---

## Performance Improvements

1. **No Signal Overhead:** Direct polling is faster than signal emission/connection
2. **Self-Correcting:** No manual resync logic needed
3. **Frame Drop Resilience:** While loops catch up automatically
4. **Web Platform:** Validation prevents corruption crashes

---

## Known Limitations

### Godot-Specific Issues
1. **No Audio Scheduling API:** Cannot schedule sample-accurate playback like Unity
2. **Web Audio Corruption:** `get_time_since_last_mix()` sometimes returns invalid values
3. **Buffer-Based Updates:** Position updates in chunks, not continuously
4. **Latency Inaccuracy:** `get_output_latency()` often incorrect

### Solutions Implemented
- Aggressive validation for web platform
- Fallback timing recovery
- Player calibration compensates for latency
- Smooth interpolation masks buffer updates

---

## References

- Industry Best Practices: DDRKirby's Rhythm Quest devlog
- Godot Audio Issues: GitHub issues #43833, #52767, #38946
- Clone Hero: Open source reference implementation
- Unity Comparison: AudioSource.PlayScheduled() vs Godot's approach

---

## Future Enhancements

### Potential Improvements
1. **Multiple BPM Support:** Handle BPM changes mid-song
2. **Pure Beat-Based Format:** Migrate from ticks to floating-point beats
3. **Advanced Calibration:** Audio-based calibration (not just visual)
4. **Timing Window Profiles:** Different difficulty presets
5. **Replay System:** Record and playback inputs

### Consider Unity If
- Serious web deployment required
- Mobile platform is primary target
- Sample-accurate scheduling needed
- 100+ song library planned

Godot works fine for desktop rhythm games but has significant web/mobile limitations.

---

## Author Notes

This architecture follows industry standards from professional rhythm games:
- Guitar Hero, Rock Band, DDR
- Clone Hero (open source)
- Stepmania
- Rhythm Quest (indie reference)

The old velocity-based approach accumulates errors and breaks under stress. Position interpolation is self-correcting and frame-rate independent - this is the professional approach used in all modern rhythm games.

**TL;DR:** DSP time is truth. Calculate position every frame. Never accumulate velocity.
