# ECOMB Narrative Flow - Setup Guide

## Overview

This guide explains how to set up the complete opening narrative sequence in Godot 4.5.1. The flow takes players from character creation through tutorial, calibration, and into their first battle.

## Complete Scene Flow

```
Main Title
    ↓
Create Character
    ↓
Scene 1: Post-Character Creation Narration (4 messages)
    ↓
Scene 2: Tutorial Explanation (4 steps with visual highlights)
    ↓
Scene 3A: Tutorial Calibration (60 BPM with "Done" button)
    ↓
Scene 4: Pre-Battle Narrative (4 messages + Coach reveal)
    ↓
Scene 5: Lesson1Battle (existing, updated dialog)
    ↓
Scene 6: Battle Results (existing)
    ↓
Overworld
```

**Separate Flow for Options Menu:**
```
Overworld → Options Menu → Scene 3B: Calibration → Back to Options
```

---

## Scripts Created

All necessary scripts have been created in the repository:

### Core Components
- `scripts/ui/TypewriterText.gd` - Reusable typewriter text component
- `scripts/ui/narrative/NarrativeScene.gd` - Base controller for narrative scenes

### Scene Scripts
1. `scripts/ui/narrative/PostCharacterCreationScene.gd` - Scene 1
2. `scripts/ui/tutorial/TutorialExplanationScene.gd` - Scene 2
3. `scripts/ui/tutorial/TutorialCalibrationScene.gd` - Scene 3A
4. `scripts/ui/narrative/PreBattleNarrativeScene.gd` - Scene 4

### Updated Files
- `scripts/battle/data/Lesson1Data.json` - Updated dialog (Scene 5)
- `scripts/autoload/GameManager.gd` - Added tutorial tracking flags

---

## Godot Scene Setup Instructions

### Scene 1: Post-Character Creation Narration

**File:** `scenes/ui/narrative/PostCharacterCreationScene.tscn`

1. Create new scene in Godot
2. Root node: `Control`
3. Attach script: `res://scripts/ui/narrative/PostCharacterCreationScene.gd`
4. Save as: `res://scenes/ui/narrative/PostCharacterCreationScene.tscn`

**No additional nodes needed** - the script creates everything dynamically.

**Configuration in Inspector:**
- Next Scene Path: `res://scenes/tutorial/TutorialExplanationScene.tscn`
- Fade Duration: `3.0`

---

### Scene 2: Tutorial Explanation

**File:** `scenes/tutorial/TutorialExplanationScene.tscn`

1. Create new scene in Godot
2. Root node: `Control`
3. Attach script: `res://scripts/ui/tutorial/TutorialExplanationScene.gd`
4. Save as: `res://scenes/tutorial/TutorialExplanationScene.tscn`

**No additional nodes needed** - the script creates all UI dynamically.

**Configuration in Inspector:**
- Next Scene Path: `res://scenes/tutorial/TutorialCalibrationScene.tscn`
- Fade Duration: `3.0`

---

### Scene 3A: Tutorial Calibration

**File:** `scenes/tutorial/TutorialCalibrationScene.tscn`

1. Create new scene in Godot
2. Root node: `Control`
3. Attach script: `res://scripts/ui/tutorial/TutorialCalibrationScene.gd`
4. Save as: `res://scenes/tutorial/TutorialCalibrationScene.tscn`

**No additional nodes needed** - the script creates everything.

**Configuration in Inspector:**
- Next Scene Path: `res://scenes/ui/narrative/PreBattleNarrativeScene.tscn`

**Audio Setup (Optional):**
- Create a metronome audio file at 60 BPM (tone on beat 1)
- Place in `res://music/metronome_60bpm.ogg`
- TODO: Uncomment audio loading code in script (line ~177)

---

### Scene 4: Pre-Battle Narrative

**File:** `scenes/ui/narrative/PreBattleNarrativeScene.tscn`

1. Create new scene in Godot
2. Root node: `Control`
3. Attach script: `res://scripts/ui/narrative/PreBattleNarrativeScene.gd`
4. Save as: `res://scenes/ui/narrative/PreBattleNarrativeScene.tscn`

**Configuration in Inspector:**
- Next Scene Path: `res://scenes/battle/Lesson1Battle.tscn`
- Fade Duration: `3.0`

