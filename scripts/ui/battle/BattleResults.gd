extends Control

# ============================================================================
# BATTLE RESULTS - End-of-battle SUCCESS screen
# ============================================================================
# Shows detailed battle completion stats for SUCCESSFUL battles only:
# - Hit breakdown (PERFECT, GOOD, OKAY, MISS counts)
# - Total XP earned and awarded
# - Max combo achieved
# - Level up notifications
# - Battle name and "You did it!" message
#
# Connects to BattleManager.battle_completed signal
# NOTE: Battle FAILURE uses a separate simple dialog (BattleFailure.gd)
#
# SCENE STRUCTURE:
# BattleResults (Control) - this script
# └─ CanvasLayer (always on top)
#     └─ Panel (semi-transparent overlay)
#         └─ VBoxContainer
#             ├─ TitleLabel - "BATTLE COMPLETE!" or "BATTLE FAILED!"
#             ├─ StatsContainer - shows hit counts, combo, strength
#             ├─ LevelUpLabel - shows level up notification
#             └─ ButtonContainer - Continue, Restart, Quit buttons

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var title_label: Label = $CanvasLayer/Panel/VBoxContainer/TitleLabel
@onready var strength_earned_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthEarnedLabel
@onready var strength_awarded_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthAwardedLabel
@onready var max_combo_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/MaxComboLabel
@onready var perfect_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/PerfectLabel
@onready var good_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/GoodLabel
@onready var okay_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/OkayLabel
@onready var miss_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/MissLabel
@onready var level_up_label: Label = $CanvasLayer/Panel/VBoxContainer/LevelUpLabel
@onready var continue_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/ContinueButton
@onready var restart_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/RestartButton

# Sound effects
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var restart_sound: AudioStreamPlayer = $RestartSound
@onready var continue_sound: AudioStreamPlayer = $ContinueSound

var battle_results: Dictionary = {}
var fade_rect: ColorRect
var fireworks_layer: Node2D
var fireworks_timer: Timer
var is_showing_fireworks: bool = false

# Firework color palettes
var note_colors = [Color.CYAN, Color.MAGENTA, Color.YELLOW]
var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE, Color.MAGENTA]

func _ready():
	# Start hidden - will only show when explicitly called
	visible = false
	if canvas_layer:
		canvas_layer.visible = false

	# Create fade overlay for scene transitions
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.z_index = 1000
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)

	# Create fireworks layer (between fade and canvas layer)
	fireworks_layer = Node2D.new()
	fireworks_layer.z_index = 50  # Behind canvas layer (100) but above fade
	add_child(fireworks_layer)

	# Create timer for spawning fireworks
	fireworks_timer = Timer.new()
	fireworks_timer.wait_time = randf_range(0.3, 0.8)  # Random interval
	fireworks_timer.timeout.connect(_spawn_firework)
	add_child(fireworks_timer)

	# DO NOT auto-connect to BattleManager signal
	# Results will be shown manually by the battle scene when appropriate

	# Connect buttons
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
		restart_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())

func _exit_tree():
	"""Clean up when scene is freed."""
	# Ensure we disconnect any lingering signal connections if they exist
	# (though we don't auto-connect anymore, this is a safety measure)
	if BattleManager and BattleManager.battle_completed.is_connected(Callable(self, "_on_battle_completed")):
		BattleManager.battle_completed.disconnect(Callable(self, "_on_battle_completed"))

func show_battle_results(results: Dictionary):
	"""Show battle results - called manually by battle scene at end."""
	battle_results = results
	show_results()

func show_results():
	"""Display the battle results for successful completion."""
	visible = true
	if canvas_layer:
		canvas_layer.visible = true

	# Start fireworks celebration!
	_start_fireworks()

	# Pause the game
	get_tree().paused = true

	# Update title - Always success (failure uses BattleFailure dialog)
	if title_label:
		title_label.text = "YOU DID IT!"
		title_label.modulate = Color.GREEN

	# Update stats - show "Earned X of Y" where Y is max possible
	var strength_awarded = battle_results.get("strength_awarded", 0)
	var strength_max_possible = battle_results.get("strength_max_possible", 0)

	if strength_earned_label:
		strength_earned_label.text = "Earned %d of %d Strength" % [strength_awarded, strength_max_possible]

	# Hide the redundant second label
	if strength_awarded_label:
		strength_awarded_label.visible = false

	if max_combo_label:
		max_combo_label.text = "Max Combo: %d" % battle_results.get("combo_max", 0)

	# Update hit breakdown
	var hit_counts = battle_results.get("hit_counts", {})
	if perfect_count_label:
		perfect_count_label.text = "PERFECT: %d" % hit_counts.get("PERFECT", 0)
	if good_count_label:
		good_count_label.text = "GOOD: %d" % hit_counts.get("GOOD", 0)
	if okay_count_label:
		okay_count_label.text = "OKAY: %d" % hit_counts.get("OKAY", 0)
	if miss_count_label:
		miss_count_label.text = "MISS: %d" % hit_counts.get("MISS", 0)

	# Check for level up (compare strength before and after)
	if level_up_label and GameManager:
		# The level up already happened in fade_to_title(), just check if we leveled
		# We can't easily track this without storing old level, so hide for now
		# User will see level up in future implementation
		level_up_label.visible = false

	# Hide restart button (only for success - failure has its own dialog)
	if restart_button:
		restart_button.visible = true

