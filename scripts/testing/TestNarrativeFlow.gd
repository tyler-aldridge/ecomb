extends Control

## ============================================================================
## TEST NARRATIVE FLOW SCENE
## ============================================================================
## Quick testing tool to jump to any scene in the narrative flow.
## Includes fade transitions between all scenes for proper testing.
##
## USAGE:
## 1. Create scene in Godot with this script attached
## 2. Click buttons to jump to any scene in the flow
## 3. Test complete flow from start to finish
## 4. Verify all fade transitions work correctly
##
## This is a TESTING TOOL ONLY - remove before production.
## ============================================================================

# Scene paths
const SCENES = {
	"main_title": "res://scenes/title/MainTitle.tscn",
	"character_creation": "res://scenes/character/CharacterCreation.tscn",  # VERIFY PATH
	"scene_1_narration": "res://scenes/ui/narrative/PostCharacterCreationScene.tscn",
	"scene_2_tutorial": "res://scenes/tutorial/TutorialExplanationScene.tscn",
	"scene_3a_calibration": "res://scenes/tutorial/TutorialCalibrationScene.tscn",
	"scene_4_pre_battle": "res://scenes/ui/narrative/PreBattleNarrativeScene.tscn",
	"scene_5_battle": "res://scenes/battle/Lesson1Battle.tscn",
	"scene_6_results": "res://scenes/ui/battle/BattleResults.tscn"
}

# UI elements
var button_container: VBoxContainer
var fade_overlay: ColorRect
var title_label: Label

func _ready():
	setup_ui()

func setup_ui():
	"""Create test UI with buttons for each scene."""
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.size = get_viewport().get_visible_rect().size
	add_child(bg)

	# Title
	title_label = Label.new()
	title_label.text = "ECOMB Narrative Flow - Test Scene"
	title_label.position = Vector2(660, 50)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(title_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Click any button to jump to that scene with fade transition.\nTest complete flow by clicking through sequentially."
	instructions.position = Vector2(460, 150)
	instructions.add_theme_font_size_override("font_size", 20)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	add_child(instructions)

	# Button container
	button_container = VBoxContainer.new()
	button_container.position = Vector2(660, 250)
	button_container.add_theme_constant_override("separation", 20)
	add_child(button_container)

	# Create buttons for each scene
	create_button("Main Title", "main_title")
	create_button("Character Creation", "character_creation")
	create_separator()
	create_button("Scene 1: Post-Character Narration", "scene_1_narration")
	create_button("Scene 2: Tutorial Explanation", "scene_2_tutorial")
	create_button("Scene 3A: Tutorial Calibration", "scene_3a_calibration")
	create_button("Scene 4: Pre-Battle Narrative", "scene_4_pre_battle")
	create_separator()
	create_button("Scene 5: Lesson 1 Battle", "scene_5_battle")
	create_button("Scene 6: Battle Results", "scene_6_results")
	create_separator()
	create_button("🚀 TEST COMPLETE FLOW (AUTO)", "complete_flow")

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.modulate.a = 0.0
	fade_overlay.z_index = 100
	add_child(fade_overlay)

	# Fade in on start
	fade_in()

func create_button(text: String, scene_key: String):
	"""Create a navigation button."""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(600, 60)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func(): navigate_to_scene(scene_key))
	button_container.add_child(button)

func create_separator():
	"""Create visual separator between button groups."""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	button_container.add_child(spacer)

func navigate_to_scene(scene_key: String):
	"""Navigate to a scene with fade transition."""
	if scene_key == "complete_flow":
		start_complete_flow()
		return

	if not SCENES.has(scene_key):
		push_error("Scene key not found: " + scene_key)
		return

	var scene_path = SCENES[scene_key]

	# Verify scene exists
	if not FileAccess.file_exists(scene_path):
		push_warning("Scene file not created yet: " + scene_path)
		title_label.text = "⚠️ Scene not created: " + scene_path
		title_label.modulate = Color.ORANGE
		await get_tree().create_timer(2.0).timeout
		title_label.text = "ECOMB Narrative Flow - Test Scene"
		title_label.modulate = Color.YELLOW
		return

	# Fade out and load scene
	fade_out(scene_path)

func fade_in():
	"""Fade in from black."""
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_OUT)

func fade_out(next_scene: String):
	"""Fade out to black and load scene."""
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): get_tree().change_scene_to_file(next_scene))

func start_complete_flow():
	"""Auto-test the complete narrative flow."""
	title_label.text = "🚀 Starting Complete Flow Test..."
	title_label.modulate = Color.GREEN

	# Wait 2 seconds then start
	await get_tree().create_timer(2.0).timeout

	# Set flags to first-time player state
	GameManager.set_setting("has_seen_tutorial", false)
	GameManager.set_setting("has_calibrated", false)

	# Start from Scene 1 (assumes character creation is done)
	navigate_to_scene("scene_1_narration")