**Optional - Coach Sprite:**
1. Add child node: `AnimatedSprite2D`
2. Name it: `CoachSprite`
3. Position: `(960, 540)` (center of screen)
4. Load Coach Flex Galaxy sprite frames
5. Set animations: `idle`, `flexing`, `impossible_pose`, `victory_celebration`
6. Uncomment sprite code in script (lines ~53-59, ~62-66)

---

### Scene 5: Lesson1Battle (Existing - Updated)

**File:** `scenes/battle/Lesson1Battle.tscn` (already exists)

**Changes made:**
- `scripts/battle/data/Lesson1Data.json` - Dialog updated to narrative version
- No tutorial instructions in battle dialog anymore
- Tutorial indicators removed from battle start

**No Godot scene changes needed** - JSON data already updated.

---

### Scene 6: Battle Results (Existing - No Changes)

**File:** `scenes/ui/battle/BattleResults.tscn` (already exists)

**No changes needed** - works as-is.

---

## Scene 3B: Options Menu Calibration (Future)

This is the same as Scene 3A but accessed from overworld options menu.

**When implementing:**
1. Duplicate `TutorialCalibrationScene.tscn`
2. Save as `scenes/ui/calibration/CalibrationScene.tscn`
3. Change button text from "Done Calibrating" to "Back to Options"
4. Set next_scene_path to options menu scene

---

## Connecting the Flow

### From Character Creation → Scene 1

In your character creation scene, after player finishes:

```gdscript
# After character is created
GameManager.set_player_name(player_name)
GameManager.set_selected_character(character_choice)

# Check if returning player
if GameManager.should_skip_narrative_intro():
    # Skip to overworld or battle
    get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
else:
    # First time - start narrative flow
    get_tree().change_scene_to_file("res://scenes/ui/narrative/PostCharacterCreationScene.tscn")
```

### Scene Transitions (Automatic)

Each scene automatically transitions to the next via `next_scene_path` property. The flow is:

1. PostCharacterCreationScene → TutorialExplanationScene
2. TutorialExplanationScene → TutorialCalibrationScene
3. TutorialCalibrationScene → PreBattleNarrativeScene
4. PreBattleNarrativeScene → Lesson1Battle
5. Lesson1Battle → BattleResults
6. BattleResults → Overworld (via continue button)

---

## Testing the Flow

### Test Complete Flow

1. Start from character creation
2. Let it run through all scenes
3. Check for errors in console
4. Verify timing of typewriter text
5. Verify fade transitions (3 seconds each)
6. Test player input (click/spacebar to skip)

### Test Individual Scenes

Each scene can be tested individually:

```gdscript
# In Godot, set as main scene temporarily
# Or run via code:
get_tree().change_scene_to_file("res://scenes/tutorial/TutorialExplanationScene.tscn")
```

### Test Returning Player Flow

```gdscript
# Simulate returning player
GameManager.mark_tutorial_seen()
GameManager.mark_calibrated()

# Should skip directly to battle or overworld
if GameManager.should_skip_narrative_intro():
    print("Skipping tutorial (returning player)")
```

---

## Visual & Audio Specifications

### Backgrounds

- **Scenes 1, 2, 3A, 4:** Black background (`Color.BLACK`)
- **Scene 5:** Full Lesson1Battle environment (existing)

### Text Formatting

- **Font:** White pixel font
- **Size:** 32px (typewriter), 24px (instructions), 20px (labels)
- **Container:** 1000px max width, centered
- **Timing:** 0.03 seconds per character

### Borders & Highlights

- **Tutorial borders:** 10px thick, yellow (`Color.YELLOW`)
- **Flashing:** 0.5s fade in/out loop
- **Padding:** 100px for player sprite, 10px for other elements

### Audio

- **Scene 3A:** 60 BPM metronome (TODO: create audio file)
- **Scene 5:** 152 BPM battle track (already exists)
- **Background music:** Ambient synthwave (optional, not implemented)

---

## Calibration System Changes

### IMPORTANT: Timing Offset Slider Removed

**Removed from:**
- ❌ Pause menu during gameplay
- ❌ Main title menu
- ❌ Battle UI

**Only accessible from:**
- ✅ Tutorial Calibration (Scene 3A) - first time players
- ✅ Options Menu Calibration (Scene 3B) - returning players

**Calibration saved to:**
- `GameManager.settings["rhythm_timing_offset"]` (milliseconds)
- Automatically applied in `Conductor._process()`