func _on_continue_pressed():
	"""Continue to next scene or return to title."""
	if continue_sound:
		continue_sound.play()

	# Fade to black then continue
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	# For now, go to title. Later: navigate to overworld or next battle
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _on_restart_pressed():
	"""Restart the battle."""
	if restart_sound:
		restart_sound.play()

	# Fade to black then restart
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _start_fireworks():
	"""Start the fireworks celebration effect."""
	is_showing_fireworks = true
	if fireworks_timer:
		fireworks_timer.start()

func _stop_fireworks():
	"""Stop spawning new fireworks."""
	is_showing_fireworks = false
	if fireworks_timer:
		fireworks_timer.stop()

func _spawn_firework():
	"""Spawn a single firework that launches and explodes."""
	if not is_showing_fireworks:
		return

	# Randomize next firework spawn time
	if fireworks_timer:
		fireworks_timer.wait_time = randf_range(0.3, 0.8)

	# Random launch position at bottom of screen
	var viewport_size = get_viewport().get_visible_rect().size
	var launch_x = randf_range(viewport_size.x * 0.2, viewport_size.x * 0.8)
	var launch_pos = Vector2(launch_x, viewport_size.y + 20)

	# Random target position (where firework will explode)
	var target_x = randf_range(viewport_size.x * 0.2, viewport_size.x * 0.8)
	var target_y = randf_range(viewport_size.y * 0.2, viewport_size.y * 0.6)
	var target_pos = Vector2(target_x, target_y)

	# Create trail particle for the ascending firework
	var trail = ColorRect.new()
	trail.size = Vector2(8, 8)
	trail.position = launch_pos
	trail.color = Color.WHITE
	fireworks_layer.add_child(trail)

	# Animate firework to target position
	var ascent_time = randf_range(0.8, 1.2)
	var tween = create_tween()
	tween.tween_property(trail, "position", target_pos, ascent_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(trail, "modulate:a", 0.0, 0.1)

	# Explode at peak
	tween.tween_callback(func(): _create_firework_explosion(target_pos))
	tween.tween_callback(trail.queue_free)

func _create_firework_explosion(position: Vector2):
	"""Create an explosion of particles at the given position."""
	# Randomly choose explosion type
	var explosion_type = randi() % 4  # 4 different patterns

	# Randomly choose color palette (note colors or rainbow)
	var use_rainbow = randf() > 0.5
	var color_palette = rainbow_colors if use_rainbow else note_colors

	# Number of particles varies by explosion type
	var particle_count = 0
	match explosion_type:
		0:  # Burst (circular)
			particle_count = 30
			_create_burst_explosion(position, particle_count, color_palette)
		1:  # Ring
			particle_count = 40
			_create_ring_explosion(position, particle_count, color_palette)
		2:  # Fountain (downward cascade)
			particle_count = 25
			_create_fountain_explosion(position, particle_count, color_palette)
		3:  # Willow (drooping)
			particle_count = 35
			_create_willow_explosion(position, particle_count, color_palette)

func _create_burst_explosion(position: Vector2, count: int, colors: Array):
	"""Create a circular burst explosion."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.position = position
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Explode outward in all directions
		var angle = (i / float(count)) * TAU
		var speed = randf_range(150, 300)
		var direction = Vector2(cos(angle), sin(angle))
		var distance = speed

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", position + direction * distance, 1.0).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 1.0)
		tween.tween_callback(particle.queue_free)

func _create_ring_explosion(position: Vector2, count: int, colors: Array):
	"""Create a ring-shaped explosion."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(5, 5)
		particle.position = position
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Create ring by having particles move outward at same speed
		var angle = (i / float(count)) * TAU
		var direction = Vector2(cos(angle), sin(angle))
		var distance = 200

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", position + direction * distance, 0.8)
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_callback(particle.queue_free)

func _create_fountain_explosion(position: Vector2, count: int, colors: Array):
	"""Create a fountain that cascades downward."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(7, 7)
		particle.position = position
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Arc upward then fall down
		var angle_offset = randf_range(-0.5, 0.5)
		var angle = -PI/2 + angle_offset  # Mostly upward
		var speed = randf_range(100, 200)
		var direction = Vector2(cos(angle), sin(angle))

		var tween = create_tween()
		tween.set_parallel(true)
		# Move up and out
		tween.tween_property(particle, "position", position + direction * speed, 0.6).set_ease(Tween.EASE_OUT)
		# Then fall down with gravity effect
		tween.tween_property(particle, "position:y", position.y + 400, 1.0).set_delay(0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5).set_delay(1.0)
		tween.tween_callback(particle.queue_free).set_delay(1.6)

func _create_willow_explosion(position: Vector2, count: int, colors: Array):
	"""Create a willow/drooping explosion."""
	for i in range(count):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 12)  # Elongated particles for trails
		particle.position = position
		particle.color = colors[randi() % colors.size()]
		fireworks_layer.add_child(particle)

		# Explode outward then droop down
		var angle = (i / float(count)) * TAU
		var speed = randf_range(100, 250)
		var direction = Vector2(cos(angle), sin(angle))

		var tween = create_tween()
		var mid_point = position + direction * speed
		var end_point = Vector2(mid_point.x, mid_point.y + 300)

		# Move outward
		tween.tween_property(particle, "position", mid_point, 0.5).set_ease(Tween.EASE_OUT)
		# Droop down
		tween.tween_property(particle, "position", end_point, 0.8).set_ease(Tween.EASE_IN)
		# Fade out
		var fade_tween = create_tween()
		fade_tween.tween_property(particle, "modulate:a", 0.0, 1.3)
		fade_tween.tween_callback(particle.queue_free)

func _fade_to_black():
	"""Fade overlay to black for scene transition."""
	# Stop fireworks when fading out
	_stop_fireworks()

	if not is_instance_valid(fade_rect):
		return
	fade_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
