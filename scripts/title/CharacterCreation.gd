extends Control

signal closed
signal finished  # Re-added this signal for the fade transition

@onready var character_grid: GridContainer = $CenterContainer/VBoxContainer/CharacterGrid
@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/InputSection/NameContainer/NameInput
@onready var favorite_input: LineEdit = $CenterContainer/VBoxContainer/InputSection/FavoriteContainer/FavoriteInput
@onready var start_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton
@onready var cancel_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/CancelButton

# Character data
var characters = [
	{
		"id": "muscle_man",
		"name": "Muscle Man"
	}
]

var selected_character_id: String = ""

func _ready():
	# Setup character grid
	if character_grid:
		character_grid.columns = 3  # Adjust based on how many characters you'll have
	
	# Force muscle man animation to play
	var muscle_sprite = character_grid.get_node_or_null("MuscleManContainer/MuscleManSprite")
	if muscle_sprite:
		muscle_sprite.play("idle")
	
	# Disable interaction with Muscle Man button since he's auto-selected
	var muscle_button = character_grid.get_node_or_null("MuscleManContainer/MuscleManButton")
	if muscle_button:
		muscle_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect buttons
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
		start_btn.disabled = true
		# Prevent interaction when disabled
		start_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# Connect input validation
	if name_input:
		name_input.text_changed.connect(_validate_inputs)
		name_input.placeholder_text = "Enter your name"
		name_input.add_theme_color_override("font_color", Color.BLACK)
		name_input.add_theme_color_override("font_placeholder_color", Color.BLACK)
		name_input.add_theme_font_size_override("font_size", 45)
		
	if favorite_input:
		favorite_input.text_changed.connect(_validate_inputs)
		favorite_input.placeholder_text = "What do you love most?"
		favorite_input.add_theme_color_override("font_color", Color.BLACK)
		favorite_input.add_theme_color_override("font_placeholder_color", Color.BLACK)
		favorite_input.add_theme_font_size_override("font_size", 45)
	
	# Create character selection
	_setup_character_grid()
	
	# Auto-select Muscle Man since he's the only option
	if characters.size() > 0:
		_select_character(characters[0].id)

func _setup_character_grid():
	# For now, we'll let you add Muscle Man manually in the editor
	# The character grid should have an AnimatedSprite2D node called "MuscleManSprite"
	# and a Button node called "MuscleManButton" that you can connect to _on_muscle_man_clicked()
	
	# Auto-select muscle man since he's the only option
	_select_character("muscle_man")

func _on_muscle_man_clicked():
	_select_character("muscle_man")

func _select_character(character_id: String):
	selected_character_id = character_id
	
	# No need to update button states since there's only one character
	# _update_button_states(character_id)
	
	# Validate inputs to enable/disable start button
	_validate_inputs("")

func _validate_inputs(_text: String = ""):
	# Enable start button only if character selected AND both inputs filled
	var name_filled = name_input and name_input.text.strip_edges() != ""
	var favorite_filled = favorite_input and favorite_input.text.strip_edges() != ""
	var character_selected = selected_character_id != ""
	
	var should_enable = name_filled and favorite_filled and character_selected
	
	if start_btn:
		start_btn.disabled = not should_enable
		# Control mouse interaction based on enabled state
		if should_enable:
			start_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			start_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_start_pressed():
	if selected_character_id != "" and name_input and favorite_input:
		var player_name = name_input.text.strip_edges()
		var favorite_thing = favorite_input.text.strip_edges()
		
		if player_name != "" and favorite_thing != "":
			# Save data to GameManager
			GameManager.set_player_name(player_name)
			GameManager.set_favorite_thing(favorite_thing)
			GameManager.set_selected_character(selected_character_id)

			# Emit finished signal to trigger fade transition in MainTitle
			emit_signal("finished")

func _on_cancel_pressed():
	emit_signal("closed")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		emit_signal("closed")
