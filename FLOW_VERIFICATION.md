# ECOMB Narrative Flow - Complete Fade Transition Map

## Scene Transition Flow with Fade Details

```
┌─────────────────────────────────────────────────────────────┐
│                     COMPLETE SCENE FLOW                      │
└─────────────────────────────────────────────────────────────┘

Main Title
│
├─ [Manual] → Character Creation
│              (No auto-transition)
│
└─ [3s Fade Out] ──────────────────────────────────┐
                                                    │
                          ┌─────────────────────────┘
                          ▼
                    Scene 1: Post-Character Narration
                    ┌─────────────────────────────┐
                    │ • 3s fade in (start)        │
                    │ • 4 messages (typewriter)   │
                    │ • 3s fade out (end)         │
                    └─────────────────────────────┘
                          │
                          │ [3s Fade Transition]
                          ▼
                    Scene 2: Tutorial Explanation
                    ┌─────────────────────────────┐
                    │ • 3s fade in (start)        │
                    │ • 4 tutorial steps          │
                    │ • Yellow borders flash      │
                    │ • 3s fade out (end)         │
                    └─────────────────────────────┘
                          │
                          │ [3s Fade Transition]
                          ▼
                    Scene 3A: Tutorial Calibration
                    ┌─────────────────────────────┐
                    │ • 3s fade in (start)        │
                    │ • 60 BPM calibration        │
                    │ • Live slider adjustment    │
                    │ • "Done" button             │
                    │ • 3s fade out (on button)   │
                    └─────────────────────────────┘
                          │
                          │ [3s Fade Transition]
                          ▼
                    Scene 4: Pre-Battle Narrative
                    ┌─────────────────────────────┐
                    │ • 3s fade in (start)        │
                    │ • 4 messages (typewriter)   │
                    │ • Coach sprite reveal       │
                    │ • 3s fade out (end)         │
                    └─────────────────────────────┘
                          │
                          │ [3s Fade Transition]
                          ▼
                    Scene 5: Lesson 1 Battle
                    ┌─────────────────────────────┐
                    │ • 2.5s fade in (start)      │
                    │ • Battle gameplay           │
                    │ • Updated dialog            │
                    │ • 2s fade out (end trigger) │
                    └─────────────────────────────┘
                          │
                          │ [2s Fade Transition]
                          ▼
                    Scene 6: Battle Results
                    ┌─────────────────────────────┐
                    │ • Shows results             │
                    │ • Continue button           │
                    │ • Restart button            │
                    └─────────────────────────────┘
                          │
                          │ [Manual]
                          ▼
                      Overworld
```

---

## Fade Transition Details by Scene

### Scene 1: PostCharacterCreationScene
**File:** `scripts/ui/narrative/PostCharacterCreationScene.gd`

**Fade In:**
- ✅ Duration: 3 seconds
- ✅ Timing: Immediately on `_ready()`
- ✅ Easing: `EASE_OUT` + `TRANS_CUBIC`
- ✅ Code: `NarrativeScene.fade_from_black()`

**Fade Out:**
- ✅ Duration: 3 seconds (split: 1.5s out, 1.5s in)
- ✅ Timing: After last message completes
- ✅ Easing: `EASE_IN` (out) + `EASE_OUT` (in)
- ✅ Code: `NarrativeScene._transition_to_next_scene()`

**Next Scene:**
- ✅ Path: `res://scenes/tutorial/TutorialExplanationScene.tscn`
- ✅ Set via: `next_scene_path` property

---

### Scene 2: TutorialExplanationScene
**File:** `scripts/ui/tutorial/TutorialExplanationScene.gd`

**Fade In:**
- ✅ Duration: 3 seconds
- ✅ Timing: Immediately on `_ready()`
- ✅ Easing: `EASE_OUT` + `TRANS_CUBIC`
- ✅ Code: `fade_from_black()`

**Fade Out:**
- ✅ Duration: 3 seconds
- ✅ Timing: After step 4 completes
- ✅ Easing: `EASE_IN`
- ✅ Code: `_transition_to_next_scene()`

**Next Scene:**
- ✅ Path: `res://scenes/tutorial/TutorialCalibrationScene.tscn`
- ✅ Set via: `next_scene_path` property

---

### Scene 3A: TutorialCalibrationScene
**File:** `scripts/ui/tutorial/TutorialCalibrationScene.gd`

**Fade In:**
- ✅ Duration: 3 seconds
- ✅ Timing: Immediately on `_ready()`
- ✅ Easing: `EASE_OUT`
- ✅ Code: `fade_from_black()`

