# ECOMB File Structure & Naming Convention

## Directory Hierarchy

```
ecomb/
├── assets/                          # Game assets (sprites, audio, etc.)
│   ├── characters/
│   ├── music/
│   └── shaders/
│
├── scenes/                          # Godot scene files (.tscn)
│   ├── title/                       # Main menu and title screen
│   │   └── MainTitle.tscn
│   │
│   ├── character/                   # Character creation (if exists)
│   │   └── CharacterCreation.tscn   # [EXISTING - VERIFY PATH]
│   │
│   ├── ui/
│   │   ├── narrative/               # [NEW] Story/narrative scenes
│   │   │   ├── PostCharacterCreationScene.tscn    # [TO CREATE]
│   │   │   └── PreBattleNarrativeScene.tscn       # [TO CREATE]
│   │   │
│   │   ├── tutorial/                # [NEW] Tutorial scenes
│   │   │   ├── TutorialExplanationScene.tscn      # [TO CREATE]
│   │   │   └── TutorialCalibrationScene.tscn      # [TO CREATE]
│   │   │
│   │   ├── calibration/             # [NEW] Options menu calibration
│   │   │   └── CalibrationScene.tscn              # [FUTURE]
│   │   │
│   │   └── battle/                  # Battle UI components
│   │       ├── BattleResults.tscn                 # [EXISTING]
│   │       ├── BattleFailure.tscn                 # [EXISTING]
│   │       ├── GrooveBar.tscn                     # [EXISTING]
│   │       ├── WholeNote.tscn                     # [EXISTING]
│   │       ├── HalfNote.tscn                      # [EXISTING]
│   │       └── QuarterNote.tscn                   # [EXISTING]
│   │
│   ├── battle/                      # Battle scenes
│   │   └── Lesson1Battle.tscn                     # [EXISTING]
│   │
│   └── overworld/                   # Overworld/exploration
│       └── Overworld.tscn                         # [EXISTING - VERIFY]
│
├── scripts/                         # GDScript files
│   ├── autoload/                    # Autoload singletons
│   │   ├── MusicManager.gd                        # [EXISTING]
│   │   ├── GameManager.gd                         # [EXISTING - MODIFIED]
│   │   ├── Router.gd                              # [EXISTING]
│   │   ├── DialogManager.gd                       # [EXISTING]
│   │   ├── BattleManager.gd                       # [EXISTING]
│   │   └── DataImporter.gd                        # [NEW - CREATED]
│   │
│   ├── ui/
│   │   ├── TypewriterText.gd                      # [NEW] Reusable component
│   │   │
│   │   ├── narrative/               # [NEW] Narrative scene scripts
│   │   │   ├── NarrativeScene.gd                  # [NEW] Base class
│   │   │   ├── PostCharacterCreationScene.gd      # [NEW] Scene 1
│   │   │   └── PreBattleNarrativeScene.gd         # [NEW] Scene 4
│   │   │
│   │   ├── tutorial/                # [NEW] Tutorial scene scripts
│   │   │   ├── TutorialExplanationScene.gd        # [NEW] Scene 2
│   │   │   └── TutorialCalibrationScene.gd        # [NEW] Scene 3A
│   │   │
│   │   └── battle/                  # Battle UI scripts
│   │       ├── Conductor.gd                       # [EXISTING - MODIFIED]
│   │       ├── Note.gd                            # [EXISTING - MODIFIED]
│   │       ├── BattleResults.gd                   # [EXISTING]
│   │       ├── BattleFailure.gd                   # [EXISTING]
│   │       ├── BattleOptionsMenu.gd               # [EXISTING]
│   │       └── BattleBackground.gd                # [EXISTING]
│   │
│   └── battle/
│       ├── levels/                  # Battle level scripts
│       │   └── Lesson1Battle.gd                   # [EXISTING - MODIFIED]
│       │
│       └── data/                    # Battle data (JSON)
│           └── Lesson1Data.json                   # [EXISTING - MODIFIED]
│
├── ARCHITECTURE_CHANGES.md          # [NEW] Rhythm architecture docs
├── NARRATIVE_FLOW_SETUP.md          # [NEW] Narrative setup guide
└── project.godot                    # Godot project file
```

---

## Naming Conventions

### ✅ Current Good Practices

1. **Scene Files:** PascalCase with descriptive names
   - `PostCharacterCreationScene.tscn`
   - `TutorialExplanationScene.tscn`
   - `Lesson1Battle.tscn`

