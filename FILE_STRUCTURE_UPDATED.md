# ECOMB File Structure - Updated & Reorganized

## ✅ File System Reorganization Complete

All files have been renamed and reorganized with a consistent naming convention for scaling.

---

## Directory Structure

```
ecomb/
├── scripts/
│   ├── autoload/                           # Global managers (singletons)
│   │   ├── GameManager.gd                  ✅ Modified
│   │   ├── BattleManager.gd                ✅ Existing
│   │   ├── DataImporter.gd                 ✅ New
│   │   ├── MusicManager.gd                 ✅ Existing
│   │   ├── DialogManager.gd                ✅ Existing
│   │   └── Router.gd                       ✅ Existing
│   │
│   ├── ui/
│   │   ├── universal/                      # Reusable components
│   │   │   ├── TypewriterText.gd           ✅ Moved here
│   │   │   ├── CalibrationScene.gd         ✅ Universal (tutorial + options menu)
│   │   │   └── DialogContainer.gd          ✅ Existing (verify)
│   │   │
│   │   ├── cutscenes/                      # Story/narrative cutscenes
│   │   │   ├── CutsceneBase.gd             ✅ Renamed from NarrativeScene.gd
│   │   │   ├── PreGameCutscene1.gd         ✅ Renamed
│   │   │   └── PreGameCutscene2.gd         ✅ Renamed
│   │   │
│   │   ├── tutorial/                       # Tutorial scenes
│   │   │   └── PreGameTutorial.gd          ✅ Renamed
│   │   │
│   │   └── battle/                         # Battle UI components
│   │       ├── Conductor.gd                ✅ Modified (DSP time)
│   │       ├── Note.gd                     ✅ Modified (interpolation)
│   │       ├── BattleResults.gd            ✅ Existing
│   │       ├── BattleFailure.gd            ✅ Existing
│   │       └── [other battle UI]           ✅ Existing
│   │
│   ├── battle/
│   │   ├── levels/                         # Battle level scripts
│   │   │   └── PreGameBattle.gd            ✅ Renamed from Lesson1Battle.gd
│   │   │
│   │   └── data/                           # Battle data (JSON)
│   │       └── PreGameBattleData.json      ✅ Renamed from Lesson1Data.json
│   │
│   └── testing/                            # Testing tools
│       └── TestNarrativeFlow.gd            ✅ Updated paths
│
└── scenes/                                 # Godot scene files (.tscn)
    ├── ui/
    │   ├── universal/                      # Universal/reusable scenes
    │   │   └── CalibrationScene.tscn       📋 CREATE (universal calibration)
    │   │
    │   ├── cutscenes/                      # Story/narrative cutscenes
    │   │   ├── PreGameCutscene1.tscn       📋 CREATE
    │   │   └── PreGameCutscene2.tscn       📋 CREATE
    │   │
    │   ├── tutorial/                       # Tutorial scenes
    │   │   └── PreGameTutorial.tscn        📋 CREATE
    │   │
    │   └── battle/                         # Battle UI
    │       ├── BattleResults.tscn          ✅ Existing
    │       └── [note scenes, etc.]         ✅ Existing
    │
    ├── battle/                             # Battle scenes
    │   └── PreGameBattle.tscn              📋 RENAME from Lesson1Battle.tscn
    │
    ├── title/                              # Title/menu scenes
    │   └── MainTitle.tscn                  ✅ Existing
    │
    └── testing/                            # Testing scenes
        └── TestNarrativeFlow.tscn          📋 CREATE (optional)
```

---

## Naming Convention - PreGame Pattern

### ✅ New Consistent Naming:

**Cutscenes:** `PreGameCutscene1`, `PreGameCutscene2`, etc.
- Sequential numbering for story order
- Easy to insert new cutscenes: `PreGameCutscene1a`, `PreGameCutscene3`, etc.

**Tutorial:** `PreGameTutorial`
- Single tutorial for pre-game sequence
- Future tutorials: `AdvancedTutorial`, `BossTutorial`, etc.

**Battle:** `PreGameBattle`
- First battle in the game
- Future battles: `GymBattle1`, `BossBattle1`, `Championship`, etc.

**Universal:** No prefix (reusable everywhere)
- `CalibrationScene` - accessible from tutorial AND options menu
- `TypewriterText` - reusable component

---

## File Changes Summary

### ✅ Renamed Scripts:

| Old Path | New Path |
|----------|----------|
| `scripts/ui/TypewriterText.gd` | `scripts/ui/universal/TypewriterText.gd` |
| `scripts/ui/narrative/NarrativeScene.gd` | `scripts/ui/cutscenes/CutsceneBase.gd` |
| `scripts/ui/narrative/PostCharacterCreationScene.gd` | `scripts/ui/cutscenes/PreGameCutscene1.gd` |
| `scripts/ui/narrative/PreBattleNarrativeScene.gd` | `scripts/ui/cutscenes/PreGameCutscene2.gd` |
| `scripts/ui/tutorial/TutorialExplanationScene.gd` | `scripts/ui/tutorial/PreGameTutorial.gd` |
| `scripts/ui/tutorial/TutorialCalibrationScene.gd` | `scripts/ui/universal/CalibrationScene.gd` |
| `scripts/battle/levels/Lesson1Battle.gd` | `scripts/battle/levels/PreGameBattle.gd` |
| `scripts/battle/data/Lesson1Data.json` | `scripts/battle/data/PreGameBattleData.json` |

### ✅ Updated References:

All file paths updated in:
- `PreGameCutscene1.gd` - extends CutsceneBase, next_scene_path updated
- `PreGameCutscene2.gd` - extends CutsceneBase, next_scene_path updated
- `CutsceneBase.gd` - documentation updated
- `PreGameTutorial.gd` - next_scene_path updated, documentation updated
- `CalibrationScene.gd` - next_scene_path updated, documentation updated
- `PreGameBattle.gd` - level_data_path updated
- `TestNarrativeFlow.gd` - all scene paths updated

---

## Scene Flow (Updated)

```
Main Title
    ↓
Character Creation
    ↓ [3s fade]
PreGameCutscene1 (Welcome to Muscle Beach)
    ↓ [3s fade]
PreGameTutorial (4 steps with yellow borders)
    ↓ [3s fade]
CalibrationScene (Universal - 60 BPM)
    ↓ [3s fade]
PreGameCutscene2 (Meet Coach Flex Galaxy)
    ↓ [3s fade]
PreGameBattle (First rhythm battle)
    ↓ [2s fade]
Battle Results
    ↓ [manual]
Overworld
```

---

## Scenes to Create in Godot

### 1. PreGameCutscene1
**Path:** `scenes/ui/cutscenes/PreGameCutscene1.tscn`
- Root: `Control`
- Script: `res://scripts/ui/cutscenes/PreGameCutscene1.gd`
- No child nodes (dynamically created)

### 2. PreGameTutorial
**Path:** `scenes/ui/tutorial/PreGameTutorial.tscn`
- Root: `Control`
- Script: `res://scripts/ui/tutorial/PreGameTutorial.gd`
- No child nodes (dynamically created)

### 3. CalibrationScene
**Path:** `scenes/ui/universal/CalibrationScene.tscn`
- Root: `Control`
- Script: `res://scripts/ui/universal/CalibrationScene.gd`
- No child nodes (dynamically created)
- **Universal:** Used in tutorial flow AND options menu

### 4. PreGameCutscene2
**Path:** `scenes/ui/cutscenes/PreGameCutscene2.tscn`
- Root: `Control`
- Script: `res://scripts/ui/cutscenes/PreGameCutscene2.gd`
- No child nodes (dynamically created)

### 5. PreGameBattle
**Path:** `scenes/battle/PreGameBattle.tscn`
- **RENAME** existing `Lesson1Battle.tscn` to `PreGameBattle.tscn`
- Update script attachment to `PreGameBattle.gd`
- Scene structure already exists

---

## Scaling Strategy

### Adding More Cutscenes:
```
PreGameCutscene1.gd
PreGameCutscene2.gd
ChapterIntro1.gd     [FUTURE]
ChapterIntro2.gd     [FUTURE]
BossIntro1.gd        [FUTURE]
Victory1.gd          [FUTURE]
```

### Adding More Battles:
```
PreGameBattle.gd
GymBattle1.gd        [FUTURE]
GymBattle2.gd        [FUTURE]
BossBattle1.gd       [FUTURE]
Championship.gd      [FUTURE]
```

### Adding More Tutorials:
```
PreGameTutorial.gd
AdvancedTutorial.gd  [FUTURE]
BossTutorial.gd      [FUTURE]
```

---

## Universal Components

### Accessible from Multiple Locations:

**CalibrationScene:**
- First-time tutorial flow: Auto-advances to PreGameCutscene2
- Options menu: Returns to options menu
- Set `next_scene_path` before loading

**TypewriterText:**
- Reusable component for any text display
- Used by CutsceneBase
- Can be used in dialog, menus, etc.

---

## Benefits of New Structure

### ✅ Clear Naming:
- PreGame prefix = pre-game sequence content
- Sequential numbering for order
- Easy to insert new content

### ✅ Organized Directories:
- cutscenes/ = story content
- tutorial/ = teaching content
- universal/ = reusable everywhere
- battle/levels/ = gameplay content

### ✅ Scalable:
- Add PreGameCutscene3, PreGameCutscene4, etc.
- Add GymBattle1, GymBattle2, etc.
- Add ChapterIntro1, ChapterIntro2, etc.

### ✅ Universal Components:
- CalibrationScene works in tutorial AND options
- TypewriterText works in any scene
- Easy to add more universal components

---

## Testing

### Updated Test Scene:
`TestNarrativeFlow.gd` now uses new paths:
- PreGameCutscene1
- PreGameTutorial
- Calibration (Universal)
- PreGameCutscene2
- PreGameBattle
- Battle Results

Create `scenes/testing/TestNarrativeFlow.tscn` with this script to test the flow.

---

## Summary of Changes

✅ **8 files renamed** with git mv (preserves history)
✅ **All path references updated** in scripts
✅ **Documentation updated** in all files
✅ **Consistent PreGame naming** for scaling
✅ **Universal components** separated out
✅ **Testing tool** updated with new paths

**Ready to create scenes in Godot!**

---

## Quick Reference

### Current File Locations:

**Cutscenes:**
- `scripts/ui/cutscenes/CutsceneBase.gd`
- `scripts/ui/cutscenes/PreGameCutscene1.gd`
- `scripts/ui/cutscenes/PreGameCutscene2.gd`

**Tutorial:**
- `scripts/ui/tutorial/PreGameTutorial.gd`

**Universal:**
- `scripts/ui/universal/CalibrationScene.gd`
- `scripts/ui/universal/TypewriterText.gd`

**Battle:**
- `scripts/battle/levels/PreGameBattle.gd`
- `scripts/battle/data/PreGameBattleData.json`

**All references updated and ready to go! 🚀**