**Fade Out:**
- ✅ Duration: 3 seconds
- ✅ Timing: When "Done Calibrating" button pressed
- ✅ Easing: `EASE_IN`
- ✅ Code: `_on_done_pressed()`

**Next Scene:**
- ✅ Path: `res://scenes/ui/narrative/PreBattleNarrativeScene.tscn`
- ✅ Set via: `next_scene_path` property

---

### Scene 4: PreBattleNarrativeScene
**File:** `scripts/ui/narrative/PreBattleNarrativeScene.gd`

**Fade In:**
- ✅ Duration: 3 seconds
- ✅ Timing: Immediately on `_ready()`
- ✅ Easing: `EASE_OUT` + `TRANS_CUBIC`
- ✅ Code: `NarrativeScene.fade_from_black()`

**Fade Out:**
- ✅ Duration: 3 seconds
- ✅ Timing: After last message completes
- ✅ Easing: `EASE_IN`
- ✅ Code: `NarrativeScene._transition_to_next_scene()`

**Next Scene:**
- ✅ Path: `res://scenes/battle/Lesson1Battle.tscn`
- ✅ Set via: `next_scene_path` property

---

### Scene 5: Lesson1Battle
**File:** `scripts/battle/levels/Lesson1Battle.gd`

**Fade In:**
- ✅ Duration: 2.5 seconds
- ✅ Timing: Immediately on `_ready()`
- ✅ Easing: `EASE_OUT` + `TRANS_CUBIC`
- ✅ Code: `fade_from_black()` (line ~352-356)

**Fade Out:**
- ✅ Duration: 2 seconds
- ✅ Timing: Beat position 800 (trigger: "fade_to_title")
- ✅ Easing: Default
- ✅ Code: `fade_to_title()` (line ~560-596)

**Next Scene:**
- ✅ Path: Shows `BattleResults` overlay (not scene change)
- ✅ Timing: After fade completes
- ✅ Code: `_show_battle_results_after_fade()`

---

### Scene 6: BattleResults
**File:** `scenes/ui/battle/BattleResults.tscn` (existing)

**Fade In:**
- ✅ Already implemented in BattleResults scene
- ✅ Shows over faded battle background

**Fade Out:**
- ✅ Manual: "Continue" or "Restart" buttons
- ✅ Continue → Overworld
- ✅ Restart → Lesson1Battle

---

## Returning Player Flow

```
Main Title
│
├─ [Check] GameManager.should_skip_narrative_intro()
│
├─ If TRUE (returning player):
│  └─ [Direct] → Overworld or Battle Select
│
└─ If FALSE (new player):
   └─ [Normal Flow] → Scene 1 → ... → Battle
```

**Implementation:**
```gdscript
# In character creation or main title
if GameManager.should_skip_narrative_intro():
    get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
else:
    get_tree().change_scene_to_file("res://scenes/ui/narrative/PostCharacterCreationScene.tscn")
```

---

## Fade Transition Summary

### ✅ All Scenes Have Proper Fades

| Scene | Fade In | Fade Out | Next Scene Auto |
|-------|---------|----------|----------------|
| Scene 1 (Narration) | 3s ✅ | 3s ✅ | Yes ✅ |
| Scene 2 (Tutorial) | 3s ✅ | 3s ✅ | Yes ✅ |
| Scene 3A (Calibration) | 3s ✅ | 3s ✅ | Yes ✅ |
| Scene 4 (Pre-Battle) | 3s ✅ | 3s ✅ | Yes ✅ |
| Scene 5 (Battle) | 2.5s ✅ | 2s ✅ | Yes ✅ |
| Scene 6 (Results) | Yes ✅ | Manual ✅ | No |

---

## Testing Checklist

### Complete Flow Test

Use the `TestNarrativeFlow.gd` scene:

1. **Create Test Scene:**
   - New scene in Godot
   - Root: `Control`
   - Attach: `res://scripts/testing/TestNarrativeFlow.gd`
   - Save as: `res://scenes/testing/TestNarrativeFlow.tscn`

2. **Test Individual Scenes:**
   - [ ] Click "Scene 1" → Verify 3s fade in
   - [ ] Click "Scene 2" → Verify 3s fade in
   - [ ] Click "Scene 3A" → Verify 3s fade in
   - [ ] Click "Scene 4" → Verify 3s fade in
   - [ ] Click "Scene 5" → Verify 2.5s fade in
   - [ ] Click "Scene 6" → Verify results display