2. **Script Files:** PascalCase matching scene names
   - `PostCharacterCreationScene.gd`
   - `TutorialExplanationScene.gd`
   - `Lesson1Battle.gd`

3. **Directories:** lowercase with underscores or camelCase
   - `autoload/`
   - `ui/narrative/`
   - `battle/levels/`

4. **Autoloads:** PascalCase singletons
   - `GameManager.gd`
   - `BattleManager.gd`
   - `DataImporter.gd`

### 📋 Naming Pattern

```
Feature/Purpose + Type + .extension

Examples:
- PostCharacterCreationScene.gd  (Purpose: PostCharacterCreation, Type: Scene)
- TutorialExplanationScene.tscn  (Purpose: TutorialExplanation, Type: Scene)
- TypewriterText.gd              (Purpose: TypewriterText, Type: Component)
- Lesson1Battle.gd               (Purpose: Lesson1Battle, Type: Level)
- Lesson1Data.json               (Purpose: Lesson1, Type: Data)
```

---

## File Categories

### 📂 Core Components (Reusable)

**Location:** `scripts/ui/`

- `TypewriterText.gd` - Reusable typewriter text display
- **Future:** `DialogBox.gd`, `FadeTransition.gd`, etc.

**Purpose:** Components used across multiple scenes

---

### 📂 Base Classes (Inheritance)

**Location:** `scripts/ui/narrative/`

- `NarrativeScene.gd` - Base for narrative scenes

**Purpose:** Abstract classes extended by specific scenes

---

### 📂 Scene-Specific Scripts

**Location:** `scripts/ui/[category]/`

**Narrative Scenes:**
- `scripts/ui/narrative/PostCharacterCreationScene.gd`
- `scripts/ui/narrative/PreBattleNarrativeScene.gd`

**Tutorial Scenes:**
- `scripts/ui/tutorial/TutorialExplanationScene.gd`
- `scripts/ui/tutorial/TutorialCalibrationScene.gd`

**Battle Scenes:**
- `scripts/battle/levels/Lesson1Battle.gd`
- `scripts/battle/levels/Lesson2Battle.gd` [FUTURE]

**Purpose:** Scene-specific logic that extends base classes

---

### 📂 Autoload Singletons

**Location:** `scripts/autoload/`

**Current:**
- `MusicManager.gd` - Music playback management
- `GameManager.gd` - Game state, save/load, settings
- `Router.gd` - Scene routing/navigation
- `DialogManager.gd` - Dialog display system
- `BattleManager.gd` - Battle mechanics and constants
- `DataImporter.gd` - Data conversion utilities

**Purpose:** Global systems accessible from any scene

---

### 📂 Battle Data

**Location:** `scripts/battle/data/`

- `Lesson1Data.json` - Lesson 1 battle data (notes, dialog, triggers)
- **Future:** `Lesson2Data.json`, `Boss1Data.json`, etc.

**Purpose:** Level data in JSON format

---

## Suggested Improvements

### 1. Consistent Scene Suffixes

**Current:**
- ✅ `PostCharacterCreationScene.gd`
- ✅ `TutorialExplanationScene.gd`
- ❓ `Lesson1Battle.gd` (missing "Scene" suffix)

**Recommendation:**
- Keep as-is for battles (Battle suffix is clear)
- Use "Scene" suffix for narrative/tutorial/UI scenes
- Use "Manager" suffix for autoloads

### 2. Group Related Features

**Current structure is good:**
```
ui/
  narrative/  (narrative-specific scenes)
  tutorial/   (tutorial-specific scenes)
  battle/     (battle UI components)
```

**Future scaling:**
```
ui/
  narrative/  (story scenes)
  tutorial/   (tutorial scenes)
  battle/     (battle UI)
  shop/       (shop scenes) [FUTURE]
  menu/       (menu scenes) [FUTURE]
```

### 3. Version/Iteration Naming

**For lessons/battles:**
```
Lesson1Battle.gd  ✅ Good
Lesson2Battle.gd  ✅ Future
Boss1Battle.gd    ✅ Future
```

**For data:**
```
Lesson1Data.json  ✅ Good
Lesson2Data.json  ✅ Future
```

---

## Scene File Naming Best Practices

### ✅ DO:
- Use PascalCase: `TutorialExplanationScene.tscn`
- Be descriptive: `PostCharacterCreationScene` (not `Intro1`)
- Match script names: `TutorialExplanationScene.tscn` + `TutorialExplanationScene.gd`
- Use consistent suffixes: `Scene`, `Manager`, `Data`