---

## Tutorial State Management

### GameManager Flags

```gdscript
# Check flags
GameManager.has_seen_tutorial()  # true after Scene 2 completes
GameManager.has_calibrated()     # true after Scene 3A completes
GameManager.should_skip_narrative_intro()  # true for returning players

# Set flags (done automatically by scenes)
GameManager.mark_tutorial_seen()
GameManager.mark_calibrated()
```

### Skip Options for Returning Players

Returning players (those who have completed tutorial) can:
- Skip directly to calibration or battle
- Skip typewriter scenes with click/spacebar
- Access calibration anytime from options menu

---

## Common Issues & Solutions

### Issue: Scenes won't load

**Solution:** Check file paths match exactly:
- `res://scenes/ui/narrative/PostCharacterCreationScene.tscn`
- `res://scenes/tutorial/TutorialExplanationScene.tscn`
- `res://scenes/tutorial/TutorialCalibrationScene.tscn`
- `res://scenes/ui/narrative/PreBattleNarrativeScene.tscn`

### Issue: Typewriter text not showing

**Solution:** Check TypewriterText component:
- Label created in `_ready()`
- Text set via `set_text()` method
- Font color set to white

### Issue: Yellow borders not flashing

**Solution:** Check tween animation:
- Tween set to loop
- Alpha fading between 0.3 and 1.0
- Duration 0.5 seconds each way

### Issue: Calibration slider not working

**Solution:** Check GameManager connection:
- Slider `value_changed` signal connected
- `GameManager.set_setting()` called on change
- Settings saved automatically

### Issue: Notes spawning incorrectly in calibration

**Solution:** Check Conductor setup:
- BPM set to 60
- `sec_per_beat` calculated correctly
- `play_with_beat_offset()` called
- Notes use `setup_interpolation()` not `setup_velocity()`

---

## Performance Considerations

### Memory Usage

All scenes create UI dynamically, so:
- Small scene file sizes
- No duplicate resources
- Clean memory on scene change

### Frame Rate

- Target: 60 FPS minimum
- Fade transitions: 3 seconds (smooth at any FPS)
- Note movement: Frame-rate independent (DSP time polling)

---

## Future Enhancements

### Possible Additions

1. **Background music** - Ambient synthwave during narrative scenes
2. **Sound effects** - UI clicks, text typing sounds
3. **Coach sprite animations** - Flexing, poses triggered by beat positions
4. **Visual effects** - Particles, screen shake, camera zoom
5. **Accessibility** - Text size options, colorblind mode, skip all button

### Advanced Calibration

- Audio-based calibration (not just visual)
- Multiple BPM test patterns
- Statistical analysis of tap accuracy
- Automatic outlier removal

---

## Success Criteria

When complete, players experience:
- ✅ Smooth introduction to Muscle Beach world and tone
- ✅ Clear separation of learning (tutorial) vs performance (battle)
- ✅ Clean first battle focused on personality, not instruction
- ✅ User-controlled calibration with Done button
- ✅ Respectful UX for returning players with skip options

---

## Support & Troubleshooting

If you encounter issues:

1. Check Godot console for errors
2. Verify all scene files exist at correct paths
3. Test each scene individually
4. Check GameManager flags in debugger
5. Verify JSON data loaded correctly

For architecture questions, see:
- `ARCHITECTURE_CHANGES.md` - Core rhythm system documentation
- `scripts/ui/TypewriterText.gd` - Component documentation
- `scripts/ui/narrative/NarrativeScene.gd` - Base scene documentation

---

## Quick Start Checklist

- [ ] Create Scene 1: PostCharacterCreationScene.tscn
- [ ] Create Scene 2: TutorialExplanationScene.tscn
- [ ] Create Scene 3A: TutorialCalibrationScene.tscn
- [ ] Create Scene 4: PreBattleNarrativeScene.tscn
- [ ] Test Scene 1 → verify typewriter effect
- [ ] Test Scene 2 → verify yellow borders
- [ ] Test Scene 3A → verify calibration slider
- [ ] Test Scene 4 → verify fade transitions
- [ ] Test complete flow → character creation to battle
- [ ] Test returning player skip → verify flags work
- [ ] Verify battle dialog updated → no tutorial instructions
- [ ] Verify calibration removed → no slider in pause menu

**When all checked, the narrative flow is complete!**