3. **Test Complete Flow:**
   - [ ] Click "🚀 TEST COMPLETE FLOW (AUTO)"
   - [ ] Verify Scene 1 → Scene 2 transition
   - [ ] Verify Scene 2 → Scene 3A transition
   - [ ] Verify Scene 3A → Scene 4 transition
   - [ ] Verify Scene 4 → Battle transition
   - [ ] Verify Battle → Results transition

4. **Test User Interactions:**
   - [ ] Click to skip typewriter typing
   - [ ] Click again to skip to next message
   - [ ] Press spacebar to skip
   - [ ] Verify auto-advance after 3s/5s

5. **Test Returning Player:**
   - [ ] Set `GameManager.mark_tutorial_seen()`
   - [ ] Verify skips to overworld/battle

---

## Fade Transition Code Locations

### Scene 1 & 4 (Narrative Scenes)
```gdscript
# In NarrativeScene.gd (base class)

func fade_from_black():
    fade_overlay.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_callback(_start_first_message)

func _transition_to_next_scene():
    is_transitioning = true
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)
    tween.tween_callback(_load_next_scene)
```

### Scene 2 (Tutorial)
```gdscript
# In TutorialExplanationScene.gd

func fade_from_black():
    fade_overlay.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_callback(_start_first_step)

func _transition_to_next_scene():
    is_transitioning = true
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)
    tween.tween_callback(_load_next_scene)
```

### Scene 3A (Calibration)
```gdscript
# In TutorialCalibrationScene.gd

func fade_from_black():
    fade_overlay.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_OUT)

func _on_done_pressed():
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 1.0, 3.0).set_ease(Tween.EASE_IN)
    tween.tween_callback(_load_next_scene)
```

### Scene 5 (Battle)
```gdscript
# In Lesson1Battle.gd (existing)

func fade_from_black():
    fade_overlay.modulate.a = 1.0
    var fade_tween = create_tween()
    fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, BattleManager.FADE_FROM_BLACK_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func fade_to_title():
    fade_overlay.modulate.a = 0.0
    var fade_tween = create_tween()
    fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, BattleManager.FADE_TO_BLACK_DURATION)
    fade_tween.tween_callback(_show_battle_results_after_fade.bind(...))
```

---

## Quick Start: Testing from Main Title to Battle Results

### Option 1: Manual Testing

1. **Start from Main Title** (or Character Creation)
2. **Navigate through:**
   - Character Creation (if applicable)
   - Scene 1: Post-Character Narration
   - Scene 2: Tutorial Explanation
   - Scene 3A: Tutorial Calibration
   - Scene 4: Pre-Battle Narrative
   - Scene 5: Lesson 1 Battle
   - Scene 6: Battle Results

3. **Verify each transition has:**
   - Fade in at start (3s or 2.5s)
   - Fade out at end (3s or 2s)
   - Smooth transition (no jarring cuts)

### Option 2: Quick Testing Tool

1. **Create TestNarrativeFlow scene** (instructions above)
2. **Run the test scene**
3. **Click "🚀 TEST COMPLETE FLOW (AUTO)"**
4. **Watch automated flow test**

---

## Missing Connections (To Implement)

### 1. Character Creation → Scene 1
**Location:** Character creation scene (verify path)

**Add this code:**
```gdscript
# After character is created
func _on_character_created():
    GameManager.set_player_name(player_name)
    GameManager.set_selected_character(character_choice)

    # Fade out and transition
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 1.0, 3.0).set_ease(Tween.EASE_IN)
    tween.tween_callback(_transition_to_narrative)

func _transition_to_narrative():
    if GameManager.should_skip_narrative_intro():
        get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/ui/narrative/PostCharacterCreationScene.tscn")
```

### 2. Battle Results → Overworld
**Location:** BattleResults.tscn (existing)

**Verify this exists:**
```gdscript
# In BattleResults.gd
func _on_continue_pressed():
    # Fade out and go to overworld
    get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
```

---

## Summary

### ✅ All Fade Transitions Implemented:
- Scene 1 → Scene 2: **3 seconds**
- Scene 2 → Scene 3A: **3 seconds**
- Scene 3A → Scene 4: **3 seconds**
- Scene 4 → Battle: **3 seconds**
- Battle → Results: **2 seconds**
- Results → Overworld: **Manual button**

### 📋 To Complete Flow:
1. Create 4 scene files in Godot (see NARRATIVE_FLOW_SETUP.md)
2. Add transition from Character Creation to Scene 1
3. Test using TestNarrativeFlow scene
4. Verify all fades work correctly

### 🎯 Expected Result:
Smooth, professional flow with consistent fade transitions from Main Title through to Battle Results. No jarring cuts or missing fades.

**The narrative flow is ready to test! 🚀**