### ❌ DON'T:
- Use abbreviations: `TutExpScene.tscn` ❌
- Use generic names: `Scene1.tscn` ❌
- Mix naming styles: `tutorial_scene.tscn` ❌
- Mismatch script/scene: `Tutorial.tscn` + `TutorialScene.gd` ❌

---

## Script Organization Within Files

### Standard Script Structure:

```gdscript
extends [BaseClass]
class_name [ClassName]  # If reusable

## ============================================================================
## [SCRIPT PURPOSE IN CAPS]
## ============================================================================
## Brief description of what this script does.
## Key features, usage notes, etc.
## ============================================================================

# Exports (inspector-visible variables)
@export var config_value: int = 10

# Public variables
var public_state: bool = false

# Private variables (prefix with _)
var _private_state: int = 0

# Onready variables
@onready var ui_element = $UIElement

# Constants
const MAX_VALUE: int = 100

# Signals
signal event_triggered

# Lifecycle methods
func _ready():
    pass

func _process(delta):
    pass

# Public methods
func public_method():
    pass

# Private methods (prefix with _)
func _private_method():
    pass
```

---

## Future Scaling Recommendations

### As ECOMB Grows:

1. **More Battles:**
   ```
   scripts/battle/levels/
     Lesson1Battle.gd
     Lesson2Battle.gd
     Boss1Battle.gd
     Boss2Battle.gd
   ```

2. **More Narrative Scenes:**
   ```
   scripts/ui/narrative/
     PostCharacterCreationScene.gd
     PreBattleNarrativeScene.gd
     VictoryNarrativeScene.gd  [FUTURE]
     StoryChapter2Scene.gd      [FUTURE]
   ```

3. **Character System:**
   ```
   scripts/character/
     CharacterCreation.gd
     CharacterCustomization.gd
     CharacterStats.gd
   ```

4. **Shop/Upgrades:**
   ```
   scripts/shop/
     ShopScene.gd
     UpgradeSystem.gd
   ```

5. **More Autoloads (if needed):**
   ```
   scripts/autoload/
     GameManager.gd
     BattleManager.gd
     ProgressionManager.gd  [FUTURE]
     ShopManager.gd         [FUTURE]
   ```

---

## Summary: Current File Status

### ✅ Created and Committed:
- `scripts/ui/TypewriterText.gd`
- `scripts/ui/narrative/NarrativeScene.gd`
- `scripts/ui/narrative/PostCharacterCreationScene.gd`
- `scripts/ui/narrative/PreBattleNarrativeScene.gd`
- `scripts/ui/tutorial/TutorialExplanationScene.gd`
- `scripts/ui/tutorial/TutorialCalibrationScene.gd`
- `scripts/autoload/DataImporter.gd`
- `NARRATIVE_FLOW_SETUP.md`
- `ARCHITECTURE_CHANGES.md`

### ✅ Modified:
- `scripts/ui/battle/Conductor.gd`
- `scripts/ui/battle/Note.gd`
- `scripts/battle/levels/Lesson1Battle.gd`
- `scripts/battle/data/Lesson1Data.json`
- `scripts/autoload/GameManager.gd`

### 📋 To Create in Godot:
- `scenes/ui/narrative/PostCharacterCreationScene.tscn`
- `scenes/ui/narrative/PreBattleNarrativeScene.tscn`
- `scenes/tutorial/TutorialExplanationScene.tscn`
- `scenes/tutorial/TutorialCalibrationScene.tscn`

### ✅ Already Exists:
- `scenes/title/MainTitle.tscn`
- `scenes/battle/Lesson1Battle.tscn`
- `scenes/ui/battle/BattleResults.tscn`
- `scenes/ui/battle/[Note scenes, GrooveBar, etc.]`

---

## Naming Convention Grade: A- 🎯

**Strengths:**
✅ Consistent PascalCase for scripts and scenes
✅ Descriptive names (not abbreviated)
✅ Good directory hierarchy (ui/narrative, ui/tutorial)
✅ Autoloads clearly named with "Manager" suffix
✅ Data files clearly named with "Data" suffix

**Minor Suggestions:**
- Consider "Scene" suffix for all non-autoload scripts (optional)
- Keep battle naming convention as-is (Battle suffix is clear)

**Overall:** Your naming convention is solid and will scale well! 🚀
